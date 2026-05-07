import path from 'node:path';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import Redis from 'ioredis';

import { buildApp } from '../src/app';
import { loadEnv } from '../src/config/env';

const backendRoot = path.resolve(__dirname, '..');
dotenv.config({ path: path.join(backendRoot, '.env'), override: false });
dotenv.config({ path: path.join(backendRoot, '.env.local'), override: true });

const buildConfig = () => {
  const env = loadEnv();

  return {
    ...env,
    databaseUrl:
      env.databaseUrl ?? 'postgresql://pawmate@127.0.0.1:5432/pawmate',
    redisUrl: env.redisUrl ?? 'redis://127.0.0.1:6379',
  };
};

const normalizeEmail = (value: string) => value.trim().toLowerCase();

const buildPlusAliasEmail = (baseEmail: string, suffix: string) => {
  const normalizedBase = normalizeEmail(baseEmail);
  const atIndex = normalizedBase.indexOf('@');

  if (atIndex <= 0) {
    throw new Error('AUTH_LIVE_PROOF_EMAIL must be a valid email address.');
  }

  const localPart = normalizedBase.slice(0, atIndex).split('+')[0];
  const domainPart = normalizedBase.slice(atIndex + 1);

  return `${localPart}+${suffix}@${domainPart}`;
};

const wait = (ms: number) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

const readAuthSettings = async (supabaseUrl: string, publishableKey: string) => {
  const response = await fetch(`${supabaseUrl}auth/v1/settings`, {
    headers: {
      apikey: publishableKey,
      Authorization: `Bearer ${publishableKey}`,
    },
  });

  if (!response.ok) {
    return {
      status: response.status,
      google: null,
      apple: null,
    };
  }

  const payload = (await response.json()) as {
    external?: {
      google?: boolean;
      apple?: boolean;
    };
  };

  return {
    status: response.status,
    google: payload.external?.google ?? null,
    apple: payload.external?.apple ?? null,
  };
};

const findSupabaseUserByEmail = async (
  adminClient: ReturnType<typeof createClient>,
  email: string,
) => {
  for (let page = 1; page <= 5; page += 1) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 200,
    });

    if (error) {
      throw error;
    }

    const matchedUser = data.users.find(
      (user) => normalizeEmail(user.email ?? '') === normalizeEmail(email),
    );

    if (matchedUser) {
      return matchedUser;
    }

    if (data.users.length < 200) {
      break;
    }
  }

  return undefined;
};

const deleteRedisSessionsForUser = async (redis: Redis, userId?: string) => {
  if (!userId) {
    return;
  }

  const userSessionSetKey = `auth:user-sessions:${userId}`;
  const sessionIds = await redis.zrange(userSessionSetKey, 0, -1);
  const sessionKeys = sessionIds.map((sessionId) => `auth:session:${sessionId}`);

  if (sessionKeys.length > 0) {
    await redis.del(...sessionKeys);
  }

  await redis.del(userSessionSetKey);
};

const smoke = async () => {
  const config = buildConfig();

  if (!config.supabaseUrl || !config.supabaseAnonKey || !config.supabaseServiceRoleKey) {
    throw new Error(
      'SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, and SUPABASE_SECRET_KEY are required for auth live proof.',
    );
  }

  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: config.databaseUrl,
      },
    },
  });
  const redis = new Redis(config.redisUrl!, { maxRetriesPerRequest: 1 });
  const app = buildApp({ logger: false }, { config });
  const publishableClient = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
  const adminClient = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
  const proofBaseEmail = process.env.AUTH_LIVE_PROOF_EMAIL?.trim();
  if (!proofBaseEmail) {
    throw new Error(
      'AUTH_LIVE_PROOF_EMAIL is required so the live proof can use a deliverable address alias.',
    );
  }

  const email = buildPlusAliasEmail(proofBaseEmail, `live-auth-${Date.now()}`);
  const password = 'Pawmate123';

  const cleanup = async () => {
    const localUser = await prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    await deleteRedisSessionsForUser(redis, localUser?.id);
    await prisma.user.deleteMany({ where: { email } });

    const remoteUser = await findSupabaseUserByEmail(adminClient, email);
    if (remoteUser) {
      await adminClient.auth.admin.deleteUser(remoteUser.id);
    }
  };

  try {
    await cleanup();
    await app.ready();

    const settings = await readAuthSettings(
      config.supabaseUrl,
      config.supabaseAnonKey,
    );

    const registerResponse = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email,
        password,
      },
    });

    const localUserAfterRegister = await prisma.user.findUnique({
      where: { email },
      select: { id: true, emailVerified: true },
    });

    const adminGenerateLinkResponse = await adminClient.auth.admin.generateLink({
      type: 'signup',
      email,
      password,
    });

    if (registerResponse.statusCode !== 201) {
      let verifyAfterAdminFallback:
        | {
            status: number;
            body: unknown;
          }
        | null = null;
      let loginAfterAdminFallback:
        | {
            status: number;
            body: unknown;
          }
        | null = null;

      if (
        !localUserAfterRegister &&
        !adminGenerateLinkResponse.error &&
        adminGenerateLinkResponse.data.properties.hashed_token
      ) {
        const now = new Date();
        await prisma.user.create({
          data: {
            email,
            passwordHash: await bcrypt.hash(password, 12),
            authProvider: 'email',
            emailVerified: false,
            failedLoginAttempts: 0,
            createdAt: now,
            updatedAt: now,
          },
        });

        const verifyResponse = await app.inject({
          method: 'POST',
          url: '/auth/verify-email',
          payload: {
            tokenHash: adminGenerateLinkResponse.data.properties.hashed_token,
          },
        });

        const loginResponse = await app.inject({
          method: 'POST',
          url: '/auth/login',
          payload: {
            email,
            password,
          },
        });

        verifyAfterAdminFallback = {
          status: verifyResponse.statusCode,
          body: verifyResponse.json(),
        };
        loginAfterAdminFallback = {
          status: loginResponse.statusCode,
          body:
            loginResponse.statusCode >= 400
              ? loginResponse.json()
              : {
                  user: loginResponse.json().user,
                },
        };
      }

      const googleOAuthResponse = await app.inject({
        method: 'POST',
        url: '/auth/oauth',
        payload: {
          provider: 'google',
          credential: 'invalid-google-id-token',
        },
      });

      const appleOAuthResponse = await app.inject({
        method: 'POST',
        url: '/auth/oauth',
        payload: {
          provider: 'apple',
          credential: 'invalid-apple-id-token',
        },
      });

      console.log(
        JSON.stringify(
          {
            email,
            register: {
              status: registerResponse.statusCode,
              body: registerResponse.json(),
            },
            localUserAfterFailedRegister: {
              exists: Boolean(localUserAfterRegister),
              emailVerified: localUserAfterRegister?.emailVerified ?? null,
            },
            adminGenerateLink: {
              error: adminGenerateLinkResponse.error
                ? {
                    message: adminGenerateLinkResponse.error.message,
                    status: adminGenerateLinkResponse.error.status,
                    code: adminGenerateLinkResponse.error.code,
                  }
                : null,
              properties: adminGenerateLinkResponse.data
                ? {
                    verificationType:
                      adminGenerateLinkResponse.data.properties.verification_type,
                    hasEmailOtp: Boolean(
                      adminGenerateLinkResponse.data.properties.email_otp,
                    ),
                    hasHashedToken: Boolean(
                      adminGenerateLinkResponse.data.properties.hashed_token,
                    ),
                  }
                : null,
            },
            fallbackVerifyFlow: {
              verifyEmail: verifyAfterAdminFallback,
              login: loginAfterAdminFallback,
            },
            oauthProviderSettings: settings,
            oauthDiagnostics: {
              google: {
                status: googleOAuthResponse.statusCode,
                body:
                  googleOAuthResponse.statusCode >= 400
                    ? googleOAuthResponse.json()
                    : null,
              },
              apple: {
                status: appleOAuthResponse.statusCode,
                body:
                  appleOAuthResponse.statusCode >= 400
                    ? appleOAuthResponse.json()
                    : null,
              },
            },
          },
          null,
          2,
        ),
      );
      return;
    }

    const loginBeforeVerifyResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email,
        password,
      },
    });

    const resendResponse = await app.inject({
      method: 'POST',
      url: '/auth/resend-verification',
      payload: {
        email,
      },
    });

    let remoteUser = await findSupabaseUserByEmail(adminClient, email);
    if (!remoteUser) {
      await wait(1200);
      remoteUser = await findSupabaseUserByEmail(adminClient, email);
    }

    if (!remoteUser) {
      throw new Error('Remote Supabase auth user was not created after register.');
    }

    const verifyResponse =
      adminGenerateLinkResponse.error ||
      !adminGenerateLinkResponse.data.properties.hashed_token
        ? null
        : await app.inject({
            method: 'POST',
            url: '/auth/verify-email',
            payload: {
              tokenHash: adminGenerateLinkResponse.data.properties.hashed_token,
            },
          });

    const loginAfterVerifyResponse = verifyResponse
      ? await app.inject({
          method: 'POST',
          url: '/auth/login',
          payload: {
            email,
            password,
            rememberMe: true,
          },
        })
      : null;

    const googleOAuthResponse = await app.inject({
      method: 'POST',
      url: '/auth/oauth',
      payload: {
        provider: 'google',
        credential: 'invalid-google-id-token',
      },
    });

    const appleOAuthResponse = await app.inject({
      method: 'POST',
      url: '/auth/oauth',
      payload: {
        provider: 'apple',
        credential: 'invalid-apple-id-token',
      },
    });

    const googlePayload =
      googleOAuthResponse.statusCode >= 400 ? googleOAuthResponse.json() : null;
    const applePayload =
      appleOAuthResponse.statusCode >= 400 ? appleOAuthResponse.json() : null;

    console.log(
      JSON.stringify(
        {
          email,
          register: {
            status: registerResponse.statusCode,
            body: registerResponse.json(),
          },
          loginBeforeVerify: {
            status: loginBeforeVerifyResponse.statusCode,
            body:
              loginBeforeVerifyResponse.statusCode >= 400
                ? loginBeforeVerifyResponse.json()
                : null,
          },
          resendVerification: {
            status: resendResponse.statusCode,
            body: resendResponse.json(),
          },
          remoteSupabaseUser: {
            found: true,
            emailConfirmedAt: remoteUser.email_confirmed_at,
          },
          verifyEmail: verifyResponse
            ? {
                status: verifyResponse.statusCode,
                body: verifyResponse.json(),
              }
            : {
                status: null,
                error:
                  adminGenerateLinkResponse.error?.message ??
                  'No verification link returned.',
              },
          loginAfterVerify: loginAfterVerifyResponse
            ? {
                status: loginAfterVerifyResponse.statusCode,
                body:
                  loginAfterVerifyResponse.statusCode >= 400
                    ? loginAfterVerifyResponse.json()
                    : {
                        user: loginAfterVerifyResponse.json().user,
                      },
              }
            : null,
          oauthProviderSettings: settings,
          oauthDiagnostics: {
            google: {
              status: googleOAuthResponse.statusCode,
              body: googlePayload,
            },
            apple: {
              status: appleOAuthResponse.statusCode,
              body: applePayload,
            },
          },
        },
        null,
        2,
      ),
    );
  } finally {
    await app.close();
    await cleanup();
    await prisma.$disconnect();
    redis.disconnect();
    await publishableClient.auth.signOut();
  }
};

smoke().catch((error) => {
  console.error(error);
  process.exit(1);
});

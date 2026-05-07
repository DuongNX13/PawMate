import {
  type AuthResponse,
  type AuthTokenResponse,
  type UserIdentity,
} from '@supabase/supabase-js';

import { type AppConfig } from '../config/env';
import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import { createSupabaseAdminClient } from '../infrastructure/supabase-admin-client';
import { createSupabaseAuthClient } from '../infrastructure/supabase-auth-client';
import {
  type EmailVerificationDispatchResult,
  type EmailVerificationGateway,
  type OAuthIdentity,
  type OAuthProvider,
  type OAuthVerifier,
} from '../services/auth/auth-service';

type SupabaseAuthClient = NonNullable<ReturnType<typeof createSupabaseAuthClient>>;
type SupabaseAdminClient = {
  auth: {
    admin: {
      listUsers: (params: {
        page?: number;
        perPage?: number;
      }) => Promise<{
        data: {
          users: Array<{
            id: string;
            email?: string | null;
          }>;
        };
        error: {
          message: string;
        } | null;
      }>;
      generateLink: (input: {
        type: 'signup';
        email: string;
        password: string;
        options?: {
          redirectTo?: string;
        };
      }) => Promise<{
        data: {
          user: {
            id: string;
          } | null;
        };
        error: {
          message: string;
        } | null;
      }>;
      updateUserById: (
        userId: string,
        attributes: {
          email_confirm: boolean;
        },
      ) => Promise<{
        data: {
          user: {
            id: string;
          } | null;
        };
        error: {
          message: string;
        } | null;
      }>;
    };
  };
};

type GatewayDependencies = {
  authClient?: SupabaseAuthClient;
  adminClient?: SupabaseAdminClient;
};

const normalizeEmail = (email?: string | null) => email?.trim().toLowerCase();

const getVerificationRedirectUrl = (config: AppConfig) =>
  config.supabaseAuthMobileRedirectUrl ?? config.supabaseAuthRedirectUrl;

const unwrapSupabaseUser = (
  response: AuthResponse | AuthTokenResponse,
  field?: string,
) => {
  if (response.error) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      response.error.message,
      401,
      field,
    );
  }

  if (!response.data.user) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'Khong lay duoc thong tin nguoi dung tu Supabase.',
      401,
      field,
    );
  }

  return response.data.user;
};

const getProviderIdentity = (
  identities: UserIdentity[] | undefined,
  provider: OAuthProvider,
) => identities?.find((identity) => identity.provider === provider);

const readProviderUserId = (
  identity: UserIdentity | undefined,
  fallbackUserId: string,
) => {
  const providerSub = identity?.identity_data?.sub;
  if (typeof providerSub === 'string' && providerSub.trim()) {
    return providerSub.trim();
  }

  return identity?.id ?? identity?.identity_id ?? fallbackUserId;
};

const isEmailRateLimitError = (message?: string) =>
  /email rate limit exceeded/i.test(message ?? '');

const findUserByEmail = async (
  adminClient: SupabaseAdminClient,
  email: string,
) => {
  const searchPage = async (page: number): Promise<{ id: string } | undefined> => {
    const response = await adminClient.auth.admin.listUsers({
      page,
      perPage: 200,
    });

    if (response.error) {
      throw new AppError(
        AUTH_ERROR_CODES.verificationUnavailable,
        response.error.message,
        502,
        'email',
      );
    }

    const matchedUser = response.data.users.find(
      (user) => normalizeEmail(user.email) === normalizeEmail(email),
    );
    if (matchedUser) {
      return matchedUser;
    }

    if (response.data.users.length < 200 || page >= 5) {
      return undefined;
    }

    return searchPage(page + 1);
  };

  return searchPage(1);
};

const ensureVerificationFallback = async (
  config: AppConfig,
  adminClient: SupabaseAdminClient | undefined,
  user: {
    id: string;
    email: string;
    displayName?: string;
    password: string;
  },
  redirectTo: string | undefined,
): Promise<EmailVerificationDispatchResult> => {
  if (
    config.nodeEnv === 'production' ||
    !config.auth.emailRateLimitAutoVerifyFallback ||
    !adminClient
  ) {
    throw new AppError(
      AUTH_ERROR_CODES.verificationUnavailable,
      'Email verification tam thoi khong kha dung.',
      502,
      'email',
    );
  }

  const generatedLinkResponse = await adminClient.auth.admin.generateLink({
    type: 'signup',
    email: user.email,
    password: user.password,
    ...(redirectTo ? { options: { redirectTo } } : {}),
  });

  let remoteUserId = generatedLinkResponse.data.user?.id;
  if (!remoteUserId) {
    remoteUserId = (await findUserByEmail(adminClient, user.email))?.id;
  }

  if (generatedLinkResponse.error && !remoteUserId) {
    throw new AppError(
      AUTH_ERROR_CODES.verificationUnavailable,
      generatedLinkResponse.error.message,
      502,
      'email',
    );
  }

  if (!remoteUserId) {
    throw new AppError(
      AUTH_ERROR_CODES.verificationUnavailable,
      'Khong the tu dong xac minh email trong local fallback.',
      502,
      'email',
    );
  }

  const confirmResponse = await adminClient.auth.admin.updateUserById(
    remoteUserId,
    {
      email_confirm: true,
    },
  );

  if (confirmResponse.error) {
    throw new AppError(
      AUTH_ERROR_CODES.verificationUnavailable,
      confirmResponse.error.message,
      502,
      'email',
    );
  }

  return {
    status: 'auto-verified',
  };
};

export const createSupabaseEmailVerificationGateway = (
  config: AppConfig,
  dependencies: GatewayDependencies = {},
): EmailVerificationGateway | undefined => {
  const authClient = dependencies.authClient ?? createSupabaseAuthClient(config);
  const adminClient =
    dependencies.adminClient ?? createSupabaseAdminClient(config);

  if (!authClient) {
    return undefined;
  }

  return {
    async sendEmailVerification(user) {
      const redirectTo = getVerificationRedirectUrl(config);
      const response = await authClient.signUp({
        email: user.email,
        password: user.password,
        options: {
          ...(redirectTo ? { emailRedirectTo: redirectTo } : {}),
          data: {
            local_user_id: user.id,
            display_name: user.displayName,
          },
        },
      });

      if (response.error) {
        if (isEmailRateLimitError(response.error.message)) {
          return ensureVerificationFallback(
            config,
            adminClient,
            user,
            redirectTo,
          );
        }

        throw new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          response.error.message,
          502,
          'email',
        );
      }

      return {
        status: 'verification-email-sent',
      };
    },

    async verifyEmailToken(input) {
      const response =
        'tokenHash' in input
          ? await authClient.verifyOtp({
              token_hash: input.tokenHash,
              type: 'signup',
            })
          : await authClient.verifyOtp({
              email: input.email,
              token: input.token,
              type: 'signup',
            });

      if (response.error) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidVerificationToken,
          response.error.message,
          400,
          'tokenHash' in input ? 'tokenHash' : 'token',
        );
      }

      const email = normalizeEmail(response.data.user?.email);
      if (!email) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidVerificationToken,
          'Supabase khong tra ve email hop le sau khi xac minh.',
          400,
        );
      }

      return { email };
    },

    async resendEmailVerification(input) {
      const redirectTo = getVerificationRedirectUrl(config);
      const response = await authClient.resend({
        type: 'signup',
        email: input.email,
        options: {
          ...(redirectTo ? { emailRedirectTo: redirectTo } : {}),
        },
      });

      if (response.error) {
        throw new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          response.error.message,
          502,
          'email',
        );
      }
    },
  };
};

export const createSupabaseOAuthVerifier = (
  config: AppConfig,
  dependencies: GatewayDependencies = {},
): OAuthVerifier | undefined => {
  const authClient = dependencies.authClient ?? createSupabaseAuthClient(config);

  if (!authClient) {
    return undefined;
  }

  return {
    async verify(provider, credential, context = {}): Promise<OAuthIdentity> {
      const response = await authClient.signInWithIdToken({
        provider,
        token: credential,
        ...(context.accessToken ? { access_token: context.accessToken } : {}),
        ...(context.nonce ? { nonce: context.nonce } : {}),
      });

      const user = unwrapSupabaseUser(response, 'credential');
      const email = normalizeEmail(user.email);

      if (!email) {
        throw new AppError(
          AUTH_ERROR_CODES.oauthVerificationFailed,
          'Tai khoan OAuth khong co email hop le.',
          401,
          'credential',
        );
      }

      const providerIdentity = getProviderIdentity(user.identities, provider);

      return {
        email,
        providerUserId: readProviderUserId(providerIdentity, user.id),
        displayName: (() => {
          if (typeof user.user_metadata?.full_name === 'string') {
            return user.user_metadata.full_name;
          }

          if (typeof user.user_metadata?.name === 'string') {
            return user.user_metadata.name;
          }

          return undefined;
        })(),
      };
    },
  };
};

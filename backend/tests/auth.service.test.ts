import jwt from 'jsonwebtoken';

import { type AppConfig } from '../src/config/env';
import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { createAuthService } from '../src/services/auth/auth-service';

const buildConfig = (): AppConfig => ({
  appName: 'PawMate Backend',
  nodeEnv: 'test',
  host: '127.0.0.1',
  port: 3000,
  logLevel: 'error',
  auth: {
    accessTokenSecret: 'test-access-secret',
    refreshTokenSecret: 'test-refresh-secret',
    accessTokenTtlMinutes: 15,
    refreshTokenTtlDays: 30,
    maxLoginAttempts: 5,
    lockoutMinutes: 15,
    maxActiveSessions: 3,
    socialLoginEnabled: true,
    emailRateLimitAutoVerifyFallback: false,
  },
  databaseUrl: undefined,
  redisUrl: undefined,
  supabaseProjectRef: undefined,
  supabaseUrl: 'https://demo.supabase.co/',
  supabaseAnonKey: undefined,
  supabaseServiceRoleKey: undefined,
  supabaseAuthRedirectUrl: undefined,
  supabaseAuthMobileRedirectUrl: undefined,
  oauthVerification: {
    googleAllowedAudiences: [],
    appleAllowedAudiences: [],
  },
  supabaseBuckets: {
    avatars: 'avatars',
    petPhotos: 'pet-photos',
    posts: 'posts',
  },
});

const extractRefreshPayload = (refreshToken: string) =>
  jwt.decode(refreshToken) as jwt.JwtPayload & { sid: string; sub: string };

describe('Auth service', () => {
  it('registers a new user and rejects duplicates or malformed email', async () => {
    const service = createAuthService({
      config: buildConfig(),
      emailVerificationGateway: {
        sendEmailVerification: jest.fn().mockResolvedValue({
          status: 'verification-email-sent',
        }),
        verifyEmailToken: jest.fn().mockResolvedValue({
          email: 'shelly@pawmate.vn',
        }),
        resendEmailVerification: jest.fn().mockResolvedValue(undefined),
      },
    });

    await expect(
      service.register({
        email: 'shelly@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toMatchObject({
      message: 'Check your email',
    });

    await expect(
      service.register({
        email: 'bad-email',
        password: 'Pawmate123',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidEmail,
    });

    await expect(
      service.register({
        email: 'shelly@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.duplicateEmail,
    });
  });

  it('rolls back the local user when the verification email gateway fails', async () => {
    const emailVerificationGateway = {
      sendEmailVerification: jest
        .fn()
        .mockRejectedValueOnce(
          new AppError(
            AUTH_ERROR_CODES.verificationUnavailable,
            'email rate limit exceeded',
            502,
            'email',
          ),
        )
        .mockResolvedValueOnce({
          status: 'verification-email-sent',
        }),
      verifyEmailToken: jest.fn().mockResolvedValue({
        email: 'rollback@pawmate.vn',
      }),
      resendEmailVerification: jest.fn().mockResolvedValue(undefined),
    };
    const service = createAuthService({
      config: buildConfig(),
      emailVerificationGateway,
    });

    await expect(
      service.register({
        email: 'rollback@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.verificationUnavailable,
    });

    await expect(
      service.register({
        email: 'rollback@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toMatchObject({
      message: 'Check your email',
    });
  });

  it('marks the user verified immediately when email fallback auto-verifies', async () => {
    const service = createAuthService({
      config: buildConfig(),
      emailVerificationGateway: {
        sendEmailVerification: jest.fn().mockResolvedValue({
          status: 'auto-verified',
        }),
        verifyEmailToken: jest.fn().mockResolvedValue({
          email: 'fallback@pawmate.vn',
        }),
        resendEmailVerification: jest.fn().mockResolvedValue(undefined),
      },
    });

    await expect(
      service.register({
        email: 'fallback@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toMatchObject({
      message: 'Verification temporarily bypassed. You can log in now.',
    });

    await expect(
      service.login({
        email: 'fallback@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toHaveProperty('accessToken');
  });

  it('locks the account after repeated wrong passwords and recovers after the lock window', async () => {
    let currentTime = new Date('2026-04-08T03:00:00.000Z');
    const service = createAuthService({
      config: buildConfig(),
      now: () => currentTime,
    });

    const registration = await service.register({
      email: 'lock@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);

    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'wrong-password',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidCredentials,
    });
    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'wrong-password',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidCredentials,
    });
    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'wrong-password',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidCredentials,
    });
    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'wrong-password',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidCredentials,
    });

    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'wrong-password',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.accountLocked,
    });

    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.accountLocked,
    });

    currentTime = new Date('2026-04-08T03:16:00.000Z');

    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toHaveProperty('accessToken');
  });

  it('rotates refresh tokens, rejects expired tokens, and detects token reuse', async () => {
    const config = buildConfig();
    const service = createAuthService({ config });
    const registration = await service.register({
      email: 'rotate@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);

    const loginResult = await service.login({
      email: 'rotate@pawmate.vn',
      password: 'Pawmate123',
      rememberMe: true,
    });

    const rotated = await service.refresh({
      refreshToken: loginResult.refreshToken,
    });
    expect(rotated.refreshToken).not.toBe(loginResult.refreshToken);

    await expect(
      service.refresh({
        refreshToken: loginResult.refreshToken,
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.refreshTokenReuse,
    });

    const payload = extractRefreshPayload(rotated.refreshToken);
    const expiredToken = jwt.sign(
      {
        typ: 'refresh',
        sid: payload.sid,
      },
      config.auth.refreshTokenSecret,
      {
        subject: payload.sub,
        expiresIn: -1,
      },
    );

    await expect(
      service.refresh({
        refreshToken: expiredToken,
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.expiredRefreshToken,
    });
  });

  it('revokes all active sessions when logout is called', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'logout-all@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);

    const firstSession = await service.login({
      email: 'logout-all@pawmate.vn',
      password: 'Pawmate123',
      rememberMe: true,
      deviceId: 'device-a',
    });
    const secondSession = await service.login({
      email: 'logout-all@pawmate.vn',
      password: 'Pawmate123',
      rememberMe: true,
      deviceId: 'device-b',
    });

    await service.logout({
      refreshToken: firstSession.refreshToken,
    });

    await expect(
      service.refresh({
        refreshToken: secondSession.refreshToken,
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.refreshTokenReuse,
    });
  });

  it('supports OAuth for new users and reuses the same account on repeat sign-in', async () => {
    const oauthVerifier = {
      verify: jest.fn().mockResolvedValue({
        email: 'oauth@pawmate.vn',
        providerUserId: 'google-user-1',
        displayName: 'OAuth User',
      }),
    };
    const service = createAuthService({
      config: buildConfig(),
      oauthVerifier,
    });

    const firstLogin = await service.oauth({
      provider: 'google',
      credential: 'demo-token',
    });
    const secondLogin = await service.oauth({
      provider: 'google',
      credential: 'demo-token',
    });

    expect(firstLogin.user.email).toBe('oauth@pawmate.vn');
    expect(secondLogin.user.id).toBe(firstLogin.user.id);
    expect(oauthVerifier.verify).toHaveBeenCalledTimes(2);
  });

  it('blocks OAuth when social login is disabled for the current MVP', async () => {
    const config = buildConfig();
    config.auth.socialLoginEnabled = false;
    const service = createAuthService({
      config,
      oauthVerifier: {
        verify: jest.fn(),
      },
    });

    await expect(
      service.oauth({
        provider: 'google',
        credential: 'demo-token',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.providerDisabled,
      field: 'provider',
    });
  });

  it('verifies email tokens and unlocks email login afterwards', async () => {
    const emailVerificationGateway = {
      sendEmailVerification: jest.fn().mockResolvedValue({
        status: 'verification-email-sent',
      }),
      verifyEmailToken: jest.fn().mockResolvedValue({
        email: 'verify@pawmate.vn',
      }),
      resendEmailVerification: jest.fn().mockResolvedValue(undefined),
    };
    const service = createAuthService({
      config: buildConfig(),
      emailVerificationGateway,
    });

    const registration = await service.register({
      email: 'verify@pawmate.vn',
      password: 'Pawmate123',
    });

    await expect(
      service.login({
        email: 'verify@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.emailUnverified,
    });

    await expect(
      service.verifyEmail({
        tokenHash: 'supabase-signup-hash',
      }),
    ).resolves.toMatchObject({
      userId: registration.userId,
      email: 'verify@pawmate.vn',
      message: 'Email verified',
    });

    expect(emailVerificationGateway.verifyEmailToken).toHaveBeenCalledWith({
      tokenHash: 'supabase-signup-hash',
    });

    await expect(
      service.login({
        email: 'verify@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toHaveProperty('accessToken');
  });

  it('resends verification for unverified users and short-circuits verified users', async () => {
    const emailVerificationGateway = {
      sendEmailVerification: jest.fn().mockResolvedValue({
        status: 'verification-email-sent',
      }),
      verifyEmailToken: jest.fn().mockResolvedValue({
        email: 'resend@pawmate.vn',
      }),
      resendEmailVerification: jest.fn().mockResolvedValue(undefined),
    };
    const service = createAuthService({
      config: buildConfig(),
      emailVerificationGateway,
    });

    const registration = await service.register({
      email: 'resend@pawmate.vn',
      password: 'Pawmate123',
    });

    await expect(
      service.resendVerification({
        email: 'resend@pawmate.vn',
      }),
    ).resolves.toEqual({
      message: 'Verification email resent',
    });

    expect(
      emailVerificationGateway.resendEmailVerification,
    ).toHaveBeenCalledWith({
      email: 'resend@pawmate.vn',
    });

    await service.markEmailVerified(registration.userId);

    await expect(
      service.resendVerification({
        email: 'resend@pawmate.vn',
      }),
    ).resolves.toEqual({
      message: 'Email already verified',
    });

    expect(emailVerificationGateway.resendEmailVerification).toHaveBeenCalledTimes(
      1,
    );
  });

  it('raises a clear conflict when the same email is already linked to another provider', async () => {
    const service = createAuthService({
      config: buildConfig(),
      oauthVerifier: {
        verify: jest.fn().mockResolvedValue({
          email: 'conflict@pawmate.vn',
          providerUserId: 'apple-user-1',
        }),
      },
    });

    const registration = await service.register({
      email: 'conflict@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);

    await expect(
      service.oauth({
        provider: 'apple',
        credential: 'apple-token',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthConflict,
    });
  });

  it('verifies access tokens and rejects malformed ones', async () => {
    const service = createAuthService({
      config: buildConfig(),
    });

    const registration = await service.register({
      email: 'access@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);
    const loginResult = await service.login({
      email: 'access@pawmate.vn',
      password: 'Pawmate123',
    });

    expect(service.verifyAccessToken(loginResult.accessToken)).toMatchObject({
      userId: registration.userId,
    });

    expect(() => service.verifyAccessToken('broken-token')).toThrow(AppError);
  });

  it('passes provider context through to the OAuth verifier', async () => {
    const oauthVerifier = {
      verify: jest.fn().mockResolvedValue({
        email: 'context@pawmate.vn',
        providerUserId: 'google-user-ctx',
        displayName: 'Context User',
      }),
    };
    const service = createAuthService({
      config: buildConfig(),
      oauthVerifier,
    });

    await service.oauth({
      provider: 'google',
      credential: 'google-id-token',
      accessToken: 'google-access-token',
      nonce: 'nonce-value',
      redirectUri: 'pawmate://auth/callback',
    });

    expect(oauthVerifier.verify).toHaveBeenCalledWith(
      'google',
      'google-id-token',
      {
        accessToken: 'google-access-token',
        nonce: 'nonce-value',
        redirectUri: 'pawmate://auth/callback',
      },
    );
  });
});

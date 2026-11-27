import jwt from 'jsonwebtoken';

import { type AppConfig } from '../src/config/env';
import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import {
  createAuthService,
  type AuthSessionResult,
} from '../src/services/auth/auth-service';

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
  it('registers a new user, masks duplicates, and rejects malformed email', async () => {
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
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
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
    ).resolves.toMatchObject({
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
      verificationStatus: 'pending',
    });
  });

  it('validates v0.27 phone format and registration field limits', async () => {
    const service = createAuthService({ config: buildConfig() });

    await expect(
      service.register({
        email: 'phone@pawmate.vn',
        password: 'Pawmate123',
        phone: '901234567',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidPhone,
      field: 'phone',
    });

    await expect(
      service.register({
        email: 'password@pawmate.vn',
        password: `A1${'x'.repeat(63)}`,
        phone: '0901234567',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.weakPassword,
      field: 'password',
    });

    await expect(
      service.register({
        email: `${'a'.repeat(245)}@example.com`,
        password: 'Pawmate123',
        phone: '0901234567',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidEmail,
      field: 'email',
    });
  });

  it('keeps a pending user and a generic response when the provider fails', async () => {
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
    ).resolves.toMatchObject({
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
      verificationStatus: 'pending',
    });

    await expect(
      service.register({
        email: 'rollback@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toMatchObject({
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
    });
    expect(
      emailVerificationGateway.sendEmailVerification,
    ).toHaveBeenCalledTimes(1);
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

  it('tracks repeated wrong passwords without letting an attacker lock out a correct login', async () => {
    const currentTime = new Date('2026-04-08T03:00:00.000Z');
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
      code: AUTH_ERROR_CODES.invalidCredentials,
    });

    await expect(
      service.login({
        email: 'lock@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toHaveProperty('accessToken');
  });

  it('rotates refresh tokens, rejects an immediate duplicate, and rejects expired tokens', async () => {
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
      code: AUTH_ERROR_CODES.invalidRefreshToken,
    });

    const payload = extractRefreshPayload(rotated.refreshToken);
    const expiredToken = jwt.sign(
      {
        typ: 'refresh',
        sid: payload.sid,
      },
      config.auth.refreshTokenSecret,
      {
        algorithm: 'HS256',
        keyid: 'refresh-v1',
        issuer: 'pawmate-api',
        audience: 'pawmate-mobile',
        subject: payload.sub,
        expiresIn: -61,
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

  it('allows only one concurrent refresh without revoking the winning token family', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'concurrent-refresh@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);
    const loginResult = await service.login({
      email: 'concurrent-refresh@pawmate.vn',
      password: 'Pawmate123',
      rememberMe: true,
    });

    const results = await Promise.allSettled([
      service.refresh({ refreshToken: loginResult.refreshToken }),
      service.refresh({ refreshToken: loginResult.refreshToken }),
    ]);
    const fulfilled = results.filter(
      (result): result is PromiseFulfilledResult<AuthSessionResult> =>
        result.status === 'fulfilled',
    );
    const rejected = results.filter(
      (result): result is PromiseRejectedResult => result.status === 'rejected',
    );

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect(rejected[0].reason).toMatchObject({
      code: AUTH_ERROR_CODES.invalidRefreshToken,
    });
    await expect(
      service.verifyAccessToken(fulfilled[0].value.accessToken),
    ).resolves.toMatchObject({ userId: registration.userId });
  });

  it('cannot restore an active session after refresh races logout-all', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'refresh-logout-race@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);
    const loginResult = await service.login({
      email: 'refresh-logout-race@pawmate.vn',
      password: 'Pawmate123',
      rememberMe: true,
    });

    const [refreshResult, logoutResult] = await Promise.allSettled([
      service.refresh({ refreshToken: loginResult.refreshToken }),
      service.logout({ refreshToken: loginResult.refreshToken }),
    ]);

    expect(logoutResult.status).toBe('fulfilled');
    await expect(
      service.verifyAccessToken(loginResult.accessToken),
    ).rejects.toMatchObject({ code: AUTH_ERROR_CODES.unauthorized });
    if (refreshResult.status === 'fulfilled') {
      await expect(
        service.verifyAccessToken(refreshResult.value.accessToken),
      ).rejects.toMatchObject({ code: AUTH_ERROR_CODES.unauthorized });
      await expect(
        service.refresh({ refreshToken: refreshResult.value.refreshToken }),
      ).rejects.toMatchObject({ code: AUTH_ERROR_CODES.refreshTokenReuse });
    }
  });

  it('refreshes an existing session without evicting another active session', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'refresh-session-limit@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);
    const sessions = await Promise.all(
      ['device-a', 'device-b', 'device-c'].map((deviceId) =>
        service.login({
          email: 'refresh-session-limit@pawmate.vn',
          password: 'Pawmate123',
          rememberMe: true,
          deviceId,
        }),
      ),
    );

    const rotated = await service.refresh({
      refreshToken: sessions[2].refreshToken,
    });

    await expect(
      service.verifyAccessToken(sessions[0].accessToken),
    ).resolves.toHaveProperty('userId', registration.userId);
    await expect(
      service.verifyAccessToken(sessions[1].accessToken),
    ).resolves.toHaveProperty('userId', registration.userId);
    await expect(
      service.verifyAccessToken(rotated.accessToken),
    ).resolves.toHaveProperty('userId', registration.userId);
  });

  it('enforces the active-session limit across concurrent logins', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'concurrent-session-limit@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);

    const sessions = await Promise.all(
      ['device-a', 'device-b', 'device-c', 'device-d'].map((deviceId) =>
        service.login({
          email: 'concurrent-session-limit@pawmate.vn',
          password: 'Pawmate123',
          rememberMe: true,
          deviceId,
        }),
      ),
    );
    const verificationResults = await Promise.allSettled(
      sessions.map((session) => service.verifyAccessToken(session.accessToken)),
    );

    expect(
      verificationResults.filter((result) => result.status === 'fulfilled'),
    ).toHaveLength(3);
    expect(
      verificationResults.filter((result) => result.status === 'rejected'),
    ).toHaveLength(1);
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
    await expect(
      service.verifyAccessToken(firstSession.accessToken),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.unauthorized,
    });
    await expect(
      service.verifyAccessToken(secondSession.accessToken),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.unauthorized,
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
      user: {
        id: registration.userId,
        email: 'verify@pawmate.vn',
        emailVerified: true,
      },
      accessToken: expect.any(String),
      refreshToken: expect.any(String),
      accessTokenExpiresAt: expect.any(String),
      refreshTokenExpiresAt: expect.any(String),
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
    const now = new Date('2026-07-14T10:00:00.000Z');
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
      now: () => now,
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
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
      verificationStatus: 'pending',
      verificationExpiresAt: '2026-07-14T10:05:00.000Z',
      resendAvailableAt: '2026-07-14T10:01:00.000Z',
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
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
      verificationStatus: 'pending',
      verificationExpiresAt: '2026-07-14T10:05:00.000Z',
      resendAvailableAt: '2026-07-14T10:01:00.000Z',
    });

    expect(
      emailVerificationGateway.resendEmailVerification,
    ).toHaveBeenCalledTimes(1);
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

    await expect(
      service.verifyAccessToken(loginResult.accessToken),
    ).resolves.toMatchObject({
      userId: registration.userId,
    });

    await expect(service.verifyAccessToken('broken-token')).rejects.toThrow(
      AppError,
    );
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

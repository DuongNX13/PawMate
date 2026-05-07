import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { createAuthService } from '../src/services/auth/auth-service';
import { createPetService } from '../src/services/pets/pet-service';

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
  supabaseUrl: undefined,
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

describe('Auth routes', () => {
  it('serves a friendly localhost auth landing page instead of a 404 at root', async () => {
    const config = buildConfig();
    const app = buildApp(
      { logger: false },
      {
        config,
        authService: createAuthService({ config }),
        petService: createPetService(config),
      },
    );
    await app.ready();

    const rootResponse = await app.inject({
      method: 'GET',
      url: '/',
    });

    expect(rootResponse.statusCode).toBe(200);
    expect(rootResponse.headers['content-type']).toContain('text/html');
    expect(rootResponse.body).toContain('PawMate Auth');
    expect(rootResponse.body).toContain('Route GET:/ not found');

    const callbackResponse = await app.inject({
      method: 'GET',
      url: '/auth/callback',
    });

    expect(callbackResponse.statusCode).toBe(200);
    expect(callbackResponse.headers['content-type']).toContain('text/html');
    expect(callbackResponse.body).toContain('Xác minh tài khoản');

    await app.close();
  });

  it('supports register, login, refresh, and logout', async () => {
    const config = buildConfig();
    const authService = createAuthService({ config });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService: createPetService(config),
      },
    );
    await app.ready();

    const registerResponse = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'route@pawmate.vn',
        password: 'Pawmate123',
      },
    });

    expect(registerResponse.statusCode).toBe(201);
    const registerPayload = registerResponse.json();
    expect(registerPayload.message).toBe('Check your email');

    await authService.markEmailVerified(registerPayload.userId);

    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'route@pawmate.vn',
        password: 'Pawmate123',
        rememberMe: true,
      },
    });

    expect(loginResponse.statusCode).toBe(200);
    const loginPayload = loginResponse.json();
    expect(loginPayload).toHaveProperty('accessToken');
    expect(loginPayload).toHaveProperty('refreshToken');

    const refreshResponse = await app.inject({
      method: 'POST',
      url: '/auth/refresh',
      payload: {
        refreshToken: loginPayload.refreshToken,
      },
    });

    expect(refreshResponse.statusCode).toBe(200);
    const refreshPayload = refreshResponse.json();
    expect(refreshPayload.refreshToken).not.toBe(loginPayload.refreshToken);

    const logoutResponse = await app.inject({
      method: 'POST',
      url: '/auth/logout',
      payload: {
        refreshToken: refreshPayload.refreshToken,
      },
    });

    expect(logoutResponse.statusCode).toBe(204);

    await app.close();
  });

  it('supports resend-verification and verify-email routes', async () => {
    const config = buildConfig();
    const emailVerificationGateway = {
      sendEmailVerification: jest.fn().mockResolvedValue({
        status: 'verification-email-sent',
      }),
      verifyEmailToken: jest.fn().mockResolvedValue({
        email: 'verify-route@pawmate.vn',
      }),
      resendEmailVerification: jest.fn().mockResolvedValue(undefined),
    };
    const authService = createAuthService({
      config,
      emailVerificationGateway,
    });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService: createPetService(config),
      },
    );
    await app.ready();

    const registerResponse = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'verify-route@pawmate.vn',
        password: 'Pawmate123',
      },
    });

    expect(registerResponse.statusCode).toBe(201);

    const resendResponse = await app.inject({
      method: 'POST',
      url: '/auth/resend-verification',
      payload: {
        email: 'verify-route@pawmate.vn',
      },
    });

    expect(resendResponse.statusCode).toBe(200);
    expect(resendResponse.json()).toEqual({
      message: 'Verification email resent',
    });

    const verifyResponse = await app.inject({
      method: 'POST',
      url: '/auth/verify-email',
      payload: {
        tokenHash: 'supabase-signup-hash',
      },
    });

    expect(verifyResponse.statusCode).toBe(200);
    expect(verifyResponse.json()).toMatchObject({
      email: 'verify-route@pawmate.vn',
      message: 'Email verified',
    });

    expect(emailVerificationGateway.resendEmailVerification).toHaveBeenCalledWith(
      {
        email: 'verify-route@pawmate.vn',
      },
    );
    expect(emailVerificationGateway.verifyEmailToken).toHaveBeenCalledWith({
      tokenHash: 'supabase-signup-hash',
    });

    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'verify-route@pawmate.vn',
        password: 'Pawmate123',
      },
    });

    expect(loginResponse.statusCode).toBe(200);

    await app.close();
  });

  it('supports oauth route with provider token context', async () => {
    const config = buildConfig();
    const oauthVerifier = {
      verify: jest.fn().mockResolvedValue({
        email: 'oauth-route@pawmate.vn',
        providerUserId: 'google-oauth-route',
        displayName: 'OAuth Route',
      }),
    };
    const authService = createAuthService({
      config,
      oauthVerifier,
    });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService: createPetService(config),
      },
    );
    await app.ready();

    const oauthResponse = await app.inject({
      method: 'POST',
      url: '/auth/oauth',
      payload: {
        provider: 'google',
        credential: 'google-id-token',
        accessToken: 'google-access-token',
        nonce: 'nonce-value',
        redirectUri: 'pawmate://auth/callback',
      },
    });

    expect(oauthResponse.statusCode).toBe(200);
    expect(oauthResponse.json()).toMatchObject({
      user: {
        email: 'oauth-route@pawmate.vn',
        authProvider: 'google',
        emailVerified: true,
      },
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

    await app.close();
  });

  it('returns a clear 403 when social login is disabled', async () => {
    const config = buildConfig();
    config.auth.socialLoginEnabled = false;
    const app = buildApp(
      { logger: false },
      {
        config,
        authService: createAuthService({
          config,
          oauthVerifier: {
            verify: jest.fn(),
          },
        }),
        petService: createPetService(config),
      },
    );
    await app.ready();

    const oauthResponse = await app.inject({
      method: 'POST',
      url: '/auth/oauth',
      payload: {
        provider: 'google',
        credential: 'google-id-token',
      },
    });

    expect(oauthResponse.statusCode).toBe(403);
    expect(oauthResponse.json()).toMatchObject({
      success: false,
      error: {
        code: AUTH_ERROR_CODES.providerDisabled,
        field: 'provider',
      },
    });

    await app.close();
  });
});

import { type AppConfig } from '../src/config/env';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { createSupabaseEmailVerificationGateway } from '../src/integrations/supabase-auth-gateway';

const buildConfig = (): AppConfig => ({
  appName: 'PawMate Backend',
  nodeEnv: 'development',
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
    socialLoginEnabled: false,
    emailRateLimitAutoVerifyFallback: true,
  },
  databaseUrl: undefined,
  redisUrl: undefined,
  supabaseProjectRef: 'qeoowayxfqyhfcgnrfnv',
  supabaseUrl: 'https://qeoowayxfqyhfcgnrfnv.supabase.co/',
  supabaseAnonKey: 'sb_publishable_test',
  supabaseServiceRoleKey: 'sb_secret_test',
  supabaseAuthRedirectUrl: 'https://app.pawmate.example/auth/callback',
  supabaseAuthMobileRedirectUrl: 'pawmate://auth/callback',
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

describe('Supabase email verification gateway', () => {
  it('returns a sent status when Supabase signUp succeeds', async () => {
    const gateway = createSupabaseEmailVerificationGateway(buildConfig(), {
      authClient: {
        signUp: jest.fn().mockResolvedValue({
          data: { user: { id: 'remote-1' } },
          error: null,
        }),
        verifyOtp: jest.fn(),
        resend: jest.fn(),
      } as never,
    });

    await expect(
      gateway?.sendEmailVerification({
        id: 'local-1',
        email: 'sent@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toEqual({
      status: 'verification-email-sent',
    });
  });

  it('auto-verifies locally when Supabase email quota is rate-limited', async () => {
    const gateway = createSupabaseEmailVerificationGateway(buildConfig(), {
      authClient: {
        signUp: jest.fn().mockResolvedValue({
          data: { user: null },
          error: {
            message: 'email rate limit exceeded',
          },
        }),
        verifyOtp: jest.fn(),
        resend: jest.fn(),
      } as never,
      adminClient: {
        auth: {
          admin: {
            generateLink: jest.fn().mockResolvedValue({
              data: {
                user: { id: 'remote-2' },
              },
              error: null,
            }),
            updateUserById: jest.fn().mockResolvedValue({
              data: {
                user: {
                  id: 'remote-2',
                  email_confirmed_at: '2026-04-22T00:00:00Z',
                },
              },
              error: null,
            }),
            listUsers: jest.fn(),
          },
        },
      } as never,
    });

    await expect(
      gateway?.sendEmailVerification({
        id: 'local-2',
        email: 'fallback@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).resolves.toEqual({
      status: 'auto-verified',
    });
  });

  it('keeps failing clearly when fallback is disabled', async () => {
    const config = buildConfig();
    config.auth.emailRateLimitAutoVerifyFallback = false;
    const gateway = createSupabaseEmailVerificationGateway(config, {
      authClient: {
        signUp: jest.fn().mockResolvedValue({
          data: { user: null },
          error: {
            message: 'email rate limit exceeded',
          },
        }),
        verifyOtp: jest.fn(),
        resend: jest.fn(),
      } as never,
    });

    await expect(
      gateway?.sendEmailVerification({
        id: 'local-3',
        email: 'blocked@pawmate.vn',
        password: 'Pawmate123',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.verificationUnavailable,
      field: 'email',
    });
  });
});

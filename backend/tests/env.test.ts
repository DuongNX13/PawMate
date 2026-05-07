import { loadEnv } from '../src/config/env';

const ORIGINAL_ENV = { ...process.env };

const resetEnv = () => {
  process.env = { ...ORIGINAL_ENV };
  delete process.env.PORT;
  delete process.env.HOST;
  delete process.env.NODE_ENV;
  delete process.env.LOG_LEVEL;
  delete process.env.AUTH_ACCESS_TOKEN_SECRET;
  delete process.env.AUTH_REFRESH_TOKEN_SECRET;
  delete process.env.AUTH_ACCESS_TOKEN_TTL_MINUTES;
  delete process.env.AUTH_REFRESH_TOKEN_TTL_DAYS;
  delete process.env.AUTH_MAX_LOGIN_ATTEMPTS;
  delete process.env.AUTH_LOCKOUT_MINUTES;
  delete process.env.AUTH_MAX_ACTIVE_SESSIONS;
  delete process.env.AUTH_SOCIAL_LOGIN_ENABLED;
  delete process.env.AUTH_EMAIL_RATE_LIMIT_AUTO_VERIFY_FALLBACK;
  delete process.env.APP_NAME;
  delete process.env.DATABASE_URL;
  delete process.env.REDIS_URL;
  delete process.env.SUPABASE_PROJECT_REF;
  delete process.env.SUPABASE_URL;
  delete process.env.SUPABASE_PUBLISHABLE_KEY;
  delete process.env.SUPABASE_SECRET_KEY;
  delete process.env.SUPABASE_ANON_KEY;
  delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  delete process.env.SUPABASE_AUTH_REDIRECT_URL;
  delete process.env.SUPABASE_AUTH_MOBILE_REDIRECT_URL;
  delete process.env.OAUTH_GOOGLE_ALLOWED_AUDIENCES;
  delete process.env.OAUTH_APPLE_ALLOWED_AUDIENCES;
  delete process.env.SUPABASE_BUCKET_AVATARS;
  delete process.env.SUPABASE_BUCKET_PET_PHOTOS;
  delete process.env.SUPABASE_BUCKET_POSTS;
};

describe('loadEnv', () => {
  beforeEach(() => {
    resetEnv();
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it('returns sensible defaults for local bootstrap', () => {
    expect(loadEnv()).toEqual({
      appName: 'PawMate Backend',
      nodeEnv: 'development',
      host: '0.0.0.0',
      port: 3000,
      logLevel: 'info',
      auth: {
        accessTokenSecret: 'dev-access-token-secret',
        refreshTokenSecret: 'dev-refresh-token-secret',
        accessTokenTtlMinutes: 15,
        refreshTokenTtlDays: 30,
        maxLoginAttempts: 5,
        lockoutMinutes: 15,
        maxActiveSessions: 3,
        socialLoginEnabled: false,
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
        reviewPhotos: 'review-photos',
      },
    });
  });

  it('throws on an invalid port value', () => {
    process.env.PORT = 'banana';

    expect(() => loadEnv()).toThrow(
      'PORT must be a valid integer between 1 and 65535.',
    );
  });

  it('throws when auth config must be a positive integer', () => {
    process.env.AUTH_MAX_LOGIN_ATTEMPTS = '0';

    expect(() => loadEnv()).toThrow(
      'AUTH_MAX_LOGIN_ATTEMPTS must be a positive integer.',
    );
  });

  it('throws when SUPABASE_URL is malformed', () => {
    process.env.SUPABASE_URL = 'not-a-url';

    expect(() => loadEnv()).toThrow(
      'SUPABASE_URL must be a valid absolute URL.',
    );
  });

  it('accepts new Supabase key aliases and redirect URLs', () => {
    process.env.SUPABASE_PROJECT_REF = 'abcxyz123';
    process.env.SUPABASE_URL = 'https://abcxyz123.supabase.co';
    process.env.SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_123';
    process.env.SUPABASE_SECRET_KEY = 'sb_secret_456';
    process.env.SUPABASE_AUTH_REDIRECT_URL =
      'https://app.pawmate.example/auth/callback';
    process.env.SUPABASE_AUTH_MOBILE_REDIRECT_URL = 'pawmate://auth/callback';
    process.env.OAUTH_GOOGLE_ALLOWED_AUDIENCES =
      'google-client-id.apps.googleusercontent.com';
    process.env.OAUTH_APPLE_ALLOWED_AUDIENCES =
      'com.pawmate.pawmateMobile, com.pawmate.pawmateMobile.web';
    process.env.AUTH_ACCESS_TOKEN_SECRET = 'access-secret';
    process.env.AUTH_REFRESH_TOKEN_SECRET = 'refresh-secret';
    process.env.AUTH_MAX_ACTIVE_SESSIONS = '4';
    process.env.AUTH_SOCIAL_LOGIN_ENABLED = 'true';
    process.env.AUTH_EMAIL_RATE_LIMIT_AUTO_VERIFY_FALLBACK = 'true';

    expect(loadEnv()).toMatchObject({
      auth: {
        accessTokenSecret: 'access-secret',
        refreshTokenSecret: 'refresh-secret',
        maxActiveSessions: 4,
        socialLoginEnabled: true,
        emailRateLimitAutoVerifyFallback: true,
      },
      supabaseProjectRef: 'abcxyz123',
      supabaseUrl: 'https://abcxyz123.supabase.co/',
      supabaseAnonKey: 'sb_publishable_123',
      supabaseServiceRoleKey: 'sb_secret_456',
      supabaseAuthRedirectUrl: 'https://app.pawmate.example/auth/callback',
      supabaseAuthMobileRedirectUrl: 'pawmate://auth/callback',
      oauthVerification: {
        googleAllowedAudiences: ['google-client-id.apps.googleusercontent.com'],
        appleAllowedAudiences: [
          'com.pawmate.pawmateMobile',
          'com.pawmate.pawmateMobile.web',
        ],
      },
    });
  });

  it('throws when a boolean flag is malformed', () => {
    process.env.AUTH_SOCIAL_LOGIN_ENABLED = 'sometimes';

    expect(() => loadEnv()).toThrow(
      'AUTH_SOCIAL_LOGIN_ENABLED must be a boolean (true/false).',
    );
  });
});

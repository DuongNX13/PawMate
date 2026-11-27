import { ConfigError, loadEnv } from '../src/config/env';

const VALID_ACCESS_SECRET = 'PawMate_Access_2026_09_22_Canary_Alpha_42';
const VALID_REFRESH_SECRET = 'PawMate_Refresh_2026_09_22_Canary_Beta_43';

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
  delete process.env.AUTH_TOKEN_ALGORITHM;
  delete process.env.AUTH_TOKEN_ISSUER;
  delete process.env.AUTH_TOKEN_AUDIENCE;
  delete process.env.AUTH_TOKEN_CLOCK_TOLERANCE_SECONDS;
  delete process.env.AUTH_ACCESS_TOKEN_KEY_ID;
  delete process.env.AUTH_REFRESH_TOKEN_KEY_ID;
  delete process.env.AUTH_PREVIOUS_ACCESS_TOKEN_KEY_ID;
  delete process.env.AUTH_PREVIOUS_ACCESS_TOKEN_SECRET;
  delete process.env.AUTH_PREVIOUS_REFRESH_TOKEN_KEY_ID;
  delete process.env.AUTH_PREVIOUS_REFRESH_TOKEN_SECRET;
  delete process.env.TRUSTED_PROXY_CIDRS;
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
  delete process.env.SUPABASE_BUCKET_RESCUE_MEDIA_STAGING;
  delete process.env.SUPABASE_BUCKET_RESCUE_MEDIA_PUBLIC;
  delete process.env.PAWMATE_RESCUE_BROWSE_ENABLED;
  delete process.env.PAWMATE_RESCUE_CREATE_ENABLED;
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
        jwt: {
          algorithm: 'HS256',
          issuer: 'pawmate-api',
          audience: 'pawmate-mobile',
          clockToleranceSeconds: 30,
          accessKeyId: 'access-v1',
          refreshKeyId: 'refresh-v1',
          previousAccessKey: undefined,
          previousRefreshKey: undefined,
        },
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
      trustedProxyCidrs: [],
      features: {
        rescueBrowse: true,
        rescueCreate: true,
      },
      supabaseBuckets: {
        avatars: 'avatars',
        petPhotos: 'pet-photos',
        posts: 'posts',
        reviewPhotos: 'review-photos',
        rescueMediaStaging: 'rescue-media-staging',
        rescueMediaPublic: 'rescue-media-public',
        adoptionChatMediaPrivate: 'adoption-chat-media-private',
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

  it('keeps an explicit runtime database host over .env.local', () => {
    const runtimeDatabaseUrl =
      'postgresql://pawmate@127.0.0.1:5432/pawmate?schema=public';
    process.env.DATABASE_URL = runtimeDatabaseUrl;
    jest.resetModules();

    const { loadEnv: loadFreshEnv } =
      jest.requireActual<typeof import('../src/config/env')>(
        '../src/config/env',
      );

    expect(loadFreshEnv().databaseUrl).toBe(runtimeDatabaseUrl);
  });

  const setValidProductionEnv = () => {
    process.env.NODE_ENV = 'production';
    process.env.DATABASE_URL =
      'postgresql://pawmate@127.0.0.1:55432/pawmate?schema=public';
    process.env.REDIS_URL = 'redis://127.0.0.1:56379';
    process.env.AUTH_ACCESS_TOKEN_SECRET = VALID_ACCESS_SECRET;
    process.env.AUTH_REFRESH_TOKEN_SECRET = VALID_REFRESH_SECRET;
    process.env.AUTH_ACCESS_TOKEN_KEY_ID = 'access-2026-09';
    process.env.AUTH_REFRESH_TOKEN_KEY_ID = 'refresh-2026-09';
    process.env.SUPABASE_URL = 'https://fixture.supabase.co';
    process.env.SUPABASE_PUBLISHABLE_KEY = 'fixture-publishable-key';
    process.env.SUPABASE_SECRET_KEY = 'fixture-secret-key';
  };

  it('fails Rescue closed by default in production and ignores create-only mode', () => {
    setValidProductionEnv();
    expect(loadEnv().features).toEqual({
      rescueBrowse: false,
      rescueCreate: false,
    });

    process.env.PAWMATE_RESCUE_CREATE_ENABLED = 'true';
    expect(loadEnv().features).toEqual({
      rescueBrowse: false,
      rescueCreate: false,
    });
  });

  it('allows explicit production browse/create enablement', () => {
    setValidProductionEnv();
    process.env.PAWMATE_RESCUE_BROWSE_ENABLED = 'true';
    process.env.PAWMATE_RESCUE_CREATE_ENABLED = 'true';

    expect(loadEnv().features).toEqual({
      rescueBrowse: true,
      rescueCreate: true,
    });
  });

  it('fails closed when required production dependencies are missing', () => {
    process.env.NODE_ENV = 'production';
    process.env.AUTH_ACCESS_TOKEN_SECRET = VALID_ACCESS_SECRET;
    process.env.AUTH_REFRESH_TOKEN_SECRET = VALID_REFRESH_SECRET;

    expect(() => loadEnv()).toThrow(
      expect.objectContaining({
        name: 'ConfigError',
        code: 'CONFIG_DATABASE_URL_REQUIRED',
      }),
    );
  });

  it('rejects production without Redis even when all other dependencies are configured', () => {
    setValidProductionEnv();
    delete process.env.REDIS_URL;

    expect(() => loadEnv()).toThrow(
      expect.objectContaining({ code: 'CONFIG_REDIS_URL_REQUIRED' }),
    );
  });

  it.each([
    ['weak access secret', 'short', VALID_REFRESH_SECRET, 'CONFIG_ACCESS_SECRET_WEAK'],
    ['weak refresh secret', VALID_ACCESS_SECRET, 'short', 'CONFIG_REFRESH_SECRET_WEAK'],
    ['equal secrets', VALID_ACCESS_SECRET, VALID_ACCESS_SECRET, 'CONFIG_AUTH_SECRETS_NOT_SEPARATE'],
  ])('rejects %s without echoing secret material', (_name, access, refresh, code) => {
    setValidProductionEnv();
    process.env.AUTH_ACCESS_TOKEN_SECRET = access;
    process.env.AUTH_REFRESH_TOKEN_SECRET = refresh;

    let captured: unknown;
    try {
      loadEnv();
    } catch (error) {
      captured = error;
    }

    expect(captured).toBeInstanceOf(ConfigError);
    expect(captured).toMatchObject({ code });
    expect((captured as Error).message).not.toContain(access);
    expect((captured as Error).message).not.toContain(refresh);
  });

  it('rejects a long but trivially repeated production signing secret', () => {
    setValidProductionEnv();
    process.env.AUTH_ACCESS_TOKEN_SECRET = 'A'.repeat(48);

    expect(() => loadEnv()).toThrow(
      expect.objectContaining({ code: 'CONFIG_ACCESS_SECRET_WEAK' }),
    );
  });

  it('requires complete and non-conflicting previous-key pairs', () => {
    setValidProductionEnv();
    process.env.AUTH_PREVIOUS_ACCESS_TOKEN_KEY_ID = 'access-old';

    expect(() => loadEnv()).toThrow(
      expect.objectContaining({
        code: 'CONFIG_PREVIOUS_ACCESS_KEY_INCOMPLETE',
      }),
    );
  });

  it('rejects production token lifetimes, skew and proxy wildcards outside the contract', () => {
    setValidProductionEnv();
    process.env.AUTH_ACCESS_TOKEN_TTL_MINUTES = '16';
    expect(() => loadEnv()).toThrow(
      expect.objectContaining({ code: 'CONFIG_ACCESS_TTL_TOO_LONG' }),
    );

    delete process.env.AUTH_ACCESS_TOKEN_TTL_MINUTES;
    setValidProductionEnv();
    process.env.AUTH_TOKEN_CLOCK_TOLERANCE_SECONDS = '61';
    expect(() => loadEnv()).toThrow(
      expect.objectContaining({ code: 'CONFIG_TOKEN_CLOCK_TOLERANCE_INVALID' }),
    );

    delete process.env.AUTH_TOKEN_CLOCK_TOLERANCE_SECONDS;
    setValidProductionEnv();
    process.env.TRUSTED_PROXY_CIDRS = '0.0.0.0/0';
    expect(() => loadEnv()).toThrow(
      expect.objectContaining({ code: 'CONFIG_TRUSTED_PROXY_UNSAFE' }),
    );
  });

  it('accepts a complete production fixture and preserves explicit proxy CIDRs', () => {
    setValidProductionEnv();
    process.env.TRUSTED_PROXY_CIDRS = '10.0.0.0/8,192.168.10.10';

    expect(loadEnv()).toMatchObject({
      nodeEnv: 'production',
      trustedProxyCidrs: ['10.0.0.0/8', '192.168.10.10'],
      auth: {
        jwt: {
          algorithm: 'HS256',
          issuer: 'pawmate-api',
          audience: 'pawmate-mobile',
          clockToleranceSeconds: 30,
          accessKeyId: 'access-2026-09',
          refreshKeyId: 'refresh-2026-09',
        },
      },
    });
  });

  it('forbids production email auto-verification fallback', () => {
    setValidProductionEnv();
    process.env.AUTH_EMAIL_RATE_LIMIT_AUTO_VERIFY_FALLBACK = 'true';

    expect(() => loadEnv()).toThrow(
      expect.objectContaining({ code: 'CONFIG_EMAIL_AUTO_VERIFY_FORBIDDEN' }),
    );
  });
});

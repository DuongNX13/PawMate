import { loadEnv } from '../src/config/env';

const ORIGINAL_ENV = { ...process.env };

const resetEnv = () => {
  process.env = { ...ORIGINAL_ENV };
  delete process.env.PORT;
  delete process.env.HOST;
  delete process.env.NODE_ENV;
  delete process.env.LOG_LEVEL;
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
      databaseUrl: undefined,
      redisUrl: undefined,
      supabaseProjectRef: undefined,
      supabaseUrl: undefined,
      supabaseAnonKey: undefined,
      supabaseServiceRoleKey: undefined,
      supabaseAuthRedirectUrl: undefined,
      supabaseAuthMobileRedirectUrl: undefined,
      supabaseBuckets: {
        avatars: 'avatars',
        petPhotos: 'pet-photos',
        posts: 'posts',
      },
    });
  });

  it('throws on an invalid port value', () => {
    process.env.PORT = 'banana';

    expect(() => loadEnv()).toThrow(
      'PORT must be a valid integer between 1 and 65535.',
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
    process.env.SUPABASE_AUTH_MOBILE_REDIRECT_URL =
      'pawmate://auth/callback';

    expect(loadEnv()).toMatchObject({
      supabaseProjectRef: 'abcxyz123',
      supabaseUrl: 'https://abcxyz123.supabase.co/',
      supabaseAnonKey: 'sb_publishable_123',
      supabaseServiceRoleKey: 'sb_secret_456',
      supabaseAuthRedirectUrl: 'https://app.pawmate.example/auth/callback',
      supabaseAuthMobileRedirectUrl: 'pawmate://auth/callback',
    });
  });
});

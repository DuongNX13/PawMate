import path from 'node:path';
import dotenv from 'dotenv';

const backendRoot = path.resolve(__dirname, '..', '..');
dotenv.config({ path: path.join(backendRoot, '.env'), override: false });
dotenv.config({ path: path.join(backendRoot, '.env.local'), override: true });

export type AppLogLevel =
  | 'fatal'
  | 'error'
  | 'warn'
  | 'info'
  | 'debug'
  | 'trace';

export type AppConfig = {
  appName: string;
  nodeEnv: 'development' | 'test' | 'production';
  host: string;
  port: number;
  logLevel: AppLogLevel;
  auth: {
    accessTokenSecret: string;
    refreshTokenSecret: string;
    accessTokenTtlMinutes: number;
    refreshTokenTtlDays: number;
    maxLoginAttempts: number;
    lockoutMinutes: number;
    maxActiveSessions: number;
    socialLoginEnabled: boolean;
    emailRateLimitAutoVerifyFallback: boolean;
  };
  databaseUrl?: string;
  redisUrl?: string;
  supabaseProjectRef?: string;
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  supabaseServiceRoleKey?: string;
  supabaseAuthRedirectUrl?: string;
  supabaseAuthMobileRedirectUrl?: string;
  oauthVerification: {
    googleAllowedAudiences: string[];
    appleAllowedAudiences: string[];
  };
  supabaseBuckets: {
    avatars: string;
    petPhotos: string;
    posts: string;
    reviewPhotos?: string;
  };
};

const LOG_LEVELS: AppLogLevel[] = [
  'fatal',
  'error',
  'warn',
  'info',
  'debug',
  'trace',
];

const trim = (value?: string) => {
  const next = value?.trim();
  return next || undefined;
};

const readList = (name: string) => {
  const value = trim(process.env[name]);

  if (!value) {
    return [];
  }

  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
};

const readFirst = (...names: string[]) => {
  const matchedName = names.find((name) => trim(process.env[name]));
  return matchedName ? trim(process.env[matchedName]) : undefined;
};

const readNodeEnv = (): AppConfig['nodeEnv'] => {
  const value = trim(process.env.NODE_ENV);

  if (!value) {
    return 'development';
  }

  if (value === 'development' || value === 'test' || value === 'production') {
    return value;
  }

  throw new Error('NODE_ENV must be one of: development, test, production.');
};

const readPort = () => {
  const value = trim(process.env.PORT);

  if (!value) {
    return 3000;
  }

  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) {
    throw new Error('PORT must be a valid integer between 1 and 65535.');
  }

  return parsed;
};

const readPositiveInteger = (name: string, fallback: number) => {
  const value = trim(process.env[name]);

  if (!value) {
    return fallback;
  }

  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }

  return parsed;
};

const readBoolean = (name: string, fallback: boolean) => {
  const value = trim(process.env[name]);

  if (!value) {
    return fallback;
  }

  if (['true', '1', 'yes', 'on'].includes(value.toLowerCase())) {
    return true;
  }

  if (['false', '0', 'no', 'off'].includes(value.toLowerCase())) {
    return false;
  }

  throw new Error(`${name} must be a boolean (true/false).`);
};

const readLogLevel = (): AppLogLevel => {
  const value = trim(process.env.LOG_LEVEL) ?? 'info';

  if (!LOG_LEVELS.includes(value as AppLogLevel)) {
    throw new Error(`LOG_LEVEL must be one of: ${LOG_LEVELS.join(', ')}.`);
  }

  return value as AppLogLevel;
};

const readUrl = (name: string) => {
  const value = trim(process.env[name]);

  if (!value) {
    return undefined;
  }

  try {
    const parsed = new URL(value);
    return parsed.toString();
  } catch {
    throw new Error(`${name} must be a valid absolute URL.`);
  }
};

const readSecret = (name: string, fallback: string) => {
  const value = trim(process.env[name]);

  if (value) {
    return value;
  }

  if (readNodeEnv() !== 'production') {
    return fallback;
  }

  throw new Error(`${name} is required in production.`);
};

export const loadEnv = (): AppConfig => ({
  appName: trim(process.env.APP_NAME) ?? 'PawMate Backend',
  nodeEnv: readNodeEnv(),
  host: trim(process.env.HOST) ?? '0.0.0.0',
  port: readPort(),
  logLevel: readLogLevel(),
  auth: {
    accessTokenSecret: readSecret(
      'AUTH_ACCESS_TOKEN_SECRET',
      'dev-access-token-secret',
    ),
    refreshTokenSecret: readSecret(
      'AUTH_REFRESH_TOKEN_SECRET',
      'dev-refresh-token-secret',
    ),
    accessTokenTtlMinutes: readPositiveInteger(
      'AUTH_ACCESS_TOKEN_TTL_MINUTES',
      15,
    ),
    refreshTokenTtlDays: readPositiveInteger('AUTH_REFRESH_TOKEN_TTL_DAYS', 30),
    maxLoginAttempts: readPositiveInteger('AUTH_MAX_LOGIN_ATTEMPTS', 5),
    lockoutMinutes: readPositiveInteger('AUTH_LOCKOUT_MINUTES', 15),
    maxActiveSessions: readPositiveInteger('AUTH_MAX_ACTIVE_SESSIONS', 3),
    socialLoginEnabled: readBoolean('AUTH_SOCIAL_LOGIN_ENABLED', false),
    emailRateLimitAutoVerifyFallback: readBoolean(
      'AUTH_EMAIL_RATE_LIMIT_AUTO_VERIFY_FALLBACK',
      false,
    ),
  },
  databaseUrl: trim(process.env.DATABASE_URL),
  redisUrl: trim(process.env.REDIS_URL),
  supabaseProjectRef: trim(process.env.SUPABASE_PROJECT_REF),
  supabaseUrl: readUrl('SUPABASE_URL'),
  supabaseAnonKey: readFirst('SUPABASE_PUBLISHABLE_KEY', 'SUPABASE_ANON_KEY'),
  supabaseServiceRoleKey: readFirst(
    'SUPABASE_SECRET_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
  ),
  supabaseAuthRedirectUrl: readUrl('SUPABASE_AUTH_REDIRECT_URL'),
  supabaseAuthMobileRedirectUrl: readUrl('SUPABASE_AUTH_MOBILE_REDIRECT_URL'),
  oauthVerification: {
    googleAllowedAudiences: readList('OAUTH_GOOGLE_ALLOWED_AUDIENCES'),
    appleAllowedAudiences: readList('OAUTH_APPLE_ALLOWED_AUDIENCES'),
  },
  supabaseBuckets: {
    avatars: trim(process.env.SUPABASE_BUCKET_AVATARS) ?? 'avatars',
    petPhotos: trim(process.env.SUPABASE_BUCKET_PET_PHOTOS) ?? 'pet-photos',
    posts: trim(process.env.SUPABASE_BUCKET_POSTS) ?? 'posts',
    reviewPhotos:
      trim(process.env.SUPABASE_BUCKET_REVIEW_PHOTOS) ?? 'review-photos',
  },
});

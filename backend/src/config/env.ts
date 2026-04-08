import 'dotenv/config';

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
  databaseUrl?: string;
  redisUrl?: string;
  supabaseProjectRef?: string;
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  supabaseServiceRoleKey?: string;
  supabaseAuthRedirectUrl?: string;
  supabaseAuthMobileRedirectUrl?: string;
  supabaseBuckets: {
    avatars: string;
    petPhotos: string;
    posts: string;
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

export const loadEnv = (): AppConfig => ({
  appName: trim(process.env.APP_NAME) ?? 'PawMate Backend',
  nodeEnv: readNodeEnv(),
  host: trim(process.env.HOST) ?? '0.0.0.0',
  port: readPort(),
  logLevel: readLogLevel(),
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
  supabaseBuckets: {
    avatars: trim(process.env.SUPABASE_BUCKET_AVATARS) ?? 'avatars',
    petPhotos: trim(process.env.SUPABASE_BUCKET_PET_PHOTOS) ?? 'pet-photos',
    posts: trim(process.env.SUPABASE_BUCKET_POSTS) ?? 'posts',
  },
});

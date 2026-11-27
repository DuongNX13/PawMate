import { isIP } from 'node:net';
import path from 'node:path';
import dotenv from 'dotenv';

const backendRoot = path.resolve(__dirname, '..', '..');
// Precedence: explicit process/runtime env > .env.local > .env.
dotenv.config({ path: path.join(backendRoot, '.env.local'), override: false });
dotenv.config({ path: path.join(backendRoot, '.env'), override: false });

export type AppLogLevel =
  | 'fatal'
  | 'error'
  | 'warn'
  | 'info'
  | 'debug'
  | 'trace';

export type AuthJwtKey = {
  id: string;
  secret: string;
};

export type AuthJwtConfig = {
  algorithm: 'HS256';
  issuer: string;
  audience: string;
  clockToleranceSeconds: number;
  accessKeyId: string;
  refreshKeyId: string;
  previousAccessKey?: AuthJwtKey;
  previousRefreshKey?: AuthJwtKey;
};

export type AppFeatureAvailability = {
  rescueBrowse: boolean;
  rescueCreate: boolean;
};

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
    jwt?: AuthJwtConfig;
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
  trustedProxyCidrs?: string[];
  features?: Partial<AppFeatureAvailability>;
  supabaseBuckets: {
    avatars: string;
    petPhotos: string;
    posts: string;
    reviewPhotos?: string;
    rescueMediaStaging?: string;
    rescueMediaPublic?: string;
    adoptionChatMediaPrivate?: string;
  };
};

export class ConfigError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ConfigError';
  }
}

const LOG_LEVELS: AppLogLevel[] = [
  'fatal',
  'error',
  'warn',
  'info',
  'debug',
  'trace',
];
const DEFAULT_JWT_ISSUER = 'pawmate-api';
const DEFAULT_JWT_AUDIENCE = 'pawmate-mobile';
const DEFAULT_CLOCK_TOLERANCE_SECONDS = 30;
const MIN_PRODUCTION_SECRET_BYTES = 32;
const UNSAFE_PROXY_VALUES = new Set(['true', '*', '0.0.0.0/0', '::/0']);
const KNOWN_PLACEHOLDER_SECRET = /^(dev-|test-|replace-me|change-?me|secret$)/i;
const KNOWN_INTEGRATION_PLACEHOLDER = /^(replace-me|your-[a-z0-9-]+)$/i;

const trim = (value?: string) => {
  const next = value?.trim();
  return next || undefined;
};

const configError = (code: string, message: string): never => {
  throw new ConfigError(code, message);
};

const readList = (name: string) => {
  const value = trim(process.env[name]);
  if (!value) return [];
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
  if (!value) return 'development';
  if (value === 'development' || value === 'test' || value === 'production') {
    return value;
  }
  throw new Error('NODE_ENV must be one of: development, test, production.');
};

const readPort = () => {
  const value = trim(process.env.PORT);
  if (!value) return 3000;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 65535) {
    throw new Error('PORT must be a valid integer between 1 and 65535.');
  }
  return parsed;
};

const readPositiveInteger = (name: string, fallback: number) => {
  const value = trim(process.env[name]);
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }
  return parsed;
};

const readNonNegativeInteger = (name: string, fallback: number) => {
  const value = trim(process.env[name]);
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative integer.`);
  }
  return parsed;
};

const readBoolean = (name: string, fallback: boolean) => {
  const value = trim(process.env[name]);
  if (!value) return fallback;
  if (['true', '1', 'yes', 'on'].includes(value.toLowerCase())) return true;
  if (['false', '0', 'no', 'off'].includes(value.toLowerCase())) return false;
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
  if (!value) return undefined;
  try {
    return new URL(value).toString();
  } catch {
    throw new Error(`${name} must be a valid absolute URL.`);
  }
};

const readSecret = (name: string, fallback: string, code: string) => {
  const value = trim(process.env[name]);
  if (value) return value;
  if (readNodeEnv() !== 'production') return fallback;
  return configError(code, `${name} is required in production.`);
};

const readAlgorithm = (): AuthJwtConfig['algorithm'] => {
  const value = trim(process.env.AUTH_TOKEN_ALGORITHM) ?? 'HS256';
  if (value !== 'HS256') {
    return configError(
      'CONFIG_TOKEN_ALGORITHM_UNSUPPORTED',
      'AUTH_TOKEN_ALGORITHM must be HS256.',
    );
  }
  return value;
};

const readPreviousKey = (
  type: 'ACCESS' | 'REFRESH',
): AuthJwtKey | undefined => {
  const id = trim(process.env[`AUTH_PREVIOUS_${type}_TOKEN_KEY_ID`]);
  const secret = trim(process.env[`AUTH_PREVIOUS_${type}_TOKEN_SECRET`]);
  if (Boolean(id) !== Boolean(secret)) {
    return configError(
      `CONFIG_PREVIOUS_${type}_KEY_INCOMPLETE`,
      `AUTH_PREVIOUS_${type}_TOKEN_KEY_ID and AUTH_PREVIOUS_${type}_TOKEN_SECRET must be configured together.`,
    );
  }
  return id && secret ? { id, secret } : undefined;
};

const isSafeProxyAddress = (value: string) => {
  const normalized = value.trim().toLowerCase();
  if (!normalized || UNSAFE_PROXY_VALUES.has(normalized)) return false;
  const [address, prefix, extra] = normalized.split('/');
  if (extra !== undefined) return false;
  const version = isIP(address);
  if (!version) return false;
  if (prefix === undefined) return true;
  if (!/^[0-9]+$/.test(prefix)) return false;
  const numericPrefix = Number(prefix);
  return numericPrefix >= 0 && numericPrefix <= (version === 4 ? 32 : 128);
};

const isStrongProductionSecret = (value: string) =>
  Buffer.byteLength(value, 'utf8') >= MIN_PRODUCTION_SECRET_BYTES &&
  !KNOWN_PLACEHOLDER_SECRET.test(value) &&
  !/^(.)\1+$/.test(value);

export const resolveAuthJwtConfig = (config: AppConfig): AuthJwtConfig => ({
  algorithm: config.auth.jwt?.algorithm ?? 'HS256',
  issuer: config.auth.jwt?.issuer ?? DEFAULT_JWT_ISSUER,
  audience: config.auth.jwt?.audience ?? DEFAULT_JWT_AUDIENCE,
  clockToleranceSeconds:
    config.auth.jwt?.clockToleranceSeconds ?? DEFAULT_CLOCK_TOLERANCE_SECONDS,
  accessKeyId: config.auth.jwt?.accessKeyId ?? 'access-v1',
  refreshKeyId: config.auth.jwt?.refreshKeyId ?? 'refresh-v1',
  previousAccessKey: config.auth.jwt?.previousAccessKey,
  previousRefreshKey: config.auth.jwt?.previousRefreshKey,
});

export const resolveAppFeatureAvailability = (
  config: AppConfig,
): AppFeatureAvailability => {
  const enabledByDefault = config.nodeEnv !== 'production';
  const rescueBrowse = config.features?.rescueBrowse ?? enabledByDefault;
  const requestedRescueCreate =
    config.features?.rescueCreate ?? enabledByDefault;

  return {
    rescueBrowse,
    rescueCreate: rescueBrowse && requestedRescueCreate,
  };
};

const validateJwtClaims = (jwt: AuthJwtConfig) => {
  if (jwt.algorithm !== 'HS256') {
    configError(
      'CONFIG_TOKEN_ALGORITHM_UNSUPPORTED',
      'Only HS256 is supported for PawMate application tokens.',
    );
  }
  if (!jwt.issuer.trim() || !jwt.audience.trim()) {
    configError(
      'CONFIG_TOKEN_CLAIMS_REQUIRED',
      'JWT issuer and audience are required.',
    );
  }
  if (
    !Number.isInteger(jwt.clockToleranceSeconds) ||
    jwt.clockToleranceSeconds < 0 ||
    jwt.clockToleranceSeconds > 60
  ) {
    configError(
      'CONFIG_TOKEN_CLOCK_TOLERANCE_INVALID',
      'JWT clock tolerance must be between 0 and 60 seconds.',
    );
  }
  if (!jwt.accessKeyId.trim() || !jwt.refreshKeyId.trim()) {
    configError(
      'CONFIG_TOKEN_KEY_ID_REQUIRED',
      'Current JWT key IDs are required.',
    );
  }
  if (jwt.accessKeyId === jwt.refreshKeyId) {
    configError(
      'CONFIG_TOKEN_KEY_IDS_NOT_SEPARATE',
      'Access and refresh key IDs must be different.',
    );
  }
};

const validateJwtKeyIds = (jwt: AuthJwtConfig) => {
  const keyIds = [
    jwt.accessKeyId,
    jwt.refreshKeyId,
    jwt.previousAccessKey?.id,
    jwt.previousRefreshKey?.id,
  ].filter((value): value is string => Boolean(value));
  if (new Set(keyIds).size !== keyIds.length) {
    configError(
      'CONFIG_TOKEN_KEY_IDS_NOT_UNIQUE',
      'Current and previous JWT key IDs must be unique.',
    );
  }
};

const validateProductionConnectivityAndSecrets = (config: AppConfig) => {
  if (!config.databaseUrl) {
    configError(
      'CONFIG_DATABASE_URL_REQUIRED',
      'DATABASE_URL is required in production.',
    );
  }
  if (!config.redisUrl) {
    configError(
      'CONFIG_REDIS_URL_REQUIRED',
      'REDIS_URL is required in production.',
    );
  }
  if (!isStrongProductionSecret(config.auth.accessTokenSecret)) {
    configError(
      'CONFIG_ACCESS_SECRET_WEAK',
      'The production access-token secret does not meet the strength policy.',
    );
  }
  if (!isStrongProductionSecret(config.auth.refreshTokenSecret)) {
    configError(
      'CONFIG_REFRESH_SECRET_WEAK',
      'The production refresh-token secret does not meet the strength policy.',
    );
  }
  if (config.auth.accessTokenSecret === config.auth.refreshTokenSecret) {
    configError(
      'CONFIG_AUTH_SECRETS_NOT_SEPARATE',
      'Access and refresh secrets must be independent.',
    );
  }
};

const validateProductionAuthPolicy = (config: AppConfig) => {
  if (config.auth.accessTokenTtlMinutes > 15) {
    configError(
      'CONFIG_ACCESS_TTL_TOO_LONG',
      'The production access-token lifetime may not exceed 15 minutes.',
    );
  }
  if (config.auth.refreshTokenTtlDays > 30) {
    configError(
      'CONFIG_REFRESH_TTL_TOO_LONG',
      'The production refresh-token lifetime may not exceed 30 days.',
    );
  }
  if (config.auth.emailRateLimitAutoVerifyFallback) {
    configError(
      'CONFIG_EMAIL_AUTO_VERIFY_FORBIDDEN',
      'Production email auto-verification fallback is forbidden.',
    );
  }
  if (
    !config.supabaseUrl ||
    !config.supabaseAnonKey ||
    !config.supabaseServiceRoleKey ||
    KNOWN_INTEGRATION_PLACEHOLDER.test(config.supabaseAnonKey) ||
    KNOWN_INTEGRATION_PLACEHOLDER.test(config.supabaseServiceRoleKey)
  ) {
    configError(
      'CONFIG_EMAIL_VERIFICATION_ADAPTER_REQUIRED',
      'Supabase email-verification configuration is required in production.',
    );
  }
};

const validatePreviousJwtSecrets = (config: AppConfig, jwt: AuthJwtConfig) => {
  const previousSecrets = [
    jwt.previousAccessKey?.secret,
    jwt.previousRefreshKey?.secret,
  ].filter((value): value is string => Boolean(value));
  if (previousSecrets.some((secret) => !isStrongProductionSecret(secret))) {
    configError(
      'CONFIG_PREVIOUS_SECRET_WEAK',
      'A previous JWT secret does not meet the strength policy.',
    );
  }
  const allSecrets = [
    config.auth.accessTokenSecret,
    config.auth.refreshTokenSecret,
    ...previousSecrets,
  ];
  if (new Set(allSecrets).size !== allSecrets.length) {
    configError(
      'CONFIG_TOKEN_SECRETS_NOT_UNIQUE',
      'Current and previous JWT secrets must be independent.',
    );
  }
};

export const validateAppConfig = (config: AppConfig): AppConfig => {
  const jwt = resolveAuthJwtConfig(config);
  const proxyCidrs = config.trustedProxyCidrs ?? [];
  validateJwtClaims(jwt);
  validateJwtKeyIds(jwt);
  if (proxyCidrs.some((value) => !isSafeProxyAddress(value))) {
    return configError(
      'CONFIG_TRUSTED_PROXY_UNSAFE',
      'TRUSTED_PROXY_CIDRS must contain only explicit IP addresses or bounded CIDRs.',
    );
  }
  if (config.nodeEnv !== 'production') return config;
  validateProductionConnectivityAndSecrets(config);
  validateProductionAuthPolicy(config);
  validatePreviousJwtSecrets(config, jwt);

  return config;
};

const readSupabaseBuckets = (): AppConfig['supabaseBuckets'] => ({
  avatars: trim(process.env.SUPABASE_BUCKET_AVATARS) ?? 'avatars',
  petPhotos: trim(process.env.SUPABASE_BUCKET_PET_PHOTOS) ?? 'pet-photos',
  posts: trim(process.env.SUPABASE_BUCKET_POSTS) ?? 'posts',
  reviewPhotos:
    trim(process.env.SUPABASE_BUCKET_REVIEW_PHOTOS) ?? 'review-photos',
  rescueMediaStaging:
    trim(process.env.SUPABASE_BUCKET_RESCUE_MEDIA_STAGING) ??
    'rescue-media-staging',
  rescueMediaPublic:
    trim(process.env.SUPABASE_BUCKET_RESCUE_MEDIA_PUBLIC) ??
    'rescue-media-public',
  adoptionChatMediaPrivate:
    trim(process.env.SUPABASE_BUCKET_ADOPTION_CHAT_MEDIA_PRIVATE) ??
    'adoption-chat-media-private',
});

export const loadEnv = (): AppConfig => {
  const nodeEnv = readNodeEnv();
  const rescueBrowse = readBoolean(
    'PAWMATE_RESCUE_BROWSE_ENABLED',
    nodeEnv !== 'production',
  );
  const config: AppConfig = {
    appName: trim(process.env.APP_NAME) ?? 'PawMate Backend',
    nodeEnv,
    host: trim(process.env.HOST) ?? '0.0.0.0',
    port: readPort(),
    logLevel: readLogLevel(),
    auth: {
      accessTokenSecret: readSecret(
        'AUTH_ACCESS_TOKEN_SECRET',
        'dev-access-token-secret',
        'CONFIG_ACCESS_SECRET_REQUIRED',
      ),
      refreshTokenSecret: readSecret(
        'AUTH_REFRESH_TOKEN_SECRET',
        'dev-refresh-token-secret',
        'CONFIG_REFRESH_SECRET_REQUIRED',
      ),
      accessTokenTtlMinutes: readPositiveInteger(
        'AUTH_ACCESS_TOKEN_TTL_MINUTES',
        15,
      ),
      refreshTokenTtlDays: readPositiveInteger(
        'AUTH_REFRESH_TOKEN_TTL_DAYS',
        30,
      ),
      maxLoginAttempts: readPositiveInteger('AUTH_MAX_LOGIN_ATTEMPTS', 5),
      lockoutMinutes: readPositiveInteger('AUTH_LOCKOUT_MINUTES', 15),
      maxActiveSessions: readPositiveInteger('AUTH_MAX_ACTIVE_SESSIONS', 3),
      socialLoginEnabled: readBoolean('AUTH_SOCIAL_LOGIN_ENABLED', false),
      emailRateLimitAutoVerifyFallback: readBoolean(
        'AUTH_EMAIL_RATE_LIMIT_AUTO_VERIFY_FALLBACK',
        false,
      ),
      jwt: {
        algorithm: readAlgorithm(),
        issuer: trim(process.env.AUTH_TOKEN_ISSUER) ?? DEFAULT_JWT_ISSUER,
        audience: trim(process.env.AUTH_TOKEN_AUDIENCE) ?? DEFAULT_JWT_AUDIENCE,
        clockToleranceSeconds: readNonNegativeInteger(
          'AUTH_TOKEN_CLOCK_TOLERANCE_SECONDS',
          DEFAULT_CLOCK_TOLERANCE_SECONDS,
        ),
        accessKeyId: trim(process.env.AUTH_ACCESS_TOKEN_KEY_ID) ?? 'access-v1',
        refreshKeyId:
          trim(process.env.AUTH_REFRESH_TOKEN_KEY_ID) ?? 'refresh-v1',
        previousAccessKey: readPreviousKey('ACCESS'),
        previousRefreshKey: readPreviousKey('REFRESH'),
      },
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
    trustedProxyCidrs: readList('TRUSTED_PROXY_CIDRS'),
    features: {
      rescueBrowse,
      rescueCreate:
        rescueBrowse &&
        readBoolean('PAWMATE_RESCUE_CREATE_ENABLED', nodeEnv !== 'production'),
    },
    supabaseBuckets: readSupabaseBuckets(),
  };

  return validateAppConfig(config);
};

import {
  createHash,
  createPublicKey,
  type JsonWebKey as CryptoJsonWebKey,
  type KeyObject,
} from 'node:crypto';

import jwt, { type JwtPayload } from 'jsonwebtoken';

import { type AppConfig } from '../config/env';
import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import {
  type OAuthIdentity,
  type OAuthProvider,
  type OAuthVerifier,
} from '../services/auth/auth-service';
import { createSupabaseOAuthVerifier } from './supabase-auth-gateway';

type Jwk = CryptoJsonWebKey & {
  kid?: string;
};

type JwksPayload = {
  keys?: Jwk[];
};

type FetchLike = typeof fetch;

type JwksCacheEntry = {
  expiresAt: number;
  keys: Map<string, KeyObject>;
};

type RemoteJwksProviderDependencies = {
  fetchImpl?: FetchLike;
  now?: () => number;
};

type OpenIdOAuthVerifierDependencies = {
  googleJwksProvider?: ReturnType<typeof createRemoteJwksProvider>;
  appleJwksProvider?: ReturnType<typeof createRemoteJwksProvider>;
};

type CompositeOAuthVerifierDependencies = OpenIdOAuthVerifierDependencies & {
  supabaseVerifier?: OAuthVerifier;
};

type GoogleJwtPayload = JwtPayload & {
  email?: string;
  email_verified?: boolean;
  name?: string;
  nonce?: string;
  sub?: string;
};

type AppleJwtPayload = JwtPayload & {
  email?: string;
  email_verified?: boolean | 'true' | 'false';
  nonce?: string;
  sub?: string;
};

const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
const DEFAULT_JWKS_CACHE_MS = 60 * 60 * 1000;

const normalizeEmail = (email?: string | null) => email?.trim().toLowerCase();

const toAudienceList = (audiences: string[]) =>
  audiences as [string, ...string[]];

const parseCacheMaxAgeMs = (cacheControlHeader: string | null) => {
  if (!cacheControlHeader) {
    return DEFAULT_JWKS_CACHE_MS;
  }

  const matched = cacheControlHeader.match(/max-age=(\d+)/i);
  if (!matched) {
    return DEFAULT_JWKS_CACHE_MS;
  }

  const seconds = Number(matched[1]);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return DEFAULT_JWKS_CACHE_MS;
  }

  return seconds * 1000;
};

const readTokenHeader = (token: string) => {
  const decoded = jwt.decode(token, { complete: true });

  if (!decoded || typeof decoded === 'string') {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'OAuth credential khong phai JWT hop le.',
      401,
      'credential',
    );
  }

  const { kid, alg } = decoded.header;
  if (typeof kid !== 'string' || !kid.trim()) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'OAuth token thieu key id de xac minh.',
      401,
      'credential',
    );
  }

  if (typeof alg !== 'string' || alg !== 'RS256') {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'OAuth token dung thuat toan khong duoc ho tro.',
      401,
      'credential',
    );
  }

  return {
    kid: kid.trim(),
  };
};

const buildKeyMap = (keys: Jwk[]) =>
  new Map(
    keys
      .filter((key) => typeof key.kid === 'string' && key.kid.trim())
      .map((key) => [
        key.kid!.trim(),
        createPublicKey({
          key,
          format: 'jwk',
        }),
      ]),
  );

const createRemoteJwksProvider = (
  url: string,
  dependencies: RemoteJwksProviderDependencies = {},
) => {
  const fetchImpl = dependencies.fetchImpl ?? fetch;
  const now = dependencies.now ?? (() => Date.now());
  let cache: JwksCacheEntry | undefined;

  const loadKeyMap = async () => {
    if (cache && cache.expiresAt > now()) {
      return cache.keys;
    }

    const response = await fetchImpl(url, {
      headers: {
        accept: 'application/json',
      },
    });

    if (!response.ok) {
      throw new AppError(
        AUTH_ERROR_CODES.oauthVerificationFailed,
        'Khong the tai public key cua nha cung cap OAuth.',
        502,
        'credential',
      );
    }

    const payload = (await response.json()) as JwksPayload;
    const keys = Array.isArray(payload.keys) ? payload.keys : [];
    const keyMap = buildKeyMap(keys);

    if (!keyMap.size) {
      throw new AppError(
        AUTH_ERROR_CODES.oauthVerificationFailed,
        'JWKS cua nha cung cap OAuth khong hop le.',
        502,
        'credential',
      );
    }

    cache = {
      expiresAt: now() + parseCacheMaxAgeMs(response.headers.get('cache-control')),
      keys: keyMap,
    };

    return keyMap;
  };

  return {
    async getKey(kid: string) {
      const keyMap = await loadKeyMap();
      const directMatch = keyMap.get(kid);
      if (directMatch) {
        return directMatch;
      }

      cache = undefined;
      const refreshedKeys = await loadKeyMap();
      const refreshedMatch = refreshedKeys.get(kid);
      if (refreshedMatch) {
        return refreshedMatch;
      }

      throw new AppError(
        AUTH_ERROR_CODES.oauthVerificationFailed,
        'Khong tim thay public key phu hop de xac minh OAuth token.',
        401,
        'credential',
      );
    },
  };
};

const ensureEmail = (email: string | undefined) => {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'Tai khoan OAuth khong tra ve email hop le.',
      401,
      'credential',
    );
  }

  return normalizedEmail;
};

const ensureSubject = (subject: string | undefined) => {
  if (!subject?.trim()) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'OAuth token khong tra ve subject hop le.',
      401,
      'credential',
    );
  }

  return subject.trim();
};

const assertNonceMatch = (
  provider: OAuthProvider,
  nonceFromToken: string | undefined,
  expectedNonce: string | undefined,
) => {
  if (!expectedNonce) {
    return;
  }

  if (!nonceFromToken) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      `OAuth token cua ${provider} khong tra ve nonce hop le.`,
      401,
      'nonce',
    );
  }

  const normalizedExpected = expectedNonce.trim();
  const acceptedNonces = new Set([
    normalizedExpected,
    createHash('sha256').update(normalizedExpected).digest('hex'),
  ]);

  if (!acceptedNonces.has(nonceFromToken)) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      `Nonce cua ${provider} khong khop voi yeu cau dang nhap.`,
      401,
      'nonce',
    );
  }
};

const isEmailVerified = (value: boolean | 'true' | 'false' | undefined) =>
  value === undefined || value === true || value === 'true';

const verifyJwtPayload = <TPayload extends JwtPayload>(
  token: string,
  key: KeyObject,
  options: jwt.VerifyOptions,
): TPayload => {
  try {
    return jwt.verify(token, key, options) as TPayload;
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }

    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      error instanceof Error ? error.message : 'Khong the xac minh OAuth token.',
      401,
      'credential',
    );
  }
};

const verifyGoogleIdentityToken = async (
  token: string,
  audiences: string[],
  dependencies: OpenIdOAuthVerifierDependencies,
  context?: {
    nonce?: string;
  },
): Promise<OAuthIdentity> => {
  const { kid } = readTokenHeader(token);
  const key =
    await (dependencies.googleJwksProvider ??
      createRemoteJwksProvider(GOOGLE_JWKS_URL)).getKey(kid);
  const payload = verifyJwtPayload<GoogleJwtPayload>(token, key, {
    algorithms: ['RS256'],
    issuer: ['accounts.google.com', 'https://accounts.google.com'],
    audience: toAudienceList(audiences),
  });

  if (payload.email_verified !== true) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'Tai khoan Google chua co email duoc xac minh.',
      401,
      'credential',
    );
  }

  if (context?.nonce?.trim()) {
    assertNonceMatch('google', payload.nonce, context.nonce);
  }

  return {
    email: ensureEmail(payload.email),
    providerUserId: ensureSubject(payload.sub),
    displayName: typeof payload.name === 'string' ? payload.name : undefined,
  };
};

const verifyAppleIdentityToken = async (
  token: string,
  audiences: string[],
  dependencies: OpenIdOAuthVerifierDependencies,
  context?: {
    nonce?: string;
  },
): Promise<OAuthIdentity> => {
  const { kid } = readTokenHeader(token);
  const key =
    await (dependencies.appleJwksProvider ??
      createRemoteJwksProvider(APPLE_JWKS_URL)).getKey(kid);
  const payload = verifyJwtPayload<AppleJwtPayload>(token, key, {
    algorithms: ['RS256'],
    issuer: 'https://appleid.apple.com',
    audience: toAudienceList(audiences),
  });

  if (!isEmailVerified(payload.email_verified)) {
    throw new AppError(
      AUTH_ERROR_CODES.oauthVerificationFailed,
      'Tai khoan Apple chua co email duoc xac minh.',
      401,
      'credential',
    );
  }

  if (context?.nonce?.trim()) {
    assertNonceMatch('apple', payload.nonce, context.nonce);
  }

  return {
    email: ensureEmail(payload.email),
    providerUserId: ensureSubject(payload.sub),
  };
};

const hasDirectAudienceConfig = (
  config: AppConfig,
  provider: OAuthProvider,
) => {
  if (provider === 'google') {
    return config.oauthVerification.googleAllowedAudiences.length > 0;
  }

  return config.oauthVerification.appleAllowedAudiences.length > 0;
};

export const createOpenIdOAuthVerifier = (
  config: AppConfig,
  dependencies: OpenIdOAuthVerifierDependencies = {},
): OAuthVerifier | undefined => {
  const verifierDependencies: OpenIdOAuthVerifierDependencies = {
    googleJwksProvider:
      dependencies.googleJwksProvider ??
      createRemoteJwksProvider(GOOGLE_JWKS_URL),
    appleJwksProvider:
      dependencies.appleJwksProvider ?? createRemoteJwksProvider(APPLE_JWKS_URL),
  };
  const hasAnyAudienceConfig =
    config.oauthVerification.googleAllowedAudiences.length > 0 ||
    config.oauthVerification.appleAllowedAudiences.length > 0;

  if (!hasAnyAudienceConfig) {
    return undefined;
  }

  return {
    async verify(provider, credential, context = {}) {
      if (provider === 'google') {
        if (!config.oauthVerification.googleAllowedAudiences.length) {
          throw new AppError(
            AUTH_ERROR_CODES.oauthVerificationFailed,
            'Google OAuth verifier chua duoc cau hinh audience hop le.',
            501,
            'credential',
          );
        }

        return verifyGoogleIdentityToken(
          credential,
          config.oauthVerification.googleAllowedAudiences,
          verifierDependencies,
          {
            nonce: context.nonce,
          },
        );
      }

      if (!config.oauthVerification.appleAllowedAudiences.length) {
        throw new AppError(
          AUTH_ERROR_CODES.oauthVerificationFailed,
          'Apple OAuth verifier chua duoc cau hinh audience hop le.',
          501,
          'credential',
        );
      }

      return verifyAppleIdentityToken(
        credential,
        config.oauthVerification.appleAllowedAudiences,
        verifierDependencies,
        {
          nonce: context.nonce,
        },
      );
    },
  };
};

export const createOAuthVerifier = (
  config: AppConfig,
  dependencies: CompositeOAuthVerifierDependencies = {},
): OAuthVerifier | undefined => {
  const directVerifier =
    createOpenIdOAuthVerifier(config, dependencies) ?? undefined;
  const supabaseVerifier =
    dependencies.supabaseVerifier ?? createSupabaseOAuthVerifier(config);

  if (!directVerifier && !supabaseVerifier) {
    return undefined;
  }

  return {
    async verify(provider, credential, context = {}) {
      if (directVerifier && hasDirectAudienceConfig(config, provider)) {
        return directVerifier.verify(provider, credential, context);
      }

      if (supabaseVerifier) {
        return supabaseVerifier.verify(provider, credential, context);
      }

      throw new AppError(
        AUTH_ERROR_CODES.oauthVerificationFailed,
        `OAuth verifier cho ${provider} chua duoc cau hinh.`,
        501,
        'credential',
      );
    },
  };
};

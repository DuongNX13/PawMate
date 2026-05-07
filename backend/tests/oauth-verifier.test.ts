import { createHash, generateKeyPairSync } from 'node:crypto';

import jwt from 'jsonwebtoken';

import { type AppConfig } from '../src/config/env';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import {
  createOAuthVerifier,
  createOpenIdOAuthVerifier,
} from '../src/integrations/oauth-verifier';

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
    googleAllowedAudiences: ['google-client-id.apps.googleusercontent.com'],
    appleAllowedAudiences: ['com.pawmate.pawmateMobile'],
  },
  supabaseBuckets: {
    avatars: 'avatars',
    petPhotos: 'pet-photos',
    posts: 'posts',
  },
});

describe('OAuth verifier', () => {
  it('loads Google public keys from remote JWKS and caches them', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const config = buildConfig();
    const kid = 'google-remote-key';
    const token = jwt.sign(
      {
        email: 'remote-google@pawmate.vn',
        email_verified: true,
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: kid,
        issuer: 'https://accounts.google.com',
        audience: config.oauthVerification.googleAllowedAudiences[0],
        subject: 'remote-google-user',
      },
    );
    const originalFetch = global.fetch;
    const fetchMock = jest.fn().mockImplementation(async () =>
      new Response(
        JSON.stringify({
          keys: [
            {
              ...(publicKey.export({ format: 'jwk' }) as Record<string, unknown>),
              kid,
            },
          ],
        }),
        {
          status: 200,
          headers: {
            'cache-control': 'public, max-age=60',
            'content-type': 'application/json',
          },
        },
      ),
    );

    global.fetch = fetchMock as typeof fetch;

    try {
      const verifier = createOpenIdOAuthVerifier(config);

      await expect(verifier?.verify('google', token)).resolves.toEqual({
        email: 'remote-google@pawmate.vn',
        providerUserId: 'remote-google-user',
        displayName: undefined,
      });

      await expect(verifier?.verify('google', token)).resolves.toEqual({
        email: 'remote-google@pawmate.vn',
        providerUserId: 'remote-google-user',
        displayName: undefined,
      });

      expect(fetchMock).toHaveBeenCalledTimes(1);
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('verifies Google ID tokens directly with public keys', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const kid = 'google-key-1';
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      googleJwksProvider: {
        getKey: jest.fn().mockResolvedValue(publicKey),
      },
    });

    const token = jwt.sign(
      {
        email: 'google-user@pawmate.vn',
        email_verified: true,
        name: 'Google User',
        nonce: 'google-nonce',
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: kid,
        issuer: 'https://accounts.google.com',
        audience: config.oauthVerification.googleAllowedAudiences[0],
        subject: 'google-user-1',
      },
    );

    await expect(
      verifier?.verify('google', token, {
        nonce: 'google-nonce',
      }),
    ).resolves.toEqual({
      email: 'google-user@pawmate.vn',
      providerUserId: 'google-user-1',
      displayName: 'Google User',
    });
  });

  it('verifies Apple identity tokens directly with hashed nonce support', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const kid = 'apple-key-1';
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      appleJwksProvider: {
        getKey: jest.fn().mockResolvedValue(publicKey),
      },
    });
    const rawNonce = 'apple-raw-nonce';
    const hashedNonce = createHash('sha256').update(rawNonce).digest('hex');

    const token = jwt.sign(
      {
        email: 'apple-user@privaterelay.appleid.com',
        email_verified: 'true',
        nonce: hashedNonce,
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: kid,
        issuer: 'https://appleid.apple.com',
        audience: config.oauthVerification.appleAllowedAudiences[0],
        subject: 'apple-user-1',
      },
    );

    await expect(
      verifier?.verify('apple', token, {
        nonce: rawNonce,
      }),
    ).resolves.toEqual({
      email: 'apple-user@privaterelay.appleid.com',
      providerUserId: 'apple-user-1',
    });
  });

  it('rejects Google tokens with an unexpected audience', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      googleJwksProvider: {
        getKey: jest.fn().mockResolvedValue(publicKey),
      },
    });

    const token = jwt.sign(
      {
        email: 'wrong-audience@pawmate.vn',
        email_verified: true,
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: 'google-key-2',
        issuer: 'https://accounts.google.com',
        audience: 'some-other-client-id.apps.googleusercontent.com',
        subject: 'google-user-2',
      },
    );

    await expect(verifier?.verify('google', token)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
    });
  });

  it('rejects malformed OAuth credentials before verification starts', async () => {
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      googleJwksProvider: {
        getKey: jest.fn(),
      },
    });

    await expect(verifier?.verify('google', 'not-a-jwt')).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
      field: 'credential',
    });
  });

  it('rejects Google tokens that are missing email claims', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      googleJwksProvider: {
        getKey: jest.fn().mockResolvedValue(publicKey),
      },
    });
    const token = jwt.sign(
      {
        email_verified: true,
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: 'google-missing-email',
        issuer: 'https://accounts.google.com',
        audience: config.oauthVerification.googleAllowedAudiences[0],
        subject: 'google-user-missing-email',
      },
    );

    await expect(verifier?.verify('google', token)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
      field: 'credential',
    });
  });

  it('rejects Apple tokens that are missing subject claims', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      appleJwksProvider: {
        getKey: jest.fn().mockResolvedValue(publicKey),
      },
    });
    const token = jwt.sign(
      {
        email: 'apple-no-sub@pawmate.vn',
        email_verified: 'true',
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: 'apple-missing-sub',
        issuer: 'https://appleid.apple.com',
        audience: config.oauthVerification.appleAllowedAudiences[0],
      },
    );

    await expect(verifier?.verify('apple', token)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
      field: 'credential',
    });
  });

  it('surfaces a clear config error when a provider audience is not configured', async () => {
    const config = buildConfig();
    config.oauthVerification.googleAllowedAudiences = [];
    const verifier = createOpenIdOAuthVerifier(config);

    await expect(
      verifier?.verify('google', 'some-token'),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
      field: 'credential',
    });
  });

  it('falls back to Supabase when direct audiences are not configured', async () => {
    const config = buildConfig();
    config.oauthVerification.googleAllowedAudiences = [];
    config.oauthVerification.appleAllowedAudiences = [];
    const supabaseVerifier = {
      verify: jest.fn().mockResolvedValue({
        email: 'fallback@pawmate.vn',
        providerUserId: 'google-fallback',
      }),
    };
    const verifier = createOAuthVerifier(config, {
      supabaseVerifier,
    });

    await expect(
      verifier?.verify('google', 'fallback-token', {
        accessToken: 'fallback-access-token',
      }),
    ).resolves.toEqual({
      email: 'fallback@pawmate.vn',
      providerUserId: 'google-fallback',
    });

    expect(supabaseVerifier.verify).toHaveBeenCalledWith(
      'google',
      'fallback-token',
      {
        accessToken: 'fallback-access-token',
      },
    );
  });

  it('fails clearly when Apple nonce does not match', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const config = buildConfig();
    const verifier = createOpenIdOAuthVerifier(config, {
      appleJwksProvider: {
        getKey: jest.fn().mockResolvedValue(publicKey),
      },
    });

    const token = jwt.sign(
      {
        email: 'apple-user@pawmate.vn',
        email_verified: 'true',
        nonce: 'different-nonce',
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: 'apple-key-2',
        issuer: 'https://appleid.apple.com',
        audience: config.oauthVerification.appleAllowedAudiences[0],
        subject: 'apple-user-2',
      },
    );

    await expect(
      verifier?.verify('apple', token, {
        nonce: 'expected-nonce',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
    });
  });

  it('fails clearly when neither direct config nor fallback verifier can handle the provider', async () => {
    const config = buildConfig();
    config.oauthVerification.googleAllowedAudiences = [];
    const verifier = createOAuthVerifier(config, {
      supabaseVerifier: undefined,
    });

    await expect(
      verifier?.verify('google', 'unused-token'),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
      field: 'credential',
    });
  });
});

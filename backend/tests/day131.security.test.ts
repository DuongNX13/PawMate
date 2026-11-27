import jwt from 'jsonwebtoken';

import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import {
  createAuthService,
  type AuthSessionStore,
  type AuthUserStore,
  type OAuthProvider,
  type SessionRecord,
  type UserRecord,
} from '../src/services/auth/auth-service';

const OLD_ACCESS_SECRET = 'old-access-secret-material-0000000000000001';
const OLD_REFRESH_SECRET = 'old-refresh-secret-material-000000000000001';
const NEW_ACCESS_SECRET = 'new-access-secret-material-0000000000000001';
const NEW_REFRESH_SECRET = 'new-refresh-secret-material-000000000000001';

const buildConfig = (input: {
  accessSecret?: string;
  refreshSecret?: string;
  accessKeyId?: string;
  refreshKeyId?: string;
  previousAccessKey?: { id: string; secret: string };
  previousRefreshKey?: { id: string; secret: string };
  nodeEnv?: AppConfig['nodeEnv'];
} = {}): AppConfig => ({
  appName: 'PawMate Backend',
  nodeEnv: input.nodeEnv ?? 'test',
  host: '127.0.0.1',
  port: 3000,
  logLevel: 'error',
  trustedProxyCidrs: [],
  auth: {
    accessTokenSecret: input.accessSecret ?? NEW_ACCESS_SECRET,
    refreshTokenSecret: input.refreshSecret ?? NEW_REFRESH_SECRET,
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
      accessKeyId: input.accessKeyId ?? 'access-new',
      refreshKeyId: input.refreshKeyId ?? 'refresh-new',
      previousAccessKey: input.previousAccessKey,
      previousRefreshKey: input.previousRefreshKey,
    },
  },
  databaseUrl:
    input.nodeEnv === 'production'
      ? 'postgresql://pawmate@127.0.0.1:55432/pawmate?schema=public'
      : undefined,
  redisUrl:
    input.nodeEnv === 'production' ? 'redis://127.0.0.1:56379' : undefined,
  supabaseProjectRef: undefined,
  supabaseUrl:
    input.nodeEnv === 'production' ? 'https://fixture.supabase.co/' : undefined,
  supabaseAnonKey:
    input.nodeEnv === 'production' ? 'fixture-publishable-key' : undefined,
  supabaseServiceRoleKey:
    input.nodeEnv === 'production' ? 'fixture-secret-key' : undefined,
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

const createSharedStores = () => {
  const users = new Map<string, UserRecord>();
  const emailIndex = new Map<string, string>();
  const providers = new Map<string, string>();
  const sessions = new Map<string, SessionRecord>();

  const userStore: AuthUserStore = {
    async findUserByEmail(email) {
      const id = emailIndex.get(email);
      return id ? users.get(id) : undefined;
    },
    async findUserById(id) {
      return users.get(id);
    },
    async findUserByProviderAccount(provider: OAuthProvider, providerUserId) {
      const id = providers.get(`${provider}:${providerUserId}`);
      return id ? users.get(id) : undefined;
    },
    async saveUser(user) {
      users.set(user.id, user);
      emailIndex.set(user.email, user.id);
      Object.entries(user.providerAccounts).forEach(([provider, id]) => {
        if (id) providers.set(`${provider}:${id}`, user.id);
      });
    },
    async deleteUserById(id) {
      const user = users.get(id);
      if (user) emailIndex.delete(user.email);
      users.delete(id);
    },
  };

  const sessionStore: AuthSessionStore = {
    async listActiveSessionsByUser(userId) {
      return [...sessions.values()].filter(
        (session) => session.userId === userId && !session.revokedAt,
      );
    },
    async findSessionById(id) {
      return sessions.get(id);
    },
    async createSession(session) {
      sessions.set(session.id, session);
    },
    async rotateSession(session, expectedHash) {
      const current = sessions.get(session.id);
      if (!current || current.refreshTokenHash !== expectedHash || current.revokedAt) {
        return false;
      }
      sessions.set(session.id, session);
      return true;
    },
    async revokeSession(id, revokedAt) {
      const session = sessions.get(id);
      if (session) sessions.set(id, { ...session, revokedAt });
    },
    async revokeAllSessionsForUser(userId, revokedAt) {
      [...sessions.values()]
        .filter((session) => session.userId === userId && !session.revokedAt)
        .forEach((session) => sessions.set(session.id, { ...session, revokedAt }));
    },
  };

  return { userStore, sessionStore };
};

describe('Day 131 JWT contract', () => {
  it('never creates in-memory user or session stores in production', () => {
    const production = buildConfig({ nodeEnv: 'production' });
    const gateway = {
      sendEmailVerification: async () => ({ status: 'verification-email-sent' as const }),
      verifyEmailToken: async () => ({ email: 'fixture@pawmate.test' }),
      resendEmailVerification: async () => undefined,
    };

    expect(() => createAuthService({
      config: production,
      emailVerificationGateway: gateway,
    })).toThrow(expect.objectContaining({ code: 'CONFIG_AUTH_STORES_REQUIRED' }));
  });

  it('requires production verification adapters before auth can start', () => {
    const production = buildConfig({ nodeEnv: 'production' });

    expect(() => createAuthService({ config: production })).toThrow(
      expect.objectContaining({
        code: 'CONFIG_EMAIL_VERIFICATION_GATEWAY_REQUIRED',
      }),
    );

    production.auth.socialLoginEnabled = true;
    expect(() =>
      createAuthService({
        config: production,
        emailVerificationGateway: {
          sendEmailVerification: async () => ({
            status: 'verification-email-sent',
          }),
          verifyEmailToken: async () => ({ email: 'fixture@pawmate.test' }),
          resendEmailVerification: async () => undefined,
        },
      }),
    ).toThrow(
      expect.objectContaining({ code: 'CONFIG_OAUTH_VERIFIER_REQUIRED' }),
    );
  });

  it('issues tokens with explicit algorithm, kid, issuer, audience and type', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'jwt-contract@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);
    const result = await service.login({
      email: 'jwt-contract@pawmate.vn',
      password: 'Pawmate123',
    });

    const access = jwt.decode(result.accessToken, { complete: true });
    const refresh = jwt.decode(result.refreshToken, { complete: true });

    expect(access).toMatchObject({
      header: { alg: 'HS256', kid: 'access-new' },
      payload: { iss: 'pawmate-api', aud: 'pawmate-mobile', typ: 'access' },
    });
    expect(refresh).toMatchObject({
      header: { alg: 'HS256', kid: 'refresh-new' },
      payload: { iss: 'pawmate-api', aud: 'pawmate-mobile', typ: 'refresh' },
    });
  });

  it.each([
    ['wrong algorithm', { algorithm: 'HS384' as const }],
    ['wrong issuer', { issuer: 'other-issuer' }],
    ['wrong audience', { audience: 'other-audience' }],
  ])('rejects an access token with %s before session lookup', async (_name, overrides) => {
    const stores = createSharedStores();
    const findSession = jest.spyOn(stores.sessionStore, 'findSessionById');
    const service = createAuthService({ config: buildConfig(), ...stores });
    const token = jwt.sign(
      { typ: 'access', email: 'attacker@example.test', sid: 'session-1' },
      NEW_ACCESS_SECRET,
      {
        algorithm: 'HS256',
        keyid: 'access-new',
        issuer: 'pawmate-api',
        audience: 'pawmate-mobile',
        subject: 'user-1',
        expiresIn: '5m',
        ...overrides,
      },
    );

    await expect(service.verifyAccessToken(token)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.unauthorized,
    });
    expect(findSession).not.toHaveBeenCalled();
  });

  it('rejects wrong token type, expired and tampered tokens without side effects', async () => {
    const stores = createSharedStores();
    const findSession = jest.spyOn(stores.sessionStore, 'findSessionById');
    const service = createAuthService({ config: buildConfig(), ...stores });
    const sign = (payload: Record<string, unknown>, expiresIn: `${number}${'s' | 'm'}`) =>
      jwt.sign(payload, NEW_ACCESS_SECRET, {
        algorithm: 'HS256',
        keyid: 'access-new',
        issuer: 'pawmate-api',
        audience: 'pawmate-mobile',
        subject: 'user-1',
        expiresIn,
      });
    const wrongType = sign(
      { typ: 'refresh', email: 'user@example.test', sid: 'session-1' },
      '5m',
    );
    const expired = sign(
      { typ: 'access', email: 'user@example.test', sid: 'session-1' },
      '-61s',
    );
    const tamperedParts = expired.split('.');
    tamperedParts[2] = `${tamperedParts[2][0] === 'a' ? 'b' : 'a'}${tamperedParts[2].slice(1)}`;
    const tampered = tamperedParts.join('.');

    await expect(service.verifyAccessToken(wrongType)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.unauthorized,
    });
    await expect(service.verifyAccessToken(expired)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.unauthorized,
    });
    await expect(
      service.verifyAccessToken(tampered),
    ).rejects.toMatchObject({ code: AUTH_ERROR_CODES.unauthorized });
    expect(findSession).not.toHaveBeenCalled();
  });

  it('rejects a wrong-issuer token at a protected HTTP endpoint without creating a pet', async () => {
    const service = createAuthService({ config: buildConfig() });
    const registration = await service.register({
      email: 'http-jwt@pawmate.vn',
      password: 'Pawmate123',
    });
    await service.markEmailVerified(registration.userId);
    const login = await service.login({
      email: 'http-jwt@pawmate.vn',
      password: 'Pawmate123',
    });
    const validPayload = jwt.decode(login.accessToken) as jwt.JwtPayload;
    const wrongIssuer = jwt.sign(
      { typ: 'access', email: 'http-jwt@pawmate.vn', sid: validPayload.sid },
      NEW_ACCESS_SECRET,
      {
        algorithm: 'HS256',
        keyid: 'access-new',
        issuer: 'untrusted-issuer',
        audience: 'pawmate-mobile',
        subject: registration.userId,
        expiresIn: '5m',
      },
    );
    const app = buildApp(
      { logger: false },
      { config: buildConfig(), authService: service },
    );

    const rejected = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: { authorization: `Bearer ${wrongIssuer}` },
      payload: { name: 'ForbiddenPet', species: 'dog' },
    });
    expect(rejected.statusCode).toBe(401);

    const accepted = await app.inject({
      method: 'GET',
      url: '/pets',
      headers: { authorization: `Bearer ${login.accessToken}` },
    });
    expect(accepted.statusCode).toBe(200);
    expect(accepted.json()).toMatchObject({ data: [] });
    await app.close();
  });

  it('supports one previous key across instances and rejects it after retirement', async () => {
    const stores = createSharedStores();
    const oldService = createAuthService({
      config: buildConfig({
        accessSecret: OLD_ACCESS_SECRET,
        refreshSecret: OLD_REFRESH_SECRET,
        accessKeyId: 'access-old',
        refreshKeyId: 'refresh-old',
      }),
      ...stores,
    });
    const registration = await oldService.register({
      email: 'rotation@pawmate.vn',
      password: 'Pawmate123',
    });
    await oldService.markEmailVerified(registration.userId);
    const oldTokens = await oldService.login({
      email: 'rotation@pawmate.vn',
      password: 'Pawmate123',
      rememberMe: true,
    });

    const overlapService = createAuthService({
      config: buildConfig({
        previousAccessKey: { id: 'access-old', secret: OLD_ACCESS_SECRET },
        previousRefreshKey: { id: 'refresh-old', secret: OLD_REFRESH_SECRET },
      }),
      ...stores,
    });

    await expect(
      overlapService.verifyAccessToken(oldTokens.accessToken),
    ).resolves.toHaveProperty('userId', registration.userId);
    await expect(
      overlapService.refresh({ refreshToken: oldTokens.refreshToken }),
    ).resolves.toHaveProperty('accessToken');

    const retiredService = createAuthService({ config: buildConfig(), ...stores });
    await expect(
      retiredService.verifyAccessToken(oldTokens.accessToken),
    ).rejects.toMatchObject({ code: AUTH_ERROR_CODES.unauthorized });
  });
});

describe('Day 131 liveness and readiness contract', () => {
  it('does not construct a server for invalid production configuration', () => {
    const invalid = buildConfig({ nodeEnv: 'production' });
    invalid.databaseUrl = undefined;

    expect(() => buildApp({ logger: false }, { config: invalid })).toThrow(
      expect.objectContaining({ code: 'CONFIG_DATABASE_URL_REQUIRED' }),
    );
  });

  it('keeps liveness up while readiness fails and recovers', async () => {
    let databaseReady = false;
    let redisReady = true;
    const app = buildApp(
      { logger: false },
      {
        config: buildConfig({ nodeEnv: 'production' }),
        readinessChecks: [
          { name: 'database', check: async () => databaseReady },
          { name: 'redis', check: async () => redisReady },
        ],
      },
    );
    await app.ready();

    expect((await app.inject({ method: 'GET', url: '/health' })).statusCode).toBe(200);
    const unavailable = await app.inject({ method: 'GET', url: '/ready' });
    expect(unavailable.statusCode).toBe(503);
    expect(unavailable.json()).toEqual({ status: 'not_ready' });

    databaseReady = true;
    expect((await app.inject({ method: 'GET', url: '/ready' })).statusCode).toBe(200);

    redisReady = false;
    expect((await app.inject({ method: 'GET', url: '/ready' })).statusCode).toBe(503);

    redisReady = true;
    expect((await app.inject({ method: 'GET', url: '/ready' })).json()).toEqual({
      status: 'ready',
    });

    await app.close();
  });
});

import { type AppConfig } from '../src/config/env';
import {
  createAuthService,
  type AuthSessionStore,
  type AuthUserStore,
  type SessionRecord,
  type UserRecord,
} from '../src/services/auth/auth-service';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const createSharedStores = () => {
  const users = new Map<string, UserRecord>();
  const emails = new Map<string, string>();
  const sessions = new Map<string, SessionRecord>();
  const userStore: AuthUserStore = {
    findUserByEmail: async (email) => {
      const userId = emails.get(email);
      return userId ? users.get(userId) : undefined;
    },
    findUserById: async (userId) => users.get(userId),
    findUserByProviderAccount: async () => undefined,
    saveUser: async (user) => {
      users.set(user.id, user);
      emails.set(user.email, user.id);
    },
    deleteUserById: async (userId) => {
      const user = users.get(userId);
      if (user) emails.delete(user.email);
      users.delete(userId);
    },
  };
  const sessionStore: AuthSessionStore = {
    listActiveSessionsByUser: async (userId) =>
      [...sessions.values()].filter(
        (session) => session.userId === userId && !session.revokedAt,
      ),
    findSessionById: async (sessionId) => sessions.get(sessionId),
    createSession: async (session) => {
      sessions.set(session.id, session);
    },
    rotateSession: async (session, expectedHash) => {
      const current = sessions.get(session.id);
      if (
        !current ||
        current.revokedAt ||
        current.refreshTokenHash !== expectedHash
      ) {
        return false;
      }
      sessions.set(session.id, session);
      return true;
    },
    revokeSession: async (sessionId, revokedAt) => {
      const session = sessions.get(sessionId);
      if (session) sessions.set(sessionId, { ...session, revokedAt });
    },
    revokeAllSessionsForUser: async (userId, revokedAt) => {
      [...sessions.values()]
        .filter((session) => session.userId === userId && !session.revokedAt)
        .forEach((session) => {
          sessions.set(session.id, { ...session, revokedAt });
        });
    },
  };
  return { userStore, sessionStore };
};

describe('Day 133 refresh concurrency and reuse', () => {
  it('rejects a concurrent duplicate without revoking the winning rotation', async () => {
    const stores = createSharedStores();
    const config = buildTestConfig() as AppConfig;
    const gateway = {
      sendEmailVerification: async () => ({ status: 'auto-verified' as const }),
      verifyEmailToken: async () => ({ email: 'race@example.test' }),
      resendEmailVerification: async () => undefined,
    };
    const serviceA = createAuthService({
      config,
      ...stores,
      emailVerificationGateway: gateway,
    });
    const serviceB = createAuthService({
      config,
      ...stores,
      emailVerificationGateway: gateway,
    });

    await serviceA.register({
      email: 'race@example.test',
      password: 'StrongPass123!',
    });
    const login = await serviceA.login({
      email: 'race@example.test',
      password: 'StrongPass123!',
      rememberMe: true,
    });

    const results = await Promise.allSettled([
      serviceA.refresh({ refreshToken: login.refreshToken }),
      serviceB.refresh({ refreshToken: login.refreshToken }),
    ]);
    const fulfilled = results.filter(
      (
        result,
      ): result is PromiseFulfilledResult<
        Awaited<ReturnType<typeof serviceA.refresh>>
      > => result.status === 'fulfilled',
    );
    const rejected = results.filter(
      (result): result is PromiseRejectedResult => result.status === 'rejected',
    );

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect(rejected[0].reason).toMatchObject({
      code: 'AUTH_007',
      statusCode: 401,
    });
    await expect(
      serviceA.verifyAccessToken(fulfilled[0].value.accessToken),
    ).resolves.toMatchObject({ userId: expect.any(String) });
    await expect(
      serviceB.refresh({ refreshToken: fulfilled[0].value.refreshToken }),
    ).resolves.toMatchObject({ refreshToken: expect.any(String) });
  });

  it('revokes the winning session when the old refresh token is replayed after grace', async () => {
    const stores = createSharedStores();
    const config = buildTestConfig() as AppConfig;
    let nowMs = Date.UTC(2026, 8, 25, 10, 0, 0);
    const now = () => new Date(nowMs);
    const gateway = {
      sendEmailVerification: async () => ({ status: 'auto-verified' as const }),
      verifyEmailToken: async () => ({ email: 'replay@example.test' }),
      resendEmailVerification: async () => undefined,
    };
    const service = createAuthService({
      config,
      ...stores,
      now,
      emailVerificationGateway: gateway,
    });
    await service.register({
      email: 'replay@example.test',
      password: 'StrongPass123!',
    });
    const login = await service.login({
      email: 'replay@example.test',
      password: 'StrongPass123!',
      rememberMe: true,
    });
    nowMs += 1000;
    const rotated = await service.refresh({ refreshToken: login.refreshToken });
    nowMs += 6000;

    await expect(
      service.refresh({ refreshToken: login.refreshToken }),
    ).rejects.toMatchObject({ code: 'AUTH_009', statusCode: 401 });
    await expect(
      service.verifyAccessToken(rotated.accessToken),
    ).rejects.toMatchObject({ code: 'AUTH_013', statusCode: 401 });
  });
});

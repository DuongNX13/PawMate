import assert from 'node:assert/strict';

import Redis from 'ioredis';
import jwt from 'jsonwebtoken';

import { type AppConfig } from '../src/config/env';
import { RedisAuthSessionStore } from '../src/repositories/redis-auth-session-store';
import {
  createAuthService,
  type AuthUserStore,
  type UserRecord,
} from '../src/services/auth/auth-service';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';

const redisUrl = process.env.DAY133_REDIS_URL;
if (!redisUrl) throw new Error('DAY133_REDIS_URL is required.');

const runId = process.env.DAY133_RUN_ID ?? 'day133-auth-proof';
const redisA = new Redis(redisUrl, {
  lazyConnect: true,
  maxRetriesPerRequest: 0,
});
const redisB = new Redis(redisUrl, {
  lazyConnect: true,
  maxRetriesPerRequest: 0,
});
const users = new Map<string, UserRecord>();
const emailIndex = new Map<string, string>();
const userStore: AuthUserStore = {
  findUserByEmail: async (email) => {
    const id = emailIndex.get(email);
    return id ? users.get(id) : undefined;
  },
  findUserById: async (id) => users.get(id),
  findUserByProviderAccount: async () => undefined,
  saveUser: async (user) => {
    users.set(user.id, user);
    emailIndex.set(user.email, user.id);
  },
  deleteUserById: async (id) => {
    const user = users.get(id);
    if (user) emailIndex.delete(user.email);
    users.delete(id);
  },
};

const run = async () => {
  await Promise.all([redisA.connect(), redisB.connect()]);
  let nowMs = Date.now();
  const now = () => new Date(nowMs);
  const config = buildTestConfig() as AppConfig;
  const gateway = {
    sendEmailVerification: async () => ({ status: 'auto-verified' as const }),
    verifyEmailToken: async () => ({ email: `${runId}@example.test` }),
    resendEmailVerification: async () => undefined,
  };
  const serviceA = createAuthService({
    config,
    now,
    userStore,
    sessionStore: new RedisAuthSessionStore(redisA),
    emailVerificationGateway: gateway,
  });
  const serviceB = createAuthService({
    config,
    now,
    userStore,
    sessionStore: new RedisAuthSessionStore(redisB),
    emailVerificationGateway: gateway,
  });

  const registration = await serviceA.register({
    email: `${runId}@example.test`,
    password: 'StrongPass123!',
  });
  const login = await serviceA.login({
    email: `${runId}@example.test`,
    password: 'StrongPass123!',
    rememberMe: true,
  });
  const firstPayload = jwt.decode(login.refreshToken) as { sid: string };
  const ownedSessionIds = new Set([firstPayload.sid]);

  nowMs += 1000;
  const concurrent = await Promise.allSettled([
    serviceA.refresh({ refreshToken: login.refreshToken }),
    serviceB.refresh({ refreshToken: login.refreshToken }),
  ]);
  const winners = concurrent.filter(
    (
      result,
    ): result is PromiseFulfilledResult<
      Awaited<ReturnType<typeof serviceA.refresh>>
    > => result.status === 'fulfilled',
  );
  const losers = concurrent.filter(
    (result): result is PromiseRejectedResult => result.status === 'rejected',
  );
  assert.equal(winners.length, 1);
  assert.equal(losers.length, 1);
  assert.equal(losers[0].reason.code, 'AUTH_007');
  assert.equal(
    (await serviceB.verifyAccessToken(winners[0].value.accessToken)).userId,
    registration.userId,
  );

  nowMs += 6000;
  await assert.rejects(
    serviceA.refresh({ refreshToken: login.refreshToken }),
    (error: unknown) =>
      typeof error === 'object' &&
      error !== null &&
      (error as { code?: string }).code === 'AUTH_009',
  );
  await assert.rejects(
    serviceB.verifyAccessToken(winners[0].value.accessToken),
    (error: unknown) =>
      typeof error === 'object' &&
      error !== null &&
      (error as { code?: string }).code === 'AUTH_013',
  );

  nowMs += 1000;
  const secondLogin = await serviceB.login({
    email: `${runId}@example.test`,
    password: 'StrongPass123!',
    rememberMe: true,
  });
  const secondPayload = jwt.decode(secondLogin.refreshToken) as { sid: string };
  ownedSessionIds.add(secondPayload.sid);
  await serviceA.logout({ refreshToken: secondLogin.refreshToken });
  await assert.rejects(
    serviceB.verifyAccessToken(secondLogin.accessToken),
    (error: unknown) =>
      typeof error === 'object' &&
      error !== null &&
      (error as { code?: string }).code === 'AUTH_013',
  );

  const exactKeys = [
    ...[...ownedSessionIds].map((sid) => `auth:session:${sid}`),
    `auth:user-sessions:${registration.userId}`,
  ];
  if (exactKeys.length > 0) await redisA.del(...exactKeys);
  const remaining = await redisA.exists(...exactKeys);
  assert.equal(remaining, 0);
  redisA.disconnect();
  redisB.disconnect();

  return {
    runId,
    userId: registration.userId,
    concurrentRefresh: {
      success: winners.length,
      duplicateRejected: losers.length,
      duplicateCode: losers[0].reason.code,
      winnerUsableAcrossInstance: true,
    },
    delayedReplay: { code: 'AUTH_009', allSessionsRevoked: true },
    logout: { accessRejectedAcrossInstance: true },
    cleanup: { exactKeysDeleted: exactKeys.length, remaining: 0 },
    verdict: 'PASS',
  };
};

run()
  .then((result) =>
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`),
  )
  .catch((error: unknown) => {
    redisA.disconnect();
    redisB.disconnect();
    process.stderr.write(
      `${JSON.stringify({
        runId,
        verdict: 'FAIL',
        error: error instanceof Error ? error.message : 'Unknown error',
      })}\n`,
    );
    process.exitCode = 1;
  });

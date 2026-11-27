import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import Redis from 'ioredis';

import { buildApp } from '../src/app';
import { AppError } from '../src/errors/app-error';
import {
  createActionQuotaGuard,
  type QuotaCharge,
} from '../src/security/distributed-action-quota';
import { RedisActionQuotaStore } from '../src/security/redis-action-quota-store';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';

const redisUrl = process.env.DAY133_REDIS_URL;
if (!redisUrl) throw new Error('DAY133_REDIS_URL is required.');

const runId = process.env.DAY133_RUN_ID ?? `d133-${randomUUID()}`;
const namespace = `pawmate:q:v1:${runId}`;
const secret = 'day133-live-proof-secret-material-at-least-32-bytes';
const clientOptions = { lazyConnect: true, maxRetriesPerRequest: 0 } as const;
const redisA = new Redis(redisUrl, clientOptions);
const redisB = new Redis(redisUrl, clientOptions);
const startedAt = new Date().toISOString();

const scanOwnedKeys = async (client: Redis = redisA) => {
  let cursor = '0';
  const keys: string[] = [];
  do {
    const result = await client.scan(
      cursor,
      'MATCH',
      `${namespace}:*`,
      'COUNT',
      '100',
    );
    [cursor] = result;
    keys.push(...result[1]);
  } while (cursor !== '0');
  return [...new Set(keys)].sort();
};

const removeOwnedKeys = async (client: Redis = redisA) => {
  const keys = await scanOwnedKeys(client);
  if (keys.length > 0) await client.del(...keys);
  return keys.length;
};

const snapshotStringValues = async (pattern: string) => {
  let cursor = '0';
  const values: Record<string, string> = {};
  do {
    const result = await redisA.scan(cursor, 'MATCH', pattern, 'COUNT', '100');
    [cursor] = result;
    for (const key of result[1]) {
      if ((await redisA.type(key)) === 'string') {
        values[key] = (await redisA.get(key)) ?? '';
      }
    }
  } while (cursor !== '0');
  return Object.fromEntries(
    Object.entries(values).sort(([left], [right]) => left.localeCompare(right)),
  );
};

const assertLimited = (reason: PromiseRejectedResult['reason']) => {
  assert(reason instanceof AppError);
  assert.equal(reason.code, 'SEC_001');
  assert.equal(reason.statusCode, 429);
  assert((reason.retryAfterSeconds ?? 0) >= 1);
};

const run = async () => {
  await Promise.all([redisA.connect(), redisB.connect()]);
  assert.equal(await redisA.ping(), 'PONG');
  assert.equal(await redisB.ping(), 'PONG');
  await removeOwnedKeys();

  const budgetWarnings: Array<{ action: string; thresholdPercent: number }> =
    [];
  const onBudgetWarning = (event: { action: string; thresholdPercent: 80 }) => {
    budgetWarnings.push(event);
  };
  const guardA = createActionQuotaGuard({
    store: new RedisActionQuotaStore(redisA),
    secret,
    namespace,
    onBudgetWarning,
  });
  const guardB = createActionQuotaGuard({
    store: new RedisActionQuotaStore(redisB),
    secret,
    namespace,
    onBudgetWarning,
  });

  const concurrent = await Promise.allSettled(
    Array.from({ length: 12 }, (_, index) =>
      (index % 2 === 0 ? guardA : guardB).enforce({
        action: 'auth.resend',
        dimensions: { ip: '203.0.113.133', account: 'race@example.test' },
      }),
    ),
  );
  const fulfilled = concurrent.filter(
    (result): result is PromiseFulfilledResult<unknown> =>
      result.status === 'fulfilled',
  );
  const rejected = concurrent.filter(
    (result): result is PromiseRejectedResult => result.status === 'rejected',
  );
  assert.equal(fulfilled.length, 3);
  assert.equal(rejected.length, 9);
  rejected.forEach((result) => assertLimited(result.reason));

  for (let index = 0; index < 10; index += 1) {
    await (index % 2 === 0 ? guardA : guardB).enforce({
      action: 'auth.resend',
      dimensions: {
        ip: '203.0.113.142',
        account: `rotating-account-${index}@example.test`,
      },
    });
  }
  await assert.rejects(
    guardB.enforce({
      action: 'auth.resend',
      dimensions: {
        ip: '203.0.113.142',
        account: 'rotating-account-10@example.test',
      },
    }),
    (error: unknown) => {
      assertLimited(error as PromiseRejectedResult['reason']);
      return true;
    },
  );

  const concurrentBytes = await Promise.allSettled([
    guardA.enforce({
      action: 'upload.ticket',
      dimensions: { ip: '203.0.113.143', account: 'byte-race-user' },
      units: { bytes: 60 * 1024 * 1024 },
      idempotencyKey: 'day133-byte-race-a',
    }),
    guardB.enforce({
      action: 'upload.ticket',
      dimensions: { ip: '203.0.113.143', account: 'byte-race-user' },
      units: { bytes: 60 * 1024 * 1024 },
      idempotencyKey: 'day133-byte-race-b',
    }),
  ]);
  const byteWinners = concurrentBytes.filter(
    (result): result is PromiseFulfilledResult<
      Awaited<ReturnType<typeof guardA.enforce>>
    > => result.status === 'fulfilled',
  );
  const byteLosers = concurrentBytes.filter(
    (result): result is PromiseRejectedResult => result.status === 'rejected',
  );
  assert.equal(byteWinners.length, 1);
  assert.equal(byteLosers.length, 1);
  assertLimited(byteLosers[0].reason);
  if (byteWinners[0].value.lease) {
    await guardA.cancelLease(byteWinners[0].value.lease);
  }

  const idempotentRequest = {
    action: 'adoption.request' as const,
    dimensions: {
      ip: '203.0.113.140',
      account: 'idempotent-user',
      resource: 'idempotent-listing',
    },
    idempotencyKey: 'day133-idempotent-proof',
  };
  await guardA.enforce(idempotentRequest);
  const idempotencyBefore = await snapshotStringValues(
    `${namespace}:adoption.request:*`,
  );
  await guardB.enforce(idempotentRequest);
  const idempotencyAfter = await snapshotStringValues(
    `${namespace}:adoption.request:*`,
  );
  assert.deepEqual(idempotencyAfter, idempotencyBefore);

  const uploadLeases = [];
  for (let index = 0; index < 3; index += 1) {
    const decision = await (index % 2 === 0 ? guardA : guardB).enforce({
      action: 'upload.ticket',
      dimensions: { ip: '203.0.113.141', account: 'lease-user' },
      units: { bytes: 1024 },
      idempotencyKey: `day133-live-lease-${index}`,
    });
    assert(decision.lease);
    uploadLeases.push(decision.lease);
  }
  await assert.rejects(
    guardB.enforce({
      action: 'upload.ticket',
      dimensions: { ip: '203.0.113.141', account: 'lease-user' },
      units: { bytes: 1024 },
      idempotencyKey: 'day133-live-lease-over-limit',
    }),
    (error: unknown) => {
      assertLimited(error as PromiseRejectedResult['reason']);
      return true;
    },
  );
  await guardA.bindLease(uploadLeases[0], 'day133-live-media');
  await guardB.releaseLease({
    action: 'upload.ticket',
    dimensions: { account: 'lease-user' },
    resourceId: 'day133-live-media',
  });
  await guardA.enforce({
    action: 'upload.ticket',
    dimensions: { ip: '203.0.113.141', account: 'lease-user' },
    units: { bytes: 1024 },
    idempotencyKey: 'day133-live-lease-after-release',
  });

  for (let index = 0; index < 81; index += 1) {
    await (index % 2 === 0 ? guardA : guardB).enforce({
      action: 'provider.email',
      dimensions: { account: `warning-account-${index}` },
    });
  }
  assert.deepEqual(budgetWarnings, [
    { action: 'provider.email', thresholdPercent: 80 },
  ]);

  const twoInstanceNamespace = `${namespace}:two-api`;
  const appA = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      actionQuotaGuard: createActionQuotaGuard({
        store: new RedisActionQuotaStore(redisA),
        secret,
        namespace: twoInstanceNamespace,
      }),
    },
  );
  const appB = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      actionQuotaGuard: createActionQuotaGuard({
        store: new RedisActionQuotaStore(redisB),
        secret,
        namespace: twoInstanceNamespace,
      }),
    },
  );
  const responses = [];
  for (let index = 0; index < 11; index += 1) {
    responses.push(
      await (index % 2 === 0 ? appA : appB).inject({
        method: 'POST',
        url: '/auth/login',
        payload: {
          email: 'two-instance@example.test',
          password: 'WrongPass123!',
        },
      }),
    );
  }
  assert(
    responses.slice(0, 10).every((response) => response.statusCode === 401),
  );
  assert.equal(responses[10].statusCode, 429);
  assert((Number(responses[10].headers['retry-after']) || 0) >= 1);
  await Promise.all([appA.close(), appB.close()]);

  const resetStore = new RedisActionQuotaStore(redisA);
  const resetCharge: QuotaCharge = {
    keyPrefix: `${namespace}:reset`,
    limit: 2,
    windowSeconds: 2,
    amount: 1,
  };
  assert.equal((await resetStore.consume([resetCharge])).allowed, true);
  assert.equal((await resetStore.consume([resetCharge])).allowed, true);
  const blocked = await resetStore.consume([resetCharge]);
  assert.equal(blocked.allowed, false);
  await new Promise((resolve) =>
    setTimeout(resolve, (blocked.retryAfterSeconds + 1) * 1000),
  );
  assert.equal((await resetStore.consume([resetCharge])).allowed, true);

  const keysBeforeCleanup = await scanOwnedKeys();
  const serializedKeys = JSON.stringify(keysBeforeCleanup);
  assert(!serializedKeys.includes('race@example.test'));
  assert(!serializedKeys.includes('two-instance@example.test'));
  assert(!serializedKeys.includes('203.0.113.133'));
  const removedKeys = await removeOwnedKeys();
  assert.equal((await scanOwnedKeys()).length, 0);

  redisA.disconnect();
  redisB.disconnect();
  await assert.rejects(
    guardA.enforce({
      action: 'auth.login',
      dimensions: { ip: '203.0.113.134', account: 'outage@example.test' },
    }),
    (error: unknown) =>
      error instanceof AppError &&
      error.code === 'SEC_002' &&
      error.statusCode === 503 &&
      error.retryAfterSeconds === 5,
  );

  const redisRecovery = new Redis(redisUrl, clientOptions);
  await redisRecovery.connect();
  const recoveryGuard = createActionQuotaGuard({
    store: new RedisActionQuotaStore(redisRecovery),
    secret,
    namespace,
  });
  await recoveryGuard.enforce({
    action: 'discovery.read',
    dimensions: { ip: '203.0.113.144' },
  });
  const recoveryCleanup = await removeOwnedKeys(redisRecovery);
  assert.equal((await scanOwnedKeys(redisRecovery)).length, 0);
  redisRecovery.disconnect();

  return {
    runId,
    namespace,
    startedAt,
    finishedAt: new Date().toISOString(),
    redis: { url: redisUrl, pingA: 'PONG', pingB: 'PONG' },
    concurrent: { accepted: fulfilled.length, rejected: rejected.length },
    accountRotation: {
      distinctAccountsAcceptedFromOneIp: 10,
      eleventhRejectedByIp: true,
    },
    concurrentBytes: {
      requests: 2,
      bytesPerRequest: 60 * 1024 * 1024,
      accepted: byteWinners.length,
      rejected: byteLosers.length,
    },
    idempotency: { replayDidNotDoubleCharge: true },
    uploadConcurrency: {
      maximumOpenLeases: 3,
      fourthRejected: true,
      releaseRecoveredCapacity: true,
    },
    providerBudgetWarning: {
      emittedOnceAtPercent: 80,
      nonSecret: true,
    },
    twoApiInstances: {
      firstTenStatus: 401,
      eleventhStatus: responses[10].statusCode,
      retryAfter: responses[10].headers['retry-after'],
    },
    reset: {
      blockedRetryAfterSeconds: blocked.retryAfterSeconds,
      recovered: true,
    },
    identityLeakScan: 'PASS',
    outageFailClosed: 'PASS',
    recoveryAfterClientOutage: 'PASS',
    cleanup: {
      removedKeysBeforeOutage: removedKeys,
      removedKeysAfterRecovery: recoveryCleanup,
      remainingKeys: 0,
    },
    verdict: 'PASS',
  };
};

run()
  .then((result) => {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  })
  .catch(async (error: unknown) => {
    try {
      if (redisA.status !== 'end') await removeOwnedKeys();
    } catch {
      // Preserve the original failure; cleanup is reported by the caller.
    }
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

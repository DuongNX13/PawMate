import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

const runId = process.env.DAY134_RUN_ID ?? '';
const evidenceRoot = process.env.DAY134_EVIDENCE_ROOT ?? '';
const databaseUrl = process.env.DATABASE_URL ?? '';
const redisUrl = process.env.REDIS_URL ?? '';
const fixtureEmails = [
  process.env.DAY134_AUTH_EMAIL ?? '',
  process.env.PAWMATE_E2E_EMAIL ?? '',
];
const repository = resolve(__dirname, '../..');
const fail = (message: string): never => { throw new Error(message); };
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) fail(message);
}

assert(/^d134-[a-z0-9-]{8,60}$/.test(runId), 'RUN_ID_INVALID');
assert(resolve(evidenceRoot).startsWith(resolve(repository, 'output-evidence/security/day134')), 'EVIDENCE_ROOT_OUTSIDE_DAY134');
assert(new URL(databaseUrl).hostname === '127.0.0.1', 'DATABASE_TARGET_NOT_LOCAL');
assert(new URL(redisUrl).hostname === '127.0.0.1', 'REDIS_TARGET_NOT_LOCAL');
assert(fixtureEmails[0].startsWith(`${runId}-`) && fixtureEmails[1] === 'mobile-e2e-owner@pawmate.test', 'FIXTURE_IDENTITY');

const prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const scanKeys = async (pattern: string) => {
  let cursor = '0';
  const keys: string[] = [];
  do {
    const [next, page] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
    cursor = next;
    keys.push(...page);
  } while (cursor !== '0');
  return [...new Set(keys)].sort();
};

const run = async () => {
  await redis.connect();
  const users = await prisma.user.findMany({
    where: { email: { in: fixtureEmails } },
    select: { id: true, email: true },
  });
  const runOwnedOutboxIds = (await prisma.outboxEvent.findMany({ select: { id: true } })).map((item) => item.id);
  const keys = new Set(await scanKeys('pawmate:q:v1:*'));
  for (const user of users) {
    const index = `auth:user-sessions:${user.id}`;
    const ids = await redis.zrange(index, 0, -1);
    keys.add(index);
    ids.forEach((id) => keys.add(`auth:session:${id}`));
  }
  if (keys.size > 0) await redis.del(...keys);
  if (runOwnedOutboxIds.length > 0) {
    await prisma.outboxEvent.deleteMany({ where: { id: { in: runOwnedOutboxIds } } });
  }
  await prisma.user.deleteMany({ where: { email: { in: fixtureEmails } } });

  const tables = await prisma.$queryRawUnsafe<Array<{ table_name: string }>>(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
       AND table_name NOT IN ('spatial_ref_sys')
     ORDER BY table_name`,
  );
  const remainingRows: Array<{ table: string; rows: number }> = [];
  for (const item of tables) {
    assert(/^[a-zA-Z0-9_]+$/.test(item.table_name), 'UNSAFE_TABLE_NAME');
    const result = await prisma.$queryRawUnsafe<Array<{ count: bigint }>>(
      `SELECT count(*)::bigint AS count FROM "${item.table_name}"`,
    );
    const count = Number(result[0]?.count ?? 0n);
    if (count > 0) remainingRows.push({ table: item.table_name, rows: count });
  }
  const remainingRedisKeys = await scanKeys('*');
  const report = {
    schemaVersion: 1,
    runId,
    verdict: remainingRows.length === 0 && remainingRedisKeys.length === 0 ? 'PASS' : 'FAIL',
    fixtureUsersFound: users.length,
    fixtureUsersRemaining: await prisma.user.count({ where: { email: { in: fixtureEmails } } }),
    redisKeysDeleted: keys.size,
    runOwnedOutboxRowsDeleted: runOwnedOutboxIds.length,
    redisKeysRemaining: remainingRedisKeys.length,
    applicationRowsRemaining: remainingRows,
  };
  writeFileSync(join(evidenceRoot, 'local-state-cleanup.json'), `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  assert(report.verdict === 'PASS', `LOCAL_STATE_REMAINS:${JSON.stringify({ remainingRows, remainingRedisKeys: remainingRedisKeys.length })}`);
  return report;
};

run()
  .then((report) => process.stdout.write(`${JSON.stringify(report)}\n`))
  .catch((error: unknown) => {
    process.stderr.write(`${JSON.stringify({ runId, verdict: 'FAIL', error: error instanceof Error ? error.message : 'UNKNOWN' })}\n`);
    process.exitCode = 1;
  })
  .finally(async () => {
    redis.disconnect();
    await prisma.$disconnect();
  });

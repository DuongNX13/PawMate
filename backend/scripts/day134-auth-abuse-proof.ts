import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

type Verdict = 'PASS' | 'FAIL' | 'NOT_RUN';
type Check = { name: string; actual: string; pass: boolean };
type CaseRecord = {
  id: 'D134-V01' | 'D134-V02';
  verdict: Verdict;
  checks: Check[];
  startedAt?: string;
  endedAt?: string;
  failure?: string;
};
type HttpResult = {
  status: number;
  code?: string;
  retryAfter?: string;
  json?: Record<string, unknown>;
};

const runId = process.env.DAY134_RUN_ID ?? '';
const evidenceRoot = process.env.DAY134_EVIDENCE_ROOT ?? '';
const baseA = process.env.DAY134_API_A ?? '';
const baseB = process.env.DAY134_API_B ?? '';
const databaseUrl = process.env.DATABASE_URL ?? '';
const redisUrl = process.env.REDIS_URL ?? '';
const authEmail = process.env.DAY134_AUTH_EMAIL ?? '';
const authPassword = process.env.DAY134_AUTH_PASSWORD ?? '';
const mobileEmail = process.env.PAWMATE_E2E_EMAIL ?? '';
const mobilePassword = process.env.PAWMATE_E2E_PASSWORD ?? '';
const repository = resolve(__dirname, '../..');
const maxRequests = 300;
const now = () => new Date().toISOString();
const fail = (message: string): never => { throw new Error(message); };
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) fail(message);
}

assert(/^d134-[a-z0-9-]{8,60}$/.test(runId), 'RUN_ID_INVALID');
assert(evidenceRoot && existsSync(evidenceRoot), 'EVIDENCE_ROOT_MISSING');
assert(resolve(evidenceRoot).startsWith(resolve(repository, 'output-evidence/security/day134')), 'EVIDENCE_ROOT_OUTSIDE_DAY134');
assert(baseA === 'http://127.0.0.1:31341' && baseB === 'http://127.0.0.1:31342', 'API_TARGET_MISMATCH');
assert(new URL(databaseUrl).hostname === '127.0.0.1', 'DATABASE_TARGET_NOT_LOCAL');
assert(new URL(redisUrl).hostname === '127.0.0.1', 'REDIS_TARGET_NOT_LOCAL');
assert(authEmail.startsWith(`${runId}-`) && authEmail.endsWith('@pawmate.test'), 'AUTH_FIXTURE_IDENTITY');
assert(mobileEmail === 'mobile-e2e-owner@pawmate.test', 'MOBILE_FIXTURE_IDENTITY');
assert(authPassword.length >= 12 && mobilePassword.length >= 10, 'FIXTURE_PASSWORD_POLICY');

const artifact = join(evidenceRoot, 'auth-abuse-matrix.json');
const records: CaseRecord[] = [
  { id: 'D134-V01', verdict: 'NOT_RUN', checks: [] },
  { id: 'D134-V02', verdict: 'NOT_RUN', checks: [] },
];
let requestCount = 0;
const save = () => writeFileSync(artifact, `${JSON.stringify({
  schemaVersion: 1,
  runId,
  source: 'production-mode local HTTP over two API process instances with disposable PostgreSQL and Redis',
  capturedAt: now(),
  requestCount,
  maxRequests,
  secretsPersisted: false,
  cases: records,
}, null, 2)}\n`, 'utf8');
const check = (record: CaseRecord, name: string, condition: unknown, actual: string) => {
  const pass = Boolean(condition);
  record.checks.push({ name, actual, pass });
  save();
  if (!pass) fail(`${record.id}:${name}:${actual}`);
};
const runCase = async (id: CaseRecord['id'], body: (record: CaseRecord) => Promise<void>) => {
  const record = records.find((item) => item.id === id)!;
  record.startedAt = now();
  record.verdict = 'FAIL';
  save();
  try {
    await body(record);
    record.verdict = 'PASS';
  } catch (error) {
    record.failure = error instanceof Error ? error.message : 'UNKNOWN';
    throw error;
  } finally {
    record.endedAt = now();
    save();
  }
};

const http = async (
  base: string,
  method: 'GET' | 'POST',
  path: string,
  body?: Record<string, unknown>,
  accessToken?: string,
): Promise<HttpResult> => {
  requestCount += 1;
  assert(requestCount <= maxRequests, 'HTTP_REQUEST_BUDGET_EXCEEDED');
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(10_000),
  });
  const text = await response.text();
  let json: Record<string, unknown> | undefined;
  if (text) {
    try { json = JSON.parse(text) as Record<string, unknown>; } catch { json = undefined; }
  }
  const error = json?.error as { code?: string } | undefined;
  return {
    status: response.status,
    code: error?.code,
    retryAfter: response.headers.get('retry-after') ?? undefined,
    json,
  };
};
const sessionFrom = (result: HttpResult) => {
  assert(result.status === 200 && result.json, `LOGIN_OR_REFRESH_${result.status}_${result.code ?? 'NO_CODE'}`);
  const accessToken = result.json.accessToken;
  const refreshToken = result.json.refreshToken;
  assert(typeof accessToken === 'string' && typeof refreshToken === 'string', 'SESSION_TOKEN_SHAPE');
  return { accessToken, refreshToken };
};
const mutateToken = (token: string) => `${token.slice(0, -1)}${token.endsWith('a') ? 'b' : 'a'}`;

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
const sessionState = async (userId: string) => {
  const indexKey = `auth:user-sessions:${userId}`;
  const sessionIds = await redis.zrange(indexKey, 0, -1);
  const raw = sessionIds.length > 0
    ? await redis.mget(sessionIds.map((id) => `auth:session:${id}`))
    : [];
  const active = raw.filter((value) => {
    if (!value) return false;
    const parsed = JSON.parse(value) as { revokedAt?: string };
    return !parsed.revokedAt;
  }).length;
  return { indexKey, sessionIds, total: sessionIds.length, active };
};
const resetRunState = async (userIds: string[]) => {
  const keys = new Set(await scanKeys('pawmate:q:v1:*'));
  for (const userId of userIds) {
    const state = await sessionState(userId);
    keys.add(state.indexKey);
    state.sessionIds.forEach((id) => keys.add(`auth:session:${id}`));
  }
  if (keys.size > 0) await redis.del(...keys);
  const remainingQuota = await scanKeys('pawmate:q:v1:*');
  assert(remainingQuota.length === 0, 'RUN_QUOTA_CLEANUP_FAILED');
  for (const userId of userIds) assert((await sessionState(userId)).total === 0, `RUN_SESSION_CLEANUP_FAILED:${userId}`);
  return keys.size;
};

const run = async () => {
  await redis.connect();
  const users = await prisma.user.findMany({
    where: { email: { in: [authEmail, mobileEmail] } },
    select: { id: true, email: true },
  });
  assert(users.length === 2, `FIXTURE_USER_COUNT_${users.length}`);
  const authUser = users.find((user) => user.email === authEmail)!;
  const mobileUser = users.find((user) => user.email === mobileEmail)!;
  const userIds = [authUser.id, mobileUser.id];
  await resetRunState(userIds);

  await runCase('D134-V01', async (record) => {
    const healthA = await http(baseA, 'GET', '/ready');
    const healthB = await http(baseB, 'GET', '/ready');
    check(record, 'two_production_instances_ready', healthA.status === 200 && healthB.status === 200, `A=${healthA.status}; B=${healthB.status}`);

    const wrong = await http(baseA, 'POST', '/auth/login', { email: authEmail, password: `${authPassword}!wrong` });
    check(record, 'invalid_credentials_generic', wrong.status === 401 && wrong.code === 'AUTH_003', `HTTP ${wrong.status}; code=${wrong.code}`);
    check(record, 'invalid_credentials_no_session', (await sessionState(authUser.id)).total === 0, `sessions=${(await sessionState(authUser.id)).total}`);

    const first = sessionFrom(await http(baseA, 'POST', '/auth/login', { email: authEmail, password: authPassword, rememberMe: true }));
    check(record, 'valid_login_instance_a', true, 'HTTP 200; token shape valid');
    const crossInstance = await http(baseB, 'GET', '/pets', undefined, first.accessToken);
    check(record, 'access_valid_across_instance', crossInstance.status === 200, `HTTP ${crossInstance.status}`);
    const tampered = await http(baseB, 'GET', '/pets', undefined, mutateToken(first.accessToken));
    check(record, 'tampered_access_rejected', tampered.status === 401 && tampered.code === 'AUTH_013', `HTTP ${tampered.status}; code=${tampered.code}`);

    const rotated = sessionFrom(await http(baseB, 'POST', '/auth/refresh', { refreshToken: first.refreshToken }));
    check(record, 'refresh_rotates_across_instance', true, 'HTTP 200; replacement token shape valid');
    const rotatedAccess = await http(baseA, 'GET', '/pets', undefined, rotated.accessToken);
    check(record, 'rotated_access_valid_on_other_instance', rotatedAccess.status === 200, `HTTP ${rotatedAccess.status}`);
    await new Promise((resolveWait) => setTimeout(resolveWait, 5_200));
    const replay = await http(baseA, 'POST', '/auth/refresh', { refreshToken: first.refreshToken });
    check(record, 'delayed_refresh_replay_rejected', replay.status === 401 && replay.code === 'AUTH_009', `HTTP ${replay.status}; code=${replay.code}`);
    const revoked = await http(baseB, 'GET', '/pets', undefined, rotated.accessToken);
    check(record, 'replay_revokes_replacement_access', revoked.status === 401 && revoked.code === 'AUTH_013', `HTTP ${revoked.status}; code=${revoked.code}`);
    check(record, 'replay_revokes_all_active_sessions', (await sessionState(authUser.id)).active === 0, `active=${(await sessionState(authUser.id)).active}`);

    const resetBeforeQuota = await resetRunState(userIds);
    check(record, 'independent_quota_case_reset', true, `deletedKeys=${resetBeforeQuota}`);
    const attempts = await Promise.all(Array.from({ length: 11 }, (_, index) => http(index % 2 === 0 ? baseA : baseB, 'POST', '/auth/login', { email: authEmail, password: authPassword, rememberMe: true })));
    const accepted = attempts.filter((item) => item.status === 200).length;
    const rejected = attempts.filter((item) => item.status === 429 && item.code === 'SEC_001').length;
    check(record, 'distributed_n_plus_one_quota', accepted === 10 && rejected === 1, `accepted=${accepted}; rejected=${rejected}`);
    const quotaState = await sessionState(authUser.id);
    check(record, 'rejected_request_has_no_session_side_effect', quotaState.total === 10, `sessionRecords=${quotaState.total}`);
    const rejectedResult = attempts.find((item) => item.status === 429);
    check(record, 'quota_retry_after_present', Boolean(rejectedResult?.retryAfter && Number(rejectedResult.retryAfter) > 0), `retryAfter=${rejectedResult?.retryAfter ?? 'missing'}`);
    const quotaKeys = await scanKeys('pawmate:q:v1:*');
    check(record, 'quota_keys_do_not_leak_identity', quotaKeys.length > 0 && quotaKeys.every((key) => !key.toLowerCase().includes(authEmail.toLowerCase())), `keys=${quotaKeys.length}; rawIdentityPresent=${quotaKeys.some((key) => key.toLowerCase().includes(authEmail.toLowerCase()))}`);
    const cleanupCount = await resetRunState(userIds);
    check(record, 'v01_exact_run_cleanup', true, `deletedKeys=${cleanupCount}`);
  });

  await runCase('D134-V02', async (record) => {
    const first = sessionFrom(await http(baseA, 'POST', '/auth/login', { email: mobileEmail, password: mobilePassword }));
    const second = sessionFrom(await http(baseB, 'POST', '/auth/login', { email: mobileEmail, password: mobilePassword }));
    check(record, 'two_client_sessions_created', (await sessionState(mobileUser.id)).active === 2, `active=${(await sessionState(mobileUser.id)).active}`);
    const logout = await http(baseA, 'POST', '/auth/logout', { refreshToken: first.refreshToken });
    check(record, 'logout_instance_a', logout.status === 204, `HTTP ${logout.status}`);
    const secondRefresh = await http(baseB, 'POST', '/auth/refresh', { refreshToken: second.refreshToken });
    check(record, 'other_client_refresh_revoked', secondRefresh.status === 401 && secondRefresh.code === 'AUTH_009', `HTTP ${secondRefresh.status}; code=${secondRefresh.code}`);
    const firstAccess = await http(baseA, 'GET', '/pets', undefined, first.accessToken);
    const secondAccess = await http(baseB, 'GET', '/pets', undefined, second.accessToken);
    check(record, 'both_access_tokens_revoked', firstAccess.status === 401 && secondAccess.status === 401, `A=${firstAccess.status}; B=${secondAccess.status}`);
    check(record, 'logout_revokes_all_active_sessions', (await sessionState(mobileUser.id)).active === 0, `active=${(await sessionState(mobileUser.id)).active}`);
    const cleanupCount = await resetRunState(userIds);
    check(record, 'v02_exact_run_cleanup', true, `deletedKeys=${cleanupCount}`);
  });

  const databaseRowCount = await prisma.user.count({ where: { email: { in: [authEmail, mobileEmail] } } });
  assert(databaseRowCount === 2, `FIXTURE_ROWS_CHANGED_${databaseRowCount}`);
  const summary = {
    schemaVersion: 1,
    runId,
    verdict: records.every((item) => item.verdict === 'PASS') ? 'PASS' : 'FAIL',
    requestCount,
    maximumRequests: maxRequests,
    fixtureDatabaseRows: databaseRowCount,
    quotaKeysRemaining: (await scanKeys('pawmate:q:v1:*')).length,
    sessionRecordsRemaining: (await Promise.all(userIds.map((id) => sessionState(id)))).reduce((sum, item) => sum + item.total, 0),
    artifactSha256: createHash('sha256').update(readFileSync(artifact)).digest('hex'),
  };
  writeFileSync(join(evidenceRoot, 'auth-abuse-summary.json'), `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  return summary;
};

run()
  .then((summary) => process.stdout.write(`${JSON.stringify(summary)}\n`))
  .catch((error: unknown) => {
    save();
    process.stderr.write(`${JSON.stringify({ runId, verdict: 'FAIL', error: error instanceof Error ? error.message : 'UNKNOWN' })}\n`);
    process.exitCode = 1;
  })
  .finally(async () => {
    redis.disconnect();
    await prisma.$disconnect();
  });

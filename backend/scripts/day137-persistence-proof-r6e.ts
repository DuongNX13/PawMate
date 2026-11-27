// Test-only: production handlers + exclusive PostgreSQL/PostGIS/Redis.
// No provider operation is executed or counted as covered in this lane.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import { buildApp } from '../src/app';
import { loadEnv } from '../src/config/env';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';
import { claimRequest } from './day137-persistence-budget-r6.mjs';
import { buildPersistencePlan, expectedRowFields } from '../../scripts/qa/day137/day137-persistence-plan-r6.mjs';
import { resolvePointer, validateAnchoredFields } from '../../scripts/qa/day137/validate-day137-completion-r5.mjs';
import { exclusiveEffect } from '../../scripts/qa/day137/day137-persistence-effects-r6.mjs';

const root = path.resolve(__dirname, '../..');
const out = process.env.DAY137_EVIDENCE_ROOT!;
const runId = process.env.DAY137_RUN_ID!;
const envelope = process.env.DAY137_ENVELOPE_PATH!;
const db = process.env.DATABASE_URL!;
const redisUrl = process.env.REDIS_URL!;
assert(/^d137-local-persist-[a-z0-9-]{6,28}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root, 'output-evidence/security/day137') + path.sep));
assert.equal(new URL(db).hostname, '127.0.0.1');
assert.equal(new URL(redisUrl).hostname, '127.0.0.1');
const hash = (v: Buffer | string) => createHash('sha256').update(v).digest('hex');
const write = (name: string, v: unknown) => fs.writeFileSync(path.join(out, name), JSON.stringify(v, null, 2) + '\n');
const ref = (name: string) => { const b = fs.readFileSync(path.join(out, name)); return { path: path.relative(root, path.join(out, name)).replaceAll('\\', '/'), bytes: b.length, sha256: hash(b) }; };
const sourcePath=process.env.DAY137_SOURCE_MANIFEST??'output-evidence/security/day137/d137-entry-20261001-r1/source-manifest.json';
assert(!path.isAbsolute(sourcePath)&&!sourcePath.split(/[\\/]/).includes('..'),'UNSAFE_SOURCE_MANIFEST');
const sourceManifest = JSON.parse(fs.readFileSync(path.join(root, sourcePath), 'utf8'));
const checkSource = () => {
  for (const f of sourceManifest.files) { const b = fs.readFileSync(path.join(root, f.path)); assert.equal(b.length, f.bytes, `SOURCE_BYTES:${f.path}`); assert.equal(hash(b), f.sha256, `SOURCE_HASH:${f.path}`); }
};
checkSource();
const sourceFingerprint = sourceManifest.sourceFingerprint;
const producerHash = hash(fs.readFileSync(__filename));
const psql = path.join(root, 'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const pgArgs = ['-h', '127.0.0.1', '-p', new URL(db).port, '-U', 'pawmate', '-d', new URL(db).pathname.slice(1), '-At', '-v', 'ON_ERROR_STOP=1'];
const sql = (query: string) => JSON.parse(execFileSync(psql, [...pgArgs, '-c', query], { encoding: 'utf8', timeout: 10000 }).trim());
const tables = [...fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8').matchAll(/@@map\("([a-z_]+)"\)/g)].map(m => m[1]);
const snapshotQuery = `SELECT jsonb_object_agg(name,value) FROM (${tables.map(t => `SELECT '${t}' name,jsonb_build_object('count',count(*),'contentHash',md5(coalesce(string_agg(row_to_json(t)::text,'' ORDER BY row_to_json(t)::text),''))) value FROM "${t}" t`).join(' UNION ALL ')}) s;`;
const snapshot = () => sql(snapshotQuery);
const prisma = new PrismaClient({ datasources: { db: { url: db } } });
const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const roleNames = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'];
const f: any = { users: Object.fromEntries(roleNames.map(r => [r, randomUUID()])), pet: randomUUID(), otherPet: randomUUID(), missingPet: randomUUID(), health: randomUUID(), reminder: randomUUID(), missingChild: randomUUID(), reminderAt: '2030-01-01T00:00:00.000Z', snoozeAt: '2030-01-02T00:00:00.000Z' };
const plan = buildPersistencePlan(f).filter(c => c.expectedStatus < 300);
const requirements: any[] = [];
const expectedFixture = { kind: 'DAY137_EXPECTED_FIXTURE', runId, sourceFingerprint, values: f };
write('expected-fixture.json', expectedFixture);
write('plan.json', { runId, sourceFingerprint, producerHash, fixtureRef: ref('expected-fixture.json'), cases: plan });
const provider = loadEnv(); // configured adapter only; no secrets are serialized
const config = { ...buildTestConfig(), nodeEnv: 'production' as const, databaseUrl: db, redisUrl, supabaseUrl: provider.supabaseUrl, supabaseAnonKey: provider.supabaseAnonKey, supabaseServiceRoleKey: provider.supabaseServiceRoleKey, supabaseProjectRef: provider.supabaseProjectRef, supabaseBuckets: provider.supabaseBuckets,
  auth: { ...buildTestConfig().auth, accessTokenSecret: 'day137-persistence-access-local-only-20261002', refreshTokenSecret: 'day137-persistence-refresh-local-only-20261002' } };
let cloudCalls = 0;
const oldFetch = globalThis.fetch;
globalThis.fetch = (async () => { cloudCalls++; throw new Error('NETWORK_NOT_AUTHORIZED_IN_LOCAL_LANE'); }) as typeof fetch;
const app = buildApp({ logger: false }, { config });
const sessions: Record<string, string> = {};
const cases: any[] = [];
let requestCount = 0;
let failure: unknown;
let cleaned = false;
const save = () => write('cross-role-results.json', { schemaVersion: 1, runId, sourceFingerprint, cases, requestCount, cloudCalls, verdict: failure ? 'FAIL' : cases.length === plan.length && cases.every(c => c.verdict === 'PASS') ? 'PASS_PERSISTENCE_SLICE' : 'PARTIAL', limitations: ['Selected Pet/Health/Reminder state slice only; not whole Day137 acceptance', 'Fastify inject is in-process transport; SQL/PostGIS and Redis are real', 'No live Supabase Auth/Storage calls; prior provider evidence remains immutable'] });
const call = async (method: any, url: string, role: string, payload?: any) => {
  claimRequest(envelope); requestCount++;
  return app.inject({ method, url, ...(payload === undefined ? {} : { payload }), headers: role === 'anonymous' ? {} : { authorization: `Bearer ${sessions[role]}` } });
};
async function seed(c: any) {
  await prisma.healthRecord.deleteMany(); await prisma.reminder.deleteMany(); await prisma.pet.deleteMany();
  const common = { userId: f.users.owner_adopter, species: 'dog' as const, name: 'Seed pet', breed: 'Corgi', color: 'Vàng trắng' };
  if (c.parent !== 'missing') await prisma.pet.create({ data: { id: f.pet, ...common, deletedAt: c.parent === 'deleted' ? new Date('2026-09-30T00:00:00Z') : null } });
  await prisma.pet.create({ data: { id: f.otherPet, ...common } });
  if (c.parent !== 'missing') {
    const parent = c.resource === 'wrong_parent' ? f.otherPet : f.pet;
    const deletedAt = c.resource === 'deleted' ? new Date('2026-09-30T00:00:00Z') : null;
    if (!(c.table === 'health' && c.resource === 'missing')) await prisma.healthRecord.create({ data: { id: f.health, petId: parent, createdByUserId: f.users.owner_adopter, recordType: 'checkup', recordDate: new Date('2026-09-30'), title: 'Seed checkup', attachments: [], deletedAt } });
    if (!(c.table === 'reminder' && c.resource === 'missing')) await prisma.reminder.create({ data: { id: f.reminder, petId: parent, createdByUserId: f.users.owner_adopter, title: 'Seed reminder', reminderAt: new Date(f.reminderAt), nextTriggerAt: c.state === 'done' ? null : new Date(c.state === 'snoozed' ? f.snoozeAt : f.reminderAt), repeatRule: 'none', timezone: 'Asia/Bangkok', status: c.state === 'done' ? 'done' : 'scheduled', completedAt: c.state === 'done' ? new Date('2026-09-30T00:00:00Z') : null, snoozedUntil: c.state === 'snoozed' ? new Date(f.snoozeAt) : null, deletedAt } });
  }
}
const tableName = (table: string) => ({ pet: 'pets', health: 'health_records', reminder: 'reminders' })[table]!;
function recipeFields(c: any) {
  if (c.expectedStatus >= 400) return { response: { '/error/code': c.error }, sql: { '/unchanged': true, '/outboxDelta': 0 }, absentData: true };
  if (c.operation.endsWith('LIST')) {
    const n = c.state === 'done' && !c.url.includes('includeDone') ? 0 : 1;
    const response: any = { '/data/total': n, '/data/limit': 20, '/data/items/length': n };
    if (n) {
      response['/data/items/0/id'] = c.table === 'health' ? f.health : f.reminder;
      response['/data/items/0/petId'] = f.pet;
      response['/data/items/0/createdByUserId'] = f.users.owner_adopter;
      response['/data/items/0/title'] = c.table === 'health' ? 'Seed checkup' : 'Seed reminder';
      if (c.table === 'reminder') response['/data/items/0/status'] = c.state === 'done' ? 'done' : 'scheduled';
    }
    return { response, sql: { '/unchanged': true, '/outboxDelta': 0, '/row/deleted': false,
      ...Object.fromEntries(Object.entries(expectedRowFields(c, f)).map(([k,v]) => [`/row/${k}`, v])) } };
  }
  const row: Record<string, unknown> = expectedRowFields(c, f);
  if (c.method === 'DELETE' && c.table === 'reminder') row.status = 'cancelled';
  const sqlFields: any = Object.fromEntries(Object.entries(row).map(([k,v]) => [`/row/${k}`, v]));
  sqlFields['/row/deleted'] = c.method === 'DELETE';
  sqlFields['/changedOnlyTargetTable'] = c.method !== 'GET';
  sqlFields['/outboxDelta'] = 0;
  sqlFields['/exclusiveRowEffect'] = true;
  sqlFields['/rowCountDelta'] = c.operation.endsWith('CREATE') ? 1 : 0;
  if (c.operation.endsWith('CREATE')) sqlFields['/newTargetId'] = true;
  if (c.method === 'GET') { delete sqlFields['/changedOnlyTargetTable']; sqlFields['/unchanged'] = true; }
  if (c.operation === 'REMINDER-DONE') sqlFields['/row/completed_in_request_window'] = true;
  if (c.method === 'DELETE') sqlFields['/row/deleted_in_request_window'] = true;
  const response: any = {};
  if (c.method !== 'DELETE') {
    if (c.table === 'pet') { response['/data/userId'] = f.users.owner_adopter; response['/data/name'] = row.name; }
    else { response['/data/petId'] = f.pet; response['/data/createdByUserId'] = f.users.owner_adopter; response['/data/title'] = row.title; }
    if (c.table === 'reminder') response['/data/status'] = row.status;
  }
  return { response, sql: sqlFields };
}
for (const c of plan) requirements.push({ id: c.id, role: c.role, state: c.state, method: c.method, path: c.url.split('?')[0], concreteUrl: c.url, expectedStatus: c.expectedStatus,
  ...(() => { const rules = recipeFields(c); const oracles = Object.entries({ response: rules.response, sql_after: rules.sql }).flatMap(([source, fields]) => Object.entries(fields).map(([pointer,value]) => ({ id: `${source}:${pointer}`, expected: { kind: 'literal', value }, actual: { source, pointer, producerSourceSha256: producerHash } }))); return { assertionIds: oracles.map(o => o.id), assertionOracles: oracles }; })() });
write('anchored-contract.json', { sourceFingerprint, fixtureRef: ref('expected-fixture.json'), requirements });
const frozenContract = ref('anchored-contract.json');
write('preflight-references.json', { frozenContract, plan: ref('plan.json'), fixture: ref('expected-fixture.json'), sourceFingerprint, producerHash });
async function run() {
  await redis.connect(); assert.equal(await redis.dbsize(), 0); assert(Object.values(snapshot()).every((t:any) => t.count === 0));
  await prisma.user.createMany({ data: roleNames.map(role => ({ id: f.users[role], email: `${runId}-${role.toLowerCase()}@pawmate.test`, passwordHash: bcrypt.hashSync('Day137PersistenceLocalFixture!2026', 4), displayName: role, emailVerified: true })) });
  await app.ready();
  for (const role of roleNames) { const r = await call('POST', '/auth/login', 'anonymous', { email: `${runId}-${role.toLowerCase()}@pawmate.test`, password: 'Day137PersistenceLocalFixture!2026' }); assert.equal(r.statusCode, 200); sessions[role] = r.json().accessToken; }
  for (const planned of plan) {
    await seed(planned);
    const before = snapshot();
    const targetTable = tableName(planned.table);
    const rowsQuery = `SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY id),'[]'::jsonb) FROM ${targetTable} t;`;
    const rowsBefore = sql(rowsQuery);
    const startedDb = sql('SELECT to_json(clock_timestamp());');
    const c: any = { id: planned.id, requirementId: planned.id, runId, sourceFingerprint, role: planned.role, state: planned.state, method: planned.method, url: planned.url, expected: planned.expectedStatus, basis: planned.basis, precondition: { fixtureRef: ref('expected-fixture.json'), setup: { parent: planned.parent, resource: planned.resource }, beforeSqlHash: hash(JSON.stringify(before)) }, startedAt: new Date().toISOString(), verdict: 'NOT_RUN', reviewer: 'script-runtime-assertions', fieldChecks: [] };
    cases.push(c); save();
    try {
      const r = await call(planned.method, planned.url, planned.role, planned.payload);
      const endedDb = sql('SELECT to_json(clock_timestamp());');
      const response = r.headers['content-type']?.includes('json') ? r.json() : { bodyBytes: Buffer.byteLength(r.body) };
      const after = snapshot();
      const rowsAfter = sql(rowsQuery);
      const table = tableName(planned.table);
      let id = planned.table === 'pet' ? f.pet : planned.table === 'health' ? f.health : f.reminder;
      if (planned.operation.endsWith('CREATE') && r.statusCode < 300) id = response.data.id;
      assert(/^[a-f0-9-]{36}$/.test(id), 'FIXTURE_UUID_REQUIRED');
      // Missing row must return JSON null, not an empty psql field.
      const rowQuery = `SELECT coalesce((SELECT to_jsonb(t) FROM ${table} t WHERE id='${id}'::uuid),'null'::jsonb);`;
      const rawRow = sql(rowQuery);
      const row = rawRow ? { ...rawRow } : null;
      if (row) {
        for (const field of ['next_trigger_at','snoozed_until']) if (row[field]) row[field] = new Date(row[field] + (/Z$|[+-]\d\d:\d\d$/.test(row[field]) ? '' : 'Z')).toISOString();
        row.deleted = rawRow.deleted_at !== null;
        for (const [column, key] of [['deleted_at','deleted_in_request_window'], ['completed_at','completed_in_request_window']]) row[key] = rawRow[column] !== null && new Date(rawRow[column] + (/Z$|[+-]\d\d:\d\d$/.test(rawRow[column]) ? '' : 'Z')).getTime() >= new Date(startedDb).getTime() && new Date(rawRow[column] + (/Z$|[+-]\d\d:\d\d$/.test(rawRow[column]) ? '' : 'Z')).getTime() <= new Date(endedDb).getTime();
      }
      const changed = tables.filter(t => JSON.stringify(before[t]) !== JSON.stringify(after[t]));
      const effect = exclusiveEffect({ before: rowsBefore, after: rowsAfter, targetId: id, create: planned.operation.endsWith('CREATE'), readOnly: planned.method === 'GET' });
      assert.equal(effect.valid, true, 'EXCLUSIVE_ROW_EFFECT');
      const sqlAfter = { row, unchanged: changed.length === 0, changedOnlyTargetTable: changed.length === 1 && changed[0] === table, outboxDelta: after.outbox_events.count - before.outbox_events.count, ...effect };
      const sqlName = `${c.id}-sql.json`;
      write(sqlName, { runId, caseId: c.id, sourceFingerprint, startedDb, endedDb, command: [psql, ...pgArgs, '-c', rowQuery], snapshotQuery, query: rowQuery, rowsQuery, rowsCommand: [psql,...pgArgs,'-c',rowsQuery], rowsBefore, rowsAfter, targetTable, targetId: id, rawRow, before, after, sql_after: sqlAfter });
      const sqlProofName = `${c.id}-projection-sql.json`;
      const responseProofName = `${c.id}-projection-response.json`;
      const identity = { kind: 'DAY137_INDEPENDENT_FIELD_PROJECTION', runId, caseId: c.id, requirementId: c.id, sourceFingerprint, role: c.role, state: c.state, method: c.method, url: c.url, status: r.statusCode, producerSourceSha256: producerHash };
      write(sqlProofName, { ...identity, producerKind: 'independent_sql', rawSqlRef: ref(sqlName), sql_after: sqlAfter });
      write(responseProofName, { ...identity, producerKind: 'response', response });
      c.actual = { status: r.statusCode, error: response.error?.code };
      c.sqlOracle = sqlName;
      assert.equal(r.statusCode, planned.expectedStatus, `${c.id}: ${r.statusCode} ${response.error?.code}`);
      if (planned.expectedStatus >= 400) assert(!Object.hasOwn(response, 'data'), 'DENIED_RESPONSE_DATA');
      if (planned.method === 'DELETE' && r.statusCode < 300) assert.equal(r.body, '');
      const requirement = requirements.find(req => req.id === c.id);
      for (const oracle of requirement.assertionOracles) {
        const actual = resolvePointer(oracle.actual.source === 'response' ? response : sqlAfter, oracle.actual.pointer);
        const expected = oracle.expected.value;
        c.fieldChecks.push({ id: oracle.id, actual, expected, projectionRef: ref(oracle.actual.source === 'response' ? responseProofName : sqlProofName) });
        assert.deepEqual(actual, expected, `${c.id}:${oracle.id}`);
      }
      // The API-minted ID is checked by independent lookup, not copied into a preflight expectation.
      if (r.statusCode < 300 && !planned.operation.endsWith('LIST') && planned.method !== 'DELETE') assert.equal(row.id, response.data.id, 'RESPONSE_ROW_IDENTITY');
      c.verdict = 'PASS';
    } catch(e) { c.verdict = 'FAIL'; c.failure = String(e); throw e; }
    finally { c.endedAt = new Date().toISOString(); save(); }
  }
  assert.equal(cloudCalls, 0);
  checkSource();
  const loadReference = (reference: any) => { const b = fs.readFileSync(path.join(root, reference.path)); assert.equal(b.length, reference.bytes); assert.equal(hash(b), reference.sha256); return JSON.parse(b.toString('utf8')); };
  const proof = validateAnchoredFields({ results: { runId, sourceFingerprint, cases }, contract: loadReference(frozenContract), loadReference });
  write('anchored-validation.json', { ...proof, sourceFingerprint, selectedCases: plan.length, selectedCasePass: cases.filter(c => c.verdict === 'PASS').length, fieldAssertions: cases.reduce((n,c) => n+c.fieldChecks.length,0), cloudCalls, frozenContract, producerHash, runtimeProvenance: 'psql subprocess queries and Fastify responses retained; native runner exit/cleanup separately required', fullDay137Acceptance: false });
  assert.equal(proof.verdict, 'PASS_ANCHORED_FIELD_PROOF');
}
run().catch(e => { failure = e; console.error(String(e)); process.exitCode = 1; }).finally(async () => {
  save();
  try {
    const before = snapshot();
    await prisma.$executeRawUnsafe(`TRUNCATE ${tables.map(t => `"${t}"`).join(',')} CASCADE`);
    const after = snapshot(); const keys = await redis.keys('*'); if (keys.length) await redis.del(...keys);
    const remainingRows = Object.values(after).reduce((n:number,t:any) => n+t.count,0);
    const redisRemaining = await redis.dbsize(); assert.equal(remainingRows,0); assert.equal(redisRemaining,0);
    cleaned = true; checkSource();
    write('fixture-cleanup.json', { runId, fixtureOnlyDisposable: true, sqlBefore: before, sqlAfter: after, remainingRows, redisRemaining, sourceFingerprint, protectedFiles: sourceManifest.files.length, cloudCalls });
  } catch(e) { console.error(`CLEANUP:${e}`); process.exitCode = 1; }
  await app.close(); await prisma.$disconnect(); redis.disconnect(); globalThis.fetch = oldFetch;
  if (failure) write('first-failure.json', { at: new Date().toISOString(), error: String(failure), cleanupVerified: cleaned });
});

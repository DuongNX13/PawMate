// Test-only production-handler proof; real owned SQL/Redis, zero provider calls.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import { loadEnv } from '../src/config/env';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';
import { claimRequest } from './day137-adoptionlocal-budget-r15.mjs';
import { buildAdoptionLocalPlan } from '../../scripts/qa/day137/day137-adoptionlocal-plan-r15.mjs';
import { validateAdoptionLocalCase, adoptionRowsQuery } from '../../scripts/qa/day137/day137-adoptionlocal-oracle-r15.mjs';
import { snapshotContract } from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';
const root = path.resolve(__dirname, '../..'), out = process.env.DAY137_EVIDENCE_ROOT!, runId = process.env.DAY137_RUN_ID!, envelope = process.env.DAY137_ENVELOPE_PATH!, db = process.env.DATABASE_URL!, redisUrl = process.env.REDIS_URL!;
assert(/^d137-local-adoptionlocal-[a-z0-9-]{6,28}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root, 'output-evidence/security/day137') + path.sep));
assert.equal(new URL(db).hostname, '127.0.0.1'); assert.equal(new URL(redisUrl).hostname, '127.0.0.1');
const hash = (v: Buffer | string) => createHash('sha256').update(v).digest('hex');
const write = (n: string, v: unknown) => fs.writeFileSync(path.join(out, n), JSON.stringify(v, null, 2) + '\n');
const ref = (n: string) => { const b = fs.readFileSync(path.join(out, n)); return { path: path.relative(root, path.join(out, n)).replaceAll('\\', '/'), bytes: b.length, sha256: hash(b) }; };
const source = JSON.parse(fs.readFileSync(path.join(root, 'output-evidence/security/day137/d137-completion-20261005-r13/source-manifest.json'), 'utf8'));
const checkSource = () => { for (const f of source.files) { const b = fs.readFileSync(path.join(root, f.path)); assert.equal(b.length, f.bytes); assert.equal(hash(b), f.sha256, f.path); } }; checkSource();
const sourceFingerprint = source.sourceFingerprint, producerHash = hash(fs.readFileSync(__filename));
const psql = path.join(root, 'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const pgArgs = ['-h', '127.0.0.1', '-p', new URL(db).port, '-U', 'pawmate', '-d', new URL(db).pathname.slice(1), '-At', '-v', 'ON_ERROR_STOP=1'];
const sql = (q: string) => JSON.parse(execFileSync(psql, [...pgArgs, '-c', q], { encoding: 'utf8', timeout: 10000 }).trim());
const schema = fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8'), contract = snapshotContract(schema);
const snapshot = () => sql(contract.query), rows = () => sql(adoptionRowsQuery);
const prisma = new PrismaClient({ datasources: { db: { url: db } } }), redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const roleNames = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'], listingKeys = ['a', 'b', 'c', 'd', 'e'];
const provider = loadEnv(), base = buildTestConfig();
const config = { ...base, nodeEnv: 'production' as const, databaseUrl: db, redisUrl, supabaseUrl: provider.supabaseUrl, supabaseAnonKey: provider.supabaseAnonKey, supabaseServiceRoleKey: provider.supabaseServiceRoleKey, supabaseProjectRef: provider.supabaseProjectRef, supabaseBuckets: provider.supabaseBuckets, auth: { ...base.auth, accessTokenSecret: 'day137-adoptionlocal-access-local-only', refreshTokenSecret: 'day137-adoptionlocal-refresh-local-only' } };
const f: any = { users: Object.fromEntries(roleNames.map(r => [r, randomUUID()])), emails: Object.fromEntries(roleNames.map(r => [r, `${runId}-${r.toLowerCase()}@pawmate.test`])), listings: Object.fromEntries(listingKeys.map(k => [k, randomUUID()])), media: Object.fromEntries(listingKeys.map(k => [k, randomUUID()])), seedRequests: { owner_adopter: randomUUID(), outsider: randomUUID() }, missingId: randomUUID(), listingValues: { a: { role: 'shelter_A', petName: 'Mochi A', species: 'dog', status: 'available', stamp: '2026-09-02T00:00:00Z' }, b: { role: 'shelter_B', petName: 'Kem B', species: 'cat', status: 'available', stamp: '2026-09-01T00:00:00Z' }, c: { role: 'shelter_A', petName: 'Older C', species: 'dog', status: 'closed', stamp: '2026-08-01T00:00:00Z' }, d: { role: 'shelter_B', petName: 'Older D', species: 'rabbit', status: 'closed', stamp: '2026-08-01T00:00:00Z' }, e: { role: 'shelter_A', petName: 'Deleted E', species: 'dog', status: 'available', stamp: '2026-08-01T00:00:00Z' } } };
const plan = buildAdoptionLocalPlan(f);
write('expected-fixture.json', { runId, sourceFingerprint, values: f }); write('plan.json', { runId, sourceFingerprint, producerHash, cases: plan });
write('preflight-references.json', { plan: ref('plan.json'), fixture: ref('expected-fixture.json'), sourceFingerprint, producerHash });
let cloudCalls = 0; const oldFetch = globalThis.fetch;
globalThis.fetch = (async () => { cloudCalls++; throw new Error('LOCAL_ADOPTION_PROVIDER_NETWORK_FORBIDDEN'); }) as typeof fetch;
let app: any, requestCount = 0, failure: unknown, cleaned = false;
const cases: any[] = [], sessions: Record<string, any> = {}, initialSessions: Array<{ key: string; value: string }> = [];
const save = () => write('cross-role-results.json', { schemaVersion: 1, runId, sourceFingerprint, producerHash, cases, requestCount, cloudCalls, verdict: failure ? 'FAIL' : cases.length === plan.length && cases.every(c => c.verdict === 'PASS') ? 'PASS_ADOPTIONLOCAL_SLICE' : 'PARTIAL', limitations: ['25 canonical only; metadata fixtures are not provider/media byte proof', 'production handlers, real SQL/Redis; Fastify in-process HTTP not deployed TCP'] });
const call = async (method: string, url: string, role: string, payload?: any, idem?: string) => { claimRequest(envelope); requestCount++; return app.inject({ method, url, payload, headers: { ...(role === 'anonymous' ? {} : { authorization: `Bearer ${sessions[role].accessToken}` }), ...(idem ? { 'idempotency-key': idem } : {}) } }); };
async function reset(p: any) {
  await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.filter(t => t !== 'users').map(t => `"${t}"`).join(',')} CASCADE`);
  await prisma.user.updateMany({ data: { emailVerified: true } });
  const keys = await redis.keys('*'); if (keys.length) await redis.del(...keys);
  for (const s of initialSessions) await redis.set(s.key, s.value, 'EX', 30 * 86400);
  for (const key of listingKeys) {
    const v = f.listingValues[key], stamp = new Date(v.stamp);
    await prisma.mediaAsset.create({ data: { id: f.media[key], ownerUserId: f.users[v.role], purpose: 'adoption_listing', mimeType: 'image/jpeg', sizeBytes: 123, sha256: 'a'.repeat(64), status: 'attached', storageKey: `${runId}/${f.media[key]}.jpg`, publicUrl: `https://fixtures.invalid/${f.media[key]}.jpg`, width: 800, height: 600, createdAt: stamp, updatedAt: stamp } });
    await prisma.adoptionListing.create({ data: { id: f.listings[key], shelterId: f.users[v.role], heroMediaId: f.media[key], petName: v.petName, species: v.species, breed: 'Fixture breed', ageLabel: '2 years', ageMonths: 24, description: 'Synthetic adoption fixture', traits: ['friendly'], healthBadges: ['vaccinated'], verificationBadges: ['verified_shelter'], status: p.kind === 'list' && p.state === 'empty' ? 'closed' : v.status, deletedAt: key === 'e' ? stamp : null, createdAt: stamp, updatedAt: stamp } });
  }
  for (const role of ['owner_adopter', 'outsider']) if (!(p.kind === 'requests' && p.state === 'empty')) {
    const listing = role === 'owner_adopter' ? 'c' : 'd', stamp = new Date('2026-09-03T00:00:00Z');
    await prisma.adoptionRequest.create({ data: { id: f.seedRequests[role], listingId: f.listings[listing], adopterUserId: f.users[role], shelterId: f.users[f.listingValues[listing].role], livingCondition: 'Seed home', petExperience: 'Seed experience', carePlan: 'Seed care', commitmentAccepted: true, status: 'submitted', createdAt: stamp, updatedAt: stamp } });
  }
  if (p.state === 'revoked' && p.role !== 'anonymous') { const r = await call('POST', '/auth/logout', 'anonymous', { refreshToken: sessions[p.role].refreshToken }); assert.equal(r.statusCode, 204); }
}
async function run() {
  const { buildApp } = await import('../src/app'); app = buildApp({ logger: false }, { config }); await app.ready(); await redis.connect();
  assert.equal(await redis.dbsize(), 0); assert(Object.values(snapshot()).every((t: any) => t.count === 0));
  const password = 'Day137AdoptionSynthetic!2026', stamp = new Date('2026-09-01T00:00:00Z');
  await prisma.user.createMany({ data: roleNames.map(role => ({ id: f.users[role], email: f.emails[role], passwordHash: bcrypt.hashSync(password, 4), displayName: role, emailVerified: true, createdAt: stamp, updatedAt: stamp })) });
  for (const role of roleNames) { const r = await call('POST', '/auth/login', 'anonymous', { email: f.emails[role], password }); assert.equal(r.statusCode, 200); sessions[role] = r.json(); }
  for (const key of await redis.keys('auth:session:*')) initialSessions.push({ key, value: (await redis.get(key))! });
  for (const p of plan) {
    await reset(p);
    const before = snapshot(), rowsBefore = rows(), startedDb = sql('SELECT to_json(clock_timestamp());');
    const identity = { runId, id: p.id, sourceFingerprint, producerHash, method: p.method, url: p.url, role: p.role, state: p.state };
    const c: any = { ...identity, startedAt: new Date().toISOString(), precondition: { fixtureRef: ref('expected-fixture.json'), reset: 'isolated tables/quotas and production-created sessions reset; two other closed-listing requests seeded' }, command: ['Fastify.inject', p.method, p.url], reviewer: 'independent psql exact field/effect oracle', verdict: 'NOT_RUN' }; cases.push(c); save();
    try {
      const invoke = async (i: number) => {
        const changed = p.state === 'conflict' && i === 1 ? p.kind === 'decision' ? { decision: 'skip' } : { ...p.payload, note: 'Different fixture' } : p.payload;
        const response = await call(p.method, p.url, p.role, changed, p.method === 'POST' ? p.idempotencyKey + (p.state === 'duplicate' && i === 1 ? '-new' : '') : undefined);
        return { status: response.statusCode, body: response.json(), cacheControl: response.headers['cache-control'] };
      };
      const responses = p.concurrent ? await Promise.all([invoke(0), invoke(1)]) : [await invoke(0)];
      if (p.repeat && !p.concurrent) responses.push(await invoke(1));
      const endedDb = sql('SELECT to_json(clock_timestamp());'), after = snapshot(), rowsAfter = rows();
      write(`${p.id}-response.json`, { ...identity, responses });
      write(`${p.id}-sql.json`, { ...identity, query: contract.query, command: [psql, ...pgArgs, '-c', contract.query], rowQuery: adoptionRowsQuery, rowCommand: [psql, ...pgArgs, '-c', adoptionRowsQuery], before, after, rowsBefore, rowsAfter, startedDb, endedDb });
      c.responseRef = ref(`${p.id}-response.json`); c.sqlRef = ref(`${p.id}-sql.json`); c.actual = { statuses: responses.map(x => x.status) };
      const load = (r: any) => JSON.parse(fs.readFileSync(path.join(root, r.path), 'utf8'));
      const proof = validateAdoptionLocalCase({ planned: p, actual: c, raw: load(c.responseRef), sql: load(c.sqlRef), fixture: f, runId, sourceFingerprint, producerHash, schema }); c.assertions = proof.assertions; assert.equal(proof.verdict, 'PASS', JSON.stringify(proof.errors)); c.verdict = 'PASS';
    } catch (e) { c.verdict = 'FAIL'; c.failure = String(e); throw e; } finally { c.endedAt = new Date().toISOString(); save(); }
  }
  assert.equal(cloudCalls, 0); checkSource();
}
run().catch(e => { failure = e; console.error(String(e)); process.exitCode = 1; }).finally(async () => {
  save(); try {
    const before = snapshot(); await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.map(t => `"${t}"`).join(',')} CASCADE`);
    const after = snapshot(), keys = await redis.keys('*'); if (keys.length) await redis.del(...keys);
    const remainingRows = Object.values(after).reduce((n: number, t: any) => n + t.count, 0), redisRemaining = await redis.dbsize(); assert.equal(remainingRows, 0); assert.equal(redisRemaining, 0); checkSource(); cleaned = true;
    write('fixture-cleanup.json', { runId, sourceFingerprint, fixtureOnlyDisposable: true, sqlBefore: before, sqlAfter: after, remainingRows, redisRemaining, cloudCalls });
  } catch (e) { console.error(`CLEANUP:${e}`); process.exitCode = 1; }
  await app?.close(); await prisma.$disconnect(); redis.disconnect(); globalThis.fetch = oldFetch;
  if (failure) write('first-failure.json', { at: new Date().toISOString(), error: String(failure), cleanupVerified: cleaned });
});

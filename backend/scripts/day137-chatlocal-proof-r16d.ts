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
import { claimRequest } from './day137-chatlocal-budget-r16.mjs';
import { buildChatLocalPlan } from '../../scripts/qa/day137/day137-chatlocal-plan-r16d.mjs';
import { restoreSessionFixture } from '../../scripts/qa/day137/day137-auth-fixture-reset-r15b.mjs';
import { validateChatLocalCase, chatRowsQuery } from '../../scripts/qa/day137/day137-chatlocal-oracle-r16.mjs';
import { snapshotContract } from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';
const root = path.resolve(__dirname, '../..'), out = process.env.DAY137_EVIDENCE_ROOT!, runId = process.env.DAY137_RUN_ID!, envelope = process.env.DAY137_ENVELOPE_PATH!, db = process.env.DATABASE_URL!, redisUrl = process.env.REDIS_URL!;
assert(/^d137-local-chatlocal-[a-z0-9-]{6,28}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root, 'output-evidence/security/day137') + path.sep));
assert.equal(new URL(db).hostname, '127.0.0.1'); assert.equal(new URL(redisUrl).hostname, '127.0.0.1');
const hash = (v: Buffer | string) => createHash('sha256').update(v).digest('hex');
const write = (n: string, v: unknown) => fs.writeFileSync(path.join(out, n), JSON.stringify(v, null, 2) + '\n');
const ref = (n: string) => { const b = fs.readFileSync(path.join(out, n)); return { path: path.relative(root, path.join(out, n)).replaceAll('\\', '/'), bytes: b.length, sha256: hash(b) }; };
const sourcePath=process.env.DAY137_SOURCE_MANIFEST??'output-evidence/security/day137/d137-completion-20261005-r13/source-manifest.json';
assert(!path.isAbsolute(sourcePath)&&!sourcePath.split(/[\\/]/).includes('..'),'UNSAFE_SOURCE_MANIFEST');
const source = JSON.parse(fs.readFileSync(path.join(root,sourcePath), 'utf8'));
const checkSource = () => { for (const f of source.files) { const b = fs.readFileSync(path.join(root, f.path)); assert.equal(b.length, f.bytes); assert.equal(hash(b), f.sha256, f.path); } }; checkSource();
const sourceFingerprint = source.sourceFingerprint, producerHash = hash(fs.readFileSync(__filename));
const psql = path.join(root, 'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const pgArgs = ['-h', '127.0.0.1', '-p', new URL(db).port, '-U', 'pawmate', '-d', new URL(db).pathname.slice(1), '-At', '-v', 'ON_ERROR_STOP=1'];
const sql = (q: string) => JSON.parse(execFileSync(psql, [...pgArgs, '-c', q], { encoding: 'utf8', timeout: 10000 }).trim());
const schema = fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8'), contract = snapshotContract(schema);
const snapshot = () => sql(contract.query), rows = () => sql(chatRowsQuery);
const prisma = new PrismaClient({ datasources: { db: { url: db } } }), redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const roleNames = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'];
const provider = loadEnv(), base = buildTestConfig();
const config = { ...base, nodeEnv: 'production' as const, databaseUrl: db, redisUrl, supabaseUrl: provider.supabaseUrl, supabaseAnonKey: provider.supabaseAnonKey, supabaseServiceRoleKey: provider.supabaseServiceRoleKey, supabaseProjectRef: provider.supabaseProjectRef, supabaseBuckets: provider.supabaseBuckets, auth: { ...base.auth, accessTokenSecret: 'day137-chatlocal-access-local-only', refreshTokenSecret: 'day137-chatlocal-refresh-local-only' } };
const fullRevalidation=process.env.DAY137_FULL_CHAT_REVALIDATION==='1';
const f: any = fullRevalidation
  ? { users: Object.fromEntries(roleNames.map(r => [r, randomUUID()])), emails: Object.fromEntries(roleNames.map(r => [r, `${runId}-${r.toLowerCase()}@pawmate.test`])), hero: randomUUID(), listing: randomUUID(), request: randomUUID(), thread: randomUUID(), messages: [randomUUID(),randomUUID(),randomUUID()], pending: { owner_adopter: randomUUID(), shelter_A: randomUUID() }, attached: randomUUID(), missingId: randomUUID() }
  : JSON.parse(fs.readFileSync(path.join(root,'output-evidence/security/day137/d137-local-chatlocal-20261005-r16/expected-fixture.json'),'utf8')).values;
const plan = fullRevalidation ? buildChatLocalPlan(f) : buildChatLocalPlan(f).slice(67);
write('expected-fixture.json', { runId, sourceFingerprint, values: f }); write('plan.json', { runId, sourceFingerprint, producerHash, cases: plan });
write('preflight-references.json', { plan: ref('plan.json'), fixture: ref('expected-fixture.json'), sourceFingerprint, producerHash });
let cloudCalls = 0; const oldFetch = globalThis.fetch;
globalThis.fetch = (async () => { cloudCalls++; throw new Error('LOCAL_CHAT_PROVIDER_NETWORK_FORBIDDEN'); }) as typeof fetch;
let app: any, requestCount = 0, failure: unknown, cleaned = false;
const cases: any[] = [], sessions: Record<string, any> = {}, initialSessions: Array<{ key: string; value: string }> = [];
const save = () => write('cross-role-results.json', { schemaVersion: 1, resumedAfterAcceptedPrefix: fullRevalidation ? 0 : 67, runId, sourceFingerprint, producerHash, cases, requestCount, cloudCalls, verdict: failure ? 'FAIL' : cases.length === plan.length && cases.every(c => c.verdict === 'PASS') ? 'PASS_CHATLOCAL_SLICE' : 'PARTIAL', limitations: ['15 canonical only; media attachment metadata is not provider byte proof', 'production handlers, real SQL/Redis; Fastify in-process HTTP not deployed TCP'] });
const call = async (method: string, url: string, role: string, payload?: any, idem?: string) => { claimRequest(envelope); requestCount++; return app.inject({ method, url, payload, headers: { ...(role === 'anonymous' ? {} : { authorization: `Bearer ${sessions[role].accessToken}` }), ...(idem ? { 'idempotency-key': idem } : {}) } }); };
async function reset(p: any) {
  await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.filter(t => t !== 'users').map(t => `"${t}"`).join(',')} CASCADE`);
  await prisma.user.updateMany({ data: { emailVerified: true } });
  const keys = await redis.keys('*'); if (keys.length) await redis.del(...keys);
  for (const s of initialSessions) await restoreSessionFixture(redis, s);
  const stamp=new Date('2026-09-01T00:00:00Z');
  await prisma.mediaAsset.create({data:{id:f.hero,ownerUserId:f.users.shelter_A,purpose:'adoption_listing',mimeType:'image/jpeg',sizeBytes:123,sha256:'c'.repeat(64),status:'attached',storageKey:runId+'/hero.jpg',publicUrl:'https://fixtures.invalid/hero.jpg',width:800,height:600,createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionListing.create({data:{id:f.listing,shelterId:f.users.shelter_A,heroMediaId:f.hero,petName:'Synthetic Mochi',species:'dog',ageLabel:'2 years',status:'available',traits:[],healthBadges:[],verificationBadges:[],createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionRequest.create({data:{id:f.request,listingId:f.listing,adopterUserId:f.users.owner_adopter,shelterId:f.users.shelter_A,livingCondition:'Synthetic home',petExperience:'Synthetic experience',carePlan:'Synthetic care',commitmentAccepted:true,status:'submitted',createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionChatThread.create({data:{id:f.thread,requestId:f.request,adopterUserId:f.users.owner_adopter,shelterId:f.users.shelter_A,closedAt:p.state==='closed'?stamp:null,createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionChatParticipant.createMany({data:['owner_adopter','shelter_A'].map(role=>({threadId:f.thread,userId:f.users[role],role:role==='owner_adopter'?'adopter':'shelter',lastReadAt:stamp,lastReadSequence:0n,createdAt:stamp,updatedAt:stamp}))});
  for(const role of ['owner_adopter','shelter_A'])await prisma.mediaAsset.create({data:{id:f.pending[role],ownerUserId:f.users[role],purpose:'adoption_chat',mimeType:'image/jpeg',sizeBytes:123,sha256:'a'.repeat(64),status:'verified',storageKey:`adoption_chat/${f.thread}/${f.pending[role]}/${'a'.repeat(64)}/private.jpg`,width:800,height:600,createdAt:stamp,updatedAt:stamp}});
  if(p.state!=='empty'){
    for(let i=0;i<3;i++){const time=new Date('2026-09-03T00:00:0'+i+'Z');await prisma.adoptionChatMessage.create({data:{id:f.messages[i],threadId:f.thread,senderUserId:f.users[i===1?'shelter_A':'owner_adopter'],body:'Seed '+(i+1),createdAt:time,updatedAt:time}});}
    await prisma.mediaAsset.create({data:{id:f.attached,ownerUserId:f.users.shelter_A,purpose:'adoption_chat',mimeType:'image/jpeg',sizeBytes:123,sha256:'b'.repeat(64),status:'attached',storageKey:`adoption_chat/${f.thread}/${f.attached}/${'b'.repeat(64)}/private.jpg`,adoptionChatMessageId:f.messages[1],position:0,width:800,height:600,createdAt:stamp,updatedAt:stamp}});
    if(p.state==='stale'&&p.role!=='anonymous'&&['owner_adopter','shelter_A'].includes(p.role)){const message=await prisma.adoptionChatMessage.findUniqueOrThrow({where:{id:f.messages[1]}});await prisma.adoptionChatParticipant.update({where:{threadId_userId:{threadId:f.thread,userId:f.users[p.role]}},data:{lastReadAt:message.createdAt,lastReadSequence:message.sequence,updatedAt:stamp}});}
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
    const auth = p.role === 'anonymous' ? null : (() => {
      const fixture = initialSessions.find(x => JSON.parse(x.value).userId === f.users[p.role])!;
      const cli = path.join(root, 'output-evidence/day67/portable-redis/redis-3.0.504/redis-cli.exe');
      const args = ['-h', '127.0.0.1', '-p', new URL(redisUrl).port, '--raw'];
      const session = JSON.parse(execFileSync(cli, [...args, 'get', fixture.key], { encoding: 'utf8' }).trim());
      const index = execFileSync(cli, [...args, 'zrange', 'auth:user-sessions:' + session.userId, '0', '-1'], { encoding: 'utf8' }).trim().split(/\r?\n/);
      assert(index.includes(session.id)); assert.equal(Boolean(session.revokedAt), p.state === 'revoked');
      return { boundary: 'independent redis-cli session and user-index readback', key: fixture.key, session, index };
    })();
    const before = snapshot(), rowsBefore = rows(), startedDb = sql('SELECT to_json(clock_timestamp());');
    const identity = { runId, id: p.id, sourceFingerprint, producerHash, method: p.method, url: p.url, role: p.role, state: p.state };
    const c: any = { ...identity, startedAt: new Date().toISOString(), precondition: { fixtureRef: ref('expected-fixture.json'), reset: 'owned session+user index restored; thread participants/messages/private media metadata independently captured', auth }, command: ['Fastify.inject', p.method, p.url], reviewer: 'independent psql exact field/effect oracle', verdict: 'NOT_RUN' }; cases.push(c); save();
    try {
      const invoke = async (i: number) => {
        const changed = p.state === 'conflict' && i === 1 ? { ...p.payload, body: 'Different fixture' } : p.payload;
        const response = await call(p.method, p.url, p.role, changed, p.method === 'POST' ? p.idempotencyKey : undefined);
        return { status: response.statusCode, body: response.json(), cacheControl: response.headers['cache-control'] };
      };
      const responses = p.concurrent ? await Promise.all([invoke(0), invoke(1)]) : [await invoke(0)];
      if (p.repeat && !p.concurrent) responses.push(await invoke(1));
      const endedDb = sql('SELECT to_json(clock_timestamp());'), after = snapshot(), rowsAfter = rows();
      write(`${p.id}-response.json`, { ...identity, responses });
      write(`${p.id}-sql.json`, { ...identity, query: contract.query, command: [psql, ...pgArgs, '-c', contract.query], rowQuery: chatRowsQuery, rowCommand: [psql, ...pgArgs, '-c', chatRowsQuery], before, after, rowsBefore, rowsAfter, startedDb, endedDb });
      c.responseRef = ref(`${p.id}-response.json`); c.sqlRef = ref(`${p.id}-sql.json`); c.actual = { statuses: responses.map(x => x.status) };
      const load = (r: any) => JSON.parse(fs.readFileSync(path.join(root, r.path), 'utf8'));
      const proof = validateChatLocalCase({ planned: p, actual: c, raw: load(c.responseRef), sql: load(c.sqlRef), fixture: f, runId, sourceFingerprint, producerHash, schema }); c.assertions = proof.assertions; assert.equal(proof.verdict, 'PASS', JSON.stringify(proof.errors)); c.verdict = 'PASS';
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

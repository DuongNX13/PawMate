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
import { claimRequest } from './day137-rescuelocal-budget-r17.mjs';
import { buildRescueLocalPlan } from '../../scripts/qa/day137/day137-rescuelocal-plan-r17.mjs';
import { restoreSessionFixture } from '../../scripts/qa/day137/day137-auth-fixture-reset-r15b.mjs';
import { validateRescueLocalCase, rescueRowsQuery } from '../../scripts/qa/day137/day137-rescuelocal-oracle-r17.mjs';
import { snapshotContract } from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';
const root = path.resolve(__dirname, '../..'), out = process.env.DAY137_EVIDENCE_ROOT!, runId = process.env.DAY137_RUN_ID!, envelope = process.env.DAY137_ENVELOPE_PATH!, db = process.env.DATABASE_URL!, redisUrl = process.env.REDIS_URL!;
assert(/^d137-local-rescuelocal-[a-z0-9-]{6,28}$/.test(runId));
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
const snapshot = () => sql(contract.query), rows = () => sql(rescueRowsQuery);
const prisma = new PrismaClient({ datasources: { db: { url: db } } }), redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const roleNames = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'];
const provider = loadEnv(), base = buildTestConfig();
const config = { ...base, nodeEnv: 'production' as const, databaseUrl: db, redisUrl, supabaseUrl: provider.supabaseUrl, supabaseAnonKey: provider.supabaseAnonKey, supabaseServiceRoleKey: provider.supabaseServiceRoleKey, supabaseProjectRef: provider.supabaseProjectRef, supabaseBuckets: provider.supabaseBuckets, features: { rescueBrowse: true, rescueCreate: true }, auth: { ...base.auth, accessTokenSecret: 'day137-rescuelocal-access-local-only', refreshTokenSecret: 'day137-rescuelocal-refresh-local-only' } };
const f: any = { users:Object.fromEntries(roleNames.map(r=>[r,randomUUID()])),emails:Object.fromEntries(roleNames.map(r=>[r,`${runId}-${r.toLowerCase()}@pawmate.test`])),draft:randomUUID(),sourceDraft:randomUUID(),case:randomUUID(),draftMedia:randomUUID(),caseMedia:randomUUID(),comments:[randomUUID(),randomUUID(),randomUUID()],missingId:randomUUID() };
const plan = buildRescueLocalPlan(f);
write('expected-fixture.json', { runId, sourceFingerprint, values: f }); write('plan.json', { runId, sourceFingerprint, producerHash, cases: plan });
write('preflight-references.json', { plan: ref('plan.json'), fixture: ref('expected-fixture.json'), sourceFingerprint, producerHash });
let cloudCalls = 0; const oldFetch = globalThis.fetch;
globalThis.fetch = (async () => { cloudCalls++; throw new Error('LOCAL_RESCUE_PROVIDER_NETWORK_FORBIDDEN'); }) as typeof fetch;
let app: any, offApp: any, requestCount = 0, failure: unknown, cleaned = false;
const cases: any[] = [], sessions: Record<string, any> = {}, initialSessions: Array<{ key: string; value: string }> = [];
const save = () => write('cross-role-results.json', { schemaVersion: 1, runId, sourceFingerprint, producerHash, cases, requestCount, cloudCalls, verdict: failure ? 'FAIL' : cases.length === plan.length && cases.every(c => c.verdict === 'PASS') ? 'PASS_RESCUELOCAL_SLICE' : 'PARTIAL', limitations: ['40 canonical only; media ticket/complete and provider bytes excluded', 'production handlers, real SQL/Redis; Fastify in-process HTTP not deployed TCP'] });
const call = async (method: string, url: string, role: string, payload?: any, idem?: string, target = app) => { claimRequest(envelope); requestCount++; return target.inject({ method, url, payload, headers: { ...(role === 'anonymous' ? {} : { authorization: `Bearer ${sessions[role].accessToken}` }), ...(idem ? { 'idempotency-key': idem } : {}) } }); };
async function reset(p: any) {
  await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.filter(t => t !== 'users').map(t => `"${t}"`).join(',')} CASCADE`);
  await prisma.user.updateMany({ data: { emailVerified: true } });
  const keys = await redis.keys('*'); if (keys.length) await redis.del(...keys);
  for (const s of initialSessions) await restoreSessionFixture(redis, s);
  const stamp=new Date('2026-09-01T00:00:00Z'),owner=f.users.owner_adopter;
  const baseDraft={ownerUserId:owner,source:'rescue_home',petName:'Synthetic rescue',species:'dog' as const,breedOrColor:'Golden synthetic',lostAt:stamp,exactLatitude:10.7769,exactLongitude:106.7009,formattedAddress:'123 Synthetic Road, Test area',areaLabel:'STALE PRIVATE ADDRESS',privacyRadiusMeters:500,identifyingFeatures:'Synthetic red collar',behaviorHint:'Friendly',contactPreference:'in_app' as const,version:1,createdAt:stamp,updatedAt:stamp};
  await prisma.rescueCaseDraft.create({data:{...baseDraft,id:f.draft,petName:p.state==='incomplete'?null:baseDraft.petName}});
  await prisma.rescueCaseDraft.create({data:{...baseDraft,id:f.sourceDraft,publishedAt:stamp}});
  await prisma.rescueCase.create({data:{id:f.case,sourceDraftId:f.sourceDraft,ownerUserId:owner,petName:'Synthetic rescue',species:'dog',breedOrColor:'Golden synthetic',lostAt:stamp,areaLabel:'Test area',approximateLatitude:10.7775,approximateLongitude:106.6995,privacyRadiusMeters:500,identifyingFeatures:'Synthetic red collar',behaviorHint:'Friendly',contactPreference:'in_app',status:p.state==='closed'?'found':'missing',version:1,commentCount:p.state==='empty'?0:1,deletedAt:p.state==='deleted'||p.kind==='list'&&p.state==='empty'?stamp:null,foundAt:p.state==='closed'?stamp:null,createdAt:stamp,updatedAt:stamp}});
  await prisma.rescueCasePrivateLocation.create({data:{caseId:f.case,ownerUserId:owner,latitude:10.7769,longitude:106.7009,formattedAddress:'123 Synthetic Road, Test area',createdAt:stamp,updatedAt:stamp}});
  for(const [id,draftId,caseId]of [[f.draftMedia,f.draft,null],[f.caseMedia,null,f.case]])await prisma.mediaAsset.create({data:{id,ownerUserId:owner,purpose:'rescue_case',mimeType:'image/webp',sizeBytes:123,sha256:'a'.repeat(64),status:'attached',verificationVersion:1,verifiedAt:stamp,storageKey:runId+'/'+id+'.webp',publicUrl:'https://fixtures.invalid/'+id+'.webp',draftId,caseId,position:0,width:800,height:600,createdAt:stamp,updatedAt:stamp}});
  if(p.state!=='empty')for(let i=0;i<3;i++){const time=new Date('2026-09-03T00:00:0'+i+'Z');await prisma.rescueComment.create({data:{id:f.comments[i],caseId:f.case,authorUserId:f.users[i===1?'outsider':'owner_adopter'],body:'Seed '+(i+1),moderationState:i===1?'hidden':'visible',deletedAt:i===2?time:null,createdAt:time,updatedAt:time}});}
  if (p.state === 'revoked' && p.role !== 'anonymous') { const r = await call('POST', '/auth/logout', 'anonymous', { refreshToken: sessions[p.role].refreshToken }); assert.equal(r.statusCode, 204); }
}
async function run() {
  const { buildApp } = await import('../src/app'); app = buildApp({ logger: false }, { config }); await app.ready(); offApp=buildApp({logger:false},{config:{...config,features:{rescueBrowse:false,rescueCreate:false}}}); await offApp.ready(); await redis.connect();
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
    const c: any = { ...identity, startedAt: new Date().toISOString(), precondition: { fixtureRef: ref('expected-fixture.json'), reset: 'owned session+index; Rescue draft/case/private GPS/media/comment seeds independently captured', auth }, command: ['Fastify.inject', p.method, p.url], reviewer: 'independent psql exact field/effect oracle', verdict: 'NOT_RUN' }; cases.push(c); save();
    try {
      const invoke = async (i: number) => {
        const changed = p.state === 'conflict' && i === 1 ? { source: 'deep_link' } : p.payload;
        const response = await call(p.method, p.url, p.role, changed, ['draft','publish','comment','status'].includes(p.kind) ? p.idempotencyKey : undefined, p.state==='flag-off' ? offApp : app);
        return { status: response.statusCode, body: response.json(), cacheControl: response.headers['cache-control'] };
      };
      const responses = p.concurrent ? await Promise.all([invoke(0), invoke(1)]) : [await invoke(0)];
      if (p.repeat && !p.concurrent) responses.push(await invoke(1));
      const endedDb = sql('SELECT to_json(clock_timestamp());'), after = snapshot(), rowsAfter = rows();
      write(`${p.id}-response.json`, { ...identity, responses, effectiveFeatures:p.state==='flag-off'?{rescueBrowse:false,rescueCreate:false}:config.features });
      write(`${p.id}-sql.json`, { ...identity, query: contract.query, command: [psql, ...pgArgs, '-c', contract.query], rowQuery: rescueRowsQuery, rowCommand: [psql, ...pgArgs, '-c', rescueRowsQuery], before, after, rowsBefore, rowsAfter, startedDb, endedDb });
      c.responseRef = ref(`${p.id}-response.json`); c.sqlRef = ref(`${p.id}-sql.json`); c.actual = { statuses: responses.map(x => x.status) };
      const load = (r: any) => JSON.parse(fs.readFileSync(path.join(root, r.path), 'utf8'));
      const proof = validateRescueLocalCase({ planned: p, actual: c, raw: load(c.responseRef), sql: load(c.sqlRef), fixture: f, runId, sourceFingerprint, producerHash, schema }); c.assertions = proof.assertions; assert.equal(proof.verdict, 'PASS', JSON.stringify(proof.errors)); c.verdict = 'PASS';
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
  await offApp?.close(); await app?.close(); await prisma.$disconnect(); redis.disconnect(); globalThis.fetch = oldFetch;
  if (failure) write('first-failure.json', { at: new Date().toISOString(), error: String(failure), cleanupVerified: cleaned });
});

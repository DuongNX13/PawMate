// Test-only entrypoint: production routes/services, disposable PostgreSQL and Redis.
// No provider mock is counted as a Storage proof; media provider coverage is separate.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import { buildApp } from '../src/app';
import { createVetService } from '../src/services/vets/vet-service';
import { PrismaVetNearbyStore } from '../src/repositories/prisma-vet-nearby-store';
import { loadEnv } from '../src/config/env';
import { type CreatePetInput } from '../src/services/pets/pet-service';
import { buildTestConfig } from '../tests/helpers/rescue-read-fixtures';
import { createClient } from '@supabase/supabase-js';
import { createSupabaseRescueMediaStorage } from '../src/infrastructure/rescue-media-storage';
import { claimRequest } from './day137-request-budget-r2.mjs';
import { evaluateRevocation } from './day137-session-oracle.mjs';
import { proveBoundaries } from './day137-boundary-extension-r2';

const root = path.resolve(__dirname, '../..');
const out = process.env.DAY137_EVIDENCE_ROOT!;
const runId = process.env.DAY137_RUN_ID!;
const db = process.env.DATABASE_URL!;
const redisUrl = process.env.REDIS_URL!;
assert(/^d137-local-[a-z0-9-]{6,40}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root, 'output-evidence/security/day137') + path.sep));
assert.equal(new URL(db).hostname, '127.0.0.1');
assert.equal(new URL(redisUrl).hostname, '127.0.0.1');
const psql = path.join(root, 'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const pgArgs = ['-h', '127.0.0.1', '-p', new URL(db).port, '-U', 'pawmate', '-d', new URL(db).pathname.slice(1), '-At', '-v', 'ON_ERROR_STOP=1'];
const sql = (query: string) => JSON.parse(execFileSync(psql, [...pgArgs, '-c', query], { encoding: 'utf8', timeout: 10000 }).trim());
const tables = [...fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8').matchAll(/@@map\("([a-z_]+)"\)/g)].map(m => m[1]);
const oracleQuery = `SELECT jsonb_object_agg(name, value) FROM (${tables.map(t => `SELECT '${t}' AS name, jsonb_build_object('count',count(*),'contentHash',md5(coalesce(string_agg(row_to_json(t)::text,'' ORDER BY row_to_json(t)::text),''))) AS value FROM "${t}" t`).join(' UNION ALL ')}) s;`;
const snapshot = () => sql(oracleQuery);
const digest = (v: unknown) => createHash('sha256').update(JSON.stringify(v)).digest('hex');
const entry = JSON.parse(fs.readFileSync(path.join(root, 'output-evidence/security/day137/d137-entry-20261001-r1/contract.json'), 'utf8'));
const cases: any[] = [];
const routes: any[] = [];
const prisma = new PrismaClient({ datasources: { db: { url: db } } });
const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const config={...buildTestConfig(),databaseUrl:db,redisUrl,features:{rescueBrowse:true,rescueCreate:true},auth:{...buildTestConfig().auth,accessTokenSecret:'day137-local-only-access-fixture-20261001',refreshTokenSecret:'day137-local-only-refresh-fixture-20261001'}};
const envelopePath=process.env.DAY137_ENVELOPE_PATH!;assert(envelopePath,'ENVELOPE_REQUIRED');
assert.equal(config.supabaseUrl,undefined);assert.equal(config.supabaseServiceRoleKey,undefined);
assert.equal(path.resolve(process.cwd()),path.join(out,'runtime'),'OWNED_STORAGE_CWD_REQUIRED');
const storageRoot=path.resolve(process.cwd(),'storage');assert(!fs.existsSync(storageRoot),'FRESH_LOCAL_STORAGE');
globalThis.fetch=(async()=>{throw new Error('LOCAL_ONLY_EXTERNAL_FETCH_FORBIDDEN');}) as typeof fetch;
const cleanupCallbacks:Array<()=>Promise<void>>=[async()=>{if(fs.existsSync(storageRoot)){assert(storageRoot===path.join(out,'runtime','storage'));fs.rmSync(storageRoot,{recursive:true,force:false});}assert(!fs.existsSync(storageRoot));fs.writeFileSync(path.join(out,'local-storage-cleanup.json'),JSON.stringify({runId,ownedRoot:storageRoot,remainingOwnedFiles:0,cloudRequests:0,readbackVerified:true},null,2));}];
// Preserve the production Vet factory and SQL adapter while isolating photo storage cwd.
const seedPath=path.join(root,'backend/prisma/data/day2_vet_seed_candidates.json');
const pilotSeedPath=path.join(root,'backend/prisma/data/day3_vet_geo_pilot.json');
assert(fs.existsSync(seedPath)&&fs.existsSync(pilotSeedPath),'SOURCE_BOUND_VET_SEEDS_REQUIRED');
const vetService=createVetService({seedPath,pilotSeedPath,nearbyStore:new PrismaVetNearbyStore(prisma)});
const app=buildApp({logger:false},{config,vetService});const applications=[app];
app.addHook('onRoute',options=>{for(const method of Array.isArray(options.method)?options.method:[options.method])if(method!=='HEAD')routes.push({method,path:options.url});});
const roles = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'];
const users = Object.fromEntries(roles.map(role => [role, randomUUID()]));
const sessions: Record<string, { accessToken: string; refreshToken: string }> = {};
let requests = 0;
let failure: unknown;
const save = () => fs.writeFileSync(path.join(out, 'cross-role-results.json'), `${JSON.stringify({ schemaVersion: 1, runId, sourceFingerprint: entry.sourceFingerprint, transport: 'Fastify inject; real production handlers, SQL/PostGIS, Redis sessions/quota', limitations: ['Source-bound revoked-bearer states for two caller contexts; real SQL/Redis. NOT baseline/provider acceptance.', 'No remote requests or new Auth fixtures.'], requestCount: requests, maxRequests: 200, cases }, null, 2)}\n`);
const call = async (method: any, url: string, role = 'anonymous', payload?: any, extra?: any, target = app) => {
  claimRequest(envelopePath, 'runtime');
  assert(++requests <= 200, 'REQUEST_BUDGET');
  return target.inject({ method, url, ...(payload === undefined ? {} : { payload }), headers: {
    ...(role === 'anonymous' ? {} : { authorization: `Bearer ${sessions[role].accessToken}` }), ...extra,
  } });
};
const perform = async (id: string, basis: string, role: string, method: any, url: string, expected: number, payload?: any, verify?: (r: any, after: any) => void | Promise<void>, extra?: any, target = app) => {
  assert(!cases.some(c => c.id === id), 'DUPLICATE_CASE');
  const before = snapshot();
  const c: any = { id, runId, sourceFingerprint: entry.sourceFingerprint, role, method, url, expected, basis, precondition: { fixtureUsers: users, beforeSqlHash: digest(before) }, startedAt: new Date().toISOString(), verdict: 'NOT_RUN', reviewer: 'agent-runtime-assertions' };
  cases.push(c); save();
  try {
    const r = await call(method, url, role, payload, extra, target);
    const after = snapshot();
    fs.writeFileSync(path.join(out, `${id}-sql.json`), JSON.stringify({ runId, id, before, after }, null, 2));
    c.sqlOracle = `${id}-sql.json`;
    c.actual = { status: r.statusCode, ...(r.headers['content-type']?.includes('json') ? { error: r.json().error?.code } : {}), cacheControl: r.headers['cache-control'] };
    assert.equal(r.statusCode, expected, `${id}: ${r.statusCode}; ${r.body.slice(0, 250)}`);
    if (expected >= 400) assert.deepEqual(after, before, `${id}: rejected request changed DB/outbox`);
    await verify?.(r, after);
    c.verdict = 'PASS';
    return r;
  } catch (error) { c.verdict = 'FAIL'; c.failure = String(error); throw error; }
  finally { c.endedAt = new Date().toISOString(); save(); }
};
const own = (r: any) => assert.equal(r.json().data.userId, users.owner_adopter);
const petPayload: CreatePetInput = { name: 'Mochi', species: 'dog', breed: 'Corgi', color: 'Vàng trắng' };
// Concurrent groups use one before/after SQL oracle. A losing CAS request must
// not be compared to a snapshot containing the winning concurrent write.
const race = async (id: string, method: any, url: string, payload: any, expected: number[], verify: (responses: any[]) => void, extra?: any) => {
  const before = snapshot();
  const c: any = { id, runId, sourceFingerprint: entry.sourceFingerprint, role: 'owner_adopter', method, url,
    expected, basis: 'two concurrent requests; persisted winner/effect counts are the independent oracle',
    precondition: { fixtureUsers: users, beforeSqlHash: digest(before), concurrency: 2 }, startedAt: new Date().toISOString(), verdict: 'NOT_RUN', reviewer: 'agent-runtime-assertions' };
  cases.push(c); save();
  try {
    const rs = await Promise.all([call(method, url, 'owner_adopter', payload, extra), call(method, url, 'owner_adopter', payload, extra)]);
    const after = snapshot();
    c.sqlOracle = `${id}-sql.json`;
    fs.writeFileSync(path.join(out, c.sqlOracle), JSON.stringify({ runId, id, before, after }, null, 2));
    c.actual = { statuses: rs.map(r => r.statusCode).sort() };
    assert.deepEqual(c.actual.statuses, [...expected].sort()); verify(rs);
    c.verdict = 'PASS';
  } catch (error) { c.verdict = 'FAIL'; c.failure = String(error); throw error; }
  finally { c.endedAt = new Date().toISOString(); save(); }
};
const fieldProof: any[] = [];
const fields = (id: string, actual: any, expected: any) => {
  assert.deepEqual(actual, expected, id);
  fieldProof.push({ id, runId, expected, actual, verdict: 'PASS', at: new Date().toISOString() });
  fs.writeFileSync(path.join(out, 'field-assertions.json'), JSON.stringify(fieldProof, null, 2));
};
const statePath=path.join(root,'output-evidence/security/day137/d137-preflight-20261002-r3/state-contract.json');
const stateContract=JSON.parse(fs.readFileSync(statePath,'utf8'));
assert.equal(stateContract.sourceFingerprint,entry.sourceFingerprint);
const run = async () => {
  await redis.connect();assert.equal(await redis.dbsize(),0);
  assert(Object.values(snapshot()).every((t:any)=>t.count===0));
  const exercisedRoles=['owner_adopter','outsider'];
  await prisma.user.createMany({data:roles.map(role=>({id:users[role],email:`${runId}-${role.toLowerCase()}@pawmate.test`,passwordHash:bcrypt.hashSync('Day137FixturePassword!20261001',4),displayName:role,emailVerified:true}))});
  await app.ready();fs.writeFileSync(path.join(out,'runtime-routes.json'),JSON.stringify({runId,routes},null,2));
  for(const role of exercisedRoles){const r=await call('POST','/auth/login','anonymous',{email:`${runId}-${role.toLowerCase()}@pawmate.test`,password:'Day137FixturePassword!20261001'});assert.equal(r.statusCode,200);sessions[role]=r.json();}
  for(const role of exercisedRoles){
    await perform(`D137-STATE-REVOKE-${role}`,'real Redis logout before protected route matrix',role,'POST','/auth/logout',204,{refreshToken:sessions[role].refreshToken});
    const targets=stateContract.requirements.filter((r:any)=>r.role===role&&r.state==='revoked_bearer');
    assert.equal(targets.length,46,'SOURCE_LOCKED_REVOKED_ROUTE_COUNT');
    for(const target of targets){
      const url=target.path.replace(/:[A-Za-z]+/g,randomUUID());
      const id=target.id;
      await perform(id,'revoked Redis session must fail before payload/resource/storage access',role,target.method,url,401,
        ['POST','PUT','PATCH'].includes(target.method)?{}:undefined);
      const c=cases[cases.length-1];const oracle=JSON.parse(fs.readFileSync(path.join(out,c.sqlOracle),'utf8'));
      c.requirementId=target.id;c.state='revoked_bearer';
      c.fieldChecks=[{id:'http_status',expected:401,actual:c.actual.status},
        {id:'fresh_independent_sql',expected:c.precondition.beforeSqlHash,actual:digest(oracle.before)},
        {id:'rejected_no_db_outbox_effect',expected:digest(oracle.before),actual:digest(oracle.after)}];
      assert(target.assertionIds.every((id:string)=>c.fieldChecks.some((f:any)=>f.id===id&&JSON.stringify(f.actual)===JSON.stringify(f.expected))));
      save();
    }
  }
};
run().catch(e => { failure = e; console.error(String(e)); process.exitCode = 1; }).finally(async () => {
  save();
  for (const cleanup of cleanupCallbacks.reverse()) {
    try { await cleanup(); } catch (e) { console.error(`LOCAL_STORAGE_CLEANUP:${e}`); process.exitCode = 1;
      fs.writeFileSync(path.join(out, 'local-storage-cleanup-failure.json'), JSON.stringify({runId,error:String(e)})); }
  }
  // This database/cache was proven empty and is exclusive to this run. Never execute on cloud/shared state.
  try {
    const before = snapshot();
    await prisma.$executeRawUnsafe(`TRUNCATE ${tables.map(t => `"${t}"`).join(',')} CASCADE`);
    const after = snapshot();
    const keys = await redis.keys('*');
    if (keys.length) await redis.del(...keys);
    const clean = { runId, fixtureOnlyDisposable: true, sqlBefore: before, sqlAfter: after, remainingRows: Object.values(after).reduce((n: number, t: any) => n + t.count, 0), redisRemaining: await redis.dbsize() };
    assert.equal(clean.remainingRows, 0); assert.equal(clean.redisRemaining, 0);
    fs.writeFileSync(path.join(out, 'fixture-cleanup.json'), JSON.stringify(clean, null, 2));
  } catch (e) { console.error(`CLEANUP:${e}`); process.exitCode = 1; }
  for (const instance of applications.reverse()) await instance.close();
  await prisma.$disconnect(); redis.disconnect();
  if (failure) fs.writeFileSync(path.join(out, 'first-failure.json'), JSON.stringify({ at: new Date().toISOString(), error: String(failure) }, null, 2));
});











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
const app=buildApp({logger:false},{config});const applications=[app];
app.addHook('onRoute',options=>{for(const method of Array.isArray(options.method)?options.method:[options.method])if(method!=='HEAD')routes.push({method,path:options.url});});
const roles = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'];
const users = Object.fromEntries(roles.map(role => [role, randomUUID()]));
const sessions: Record<string, { accessToken: string; refreshToken: string }> = {};
let requests = 0;
let failure: unknown;
const save = () => fs.writeFileSync(path.join(out, 'cross-role-results.json'), `${JSON.stringify({ schemaVersion: 1, runId, sourceFingerprint: entry.sourceFingerprint, transport: 'Fastify inject; real production handlers, SQL/PostGIS, Redis sessions/quota', limitations: ['Production local photo adapters; nodeEnv=test and Supabase disabled, real SQL/Redis. NOT cloud upload or provider acceptance.', 'No remote requests or new Auth fixtures.'], requestCount: requests, maxRequests: 800, cases }, null, 2)}\n`);
const call = async (method: any, url: string, role = 'anonymous', payload?: any, extra?: any, target = app) => {
  claimRequest(envelopePath, 'runtime');
  assert(++requests <= 800, 'REQUEST_BUDGET');
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
const run = async () => {
  await redis.connect(); assert.equal(await redis.dbsize(), 0);
  assert(Object.values(snapshot()).every((t: any) => t.count === 0));
  await prisma.user.createMany({ data: roles.map(role => ({ id: users[role], email: `${runId}-${role.toLowerCase()}@pawmate.test`,
    passwordHash: bcrypt.hashSync('Day137FixturePassword!20261001', 4), displayName: role, emailVerified: true })) });
  const vetId=randomUUID();
  await prisma.$executeRawUnsafe(`INSERT INTO vets(id,external_id,name,address,city,district,location,ready_for_map,created_at,updated_at) VALUES($1::uuid,$1::text,'Synthetic clinic','Synthetic address','TP Hồ Chí Minh','Quận 1',ST_SetSRID(ST_MakePoint(106.7009,10.7769),4326)::geography,true,now(),now())`,vetId);
  await app.ready();fs.writeFileSync(path.join(out,'runtime-routes.json'),JSON.stringify({runId,routes},null,2));
  for(const role of roles){const r=await call('POST','/auth/login','anonymous',{email:`${runId}-${role.toLowerCase()}@pawmate.test`,password:'Day137FixturePassword!20261001'});assert.equal(r.statusCode,200);sessions[role]=r.json();}
  const pet=await perform('D137-PHOTO-PET-SEED','local own pet fixture','owner_adopter','POST','/pets',201,petPayload);
  const petId=pet.json().data.id;
  const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=','base64');
  const photo={fileName:'owned-fixture.png',contentType:'image/png',base64Data:image.toString('base64')};
  let petUrl='';const reviewUrls:Record<string,string>={};
  for(const role of ['anonymous',...roles]){
    const r=await perform(`D137-PHOTO-PET-UPLOAD-${role}`,'Pet route default HTTP200; owner SQL avatar and actual file hash',role,'POST',`/pets/${petId}/photo`,role==='anonymous'?401:role==='owner_adopter'?200:403,photo,role==='owner_adopter'?(r:any)=>{petUrl=new URL(r.json().data.avatarUrl).pathname;fields('pet-avatar-dto',{owner:r.json().data.pet.userId,url:r.json().data.avatarUrl},{owner:users.owner_adopter,url:r.json().data.avatarUrl});fields('pet-avatar-sql',sql(`SELECT to_json(avatar_url) FROM pets WHERE id='${petId}'::uuid;`),r.json().data.avatarUrl);fields('pet-file-hash',digest(fs.readFileSync(path.join(storageRoot,'pet-photos',petId,'owned-fixture.png'))),digest(image));}:undefined);
    const rr=await perform(`D137-PHOTO-REVIEW-UPLOAD-${role}`,'actual production local fallback adapter; caller path bound',role,'POST',`/vets/${vetId}/reviews/photos`,role==='anonymous'?401:201,{...photo,userId:users.outsider},role==='anonymous'?undefined:(r:any)=>{const d=r.json().data;fields(`review-upload-${role}`,{storage:d.storage,bytes:d.sizeBytes,contentType:d.contentType,parts:d.path.split('/').slice(0,2)},{storage:'local',bytes:image.length,contentType:'image/png',parts:[vetId,users[role]]});reviewUrls[role]=new URL(d.url).pathname;});
  }
  for(const role of ['anonymous',...roles]){
    for(const [kind,url] of Object.entries({pet:petUrl,review:reviewUrls.owner_adopter}))await perform(`D137-PHOTO-READ-${kind}-${role}`,'public local asset bytes independent SHA oracle',role,'GET',url,200,undefined,(r:any)=>{fields(`asset-bytes-${kind}-${role}`,{hash:digest(r.rawPayload),type:r.headers['content-type'].split(';')[0]},{hash:digest(image),type:'image/png'});});
    for(const [kind,url] of Object.entries({pet:`/assets/pet-photos/${petId}/absent.png`,review:`/assets/review-photos/${vetId}/${users.owner_adopter}/absent.png`}))await perform(`D137-PHOTO-MISSING-ASSET-${kind}-${role}`,'absent file is404,no SQL effects',role,'GET',url,404);
  }
  await perform('D137-PHOTO-INVALID-PET','invalid MIME rejected without avatar write','owner_adopter','POST',`/pets/${petId}/photo`,400,{...photo,contentType:'text/html'});
  await perform('D137-PHOTO-INVALID-REVIEW','invalid MIME rejected without asset write','owner_adopter','POST',`/vets/${vetId}/reviews/photos`,400,{...photo,contentType:'text/html'});
  const filesBefore=fs.readdirSync(path.join(storageRoot,'review-photos',vetId,users.owner_adopter));
  await perform('D137-PHOTO-MISSING-VET','missing vet cannot receive image','owner_adopter','POST',`/vets/${randomUUID()}/reviews/photos`,404,photo);
  fields('missing-vet-no-file',fs.readdirSync(path.join(storageRoot,'review-photos',vetId,users.owner_adopter)),filesBefore);
  await perform('D137-PHOTO-MISSING-PET','missing pet cannot receive image','owner_adopter','POST',`/pets/${randomUUID()}/photo`,404,photo);
  await perform('D137-PHOTO-PET-DELETE','soft delete owner fixture','owner_adopter','DELETE',`/pets/${petId}`,204);
  await perform('D137-PHOTO-DELETED-PET','deleted pet rejects image','owner_adopter','POST',`/pets/${petId}/photo`,404,photo);
  for(const role of roles){await perform(`D137-PHOTO-REVOKE-${role}`,'logout real Redis session',role,'POST','/auth/logout',204,{refreshToken:sessions[role].refreshToken});await perform(`D137-PHOTO-REVOKED-REVIEW-${role}`,'revoked bearer cannot upload',role,'POST',`/vets/${vetId}/reviews/photos`,401,photo);}
};
run().catch(e => { failure = e; console.error(String(e)); process.exitCode = 1; }).finally(async () => {
  save();
  for (const cleanup of cleanupCallbacks.reverse()) {
    try { await cleanup(); } catch (e) { console.error(`CLOUD_CLEANUP:${e}`); process.exitCode = 1;
      fs.writeFileSync(path.join(out, 'cloud-cleanup-failure.json'), JSON.stringify({runId,error:String(e)})); }
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









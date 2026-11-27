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
import { claimRequest } from './day137-request-budget.mjs';
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
// Production startup requires a configured email adapter even for preverified
// local users. Read the existing adapter config without persisting its secrets.
// These cases never call register/verify/resend or mutate remote Auth users.
const providerConfig = loadEnv();
assert.equal(new URL(providerConfig.supabaseUrl!).hostname, 'qeoowayxfqyhfcgnrfnv.supabase.co');
const config = { ...buildTestConfig(), nodeEnv: 'production' as const, databaseUrl: db, redisUrl,
  supabaseUrl: providerConfig.supabaseUrl, supabaseAnonKey: providerConfig.supabaseAnonKey,
  supabaseServiceRoleKey: providerConfig.supabaseServiceRoleKey,
  supabaseProjectRef: providerConfig.supabaseProjectRef,
  supabaseBuckets: providerConfig.supabaseBuckets,
  features: { rescueBrowse: true, rescueCreate: true },
  auth: { ...buildTestConfig().auth, accessTokenSecret: 'day137-local-only-access-fixture-20261001', refreshTokenSecret: 'day137-local-only-refresh-fixture-20261001' } };
const envelopePath = process.env.DAY137_ENVELOPE_PATH!;
assert(envelopePath, 'ENVELOPE_REQUIRED');
const owned = new Map<string, string>();
const cleanupCallbacks: Array<() => Promise<void>> = [];
let cleanupMode = false;
const registerOwned = (bucket: string, key: string) => {
  assert.equal(bucket, config.supabaseBuckets.adoptionChatMediaPrivate ?? 'adoption-chat-media-private');
  assert(/^adoption_chat\/[a-f0-9-]{36}\/[a-f0-9-]{36}\/[a-f0-9]{64}\/private.png$/.test(key));
  assert(owned.size < 2 && !owned.has(key), 'OWNED_OBJECT_LIMIT');
  owned.set(key, bucket);
  fs.writeFileSync(path.join(out, 'owned-cloud-objects.json'), JSON.stringify({runId, objects: [...owned].map(([key,bucket]) => ({key,bucket}))}, null, 2));
};
const countedFetch: typeof fetch = async (input, init) => {
  const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
  assert.equal(url.hostname, 'qeoowayxfqyhfcgnrfnv.supabase.co', 'CLOUD_PROJECT');
  assert(url.pathname.startsWith('/storage/v1/'), 'CLOUD_STORAGE_ONLY');
  const method = (init?.method ?? (typeof input === 'object' && 'method' in input ? input.method : 'GET')).toUpperCase();
  if (method !== 'GET' && method !== 'HEAD') {
    const privateBucket = config.supabaseBuckets.adoptionChatMediaPrivate ?? 'adoption-chat-media-private';
    const allowedList = method === 'POST' && url.pathname === `/storage/v1/object/list/${privateBucket}`;
    const allowedUpload = method === 'POST' && [...owned].some(([key,bucket]) => decodeURIComponent(url.pathname) === `/storage/v1/object/${bucket}/${key}`);
    const body = typeof init?.body === 'string' ? JSON.parse(init.body) : undefined;
    const allowedDelete = cleanupMode && method === 'DELETE' && url.pathname === `/storage/v1/object/${privateBucket}` &&
      Array.isArray(body?.prefixes) && body.prefixes.length === 1 && owned.get(body.prefixes[0]) === privateBucket;
    assert(allowedList || allowedUpload || allowedDelete, 'CLOUD_MUTATION_OUTSIDE_OWNED_OBJECT');
  }
  claimRequest(envelopePath, 'cloud', cleanupMode);
  return fetch(input, { ...init, signal: init?.signal ?? AbortSignal.timeout(15000) });
};
const cloud = createClient(config.supabaseUrl!, config.supabaseServiceRoleKey!, {
  auth: {persistSession: false, autoRefreshToken: false},
  global: {fetch: countedFetch}
});
const storage = createSupabaseRescueMediaStorage(config, cloud, { bucketSetupMode: 'verify_existing' })!;
assert(storage, 'REAL_STORAGE_REQUIRED');
const app = buildApp({ logger: false }, { config, rescueMediaStorage: storage });
const applications = [app];
app.addHook('onRoute', options => {
  for (const method of Array.isArray(options.method) ? options.method : [options.method]) {
    if (method !== 'HEAD') routes.push({ method, path: options.url });
  }
});
const roles = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'];
const users = Object.fromEntries(roles.map(role => [role, randomUUID()]));
const sessions: Record<string, { accessToken: string; refreshToken: string }> = {};
let requests = 0;
let failure: unknown;
const save = () => fs.writeFileSync(path.join(out, 'cross-role-results.json'), `${JSON.stringify({ schemaVersion: 1, runId, sourceFingerprint: entry.sourceFingerprint, transport: 'Fastify inject; real production handlers, SQL/PostGIS, Redis sessions/quota', limitations: ['Additional source-bound routes only; no cloud requests, no new email/provider verification, no uploaded media', 'Not TCP/network transport or deployed credential proof'], requestCount: requests, maxRequests: 800, cases }, null, 2)}\n`);
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
  const vetId = randomUUID();
  await prisma.$executeRawUnsafe(`INSERT INTO vets(id,external_id,name,address,city,district,location,ready_for_map,created_at,updated_at) VALUES($1::uuid,$1::text,'Day137 synthetic clinic','Synthetic clinic address','TP Hồ Chí Minh','Quận 1',ST_SetSRID(ST_MakePoint(106.7009,10.7769),4326)::geography,true,now(),now())`, vetId);
  const heroId = randomUUID(); const listingId = randomUUID();
  await prisma.mediaAsset.create({ data: { id: heroId, ownerUserId: users.shelter_A, purpose: 'adoption_listing', mimeType: 'image/webp', sizeBytes: 4096n, sha256: '7'.repeat(64), status: 'verified', storageKey: `${runId}/db-only.webp`, publicUrl: 'https://example.invalid/db-only.webp', width: 1200, height: 900, verifiedAt: new Date() } });
  await prisma.adoptionListing.create({ data: { id: listingId, shelterId: users.shelter_A, heroMediaId: heroId, petName: 'Synthetic pet', species: 'dog', ageLabel: '2 tuổi', status: 'available' } });
  await app.ready();
  fs.writeFileSync(path.join(out, 'runtime-routes.json'), JSON.stringify({ runId, routes }, null, 2));
  for (const role of roles) {
    const r = await call('POST', '/auth/login', 'anonymous', { email: `${runId}-${role.toLowerCase()}@pawmate.test`, password: 'Day137FixturePassword!20261001' });
    assert.equal(r.statusCode, 200); sessions[role] = r.json();
  }
  const reviews: Record<string,string> = {};
  for (const role of roles) {
    const r = await perform(`D137-EXTRA-REVIEW-CREATE-${role}`, 'review userId derived from bearer; SQL and returned identity bound', role, 'POST', `/vets/${vetId}/reviews`, 201,
      { rating: 5, body: 'Additional synthetic review', userId: users.outsider }, (r:any) => {
        const userId = sql(`SELECT to_json(user_id::text) FROM reviews WHERE id='${r.json().data.id}'::uuid;`);
        fields(`review-owner-${role}`, userId, users[role]);
      });
    reviews[role] = r.json().data.id;
  }
  for (const role of ['anonymous', ...roles]) {
    const account = role === 'anonymous' ? 'owner_adopter' : role;
    const email = `${runId}-${account.toLowerCase()}@pawmate.test`;
    for (const [url,status] of [['/health','ok'],['/ready','ready']]) await perform(`D137-EXTRA-${url.slice(1)}-${role}`, 'public operational endpoint; real dependency readiness', role, 'GET', url, 200,
      undefined, (r:any) => fields(`${url}-${role}`, r.json().status, status));
    for (const [i,url] of ['/', '/auth/callback'].entries()) await perform(`D137-EXTRA-WEB-${i}-${role}`, 'public HTML landing; query not reflected into raw HTML', role, 'GET',
      url + '?error_description=%3Cscript%3Efixture%3C%2Fscript%3E', 200, undefined, (r:any) => {
        assert(r.headers['content-type'].startsWith('text/html'));
        assert(r.body.includes('textContent')); assert(!r.body.includes('<script>fixture</script>'));
        fields(`web-type-${i}-${role}`, r.headers['content-type'], 'text/html; charset=utf-8');
      });
    await perform(`D137-EXTRA-PRIVACY-${role}`, 'privacy read derives verified user, no caller-supplied owner', role, 'GET', '/me/privacy-defaults', role === 'anonymous' ? 401 : 200,
      undefined, role === 'anonymous' ? undefined : (r:any) => fields(`privacy-owner-${role}`, r.json().data.userId, users[role]));
    for (const [name,url] of [['search','/vets/search?q=Day137'],['nearby','/vets/nearby?lat=10.7769&lng=106.7009&radius=5000'],['review-list',`/vets/${vetId}/reviews`]]) {
      await perform(`D137-EXTRA-VET-${name}-${role}`, 'public discovery with actual PostgreSQL/PostGIS and seeded review rows', role, 'GET', url, 200, undefined, (r:any) => {
        assert(Array.isArray(r.json().data)); assert(r.json().data.length > 0);
        if(name==='review-list') assert(r.json().data.every((x:any)=>Object.values(reviews).includes(x.id)));
        else assert(r.json().data.some((x:any)=>x.id===vetId));
        fields(`discovery-count-${name}-${role}`, r.json().data.length, name==='review-list'?4:1);
      });
    }
    // Existing verified LOCAL accounts short-circuit before provider; no remote Auth write.
    const beforeRegister = snapshot();
    await perform(`D137-EXTRA-REGISTER-${role}`, 'duplicate registration returns opaque transaction ID, not persisted user ID; no provider call', role, 'POST', '/auth/register', 201,
      { email, password: 'Day137FixturePassword!20261001' }, (r:any,after:any) => {
        assert.notEqual(r.json().userId, users[account]); assert.deepEqual(after,beforeRegister);
        fields(`register-state-${role}`, r.json().verificationStatus, 'pending');
      });
    const beforeResend = snapshot();
    await perform(`D137-EXTRA-RESEND-${role}`, 'verified-account resend remains generic and does not mutate SQL/provider', role, 'POST', '/auth/resend-verification', 200,
      {email}, (r:any,after:any) => { assert.deepEqual(after,beforeResend); fields(`resend-state-${role}`, r.json().verificationStatus, 'pending'); });
    await perform(`D137-EXTRA-LOGIN-${role}`, 'credentials, not caller bearer, own the new session', role, 'POST', '/auth/login', 200,
      {email,password:'Day137FixturePassword!20261001'}, (r:any) => {
        assert(typeof r.json().accessToken==='string' && typeof r.json().refreshToken==='string');
        fields(`login-identity-${role}`,r.json().user.id,users[account]);
      });
    const refreshed = await perform(`D137-EXTRA-REFRESH-${role}`, 'refresh belongs to supplied persisted session, not caller DTO', role, 'POST', '/auth/refresh', 200,
      {refreshToken:sessions[account].refreshToken}, (r:any)=>fields(`refresh-identity-${role}`,r.json().user.id,users[account]));
    sessions[account] = refreshed.json();
    await perform(`D137-EXTRA-OAUTH-${role}`, 'production socialLoginEnabled false fails before external verifier', role, 'POST','/auth/oauth',403,{provider:'google',credential:'synthetic-not-a-provider-token'});
    await perform(`D137-EXTRA-HELPFUL-${role}`, 'vote SQL identity derives verified caller', role, 'PUT', `/reviews/${reviews.owner_adopter}/helpful`,role==='anonymous'?401:200,
      undefined, role==='anonymous'?undefined:()=>fields(`vote-owner-${role}`,sql(`SELECT to_json(count(*)) FROM review_helpful_votes WHERE review_id='${reviews.owner_adopter}'::uuid AND user_id='${users[role]}'::uuid;`),1));
    await perform(`D137-EXTRA-REPORT-${role}`, 'report SQL identity derives verified caller; separate review avoids auto-hide interference', role, 'POST', `/reviews/${reviews[role==='anonymous'?'owner_adopter':role]}/report`,role==='anonymous'?401:201,
      {reason:'other',description:'Synthetic report'}, role==='anonymous'?undefined:(r:any)=>fields(`report-owner-${role}`,sql(`SELECT to_json(reporter_id::text) FROM review_reports WHERE id='${r.json().data.reportId}'::uuid;`),users[role]));
    await perform(`D137-EXTRA-PET-CREATE-${role}`, 'pet payload cannot transfer ownership to another caller', role, 'POST','/pets',role==='anonymous'?401:201,
      {...petPayload,userId:users.outsider},role==='anonymous'?undefined:(r:any)=>fields(`pet-owner-${role}`,sql(`SELECT to_json(user_id::text) FROM pets WHERE id='${r.json().data.id}'::uuid;`),users[role]));
    await perform(`D137-EXTRA-DECISION-${role}`, 'self-listing forbidden; another authenticated caller may record own decision', role, 'POST',`/adoption/listings/${listingId}/decisions`,
      role==='anonymous'?401:role==='shelter_A'?403:201,{decision:'like'},undefined,{'idempotency-key':`${runId}-decision-${role}`});
    const request = await perform(`D137-EXTRA-REQUEST-${role}`, 'atomic own adoption request; self shelter rejected', role, 'POST',`/adoption/listings/${listingId}/requests`,
      role==='anonymous'?401:role==='shelter_A'?403:201,{livingCondition:'Synthetic home',petExperience:'Synthetic experience',carePlan:'Synthetic care',commitmentAccepted:true},
      role==='anonymous'||role==='shelter_A'?undefined:(r:any)=>fields(`request-owner-${role}`,sql(`SELECT to_json(adopter_user_id::text) FROM adoption_requests WHERE id='${r.json().data.requestId}'::uuid;`),users[role]),
      {'idempotency-key':`${runId}-request-${role}`});
    if(role==='owner_adopter') {
      const threadId=request.json().data.threadId;
      await perform('D137-EXTRA-CHAT-SHELTER','shelter persisted participant may send; SQL sender identity bound','shelter_A','POST',`/adoption/chat/${threadId}/messages`,201,
        {body:'Synthetic shelter response',mediaIds:[]},(r:any)=>fields('chat-sender',sql(`SELECT to_json(sender_user_id::text) FROM adoption_chat_messages WHERE id='${r.json().data.messageId}'::uuid;`),users.shelter_A),
        {'idempotency-key':`${runId}-shelter-message`});
    }
  }
  for(const url of ['/me/notification-preferences','/me/privacy-defaults']) await perform(`D137-EXTRA-PREF-ANON-${url.includes('notification')?'notify':'privacy'}`,'anonymous cannot change preferences','anonymous','PUT',url,401,{expectedVersion:1});
  for(const role of ['anonymous',...roles]) {
    const account=role==='anonymous'?'owner_adopter':role;
    await perform(`D137-EXTRA-LOGOUT-${role}`,'logout targets own supplied refresh session; no SQL change',role,'POST','/auth/logout',204,{refreshToken:sessions[account].refreshToken});
    const ids=await redis.zrange(`auth:user-sessions:${users[account]}`,0,-1);
    const metadata=await Promise.all(ids.map(async(id:string)=>{const raw=await redis.get(`auth:session:${id}`);return{exists:Boolean(raw),revoked:Boolean(raw&&JSON.parse(raw).revokedAt),ttlSeconds:await redis.ttl(`auth:session:${id}`)};}));
    fields(`logout-active-${role}`,evaluateRevocation(ids.length,metadata).activeCount,0);
  }
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






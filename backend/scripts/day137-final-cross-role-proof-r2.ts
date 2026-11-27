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
const save = () => fs.writeFileSync(path.join(out, 'cross-role-results.json'), `${JSON.stringify({ schemaVersion: 1, runId, sourceFingerprint: entry.sourceFingerprint, transport: 'Fastify inject; real production handlers, SQL/PostGIS, Redis sessions/quota', limitations: ['Storage/quota supplements recorded separately; full route-state contract incomplete', 'Not TCP/network transport or deployed credential proof'], requestCount: requests, maxRequests: 800, cases }, null, 2)}\n`);
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
const run = async () => {
  await redis.connect(); assert.equal(await redis.dbsize(), 0, 'REDIS_BASELINE_NOT_EMPTY');
  assert.equal(Object.values(snapshot()).every((t: any) => t.count === 0), true, 'DATABASE_NOT_EMPTY');
  await prisma.user.createMany({ data: roles.map(role => ({ id: users[role], email: `${runId}-${role.toLowerCase()}@pawmate.test`, passwordHash: bcrypt.hashSync('Day137FixturePassword!20261001', 4), displayName: role, emailVerified: true })) });
  const vetId = randomUUID();
  await prisma.$executeRawUnsafe(`INSERT INTO vets(id,external_id,name,address,city,district,location,ready_for_map,created_at,updated_at) VALUES($1::uuid,$1::text,'Day137 synthetic clinic','Synthetic clinic address','TP Hồ Chí Minh','Quận 1',ST_SetSRID(ST_MakePoint(106.7009,10.7769),4326)::geography,true,now(),now())`, vetId);
  const heroId = randomUUID(); const listingId = randomUUID();
  await prisma.mediaAsset.create({ data: { id: heroId, ownerUserId: users.shelter_A, purpose: 'adoption_listing', mimeType: 'image/webp', sizeBytes: 4096n, sha256: '7'.repeat(64), status: 'verified', storageKey: `${runId}/not-an-object.webp`, publicUrl: 'https://example.invalid/day137-fixture.webp', width: 1200, height: 900, verifiedAt: new Date() } });
  await prisma.adoptionListing.create({ data: { id: listingId, shelterId: users.shelter_A, heroMediaId: heroId, petName: 'Day137 synthetic pet', species: 'dog', ageLabel: '2 tuổi', status: 'available' } });
  await app.ready();
  fs.writeFileSync(path.join(out, 'runtime-routes.json'), JSON.stringify({ runId, routes }, null, 2));
  for (const role of roles) {
    const r = await call('POST', '/auth/login', 'anonymous', { email: `${runId}-${role.toLowerCase()}@pawmate.test`, password: 'Day137FixturePassword!20261001' });
    assert.equal(r.statusCode, 200, r.body); sessions[role] = r.json();
  }
  const ready = await perform('D137-READY', 'actual database and Redis readiness', 'anonymous', 'GET', '/ready', 200);
  assert.equal(ready.json().status, 'ready');
  await perform('D137-PET-ANON', 'pets route requires verified bearer', 'anonymous', 'POST', '/pets', 401, petPayload);
  const created = await perform('D137-PET-CREATE', 'owner derived from verified caller, not injected DTO identity', 'owner_adopter', 'POST', '/pets', 201, { ...petPayload, ownerUserId: users.outsider, userId: users.outsider }, own);
  const petId = created.json().data.id;
  assert.equal(sql(`SELECT to_json(user_id::text) FROM pets WHERE id='${petId}'::uuid;`), users.owner_adopter);
  for (const role of ['anonymous', ...roles]) {
    await perform(`D137-PET-READ-${role}`, 'pet persisted userId ownership; auth precedes read', role, 'GET', `/pets/${petId}`, role === 'anonymous' ? 401 : role === 'owner_adopter' ? 200 : 403, undefined, role === 'owner_adopter' ? own : undefined);
    await perform(`D137-PET-LIST-${role}`, 'list scoped to verified user', role, 'GET', '/pets', role === 'anonymous' ? 401 : 200, undefined, role === 'anonymous' ? undefined : r => assert(r.json().data.every((p: any) => p.userId === users[role])));
  }
  const health = await perform('D137-HEALTH-CREATE', 'health creator is derived from caller', 'owner_adopter', 'POST', `/pets/${petId}/health-records`, 201, { type: 'checkup', date: '2026-10-01', title: 'Day137 checkup', createdByUserId: users.outsider }, r => assert.equal(r.json().data.createdByUserId, users.owner_adopter));
  const healthId = health.json().data.id;
  const reminder = await perform('D137-REMINDER-CREATE', 'reminder creator/status server owned', 'owner_adopter', 'POST', `/pets/${petId}/reminders`, 201, { title: 'Day137 reminder', reminderAt: '2099-10-01T02:30:00.000Z', timezone: 'Asia/Bangkok', repeatRule: 'none' });
  const reminderId = reminder.json().data.id;
  const privateEndpoints = [
    ['PUT', `/pets/${petId}`, { name: 'Forbidden rename' }],
    ['DELETE', `/pets/${petId}`, undefined],
    ['GET', `/pets/${petId}/health-records`, undefined],
    ['POST', `/pets/${petId}/health-records`, { type: 'checkup', date: '2026-10-01', title: 'Forbidden' }],
    ['PUT', `/pets/${petId}/health-records/${healthId}`, { title: 'Forbidden' }],
    ['DELETE', `/pets/${petId}/health-records/${healthId}`, undefined],
    ['GET', `/pets/${petId}/reminders`, undefined],
    ['POST', `/pets/${petId}/reminders`, { title: 'Forbidden', reminderAt: '2099-10-01T02:30:00.000Z', timezone: 'Asia/Bangkok', repeatRule: 'none' }],
    ['PATCH', `/pets/${petId}/reminders/${reminderId}`, { title: 'Forbidden' }],
    ['DELETE', `/pets/${petId}/reminders/${reminderId}`, undefined],
    ['POST', `/pets/${petId}/reminders/${reminderId}/mark-done`, undefined],
    ['POST', `/pets/${petId}/reminders/${reminderId}/snooze`, { snoozedUntil: '2099-10-02T02:30:00.000Z' }],
  ];
  for (const role of ['anonymous', 'outsider', 'shelter_A', 'shelter_B']) {
    for (const [i, [method, url, body]] of privateEndpoints.entries()) await perform(`D137-OWN-${i}-${role}`, 'nested resource rebound to owned pet before mutation', role, method, url as string, role === 'anonymous' ? 401 : 403, body);
  }
  await perform('D137-PET-UPDATE-OWNER', 'owner can update without transferring ownership', 'owner_adopter', 'PUT', `/pets/${petId}`, 200, { name: 'Mochi updated', userId: users.outsider }, own);
  await perform('D137-HEALTH-LIST-OWNER', 'owner health history reachable', 'owner_adopter', 'GET', `/pets/${petId}/health-records`, 200);
  await perform('D137-HEALTH-UPDATE-OWNER', 'owner health mutation persists', 'owner_adopter', 'PUT', `/pets/${petId}/health-records/${healthId}`, 200, { title: 'Updated checkup' }, r => assert.equal(r.json().data.title, 'Updated checkup'));
  await perform('D137-REMINDER-LIST-OWNER', 'owner reminder collection reachable', 'owner_adopter', 'GET', `/pets/${petId}/reminders`, 200);
  await perform('D137-REMINDER-UPDATE-OWNER', 'owner reminder mutation persists', 'owner_adopter', 'PATCH', `/pets/${petId}/reminders/${reminderId}`, 200, { title: 'Updated reminder' }, r => assert.equal(r.json().data.title, 'Updated reminder'));
  await perform('D137-REMINDER-SNOOZE-OWNER', 'owner snooze retains scheduled state', 'owner_adopter', 'POST', `/pets/${petId}/reminders/${reminderId}/snooze`, 200, { snoozedUntil: '2099-10-02T02:30:00.000Z' }, r => assert.equal(r.json().data.status, 'scheduled'));
  const notificationId = randomUUID();
  await prisma.notification.create({ data: { id: notificationId, userId: users.owner_adopter, petId, reminderId, type: 'reminder_due', title: 'Synthetic private reminder', body: 'No external push or user data' } });
  for (const role of ['anonymous', ...roles]) {
    await perform(`D137-NOTIFY-LIST-${role}`, 'notification collection caller-only', role, 'GET', '/notifications', role === 'anonymous' ? 401 : 200, undefined, role === 'anonymous' ? undefined : r => assert(r.json().data.items.every((n: any) => n.userId === users[role])));
    if (role !== 'owner_adopter') for (const action of ['read', 'dismiss']) await perform(`D137-NOTIFY-${action}-${role}`, 'private notification non-enumeration and no write', role, 'PATCH', `/notifications/${notificationId}/${action}`, role === 'anonymous' ? 401 : 404);
    await perform(`D137-NOTIFY-PROCESS-${role}`, 'user-scoped due worker does not process another owner', role, 'POST', '/notifications/process-due-reminders', role === 'anonymous' ? 401 : 200);
    await perform(`D137-NOTIFY-READALL-${role}`, 'read-all cannot affect another owner', role, 'POST', '/notifications/read-all', role === 'anonymous' ? 401 : 200);
  }
  await perform('D137-NOTIFY-READ-OWNER', 'owner can read own notification', 'owner_adopter', 'PATCH', `/notifications/${notificationId}/read`, 200, undefined, r => assert.equal(r.json().data.userId, users.owner_adopter));
  await perform('D137-NOTIFY-DISMISS-OWNER', 'owner can dismiss own notification', 'owner_adopter', 'PATCH', `/notifications/${notificationId}/dismiss`, 200);
  await perform('D137-NOTIFY-DISMISSED', 'dismissed private notification not actionable', 'owner_adopter', 'PATCH', `/notifications/${notificationId}/read`, 404);
  for (const role of ['anonymous', ...roles]) {
    const get = await perform(`D137-PREF-GET-${role}`, 'notification preferences scoped by verified caller', role, 'GET', '/me/notification-preferences', role === 'anonymous' ? 401 : 200, undefined, role === 'anonymous' ? undefined : r => assert.equal(r.json().data.userId, users[role]));
    if (role !== 'anonymous') {
      await perform(`D137-PREF-PUT-${role}`, 'CAS/version and owner scoped notification update', role, 'PUT', '/me/notification-preferences', 200, { expectedVersion: get.json().data.version, nearbyLostCases: true, chatMessages: false, adoptionUpdates: true, quietHoursEnabled: false }, r => assert.equal(r.json().data.userId, users[role]));
      await perform(`D137-PRIVACY-PUT-${role}`, 'privacy defaults owner scoped write', role, 'PUT', '/me/privacy-defaults', 200, { expectedVersion: 1, hideHouseNumber: true, hidePhoneByDefault: true, reviewMediaBeforePublish: true });
    }
  }
  await perform('D137-PREF-FORGE', 'unknown owner field forbidden', 'owner_adopter', 'PUT', '/me/privacy-defaults', 400, { expectedVersion: 2, userId: users.outsider, hideHouseNumber: false, hidePhoneByDefault: false, reviewMediaBeforePublish: true });
  await perform('D137-PREF-STALE', 'stale CAS must not overwrite', 'owner_adopter', 'PUT', '/me/privacy-defaults', 409, { expectedVersion: 1, hideHouseNumber: false, hidePhoneByDefault: false, reviewMediaBeforePublish: true });
  await race('D137-PREF-CAS-RACE', 'PUT', '/me/privacy-defaults', { expectedVersion: 2, hideHouseNumber: false, hidePhoneByDefault: false, reviewMediaBeforePublish: true }, [200, 409], () => {
    const persisted = sql(`SELECT jsonb_build_object('version',version,'hideHouseNumber',hide_house_number) FROM privacy_defaults WHERE user_id='${users.owner_adopter}'::uuid;`);
    assert.deepEqual(persisted, { version: 3, hideHouseNumber: false });
  });
  for (const role of ['anonymous', ...roles]) {
    await perform(`D137-VET-GET-${role}`, 'public vet directory reads independent of caller privilege', role, 'GET', `/vets/${vetId}`, 200, undefined, r => assert.equal(r.json().data.id, vetId));
    await perform(`D137-ADOPTION-GET-${role}`, 'authenticated listing detail; no private unrelated data', role, 'GET', `/adoption/listings/${listingId}`, role === 'anonymous' ? 401 : 200);
  }
  await perform('D137-REVIEW-ANON', 'review create requires auth', 'anonymous', 'POST', `/vets/${vetId}/reviews`, 401, { rating: 5, body: 'Synthetic review' });
  const review = await perform('D137-REVIEW-CREATE', 'review persisted under verified owner', 'owner_adopter', 'POST', `/vets/${vetId}/reviews`, 201, { rating: 5, body: 'Synthetic review', userId: users.outsider });
  assert.equal(sql(`SELECT to_json(user_id::text) FROM reviews WHERE id='${review.json().data.id}'::uuid;`), users.owner_adopter);
  const requestBody = { livingCondition: 'Synthetic safe home', petExperience: 'Synthetic test experience', carePlan: 'Synthetic care plan', commitmentAccepted: true };
  await perform('D137-ADOPTION-SELF', 'listing owner cannot request own listing', 'shelter_A', 'POST', `/adoption/listings/${listingId}/requests`, 403, requestBody, undefined, { 'idempotency-key': `${runId}-self` });
  const req = await perform('D137-ADOPTION-CREATE', 'atomic request/thread/participants/outbox/idempotency transaction', 'owner_adopter', 'POST', `/adoption/listings/${listingId}/requests`, 201, requestBody, undefined, { 'idempotency-key': `${runId}-request` });
  const threadId = req.json().data.threadId;
  const replay = await perform('D137-ADOPTION-REPLAY', 'same key/payload returns same request without another effect', 'owner_adopter', 'POST', `/adoption/listings/${listingId}/requests`, 201, requestBody, r => assert.equal(r.json().data.requestId, req.json().data.requestId), { 'idempotency-key': `${runId}-request` });
  assert.equal(replay.json().data.threadId, threadId);
  const atomic = sql(`SELECT jsonb_build_object('requests',(SELECT count(*) FROM adoption_requests WHERE adopter_user_id='${users.owner_adopter}'::uuid),'threads',(SELECT count(*) FROM adoption_chat_threads WHERE id='${threadId}'::uuid),'participants',(SELECT count(*) FROM adoption_chat_participants WHERE thread_id='${threadId}'::uuid),'events',(SELECT count(*) FROM outbox_events WHERE event_type='adoption.request_submitted.v1' AND actor_user_id='${users.owner_adopter}'::uuid));`);
  assert.deepEqual(atomic, { requests: 1, threads: 1, participants: 2, events: 1 });
  fs.writeFileSync(path.join(out, 'adoption-atomic-sql.json'), JSON.stringify(atomic));
  for (const role of ['anonymous', ...roles]) {
    // requireParticipant emits thread_not_found for outsiders; mapPersistenceError
    // intentionally maps that to 404/ADOPTION_007 to avoid thread enumeration.
    const expected = role === 'anonymous' ? 401 : ['owner_adopter', 'shelter_A'].includes(role) ? 200 : 404;
    await perform(`D137-CHAT-READ-${role}`, 'persisted membership; outsiders receive non-enumerating 404 per requireParticipant/mapPersistenceError', role, 'GET', `/adoption/chat/${threadId}`, expected);
    if (expected >= 400) await perform(`D137-CHAT-SEND-${role}`, 'nonparticipant receives non-enumerating 404 and cannot create message/outbox', role, 'POST', `/adoption/chat/${threadId}/messages`, expected, { body: 'Forbidden message', mediaIds: [] }, undefined, { 'idempotency-key': `${runId}-forbid-${role}` });
  }
  const messageKey = `${runId}-chat`;
  const msg = await perform('D137-CHAT-SEND-OWNER', 'participant message atomically persists', 'owner_adopter', 'POST', `/adoption/chat/${threadId}/messages`, 201, { body: 'Synthetic message', mediaIds: [] }, undefined, { 'idempotency-key': messageKey });
  await perform('D137-CHAT-REPLAY', 'message replay has one sequence/effect', 'owner_adopter', 'POST', `/adoption/chat/${threadId}/messages`, 201, { body: 'Synthetic message', mediaIds: [] }, r => assert.equal(r.json().data.messageId, msg.json().data.messageId), { 'idempotency-key': messageKey });
  await perform('D137-CHAT-CONFLICT', 'same key changed payload rejected without effect', 'owner_adopter', 'POST', `/adoption/chat/${threadId}/messages`, 409, { body: 'Conflicting message', mediaIds: [] }, undefined, { 'idempotency-key': messageKey });
  await race('D137-CHAT-IDEMPOTENCY-RACE', 'POST', `/adoption/chat/${threadId}/messages`, { body: 'Synthetic concurrent message', mediaIds: [] }, [201, 201], rs => {
    assert.equal(rs[0].json().data.messageId, rs[1].json().data.messageId);
    const effects = sql(`SELECT jsonb_build_object('messages',(SELECT count(*) FROM adoption_chat_messages WHERE thread_id='${threadId}'::uuid AND body='Synthetic concurrent message'),'events',(SELECT count(*) FROM outbox_events WHERE aggregate_id='${rs[0].json().data.messageId}'::uuid AND event_type='adoption.chat_message_created.v1'));`);
    assert.deepEqual(effects, { messages: 1, events: 1 });
  }, { 'idempotency-key': `${runId}-chat-race` });
  for (const role of ['anonymous', ...roles]) {
    await perform(`D137-CHAT-MARKREAD-${role}`, 'only persisted participant can advance read sequence', role, 'PUT', `/adoption/chat/${threadId}/read`, role === 'anonymous' ? 401 : ['owner_adopter', 'shelter_A'].includes(role) ? 200 : 404, { throughMessageId: msg.json().data.messageId });
    await perform(`D137-ADOPTION-REQUEST-LIST-${role}`, 'my requests scoped to adopter', role, 'GET', '/adoption/requests', role === 'anonymous' ? 401 : 200);
    await perform(`D137-ADOPTION-LIST-${role}`, 'listing collection auth and public-safe DTO', role, 'GET', '/adoption/listings', role === 'anonymous' ? 401 : 200);
  }
  const draft = await perform('D137-RESCUE-DRAFT', 'enabled create transaction owner', 'owner_adopter', 'POST', '/rescue/case-drafts', 201, { source: 'rescue_home' }, undefined, { 'idempotency-key': `${runId}-draft` });
  const draftId = draft.json().data.draftId;
  for (const role of ['anonymous', 'outsider', 'shelter_A', 'shelter_B']) await perform(`D137-RESCUE-DRAFT-${role}`, 'draft ownership in persisted storage', role, 'PATCH', `/rescue/case-drafts/${draftId}`, role === 'anonymous' ? 401 : 403, { expectedVersion: 1, petName: 'Forbidden' });
  await perform('D137-RESCUE-GPS', 'private exact GPS in draft, public privacy projection', 'owner_adopter', 'PATCH', `/rescue/case-drafts/${draftId}`, 200, { expectedVersion: 1, petName: 'Synthetic rescue', exactLocation: { latitude: 10.7769, longitude: 106.7009, formattedAddress: '123 Synthetic Road, Test area' } });
  const rescueMediaId = randomUUID();
  // DB-only verified-media fixture. Its URL is NOT counted as an object proof.
  await prisma.mediaAsset.create({ data: { id: rescueMediaId, ownerUserId: users.owner_adopter, purpose: 'rescue_case', mimeType: 'image/webp', sizeBytes: 4096n, sha256: '8'.repeat(64), status: 'verified', verificationVersion: 1, storageKey: `${runId}/db-only-rescue.webp`, publicUrl: 'https://example.invalid/day137-rescue.webp', width: 1200, height: 900, verifiedAt: new Date() } });
  await perform('D137-RESCUE-PREPARE', 'publish fields and media owner bound to caller', 'owner_adopter', 'PATCH', `/rescue/case-drafts/${draftId}`, 200, { expectedVersion: 2, species: 'dog', breedOrColor: 'Synthetic Golden', lostAt: '2026-10-01T02:30:00.000Z', identifyingFeatures: 'Synthetic red collar', mediaIds: [rescueMediaId] });
  const published = await perform('D137-RESCUE-PUBLISH', 'draft publish atomic; private exact location separate from public DTO', 'owner_adopter', 'POST', `/rescue/case-drafts/${draftId}/publish`, 201, { expectedVersion: 3 }, undefined, { 'idempotency-key': `${runId}-publish` });
  const caseId = published.json().data.caseId;
  const privacy = (r: any) => {
    const dto = r.json().data;
    assert(!JSON.stringify(dto).includes('10.7769')); assert(!JSON.stringify(dto).includes('106.7009'));
    assert(!JSON.stringify(dto).includes('123 Synthetic Road')); assert(!JSON.stringify(dto).includes('exactLocation'));
  };
  const exact = sql(`SELECT jsonb_build_object('latitude',latitude,'longitude',longitude) FROM rescue_case_private_locations WHERE case_id='${caseId}'::uuid;`);
  assert.deepEqual(exact, { latitude: 10.7769, longitude: 106.7009 });
  fs.writeFileSync(path.join(out, 'private-gps-sql.json'), JSON.stringify({ runId, caseId, exact }));
  for (const role of ['anonymous', ...roles]) {
    await perform(`D137-RESCUE-PUBLIC-LIST-${role}`, 'public list never exposes exact GPS/address', role, 'GET', '/rescue/cases', 200, undefined, privacy);
    await perform(`D137-RESCUE-PUBLIC-DETAIL-${role}`, 'public detail never exposes exact GPS/address', role, 'GET', `/rescue/cases/${caseId}`, 200, undefined, privacy);
    if (role !== 'owner_adopter') await perform(`D137-RESCUE-STATUS-DENY-${role}`, 'status write restricted to case owner', role, 'PATCH', `/rescue/cases/${caseId}/status`, role === 'anonymous' ? 401 : 403, { expectedVersion: 1, newStatus: 'found', expectedStatus: 'missing', confirmedSafe: true }, undefined, { 'idempotency-key': `${runId}-status-${role}` });
  }
  await proveBoundaries({ prisma, redis, runId, out, users, perform, snapshot, digest, config, storage, cloud,
    registerOwned, cleanupCallbacks, applications, countedFetch, setCleanupMode: () => { cleanupMode = true; },
    sourceFingerprint: entry.sourceFingerprint, threadId, messageId: msg.json().data.messageId, vetId, reviewId: review.json().data.id });
  const off = buildApp({ logger: false }, { config: { ...config, features: { rescueBrowse: false, rescueCreate: false } }, rescueMediaStorage: storage });
  applications.push(off);
  // buildApp intentionally obtains process-singleton Prisma/Redis clients.
  // Keep both test instances alive until all requests finish. Closing one here
  // disconnects the other's client and fabricates an authentication failure.
  {
    await off.ready();
    const rescueRoutes = routes.filter(r => r.path.startsWith('/rescue/'));
    for (const role of ['anonymous', ...roles]) for (const [i, r] of rescueRoutes.entries()) {
      const url = r.path.replace(':draftId', draftId).replace(':caseId', randomUUID());
      await perform(`D137-FLAG-${i}-${role}`, 'server flag checked before auth/quota/persistence', role, r.method, url, 503, r.method === 'GET' ? undefined : {}, r => assert.equal(r.json().error.code, 'RESCUE_012'), undefined, off);
    }
  }
  await perform('D137-HEALTH-DELETE-OWNER', 'owner soft delete allowed', 'owner_adopter', 'DELETE', `/pets/${petId}/health-records/${healthId}`, 204);
  await perform('D137-REMINDER-DONE-OWNER', 'owner mark-done state enforced', 'owner_adopter', 'POST', `/pets/${petId}/reminders/${reminderId}/mark-done`, 200, undefined, r => assert.equal(r.json().data.status, 'done'));
  await perform('D137-REMINDER-DELETE-OWNER', 'owner reminder deletion allowed', 'owner_adopter', 'DELETE', `/pets/${petId}/reminders/${reminderId}`, 204);
  await perform('D137-PET-DELETE-OWNER', 'owner pet soft delete allowed', 'owner_adopter', 'DELETE', `/pets/${petId}`, 204);
  await perform('D137-PET-DELETED-READ', 'deleted pet no longer accessible', 'owner_adopter', 'GET', `/pets/${petId}`, 404);
  await perform('D137-SESSION-LOGOUT', 'logout revokes real Redis session', 'shelter_B', 'POST', '/auth/logout', 204, { refreshToken: sessions.shelter_B.refreshToken });
  await perform('D137-SESSION-REVOKED', 'revoked bearer rejected; Redis may retain revoked tombstones until TTL', 'shelter_B', 'GET', '/pets', 401, undefined, async () => {
    const ids = await redis.zrange(`auth:user-sessions:${users.shelter_B}`, 0, -1);
    const metadata = await Promise.all(ids.map(async id => {
      const raw = await redis.get(`auth:session:${id}`);
      const session = raw ? JSON.parse(raw) : undefined;
      // Persist no token hashes, device/IP metadata or credentials.
      return { exists: Boolean(session), revoked: Boolean(session?.revokedAt), ttlSeconds: await redis.ttl(`auth:session:${id}`) };
    }));
    const revocation = evaluateRevocation(ids.length, metadata);
    const activeCount = revocation.activeCount;
    fs.writeFileSync(path.join(out, 'redis-session-revocation.json'), JSON.stringify({ runId, source: 'RedisAuthSessionStore.revokeAllSessionsScript; tombstones retain TTL', ...revocation }, null, 2));
  });
  await perform('D137-SESSION-REFRESH-REVOKED', 'revoked refresh cannot reissue credentials', 'anonymous', 'POST', '/auth/refresh', 401, { refreshToken: sessions.shelter_B.refreshToken });
  fs.writeFileSync(path.join(out, 'redis-observation.json'), JSON.stringify({ runId, ping: await redis.ping(), databaseSize: await redis.dbsize(), sessionIndexCounts: await Promise.all(roles.map(async role => ({ role, count: await redis.zcard(`auth:user-sessions:${users[role]}`) }))) }, null, 2));
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





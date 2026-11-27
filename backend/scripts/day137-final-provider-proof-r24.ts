// Test-only runner. Native production routes, SQL/Redis and real guarded Supabase.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash, randomUUID, randomBytes } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import Redis from 'ioredis';
import { PrismaClient } from '@prisma/client';
import { createClient } from '@supabase/supabase-js';
import { buildApp } from '../src/app';
import { loadEnv, resolveAuthJwtConfig } from '../src/config/env';
import { createSupabaseEmailVerificationGateway } from '../src/integrations/supabase-auth-gateway';
import { createSupabaseRescueMediaStorage } from '../src/infrastructure/rescue-media-storage';
import { sanitizeRescueMedia } from '../src/infrastructure/rescue-media-sanitizer';
import { buildDay137ProductionConfig, validateDay137EffectiveConfigs } from './day137-bootstrap-r20';
import { claimRequest } from './day137-final-provider-budget-r24.mjs';
import { createFinalProviderGuard } from './day137-final-provider-boundary-r24.mjs';
import { makeProviderPng } from './day137-provider-fixture.mjs';
import { snapshotContract } from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';
import { REQUIRED, validateFinalProviderCase, validateFinalProviderPacket } from '../../scripts/qa/day137/day137-final-provider-oracle-r24.mjs';

const root = path.resolve(__dirname, '../..');
const out = process.env.DAY137_EVIDENCE_ROOT!, runId = process.env.DAY137_RUN_ID!;
const envelope = process.env.DAY137_ENVELOPE_PATH!, db = process.env.DATABASE_URL!, redisUrl = process.env.REDIS_URL!;
assert(/^d137-final-provider-[a-z0-9-]{6,32}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root, 'output-evidence/security/day137') + path.sep));
assert.equal(new URL(db).hostname, '127.0.0.1'); assert.equal(new URL(redisUrl).hostname, '127.0.0.1');
const hash = (v: string | Buffer) => createHash('sha256').update(v).digest('hex');
const source = JSON.parse(fs.readFileSync(path.join(root, 'output-evidence/security/day137/d137-completion-20261005-r13/source-manifest.json'), 'utf8'));
const sourceFingerprint = source.sourceFingerprint, producerHash = hash(fs.readFileSync(__filename));
function checkSource() { for (const f of source.files) { const b = fs.readFileSync(path.join(root, f.path)); assert.equal(b.length, f.bytes); assert.equal(hash(b), f.sha256); } }
checkSource();
const config = buildDay137ProductionConfig(loadEnv(), db, redisUrl);
assert.equal(new URL(config.supabaseUrl!).origin, 'https://qeoowayxfqyhfcgnrfnv.supabase.co');
const schema = fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8');
const contract = snapshotContract(schema);
const psql = path.join(root, 'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const sql = (query: string) => JSON.parse(execFileSync(psql, ['-h', '127.0.0.1', '-p', new URL(db).port, '-U', 'pawmate', '-d', new URL(db).pathname.slice(1), '-At', '-v', 'ON_ERROR_STOP=1', '-c', query], { encoding: 'utf8', timeout: 10000 }).trim());
const snapshot = () => sql(contract.query);
const otherRows = (exclude: Record<string, string>) => sql(`SELECT jsonb_object_agg(name,value) FROM (${contract.tables.map((t: string) => `SELECT '${t}' name,jsonb_build_object('count',count(*),'contentHash',md5(coalesce(string_agg(row_to_json(t)::text,'' ORDER BY row_to_json(t)::text),''))) value FROM "${t}" t${exclude[t] ? ' WHERE NOT (' + exclude[t] + ')' : ''}`).join(' UNION ALL ')}) s;`);
const cli = path.join(root, 'output-evidence/day67/portable-redis/redis-3.0.504/redis-cli.exe');
const rc = (...args: string[]) => execFileSync(cli, ['-h', '127.0.0.1', '-p', new URL(redisUrl).port, '--raw', ...args], { encoding: 'utf8', timeout: 10000 }).trim();
const authRows = (userId: string) => {
  const indexKey = 'auth:user-sessions:' + userId, raw = rc('zrange', indexKey, '0', '-1');
  return { indexKey, indexTtlMs: Number(rc('pttl', indexKey)), sessions: (raw ? raw.split(/\r?\n/) : []).map(sid => ({ key: 'auth:session:' + sid, fields: JSON.parse(rc('get', 'auth:session:' + sid)), ttlMs: Number(rc('pttl', 'auth:session:' + sid)) })), oracle: 'independent redis-cli ZRANGE/GET/PTTL' };
};
const prisma = new PrismaClient({ datasources: { db: { url: db } } });
const redis = new Redis(redisUrl, { lazyConnect: true, maxRetriesPerRequest: 0 });
const roles = ['owner_adopter', 'outsider', 'shelter_A', 'shelter_B'], contexts = ['anonymous', ...roles];
const users: Record<string, string> = Object.fromEntries(roles.map(r => [r, randomUUID()]));
const targets: Record<string, string> = Object.fromEntries(contexts.map(r => [r, randomUUID()]));
const emails = contexts.map((_, i) => `${runId}-verify-${i}-${randomBytes(4).toString('hex')}@pawmate.test`);
const password = 'Qa-' + randomBytes(18).toString('hex') + '-1';
const buckets = [config.supabaseBuckets.rescueMediaStaging ?? 'rescue-media-staging', config.supabaseBuckets.rescueMediaPublic ?? 'rescue-media-public', config.supabaseBuckets.adoptionChatMediaPrivate ?? 'adoption-chat-media-private'];
const guard = createFinalProviderGuard({ emails, buckets });
const sessions: Record<string, any> = {}, tickets: Record<string, any> = {};
const cases: any[] = [], journal: any[] = [], secretValues = new Set<string>([password, config.supabaseServiceRoleKey!, config.supabaseAnonKey!]);
const bytes = makeProviderPng(), sanitized = sanitizeRescueMedia({ bytes, declaredMimeType: 'image/png' });
let current: any, app: any, failure: unknown, cleanupMode = false, runtimeCalls = 0;
const originalFetch = globalThis.fetch;
const safeError = (e: unknown) => {
  let text = String(e); for (const v of secretValues) if (v) text = text.replaceAll(v, '[REDACTED]');
  return text.replace(/eyJ[\w-]+\.[\w-]+\.[\w-]+/g, '[REDACTED]').replace(/([?&]token=)[^\s"&]+/g, '$1[REDACTED]');
};
const safeValue = (value: unknown): any => JSON.parse(JSON.stringify(value, (key, v) => {
  if (key === 'accessToken' || key === 'refreshToken') return '[MEMORY_ONLY]';
  if (key === 'uploadUrl' && typeof v === 'string') { const u = new URL(v); u.search = '?token=[REDACTED]'; return u.href.replace('%5BREDACTED%5D', '[REDACTED]'); }
  return v;
}));
const write = (name: string, value: any) => fs.writeFileSync(path.join(out, name), JSON.stringify(safeValue(value), null, 2) + '\n');
const ref = (name: string) => { const b = fs.readFileSync(path.join(out, name)); return { path: path.relative(root, path.join(out, name)).replaceAll('\\', '/'), bytes: b.length, sha256: hash(b) }; };
const persistOwned = () => write('owned-provider-fixtures.json', { runId, authIds: [...guard.authIds], attemptedEmailHashes: [...guard.attemptedEmails].map(hash), ticketPaths: [...guard.ticketKeys].map(([key, bucket]: any) => ({ key, bucket })), objectPaths: [...guard.objects].map(([key, bucket]: any) => ({ key, bucket })) });
const packet = () => ({ schemaVersion: 1, runId, sourceFingerprint, producerHash, requiredCaseIds: REQUIRED, cases, runtimeCalls, cloudCalls: journal.length, fullDay137Acceptance: false });
const save = () => write('state-results.json', packet());
globalThis.fetch = async (input: any, init: any = {}) => {
  const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
  const method = (init.method ?? input.method ?? 'GET').toUpperCase();
  let body: any; if (typeof init.body === 'string') { try { body = JSON.parse(init.body); } catch { assert.fail('NON_JSON_PROVIDER_BODY'); } }
  const operation = guard.check(url, method, body, new Headers(init.headers ?? input.headers));
  persistOwned(); claimRequest(envelope, 'cloud', cleanupMode);
  const j: any = { ordinal: journal.length + 1, runId, operation, method, path: url.pathname, cleanup: cleanupMode, startedAt: new Date().toISOString(), headersRedacted: true };
  if (init.body instanceof Uint8Array) j.requestByteSha256 = hash(Buffer.from(init.body));
  journal.push(j); write('provider-journal.json', journal);
  try {
    const r = await originalFetch(input, { ...init, signal: AbortSignal.timeout(20000), redirect: 'error' });
    j.status = r.status; j.responseByteSha256 = hash(Buffer.from(await r.clone().arrayBuffer())); return r;
  } catch (e) { j.error = safeError(e); throw e; }
  finally { j.endedAt = new Date().toISOString(); write('provider-journal.json', journal); }
};
const cloud = createClient(config.supabaseUrl!, config.supabaseServiceRoleKey!, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }, global: { fetch: globalThis.fetch } });
const anon = createClient(config.supabaseUrl!, config.supabaseAnonKey!, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }, global: { fetch: globalThis.fetch } });
const gateway = createSupabaseEmailVerificationGateway(config, { authClient: anon.auth, adminClient: cloud })!;
const storage = createSupabaseRescueMediaStorage(config, cloud, { bucketSetupMode: 'verify_existing' })!;
async function call(method: any, url: string, role: string, payload?: any, headers: any = {}) {
  claimRequest(envelope); runtimeCalls += 1;
  const action: any = { method, url, role, startedAt: new Date().toISOString() };
  current?.actions.push(action);
  const r = await app.inject({ method, url, payload, headers: { ...(role === 'anonymous' ? {} : { authorization: 'Bearer ' + sessions[role].accessToken }), ...headers } });
  action.endedAt = new Date().toISOString(); action.status = r.statusCode;
  action.headers = { cacheControl: r.headers['cache-control'], contentType: r.headers['content-type'] };
  const body = r.json(); action.body = safeValue(body);
  if (body.accessToken) {
    const jc = resolveAuthJwtConfig(config);
    for (const type of ['access', 'refresh']) {
      secretValues.add(body[type + 'Token']);
      action[type + 'Claims'] = jwt.verify(body[type + 'Token'], type === 'access' ? config.auth.accessTokenSecret : config.auth.refreshTokenSecret, { algorithms: ['HS256'], issuer: jc.issuer, audience: jc.audience });
      action[type + 'CryptoVerified'] = true;
    }
  }
  save(); return r;
}
async function journey(group: string, role: string, fn: () => Promise<void>) {
  const id = `D137-${group}-${role}-baseline`;
  current = { id, canonicalRequirementId: id, runId, sourceFingerprint, producerHash, startedAt: new Date().toISOString(), actions: [], sqlBefore: snapshot(), native: {}, verdict: 'NOT_RUN' };
  cases.push(current); save();
  try { await fn(); current.sqlAfter = snapshot(); current.verdict = 'PASS'; }
  catch (e) { current.sqlAfter = snapshot(); current.verdict = 'FAIL'; current.failure = safeError(e); throw e; }
  finally {
    current.endedAt = new Date().toISOString();
    if (current.verdict === 'PASS') { try { validateFinalProviderCase(safeValue(current)); } catch (e) { current.verdict = 'FAIL'; current.failure = safeError(e); failure = e; } }
    write(id + '-checkpoint.json', current); current.checkpointRef = ref(id + '-checkpoint.json'); save();
    const verdict = current.verdict; current = undefined; assert.equal(verdict, 'PASS', id);
  }
}
const expect = (r: any, status: number) => { assert.equal(r.statusCode, status); return r.json(); };
const mediaRows = (id: string) => sql(`SELECT jsonb_build_object('media',row_to_json(m),'upload',row_to_json(u)) FROM media_assets m JOIN media_upload_sessions u ON u.media_id=m.id WHERE m.id='${id}'::uuid;`);
const idemRow = (userId: string, url: string, key: string) => sql(`SELECT jsonb_build_object('user_id',user_id,'method',method,'normalized_path',normalized_path,'key_hash',key_hash,'request_hash',request_hash,'response_status',response_status,'expires_at',expires_at,'response_hash',md5(response_body::text)) FROM idempotency_records WHERE user_id='${userId}'::uuid AND normalized_path='${url}' AND key_hash='${hash(key)}';`);
function exclusion(userId: string, mediaId: string, url: string, key: string) {
  return { media_assets: `id='${mediaId}'::uuid`, media_upload_sessions: `media_id='${mediaId}'::uuid`, idempotency_records: `user_id='${userId}'::uuid AND normalized_path='${url}' AND key_hash='${hash(key)}'` };
}
function finishEffect(before: any, exclude: Record<string, string>) {
  const after = otherRows(exclude); assert.deepEqual(after, before);
  Object.assign(current.native, { unaffectedRowsBefore: before, unaffectedRowsAfter: after, sqlExpectedEffectValidated: true });
}
const deterministicId = (value: string) => { const b = createHash('sha256').update(value).digest().subarray(0, 16); b[6] = (b[6] & 15) | 64; b[8] = (b[8] & 63) | 128; const h = b.toString('hex'); return [h.slice(0, 8), h.slice(8, 12), h.slice(12, 16), h.slice(16, 20), h.slice(20)].join('-'); };

async function run() {
  process.chdir(out);
  write('effective-config-validation.json', validateDay137EffectiveConfigs({ finalProvider: config }));
  write('fixture.json', { runId, sourceFingerprint, users, targets, emails, buckets, originalSha256: hash(bytes), derivativeSha256: hash(sanitized.bytes), originalByteCount: bytes.length, derivativeByteCount: sanitized.bytes.length });
  app = buildApp({ logger: false }, { config, emailVerificationGateway: gateway, rescueMediaStorage: storage });
  await app.ready(); await redis.connect();
  assert.equal(await redis.dbsize(), 0); assert(Object.values(snapshot()).every((t: any) => t.count === 0));
  await prisma.user.createMany({ data: roles.map(r => ({ id: users[r], email: `${runId}-${r.toLowerCase()}@pawmate.test`, passwordHash: bcrypt.hashSync(password, 4), displayName: r, emailVerified: true })) });
  for (const role of roles) sessions[role] = expect(await call('POST', '/auth/login', 'anonymous', { email: `${runId}-${role.toLowerCase()}@pawmate.test`, password }), 200);
  for (const [i, role] of contexts.entries()) {
    const id = targets[role], email = emails[i];
    await prisma.user.create({ data: { id, email, passwordHash: bcrypt.hashSync(password, 4), displayName: 'Synthetic provider verification', emailVerified: false } });
    const generated = await cloud.auth.admin.generateLink({ type: 'signup', email, password, options: { data: { day137RunId: runId } } });
    if (generated.data.user?.id) { guard.ownAuth(generated.data.user.id); persistOwned(); }
    assert.equal(generated.error, null); assert(generated.data.user?.id && generated.data.properties?.hashed_token);
    assert.equal(generated.data.user.email, email); assert(!generated.data.user.email_confirmed_at);
    const remoteId = generated.data.user.id, token = generated.data.properties.hashed_token;
    guard.ownToken(token); secretValues.add(token);
    await journey('C011', role, async () => {
      const filtered = { users: `id='${id}'::uuid` }, before = otherRows(filtered);
      const userBefore = sql(`SELECT jsonb_build_object('id',id,'email',email,'email_verified',email_verified,'auth_provider',auth_provider,'display_name',display_name,'updated_at',updated_at) FROM users WHERE id='${id}'::uuid;`);
      assert.equal(userBefore.email_verified, false); assert.equal(userBefore.email, email);
      const b = expect(await call('POST', '/auth/verify-email', role, { tokenHash: token }), 200);
      assert.equal(b.userId, id); assert.equal(b.user.emailVerified, true);
      const verified = sql(`SELECT jsonb_build_object('id',id,'email',email,'email_verified',email_verified,'auth_provider',auth_provider,'display_name',display_name,'updated_at',updated_at) FROM users WHERE id='${id}'::uuid;`);
      assert.equal(verified.email, email); assert.equal(verified.email_verified, true);
      const provider = await cloud.auth.admin.getUserById(remoteId); assert.equal(provider.error, null);
      assert.equal(provider.data.user?.email, email); assert(provider.data.user?.email_confirmed_at);
      current.native = { userId: id, verifiedEmail: email, emailVerifiedBefore: userBefore.email_verified, emailVerifiedAfter: verified.email_verified, verifiedSqlBefore: userBefore, verifiedSql: verified, auth: authRows(id), provider: { userId: remoteId, email, confirmed: true } };
      finishEffect(before, filtered);
    });
    const replayBefore = snapshot(), replay = expect(await call('POST', '/auth/verify-email', role, { tokenHash: token }), 400);
    assert(['AUTH_015', 'AUTH_017'].includes(replay.error.code)); assert.deepEqual(snapshot(), replayBefore);
    write('verification-replay-' + role + '.json', { runId, role, status: 400, code: replay.error.code, sqlBefore: replayBefore, sqlAfter: snapshot(), at: new Date().toISOString() });
  }
  // Metadata read only, one cached native ensureReady. Never bootstrap/update buckets.
  await storage.ensureReady();
  const body = { purpose: 'pet_profile', mimeType: 'image/png', sizeBytes: bytes.length, sha256: hash(bytes), fileName: runId + '.png' };
  for (const role of contexts) {
    if (role === 'anonymous') {
      await journey('C053', role, async () => { const before = journal.length; expect(await call('POST', '/media/uploads', role, body, { 'idempotency-key': runId + '-anon-ticket' }), 401); current.native = { providerCallsDelta: journal.length - before }; });
      continue;
    }
    const key = runId + '-ticket-' + role, id = deterministicId(users[role] + ':/media/uploads:' + hash(key));
    const objectKey = users[role] + '/' + id + '/original.png'; guard.ticket(buckets[0], objectKey); persistOwned();
    await journey('C053', role, async () => {
      const exclude = exclusion(users[role], id, '/media/uploads', key), before = otherRows(exclude), cloudBefore = journal.length;
      const b = expect(await call('POST', '/media/uploads', role, body, { 'idempotency-key': key }), 201).data;
      assert.equal(b.mediaId, id); const u = new URL(b.uploadUrl);
      assert.equal(decodeURIComponent(u.pathname), '/storage/v1/object/upload/sign/' + buckets[0] + '/' + objectKey); assert(u.searchParams.get('token'));
      secretValues.add(u.searchParams.get('token')!); tickets[role] = b;
      const rows = mediaRows(id), idem = idemRow(users[role], '/media/uploads', key);
      assert.equal(rows.media.sha256, hash(bytes)); assert.equal(rows.media.size_bytes, bytes.length);
      current.native = { callerUserId: users[role], mediaRow: rows.media, uploadSession: rows.upload, idempotencyRow: idem, expectedStorageKey: objectKey, providerCallsDelta: journal.length - cloudBefore, expiresAtDeltaMs: Date.parse(b.expiresAt) - Date.parse(rows.media.created_at) };
      finishEffect(before, exclude);
    });
  }
  const owner = tickets.owner_adopter, originalKey = users.owner_adopter + '/' + owner.mediaId + '/original.png';
  const completeKey = runId + '-complete-owner', publicKey = 'pet_profile/' + owner.mediaId + '/' + hash(completeKey) + '/public.png';
  guard.object(buckets[0], originalKey); guard.object(buckets[1], publicKey); persistOwned();
  // Register before dispatch so an uncertain network result is never an unowned key.
  const upload = await globalThis.fetch(owner.uploadUrl, { method: 'PUT', headers: owner.uploadHeaders, body: bytes }); assert(upload.ok);
  for (const role of ['anonymous', 'outsider', 'shelter_A', 'shelter_B']) await journey('C054', role, async () => {
    const before = journal.length; expect(await call('POST', '/media/uploads/' + owner.mediaId + '/complete', role, { sha256: hash(bytes) }, { 'idempotency-key': runId + '-deny-' + role }), role === 'anonymous' ? 401 : 404);
    current.native = { providerCallsDelta: journal.length - before };
  });
  await journey('C054', 'owner_adopter', async () => {
    const url = '/media/uploads/' + owner.mediaId + '/complete', exclude = exclusion(users.owner_adopter, owner.mediaId, url, completeKey), before = otherRows(exclude);
    const b = expect(await call('POST', url, 'owner_adopter', { sha256: hash(bytes) }, { 'idempotency-key': completeKey }), 200).data;
    const rows = mediaRows(owner.mediaId), idem = idemRow(users.owner_adopter, url, completeKey);
    assert.equal(b.sha256, hash(bytes)); assert.equal(b.sizeBytes, bytes.length);
    assert.equal(rows.upload.sanitized_sha256, hash(sanitized.bytes)); assert.equal(rows.upload.detected_size_bytes, sanitized.originalSizeBytes);
    const downloaded = await cloud.storage.from(buckets[1]).download(publicKey); assert.equal(downloaded.error, null); assert(downloaded.data);
    const remote = Buffer.from(await downloaded.data.arrayBuffer()); assert.deepEqual(remote, sanitized.bytes);
    assert(!remote.includes(Buffer.from('Day137 synthetic metadata')));
    assert.equal(remote.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    const derivativeDimensions = { width: remote.readUInt32BE(16), height: remote.readUInt32BE(20) };
    assert.deepEqual(derivativeDimensions, { width: 1, height: 1 });
    fs.writeFileSync(path.join(out, 'owned-derivative.png'), remote, { flag: 'wx' });
    const stagingDelete = journal.find(j => j.operation === 'owned_object_delete' && j.path === '/storage/v1/object/' + buckets[0]);
    assert(stagingDelete?.status === 200);
    current.native = { callerUserId: users.owner_adopter, mediaRow: rows.media, uploadSession: rows.upload, idempotencyRow: idem, expectedStorageKey: publicKey, originalByteSha256: hash(bytes), originalByteCount: bytes.length, derivativeByteSha256: hash(remote), derivativeByteCount: remote.length, derivativeArtifact: ref('owned-derivative.png'), derivativeDimensions, metadataRemoved: true, stagingDeleted: true, stagingDeleteEventOrdinal: stagingDelete.ordinal };
    finishEffect(before, exclude);
  });
  const result = validateFinalProviderPacket(safeValue(packet()), { runId, sourceFingerprint, producerHash });
  assert.equal(journal.length, 32); checkSource(); write('native-acceptance.json', result);
}

run().catch(e => { failure = e; process.exitCode = 1; write('first-failure.json', { at: new Date().toISOString(), error: safeError(e) }); console.error(safeError(e)); }).finally(async () => {
  save(); cleanupMode = true; guard.setCleanup();
  const cleanup: any = { runId, auth: [], objects: [], verdict: 'NOT_RUN' };
  try {
    for (const id of guard.authIds) {
      const deleted = await cloud.auth.admin.deleteUser(id); assert.equal(deleted.error, null);
      const readback = await cloud.auth.admin.getUserById(id);
      assert.equal(readback.data.user, null); assert.equal(readback.error?.status, 404);
      cleanup.auth.push({ id, remaining: 0 }); write('provider-cleanup.json', cleanup);
    }
    const stagingObject = [...guard.objects].find(([, bucket]: any) => bucket === buckets[0]);
    const nativeStagingDelete = journal.some(j => j.operation === 'owned_object_delete' && j.path === '/storage/v1/object/' + buckets[0] && j.status === 200);
    if (stagingObject && !nativeStagingDelete) { const deleted = await cloud.storage.from(buckets[0]).remove([stagingObject[0]]); assert.equal(deleted.error, null); }
    const publicObject = [...guard.objects].find(([, bucket]: any) => bucket === buckets[1]);
    if (publicObject) { const deleted = await cloud.storage.from(buckets[1]).remove([publicObject[0]]); assert.equal(deleted.error, null); }
    for (const [key, bucket] of guard.objects) {
      const prefix = key.slice(0, key.lastIndexOf('/'));
      const result = await cloud.storage.from(bucket).list(prefix, { limit: 10 });
      assert.equal(result.error, null); assert.deepEqual(result.data, []);
      cleanup.objects.push({ bucket, key, remaining: 0 });
    }
    assert.equal(guard.authIds.size, guard.attemptedEmails.size, 'UNCERTAIN_AUTH_CREATION_REQUIRES_OWNED_READBACK');
    cleanup.verdict = 'PASS_EXACT_OWNED_CLEANUP'; cleanup.cloudCalls = journal.length;
    write('provider-cleanup.json', cleanup);
  } catch (e) { process.exitCode = 1; cleanup.verdict = 'BLOCKED'; cleanup.error = safeError(e); write('provider-cleanup.json', cleanup); }
  try {
    await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.map((t: string) => '"' + t + '"').join(',')} CASCADE`);
    const after = snapshot(); assert(Object.values(after).every((t: any) => t.count === 0));
    const keys = await redis.keys('*'); if (keys.length) await redis.del(...keys);
    assert.equal(await redis.dbsize(), 0); checkSource();
    write('fixture-cleanup.json', { runId, sourceFingerprint, sqlAfter: after, remainingRows: 0, redisRemaining: 0, verdict: 'PASS' });
  } catch (e) { process.exitCode = 1; write('fixture-cleanup.json', { runId, verdict: 'BLOCKED', error: safeError(e) }); }
  try { await app?.close(); await prisma.$disconnect(); redis.disconnect(); } catch (e) { process.exitCode = 1; console.error(safeError(e)); }
  globalThis.fetch = originalFetch;
  if (!failure && process.exitCode !== 1) console.log(JSON.stringify({ nativeCases: cases.length, cloudCalls: journal.length, runtimeCalls, verdict: 'PASS_NATIVE_PROVIDER_SLICE_NOT_FULL_DAY137' }));
});

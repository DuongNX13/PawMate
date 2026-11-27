import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { PrismaClient } from '@prisma/client';
import { createClient } from '@supabase/supabase-js';
import bcrypt from 'bcryptjs';
import type { InjectOptions, Response as InjectionResponse } from 'light-my-request';

import { buildApp } from '../src/app';
import { loadEnv } from '../src/config/env';
import { createSupabaseRescueMediaStorage } from '../src/infrastructure/rescue-media-storage';

const runId = process.env.DAY132_RUN_ID ?? '';
const evidenceRoot = process.env.DAY132_EVIDENCE_ROOT ?? '';
const authManifest = process.env.DAY132_AUTH_MANIFEST ?? '';
const projectRef = 'qeoowayxfqyhfcgnrfnv';
const privateBucket = 'adoption-chat-media-private';
const stagingBucket = 'rescue-media-staging';
const publicBucket = 'rescue-media-public';
const now = () => new Date().toISOString();
const sha = (bytes: Buffer | string) => createHash('sha256').update(bytes).digest('hex');
const fail = (message: string): never => { throw new Error(message); };
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) fail(message);
}

if (!/^d132-[a-z0-9-]{8,60}$/.test(runId)) fail('RUN_ID_INVALID');
if (!evidenceRoot || !authManifest || !existsSync(authManifest)) fail('EVIDENCE_OR_AUTH_MISSING');
const manifest = JSON.parse(readFileSync(authManifest, 'utf8')) as {
  target: { projectRef: string }; scope: { day: string; syntheticOnly: boolean; deleteOnlyRunOwned: boolean; policyMutation: boolean; existingBucketMutation: boolean; existingObjectMutation: boolean; createPrivateBucketOnly: string };
};
assert(manifest.target.projectRef === projectRef && manifest.scope.day === 'D132', 'AUTH_TARGET_MISMATCH');
assert(manifest.scope.syntheticOnly && manifest.scope.deleteOnlyRunOwned && !manifest.scope.policyMutation && !manifest.scope.existingBucketMutation && !manifest.scope.existingObjectMutation && manifest.scope.createPrivateBucketOnly === privateBucket, 'AUTH_SCOPE_MISMATCH');
assert(resolve(evidenceRoot).startsWith(resolve(join(__dirname, '..', '..', 'output-evidence', 'security', 'day-132'))), 'EVIDENCE_PATH_OUTSIDE_DAY132');

const config = loadEnv();
assert(config.supabaseUrl && config.supabaseServiceRoleKey && config.supabaseAnonKey && config.databaseUrl && config.redisUrl, 'CONFIG_INCOMPLETE');
assert(new URL(config.supabaseUrl).hostname === `${projectRef}.supabase.co`, 'SUPABASE_REF_MISMATCH');
assert(config.supabaseProjectRef === projectRef, 'CONFIG_REF_MISMATCH');
assert(new URL(config.databaseUrl).hostname === '127.0.0.1', 'NON_LOCAL_DATABASE_REFUSED');
assert(new URL(config.redisUrl).hostname === '127.0.0.1', 'NON_LOCAL_REDIS_REFUSED');
const admin = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
const anon = createClient(config.supabaseUrl, config.supabaseAnonKey, { auth: { persistSession: false, autoRefreshToken: false } });
const storage = createSupabaseRescueMediaStorage(config, admin, { bucketSetupMode: 'verify_existing' });
assert(storage, 'STORAGE_ADAPTER_MISSING');
const prisma = new PrismaClient({ datasources: { db: { url: config.databaseUrl } } });
const app = buildApp({ logger: false }, { config, rescueMediaStorage: storage });

type CaseId = 'D132-V01' | 'D132-V02' | 'D132-V03' | 'D132-V04';
type CaseRecord = { id: CaseId; verdict: 'PASS' | 'FAIL' | 'NOT_RUN'; startedAt?: string; endedAt?: string; checks: Array<{ name: string; actual: string; pass: boolean }>; failure?: string };
const records: CaseRecord[] = (['D132-V01', 'D132-V02', 'D132-V03', 'D132-V04'] as CaseId[]).map(id => ({ id, verdict: 'NOT_RUN', checks: [] }));
const ownedObjects: Array<{ bucket: string; key: string }> = [];
let ownedAuthUserId: string | undefined;
const artifact = join(evidenceRoot, 'live-matrix.json');
const cleanupArtifact = join(evidenceRoot, 'cloud-cleanup.json');
const save = () => writeFileSync(artifact, `${JSON.stringify({ schemaVersion: 1, runId, projectRef, source: 'live Supabase Storage and local disposable Postgres/Redis', capturedAt: now(), cases: records, ownedObjectKeys: ownedObjects, ownedSyntheticAuthUserId: ownedAuthUserId }, null, 2)}\n`, 'utf8');
const check = (record: CaseRecord, name: string, condition: unknown, actual: string) => {
  const pass = Boolean(condition);
  record.checks.push({ name, actual, pass }); save();
  if (!pass) fail(`${record.id}:${name}:${actual}`);
};
const runCase = async (id: CaseId, body: (record: CaseRecord) => Promise<void>) => {
  const record = records.find(item => item.id === id)!;
  record.verdict = 'FAIL'; record.startedAt = now(); save();
  try { await body(record); record.verdict = 'PASS'; }
  catch (error) { record.failure = error instanceof Error ? error.message : 'unknown'; throw error; }
  finally { record.endedAt = now(); save(); }
};
const own = (bucket: string, key: string) => { assert(!ownedObjects.some(item => item.bucket === bucket && item.key === key), 'DUPLICATE_OWNED_KEY'); ownedObjects.push({ bucket, key }); save(); };
const uploaded = async (bucket: string, key: string, bytes: Buffer, recreateOwned = false) => {
  if (recreateOwned) assert(ownedObjects.some(item => item.bucket === bucket && item.key === key), 'RECREATE_UNOWNED_REFUSED');
  else own(bucket, key);
  const result = await admin.storage.from(bucket).upload(key, bytes, { contentType: 'image/png', cacheControl: '0', upsert: false });
  assert(!result.error, `UPLOAD_FAILED:${bucket}:${result.error?.name ?? ''}`);
};
const downloaded = async (bucket: string, key: string, client = admin): Promise<Buffer | undefined> => {
  const result = await client.storage.from(bucket).download(key);
  return result.error || !result.data ? undefined : Buffer.from(await result.data.arrayBuffer());
};
const removeOwned = async (bucket: string, key: string) => {
  assert(ownedObjects.some(item => item.bucket === bucket && item.key === key), 'DELETE_UNOWNED_REFUSED');
  const result = await admin.storage.from(bucket).remove([key]);
  assert(!result.error, `REMOVE_FAILED:${bucket}:${result.error?.name ?? ''}`);
};
const publicFetch = async (bucket: string, key: string, cacheBust = false) => {
  const url = admin.storage.from(bucket).getPublicUrl(key).data.publicUrl;
  return fetch(cacheBust ? `${url}?cacheNonce=${encodeURIComponent(runId)}` : url, { cache: 'no-store' });
};
const api = async (method: 'GET' | 'POST', url: string, token?: string, payload?: unknown, idem?: string): Promise<InjectionResponse> => {
  const options: InjectOptions = { method, url, headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(idem ? { 'idempotency-key': idem } : {}) }, ...(payload === undefined ? {} : { payload: payload as object }) };
  return app.inject(options);
};
const body = (response: InjectionResponse) => response.json();
const fixtureBytes = readFileSync(resolve(__dirname, '..', '..', 'mobile', 'test', 'fixtures', 'images', 'golden_retriever_hero_v1.png'));
const fixtureHash = sha(fixtureBytes);
const id = { a: randomUUID(), b: randomUUID(), c: randomUUID(), hero: randomUUID(), listing: randomUUID(), request: randomUUID(), thread: randomUUID() };
const localPassword = `D132-${randomBytes(18).toString('hex')}9z`;
const emails = { a: `${runId}-a@pawmate.test`, b: `${runId}-b@pawmate.test`, c: `${runId}-c@pawmate.test` };
let tokens: { a: string; b: string; c: string };
let mediaId = '';
let privateKey = '';
let firstUploadKey = '';
let firstCompleteKey = '';
let firstMessageKey = '';
let messageId = '';

const seedLocal = async () => {
  const count = await prisma.user.count();
  assert(count === 0, 'LOCAL_DB_NOT_EMPTY');
  const passwordHash = await bcrypt.hash(localPassword, 10);
  for (const actor of ['a', 'b', 'c'] as const) await prisma.user.create({ data: { id: id[actor], email: emails[actor], passwordHash, emailVerified: true, displayName: `Day132 ${actor}` } });
  await prisma.mediaAsset.create({ data: { id: id.hero, ownerUserId: id.b, purpose: 'adoption_listing', mimeType: 'image/png', sizeBytes: BigInt(fixtureBytes.length), sha256: fixtureHash, status: 'verified', storageKey: `adoption_listing/${runId}/${id.hero}.png`, publicUrl: 'https://example.invalid/day132-hero.png' } });
  await prisma.adoptionListing.create({ data: { id: id.listing, shelterId: id.b, heroMediaId: id.hero, petName: 'Day132 Test Pet', species: 'dog', ageLabel: '2 years', status: 'available' } });
  await prisma.adoptionRequest.create({ data: { id: id.request, listingId: id.listing, adopterUserId: id.a, shelterId: id.b, livingCondition: 'Synthetic', petExperience: 'Synthetic', carePlan: 'Synthetic', commitmentAccepted: true, status: 'approved' } });
  await prisma.adoptionChatThread.create({ data: { id: id.thread, requestId: id.request, adopterUserId: id.a, shelterId: id.b } });
  await prisma.adoptionChatParticipant.createMany({ data: [{ threadId: id.thread, userId: id.a, role: 'adopter' }, { threadId: id.thread, userId: id.b, role: 'shelter' }] });
  const result = {} as { a: string; b: string; c: string };
  for (const actor of ['a', 'b', 'c'] as const) {
    const login = await api('POST', '/auth/login', undefined, { email: emails[actor], password: localPassword });
    assert(login.statusCode === 200, `LOCAL_LOGIN_${actor}_${login.statusCode}`);
    result[actor] = body(login).accessToken;
    assert(typeof result[actor] === 'string' && result[actor].length > 40, `LOCAL_LOGIN_TOKEN_${actor}`);
  }
  tokens = result;
};

const v01 = async (r: CaseRecord) => {
  const requestPayload = { purpose: 'adoption_chat', threadId: id.thread, mimeType: 'image/png', sizeBytes: fixtureBytes.length, sha256: fixtureHash, fileName: 'day132.png' };
  firstUploadKey = `day132-${runId}-upload-001`;
  const requested = await api('POST', '/media/uploads', tokens.a, requestPayload, firstUploadKey);
  check(r, 'authorized_upload_ticket', requested.statusCode === 201, `HTTP ${requested.statusCode}`);
  const ticket = body(requested).data as { mediaId: string; uploadUrl: string };
  mediaId = ticket.mediaId;
  const session = await prisma.mediaUploadSession.findUnique({ where: { mediaId } });
  assert(session, 'STAGING_SESSION_MISSING');
  own(stagingBucket, session.stagingStorageKey);
  const signed = new URL(ticket.uploadUrl, `${config.supabaseUrl}/storage/v1/`);
  const signedToken = signed.searchParams.get('token');
  assert(signedToken, 'SIGNED_UPLOAD_TOKEN_MISSING');
  const put = await anon.storage.from(stagingBucket).uploadToSignedUrl(session.stagingStorageKey, signedToken, fixtureBytes, { contentType: 'image/png' });
  check(r, 'signed_staging_upload', !put.error, put.error ? `error ${put.error.name}` : 'uploaded');
  firstCompleteKey = `day132-${runId}-complete-001`;
  const expectedPrivateKey = `adoption_chat/${id.thread}/${mediaId}/${sha(firstCompleteKey)}/private.png`;
  own(privateBucket, expectedPrivateKey);
  const completed = await api('POST', `/media/uploads/${mediaId}/complete`, tokens.a, { sha256: fixtureHash }, firstCompleteKey);
  check(r, 'complete_private', completed.statusCode === 200 && body(completed).data.publicUrl === undefined, `HTTP ${completed.statusCode}; publicUrl=${Boolean(body(completed).data?.publicUrl)}`);
  const media = await prisma.mediaAsset.findUnique({ where: { id: mediaId } });
  assert(media, 'MEDIA_ROW_MISSING');
  privateKey = media.storageKey;
  check(r, 'private_key_and_db_contract', media.status === 'verified' && media.publicUrl === null && privateKey === expectedPrivateKey, `status=${media.status}; publicUrl=${Boolean(media.publicUrl)}; expectedKey=${privateKey === expectedPrivateKey}`);
  firstMessageKey = `day132-${runId}-message-001`;
  const sent = await api('POST', `/adoption/chat/${id.thread}/messages`, tokens.a, { body: 'Day132 synthetic media', mediaIds: [mediaId] }, firstMessageKey);
  check(r, 'attached_message', sent.statusCode === 201, `HTTP ${sent.statusCode}`);
  messageId = body(sent).data.messageId;
  const adminBytes = await downloaded(privateBucket, privateKey);
  check(r, 'admin_storage_positive_control', adminBytes && sha(adminBytes) === media.sha256, adminBytes ? `sha256=${sha(adminBytes)}` : 'missing');
  for (const actor of ['a', 'b'] as const) {
    const response = await api('GET', `/adoption/chat/${id.thread}/media/${mediaId}`, tokens[actor]);
    check(r, `proxy_${actor}_exact_bytes`, response.statusCode === 200 && adminBytes && sha(response.rawPayload) === sha(adminBytes), `HTTP ${response.statusCode}; sha256=${sha(response.rawPayload)}`);
    check(r, `proxy_${actor}_cache_headers`, response.headers['cache-control'] === 'private, no-store, max-age=0' && response.headers.vary === 'Authorization' && response.headers['x-content-type-options'] === 'nosniff', `cache=${response.headers['cache-control']}; vary=${response.headers.vary}`);
  }
  const outsider = await api('GET', `/adoption/chat/${id.thread}/media/${mediaId}`, tokens.c);
  const anonymous = await api('GET', `/adoption/chat/${id.thread}/media/${mediaId}`);
  check(r, 'proxy_outsider_denied', outsider.statusCode === 404 && !outsider.rawPayload.equals(adminBytes!), `HTTP ${outsider.statusCode}`);
  check(r, 'proxy_anon_denied', anonymous.statusCode === 401 && !anonymous.rawPayload.equals(adminBytes!), `HTTP ${anonymous.statusCode}`);
  const anonObject = await downloaded(privateBucket, privateKey, anon);
  const anonList = await anon.storage.from(privateBucket).list(`adoption_chat/${id.thread}/${mediaId}`, { limit: 100 });
  check(r, 'direct_anon_get_and_list_denied', !anonObject && (!anonList.data || anonList.data.length === 0), `get=${Boolean(anonObject)}; list=${anonList.data?.length ?? 0}`);
  const raw = await publicFetch(privateBucket, privateKey);
  check(r, 'public_private_object_url_denied', !raw.ok, `HTTP ${raw.status}`);
  const email = `${runId}-storage-outsider@example.invalid`;
  const password = `D132-${randomBytes(20).toString('hex')}Z8`;
  const created = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  assert(created.data.user && !created.error, `SYNTHETIC_AUTH_CREATE_FAILED:${created.error?.name ?? ''}`);
  ownedAuthUserId = created.data.user.id; save();
  const signedIn = await anon.auth.signInWithPassword({ email, password });
  assert(signedIn.data.session && !signedIn.error, `SYNTHETIC_AUTH_SIGNIN_FAILED:${signedIn.error?.name ?? ''}`);
  const outsiderClient = createClient(config.supabaseUrl!, config.supabaseAnonKey!, { global: { headers: { Authorization: `Bearer ${signedIn.data.session.access_token}` } }, auth: { persistSession: false, autoRefreshToken: false } });
  const outsideGet = await downloaded(privateBucket, privateKey, outsiderClient);
  const outsideList = await outsiderClient.storage.from(privateBucket).list(`adoption_chat/${id.thread}/${mediaId}`, { limit: 100 });
  check(r, 'direct_authenticated_outsider_get_and_list_denied', !outsideGet && (!outsideList.data || outsideList.data.length === 0), `get=${Boolean(outsideGet)}; list=${outsideList.data?.length ?? 0}`);
  const adminList = await admin.storage.from(privateBucket).list(`adoption_chat/${id.thread}/${mediaId}/${privateKey.split('/')[3]}`, { limit: 100 });
  check(r, 'admin_exact_object_list_positive_control', !adminList.error && adminList.data?.some(item => item.name === 'private.png'), `admin list=${adminList.data?.length ?? 0}`);
};

const v02 = async (r: CaseRecord) => {
  const before = await api('GET', `/adoption/chat/${id.thread}/media/${mediaId}`, tokens.b);
  check(r, 'before_revocation_b_allowed', before.statusCode === 200, `HTTP ${before.statusCode}`);
  await prisma.adoptionChatParticipant.delete({ where: { threadId_userId: { threadId: id.thread, userId: id.b } } });
  try {
    const after = await api('GET', `/adoption/chat/${id.thread}/media/${mediaId}`, tokens.b);
    check(r, 'same_token_revoked_immediately', after.statusCode === 404, `HTTP ${after.statusCode}`);
    check(r, 'revoked_response_uncacheable', after.headers['cache-control'] === 'private, no-store, max-age=0', `cache=${after.headers['cache-control']}`);
    const stillAllowed = await api('GET', `/adoption/chat/${id.thread}/media/${mediaId}`, tokens.a);
    check(r, 'a_still_allowed', stillAllowed.statusCode === 200 && sha(stillAllowed.rawPayload) === sha(before.rawPayload), `HTTP ${stillAllowed.statusCode}`);
    const publicPath = await publicFetch(privateBucket, privateKey, true);
    check(r, 'no_stale_public_storage_path', !publicPath.ok, `HTTP ${publicPath.status}`);
  } finally {
    await prisma.adoptionChatParticipant.create({ data: { threadId: id.thread, userId: id.b, role: 'shelter' } });
  }
};

const v03 = async (r: CaseRecord) => {
  const base = { purpose: 'adoption_chat', threadId: id.thread, mimeType: 'image/png', sizeBytes: fixtureBytes.length, sha256: fixtureHash };
  const mediaBefore = await prisma.mediaAsset.count();
  const outboxBefore = await prisma.outboxEvent.count();
  const denied = [
    ['outsider_upload', await api('POST', '/media/uploads', tokens.c, base, `day132-${runId}-deny-c`), 404],
    ['parent_swap_upload', await api('POST', '/media/uploads', tokens.a, { ...base, threadId: randomUUID() }, `day132-${runId}-deny-parent`), 404],
    ['purpose_swap_upload', await api('POST', '/media/uploads', tokens.a, { ...base, purpose: 'rescue_case' }, `day132-${runId}-deny-purpose`), 400],
    ['owner_swap_complete', await api('POST', `/media/uploads/${mediaId}/complete`, tokens.b, { sha256: fixtureHash }, `day132-${runId}-deny-owner`), 404],
    ['sha_swap_complete', await api('POST', `/media/uploads/${mediaId}/complete`, tokens.a, { sha256: '0'.repeat(64) }, `day132-${runId}-deny-sha`), 422],
    ['cross_thread_attach', await api('POST', `/adoption/chat/${randomUUID()}/messages`, tokens.a, { body: 'deny', mediaIds: [mediaId] }, `day132-${runId}-deny-cross`), 404],
    ['cross_owner_attach', await api('POST', `/adoption/chat/${id.thread}/messages`, tokens.b, { body: 'deny', mediaIds: [mediaId] }, `day132-${runId}-deny-attach`), 400],
  ] as const;
  for (const [name, response, expected] of denied) check(r, name, response.statusCode === expected, `HTTP ${response.statusCode}; expected ${expected}`);
  check(r, 'rejected_requests_no_db_or_outbox_side_effect', await prisma.mediaAsset.count() === mediaBefore && await prisma.outboxEvent.count() === outboxBefore, `media=${await prisma.mediaAsset.count()}; outbox=${await prisma.outboxEvent.count()}`);
  const uploadReplay = await api('POST', '/media/uploads', tokens.a, { ...base, fileName: 'day132.png' }, firstUploadKey);
  check(r, 'upload_replay_same_media', uploadReplay.statusCode === 201 && body(uploadReplay).data.mediaId === mediaId, `HTTP ${uploadReplay.statusCode}`);
  const completeReplay = await api('POST', `/media/uploads/${mediaId}/complete`, tokens.a, { sha256: fixtureHash }, firstCompleteKey);
  check(r, 'complete_replay_same_media', completeReplay.statusCode === 200 && body(completeReplay).data.mediaId === mediaId, `HTTP ${completeReplay.statusCode}`);
  const messageReplay = await api('POST', `/adoption/chat/${id.thread}/messages`, tokens.a, { body: 'Day132 synthetic media', mediaIds: [mediaId] }, firstMessageKey);
  check(r, 'message_replay_no_duplicate', messageReplay.statusCode === 201 && body(messageReplay).data.messageId === messageId && await prisma.outboxEvent.count() === outboxBefore, `HTTP ${messageReplay.statusCode}; outbox=${await prisma.outboxEvent.count()}`);
  const privateBytes = await downloaded(privateBucket, privateKey);
  check(r, 'failed_swaps_did_not_change_private_object', privateBytes && sha(privateBytes) === (await prisma.mediaAsset.findUnique({ where: { id: mediaId } }))?.sha256, privateBytes ? `sha256=${sha(privateBytes)}` : 'missing');
};

const v04 = async (r: CaseRecord) => {
  const publicPetKey = `pet_profile/${runId}/${randomUUID()}.png`;
  const publicRescueKey = `rescue_case/${runId}/${randomUUID()}.png`;
  await uploaded(publicBucket, publicPetKey, fixtureBytes);
  await uploaded(publicBucket, publicRescueKey, fixtureBytes);
  const publicControlBust = await publicFetch(publicBucket, publicPetKey, true);
  check(r, 'cache_nonce_positive_control', publicControlBust.status === 200 && sha(Buffer.from(await publicControlBust.arrayBuffer())) === fixtureHash, `HTTP ${publicControlBust.status}`);
  const legacyKey = `adoption_chat/${id.thread}/${runId}/${randomUUID()}/public.png`;
  await uploaded(publicBucket, legacyKey, fixtureBytes);
  const before = await publicFetch(publicBucket, legacyKey);
  const beforeBytes = Buffer.from(await before.arrayBuffer());
  check(r, 'legacy_public_red_control', before.status === 200 && sha(beforeBytes) === fixtureHash, `HTTP ${before.status}; sha256=${sha(beforeBytes)}`);
  const legacySent = await api('POST', `/adoption/chat/${id.thread}/messages`, tokens.a, { body: 'Day132 legacy synthetic fixture', mediaIds: [] }, `day132-${runId}-legacy-msg`);
  check(r, 'legacy_message_created', legacySent.statusCode === 201, `HTTP ${legacySent.statusCode}`);
  const legacyMessageId = body(legacySent).data.messageId as string;
  const legacyMediaId = randomUUID();
  const publicUrl = admin.storage.from(publicBucket).getPublicUrl(legacyKey).data.publicUrl;
  await prisma.mediaAsset.create({ data: { id: legacyMediaId, ownerUserId: id.a, purpose: 'adoption_chat', mimeType: 'image/png', sizeBytes: BigInt(fixtureBytes.length), sha256: fixtureHash, status: 'attached', storageKey: legacyKey, publicUrl, adoptionChatMessageId: legacyMessageId } });
  const keyHash = sha(`day132-migration:${runId}`);
  const canonical = `adoption_chat/${id.thread}/${legacyMediaId}/${keyHash}/private.png`;
  const quarantine = `day132_quarantine/${runId}/${legacyMediaId}.png`;
  const source = await downloaded(publicBucket, legacyKey);
  check(r, 'migration_source_hash', source && sha(source) === fixtureHash, source ? `sha256=${sha(source)}` : 'missing');
  await uploaded(privateBucket, canonical, source!);
  const copied = await downloaded(privateBucket, canonical);
  check(r, 'copy_hash_and_count', copied && sha(copied) === fixtureHash, copied ? `count=1; sha256=${sha(copied)}` : 'missing');
  await prisma.mediaAsset.update({ where: { id: legacyMediaId }, data: { storageKey: canonical, publicUrl: null } });
  await removeOwned(publicBucket, legacyKey);
  const invalidationStartedAt = Date.now();
  const initialOld = await publicFetch(publicBucket, legacyKey);
  const initialOldBytes = Buffer.from(await initialOld.arrayBuffer());
  r.checks.push({ name: 'post_delete_pre_cutover_observation', actual: `HTTP ${initialOld.status}; bytes=${initialOldBytes.length}; cache=${initialOld.headers.get('cf-cache-status') ?? 'unknown'}`, pass: true });
  save();
  let cutoverNormal = initialOld;
  let cutoverNonce = await publicFetch(publicBucket, legacyKey, true);
  const deadline = invalidationStartedAt + 75_000;
  while ((cutoverNormal.ok || cutoverNonce.ok) && Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, 5_000));
    cutoverNormal = await publicFetch(publicBucket, legacyKey);
    cutoverNonce = await publicFetch(publicBucket, legacyKey, true);
  }
  const exposureWindowMs = Date.now() - invalidationStartedAt;
  check(r, 'old_public_path_denied_before_declaring_cutover', !cutoverNormal.ok && !cutoverNonce.ok, `HTTP ${cutoverNormal.status}/${cutoverNonce.status}; exposureWindowMs=${exposureWindowMs}`);
  for (const actor of ['a', 'b'] as const) {
    const proxy = await api('GET', `/adoption/chat/${id.thread}/media/${legacyMediaId}`, tokens[actor]);
    check(r, `migrated_proxy_${actor}`, proxy.statusCode === 200 && sha(proxy.rawPayload) === fixtureHash, `HTTP ${proxy.statusCode}; sha256=${sha(proxy.rawPayload)}`);
  }
  const outsider = await api('GET', `/adoption/chat/${id.thread}/media/${legacyMediaId}`, tokens.c);
  check(r, 'migrated_proxy_outsider_denied', outsider.statusCode === 404, `HTTP ${outsider.statusCode}`);
  await uploaded(privateBucket, quarantine, copied!);
  await removeOwned(privateBucket, canonical);
  check(r, 'rollback_private_quarantine_hash', sha((await downloaded(privateBucket, quarantine)) ?? Buffer.alloc(0)) === fixtureHash, 'private quarantine only');
  await removeOwned(privateBucket, quarantine);
  await uploaded(privateBucket, canonical, copied!, true);
  const restored = await api('GET', `/adoption/chat/${id.thread}/media/${legacyMediaId}`, tokens.a);
  const oldAfterRollback = await publicFetch(publicBucket, legacyKey, true);
  check(r, 'rollback_restores_private_not_public', restored.statusCode === 200 && sha(restored.rawPayload) === fixtureHash && !oldAfterRollback.ok, `proxy=${restored.statusCode}; old=${oldAfterRollback.status}`);
  for (const [name, key] of [['pet', publicPetKey], ['rescue', publicRescueKey]] as const) {
    const image = await publicFetch(publicBucket, key);
    const bytes = Buffer.from(await image.arrayBuffer());
    check(r, `public_${name}_imagery_unchanged`, image.status === 200 && sha(bytes) === fixtureHash, `HTTP ${image.status}; sha256=${sha(bytes)}`);
  }
};

const cleanup = async () => {
  const detail: { runId: string; startedAt: string; endedAt?: string; objects: Array<{ bucket: string; key: string; removed: boolean; readbackDenied: boolean; error?: string }>; authUser?: { id: string; removed: boolean; readbackDenied: boolean; error?: string }; verdict?: string } = { runId, startedAt: now(), objects: [] };
  for (const { bucket, key } of [...ownedObjects].reverse()) {
    try {
      await removeOwned(bucket, key);
      const still = await downloaded(bucket, key);
      detail.objects.push({ bucket, key, removed: true, readbackDenied: !still });
    } catch (error) { detail.objects.push({ bucket, key, removed: false, readbackDenied: false, error: error instanceof Error ? error.message : 'unknown' }); }
  }
  if (ownedAuthUserId) {
    const idToDelete = ownedAuthUserId;
    const deleted = await admin.auth.admin.deleteUser(idToDelete);
    const readback = await admin.auth.admin.getUserById(idToDelete);
    detail.authUser = { id: idToDelete, removed: !deleted.error, readbackDenied: Boolean(readback.error), ...(deleted.error ? { error: deleted.error.name } : {}) };
  }
  detail.endedAt = now();
  detail.verdict = detail.objects.every(item => item.removed && item.readbackDenied) && (!detail.authUser || detail.authUser.removed && detail.authUser.readbackDenied) ? 'PASS' : 'FAIL';
  writeFileSync(cleanupArtifact, `${JSON.stringify(detail, null, 2)}\n`, 'utf8');
  return detail.verdict === 'PASS';
};

const main = async () => {
  save();
  let mainError: string | undefined;
  let cleaned = false;
  try {
    await storage.ensureReady();
    await prisma.$connect();
    await app.ready();
    await seedLocal();
    await runCase('D132-V01', v01);
    await runCase('D132-V02', v02);
    await runCase('D132-V03', v03);
    await runCase('D132-V04', v04);
  } catch (error) { mainError = error instanceof Error ? error.message : 'unknown'; }
  try { cleaned = await cleanup(); } catch (error) { mainError = `${mainError ?? ''}; CLEANUP:${error instanceof Error ? error.message : 'unknown'}`; }
  try { await app.close(); } catch { /* process teardown still attempted */ }
  try { await prisma.$disconnect(); } catch { /* process teardown still attempted */ }
  const passed = !mainError && cleaned && records.every(record => record.verdict === 'PASS');
  writeFileSync(join(evidenceRoot, 'acceptance-summary.json'), `${JSON.stringify({ runId, projectRef, verdict: passed ? 'PASS' : 'BLOCKED', cases: records.map(({ id, verdict, failure }) => ({ id, verdict, ...(failure ? { failure } : {}) })), cloudCleanup: cleaned ? 'PASS' : 'FAIL', ...(mainError ? { firstFailure: mainError } : {}) }, null, 2)}\n`, 'utf8');
  process.stdout.write(`${JSON.stringify({ runId, verdict: passed ? 'PASS' : 'BLOCKED', caseResults: records.map(({ id, verdict }) => ({ id, verdict })), cleanup: cleaned ? 'PASS' : 'FAIL', ...(mainError ? { firstFailure: mainError } : {}) })}\n`);
  if (!passed) process.exitCode = 1;
};

void main();

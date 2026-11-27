// Test-only real boundary supplement. No production code or remote Auth mutation.
import assert from 'node:assert/strict';
import { createHash, createHmac, randomUUID } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import Redis from 'ioredis';
import { buildApp } from '../src/app';
import { createActionQuotaGuard, ACTION_QUOTA_POLICIES } from '../src/security/distributed-action-quota';
import { RedisActionQuotaStore } from '../src/security/redis-action-quota-store';

export async function proveBoundaries(c: any) {
  const { prisma, redis, runId, out, users, perform, snapshot, digest, config, storage, cloud, registerOwned, cleanupCallbacks, applications, threadId, messageId, vetId, reviewId } = c;
  const write = (name: string, value: any) => fs.writeFileSync(path.join(out, name), JSON.stringify(value, null, 2) + '\n');
  const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex');
  const bucket = config.supabaseBuckets.adoptionChatMediaPrivate ?? 'adoption-chat-media-private';
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z7dQAAAAASUVORK5CYII=', 'base64');
  const mediaId = randomUUID();
  const storageKey = `adoption_chat/${threadId}/${mediaId}/${sha(bytes)}/private.png`;
  const folder = storageKey.slice(0, storageKey.lastIndexOf('/'));
  registerOwned(bucket, storageKey);
  const p: any = { kind: 'DAY137_REAL_PRIVATE_OBJECT', runId, sourceFingerprint: c.sourceFingerprint,
    ownedFixtureGroup: runId, storageKey, bucket, expectedSha256: sha(bytes), observations: [],
    limitation: 'Direct owned private-object fixture proves reads; not upload/complete producer acceptance.' };
  const buckets = [config.supabaseBuckets.rescueMediaStaging ?? 'rescue-media-staging', config.supabaseBuckets.rescueMediaPublic ?? 'rescue-media-public', bucket];
  const configuration = async () => {
    const result = await Promise.all(buckets.map(async name => {
      const r = await cloud.storage.getBucket(name); assert(!r.error && r.data, 'BUCKET_READBACK');
      return r.data;
    }));
    return digest(result);
  };
  p.configBeforeSha256 = await configuration();
  write('private-object-proof.json', p);
  // Register exact owned cleanup before the first write; it also runs on failures.
  cleanupCallbacks.push(async () => {
    c.setCleanupMode();
    await storage.deletePrivateObject(storageKey);
    const r = await cloud.storage.from(bucket).list(folder, { limit: 10 });
    assert(!r.error && r.data, 'OWNED_CLEANUP_READBACK');
    assert.equal(r.data.length, 0, 'OWNED_OBJECT_REMAINS');
    p.observations.push({ id: 'object_cleanup', remainingOwnedObjects: r.data.length,
      fixturePrefix: runId, prefixMeaning: 'owned fixture group; actual object key recorded separately', timestamp: new Date().toISOString() });
    p.configAfterSha256 = await configuration();
    assert.equal(p.configAfterSha256, p.configBeforeSha256, 'BUCKET_CONFIG_DRIFT');
    write('private-object-proof.json', p);
  });
  const baseline = await cloud.storage.from(bucket).list(folder, { limit: 10 });
  assert(!baseline.error && baseline.data?.length === 0, 'OWNED_OBJECT_BASELINE');
  await storage.writePrivateObject(storageKey, bytes, 'image/png');
  await prisma.mediaAsset.create({ data: { id: mediaId, ownerUserId: users.owner_adopter,
    purpose: 'adoption_chat', mimeType: 'image/png', sizeBytes: BigInt(bytes.length), sha256: sha(bytes),
    status: 'attached', storageKey, publicUrl: null, width: 1, height: 1,
    verifiedAt: new Date(), adoptionChatMessageId: messageId, position: 0 } });
  const observe = async (id: string, role: string, url: string, expected: number, extra: any = {}) => {
    await perform(`D137-PRIVATE-${id}`, 'real private Storage bytes; persisted membership and exact media/thread binding', role, 'GET', url, expected, undefined, (r: any) => {
      const actualBytes = Buffer.from(r.rawPayload);
      const matches = actualBytes.equals(bytes);
      const o: any = { id, status: r.statusCode, timestamp: new Date().toISOString(), ...extra };
      if (expected === 200) {
        assert(matches, 'PRIVATE_BYTES_MISMATCH');
        assert.equal(r.headers['cache-control'], 'private, no-store, max-age=0');
        assert.equal(r.headers.vary, 'Authorization');
        assert.equal(r.headers['content-type'], 'image/png');
        Object.assign(o, { byteCount: actualBytes.length, expectedSha256: sha(bytes), actualSha256: sha(actualBytes),
          cacheControl: r.headers['cache-control'], vary: r.headers.vary });
      } else {
        assert(!matches && !actualBytes.includes(bytes), 'PRIVATE_BYTE_LEAK');
        o.privateBytesReturned = 0;
      }
      p.observations.push(o); write('private-object-proof.json', p);
    });
  };
  const url = `/adoption/chat/${threadId}/media/${mediaId}`;
  await observe('member_download', 'owner_adopter', url, 200);
  await observe('member_shelter_download', 'shelter_A', url, 200);
  await observe('nonmember_download', 'outsider', url, 404);
  await observe('other_shelter_download', 'shelter_B', url, 404);
  await observe('anonymous_download', 'anonymous', url, 401);
  await observe('wrong_thread_download', 'owner_adopter', `/adoption/chat/${randomUUID()}/media/${mediaId}`, 404);
  const membership = await prisma.adoptionChatParticipant.findUniqueOrThrow({ where: { threadId_userId: { threadId, userId: users.shelter_A } } });
  assert.equal(await prisma.adoptionChatMessage.count({ where: { threadId, senderUserId: users.shelter_A } }), 0, 'REVOCATION_FIXTURE_HAS_MESSAGES');
  await prisma.adoptionChatParticipant.delete({ where: { threadId_userId: { threadId, userId: users.shelter_A } } });
  try {
    const present = await prisma.adoptionChatParticipant.count({ where: { threadId, userId: users.shelter_A } });
    assert.equal(present, 0);
    await observe('revoked_download', 'shelter_A', url, 404, { membershipPresent: false });
  } finally { await prisma.adoptionChatParticipant.create({ data: membership }); }
  const publicResponse = await c.countedFetch(`${config.supabaseUrl}/storage/v1/object/public/${bucket}/${storageKey}`);
  const publicBytes = Buffer.from(await publicResponse.arrayBuffer());
  assert([400, 403, 404].includes(publicResponse.status));
  assert(!publicBytes.includes(bytes));
  p.observations.push({ id: 'public_path', status: publicResponse.status, privateBytesReturned: 0, timestamp: new Date().toISOString() });
  write('private-object-proof.json', p);

  // Production limits, production guard/store, actual disposable Redis.
  const q: any = { kind: 'DAY137_INTEGRATED_REDIS_QUOTA', runId, sourceFingerprint: c.sourceFingerprint,
    action: 'review.helpful', observations: [] };
  const accountRule = ACTION_QUOTA_POLICIES['review.helpful'].find(r => r.dimension === 'account')!;
  const resourceRule = ACTION_QUOTA_POLICIES['review.helpful'].find(r => r.dimension === 'resource')!;
  q.productionLimit = accountRule.limit;
  const secretKey = createHmac('sha256', config.auth.accessTokenSecret).update('pawmate-abuse-key-v1').digest();
  const counter = async (action: string, user: string, seconds: number) => {
    const hash = createHmac('sha256', secretKey).update(`account\u0000${user}`).digest('hex');
    const [now] = await redis.time();
    const key = `pawmate:q:v1:${action}:account:${seconds}:${hash}:${Math.floor(Number(now) / seconds)}`;
    return { key, value: Number(await redis.get(key) ?? 0), ttl: await redis.ttl(key) };
  };
  const reviewIds = [reviewId];
  for (const role of ['outsider', 'shelter_A', 'shelter_B']) {
    const r = await prisma.review.create({ data: { vetId, userId: users[role], rating: 5, body: 'Synthetic boundary review' } });
    reviewIds.push(r.id);
  }
  const beforeQuota = await counter('review.helpful', users.outsider, accountRule.windowSeconds);
  assert.equal(beforeQuota.value, 0, 'QUOTA_BASELINE_NOT_CLEAN');
  assert.equal(accountRule.limit, 3 * resourceRule.limit, 'QUOTA_RECIPE_SOURCE_DRIFT');
  for (let i = 0; i < accountRule.limit; i++) {
    const r = await perform(`D137-QUOTA-ALLOW-${i + 1}`, 'actual production account/resource quota with Redis counters', 'outsider',
      'PUT', `/reviews/${reviewIds[Math.floor(i / resourceRule.limit)]}/helpful`, 200);
    q.observations.push({ ordinal: i + 1, status: r.statusCode });
  }
  q.allowedCount = q.observations.length;
  const denied = await perform('D137-QUOTA-PLUS-ONE', 'request 61 fresh resource blocked by account 60 limit; no SQL effect', 'outsider',
    'PUT', `/reviews/${reviewIds[3]}/helpful`, 429);
  q.deniedRequestOrdinal = q.allowedCount + 1; q.deniedStatus = denied.statusCode;
  q.retryAfterSeconds = Number(denied.headers['retry-after']); assert(q.retryAfterSeconds > 0);
  const afterQuota = await counter('review.helpful', users.outsider, accountRule.windowSeconds);
  assert.equal(afterQuota.key, beforeQuota.key, 'QUOTA_WINDOW_CHANGED');
  assert.equal(afterQuota.value, accountRule.limit); assert(afterQuota.ttl > 0);
  q.redisCounter = afterQuota.value; q.redisTtlSeconds = afterQuota.ttl;
  const other = await perform('D137-QUOTA-ISOLATION', 'different verified account remains allowed on same resource', 'owner_adopter',
    'PUT', `/reviews/${reviewIds[3]}/helpful`, 200, undefined, async () => {
      assert.equal(await prisma.reviewHelpfulVote.count({ where: { reviewId: reviewIds[3], userId: users.owner_adopter } }), 1);
    });
  q.otherAccountStatus = other.statusCode; q.otherAccountIdentityVerified = true;
  const spoof = await perform('D137-QUOTA-SPOOF', 'untrusted forwarded IP cannot bypass account quota', 'outsider',
    'PUT', `/reviews/${reviewIds[3]}/helpful`, 429, undefined, undefined, { 'x-forwarded-for': '198.51.100.19' });
  q.spoofedForwardedIpStatus = spoof.statusCode;
  const preChat = await counter('chat.message', users.owner_adopter, 300);
  let firstId: string | undefined;
  for (let i = 0; i < 2; i++) await perform(`D137-QUOTA-REPLAY-${i}`, 'actual message replay creates one message/outbox/quota charge',
    'owner_adopter', 'POST', `/adoption/chat/${threadId}/messages`, 201, { body: 'Boundary replay fixture', mediaIds: [] },
    (r: any) => { if (firstId) assert.equal(r.json().data.messageId, firstId); else firstId = r.json().data.messageId; },
    { 'idempotency-key': `${runId}-boundary-replay` });
  const postChat = await counter('chat.message', users.owner_adopter, 300);
  assert.equal(preChat.key, postChat.key, 'CHAT_WINDOW_CHANGED');
  assert.equal(postChat.value - preChat.value, 1);
  assert.equal(await prisma.adoptionChatMessage.count({ where: { id: firstId } }), 1);
  assert.equal(await prisma.outboxEvent.count({ where: { aggregateId: firstId, eventType: 'adoption.chat_message_created.v1' } }), 1);
  q.idempotentReplayCount = 2; q.idempotentChargeCount = postChat.value - preChat.value;
  const deadClient = new Redis(config.redisUrl, { lazyConnect: true, enableOfflineQueue: false, maxRetriesPerRequest: 0 });
  await deadClient.connect();
  const deadApp = buildApp({ logger: false }, { config, rescueMediaStorage: storage,
    actionQuotaGuard: createActionQuotaGuard({ secret: config.auth.accessTokenSecret, store: new RedisActionQuotaStore(deadClient) }) });
  applications.push(deadApp); await deadApp.ready();
  deadClient.disconnect(); // Own quota connection only; Auth client/server stays live.
  cleanupCallbacks.push(async () => deadClient.disconnect());
  const beforeFailed = snapshot();
  const failed = await perform('D137-QUOTA-STORE-DOWN', 'real disconnected Redis quota connection; auth still valid; reject without SQL/outbox writes',
    'owner_adopter', 'PUT', `/reviews/${reviewIds[0]}/helpful`, 503, undefined,
    (r: any) => assert(Number(r.headers['retry-after']) > 0), undefined, deadApp);
  const afterFailed = snapshot(); assert.deepEqual(afterFailed, beforeFailed);
  q.unavailableStatus = failed.statusCode; q.rejectedSqlBeforeHash = digest(beforeFailed); q.rejectedSqlAfterHash = digest(afterFailed);
  write('integrated-quota-proof.json', q);
}


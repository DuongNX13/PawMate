import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import { PrismaRescueRepository } from '../src/features/rescue/persistence/prisma-rescue-repository';
import { RescuePersistenceDomainError } from '../src/features/rescue/persistence/rescue-repository';

const enabled = process.env.PAWMATE_RESCUE_DB_INTEGRATION === '1';
const describeDatabase = enabled ? describe : describe.skip;
const databaseUrl =
  process.env.PAWMATE_RESCUE_TEST_DATABASE_URL ??
  process.env.DATABASE_URL ??
  'postgresql://pawmate:pawmate@localhost:5432/pawmate';
const databaseHost = new URL(databaseUrl).hostname.toLowerCase();
const isLocalDatabase = ['localhost', '127.0.0.1', '::1'].includes(
  databaseHost,
);

if (enabled && !isLocalDatabase) {
  throw new Error(
    'Day 36 Rescue persistence tests require a local PostgreSQL database.',
  );
}

describeDatabase('Day 36 Rescue write-path PostgreSQL persistence', () => {
  jest.setTimeout(30_000);

  const ownerUserId = randomUUID();
  const commenterUserId = randomUUID();
  const concurrentUserId = randomUUID();
  const userIds = [ownerUserId, commenterUserId, concurrentUserId];
  const runId = randomUUID();
  let prisma: PrismaClient;
  let repository: PrismaRescueRepository;

  const cleanup = async () => {
    await prisma.mediaUploadSession.deleteMany({
      where: { media: { ownerUserId: { in: userIds } } },
    });
    await prisma.outboxEvent.deleteMany({
      where: { actorUserId: { in: userIds } },
    });
    await prisma.idempotencyRecord.deleteMany({
      where: { userId: { in: userIds } },
    });
    await prisma.mediaAsset.deleteMany({
      where: { ownerUserId: { in: userIds } },
    });
    await prisma.rescueComment.deleteMany({
      where: { authorUserId: { in: userIds } },
    });
    await prisma.rescueStatusEvent.deleteMany({
      where: { changedByUserId: { in: userIds } },
    });
    await prisma.rescueCasePrivateLocation.deleteMany({
      where: { ownerUserId: { in: userIds } },
    });
    await prisma.rescueCase.deleteMany({
      where: { ownerUserId: { in: userIds } },
    });
    await prisma.rescueCaseDraft.deleteMany({
      where: { ownerUserId: { in: userIds } },
    });
    await prisma.user.deleteMany({ where: { id: { in: userIds } } });
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
    repository = new PrismaRescueRepository(prisma);
    await cleanup();
    await prisma.user.createMany({
      data: [
        {
          id: ownerUserId,
          email: `day36-owner-${runId}@pawmate.local`,
          displayName: 'Day 36 Owner',
          emailVerified: true,
        },
        {
          id: commenterUserId,
          email: `day36-commenter-${runId}@pawmate.local`,
          displayName: 'Day 36 Commenter',
          emailVerified: true,
        },
        {
          id: concurrentUserId,
          email: `day36-concurrent-${runId}@pawmate.local`,
          displayName: 'Day 36 Concurrent Owner',
          emailVerified: true,
        },
      ],
    });
  });

  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  it('proves idempotent and atomic Rescue write paths with durable outbox effects', async () => {
    const createNow = new Date('2026-07-21T01:00:00.000Z');
    const createIdempotency = {
      userId: ownerUserId,
      method: 'POST' as const,
      normalizedPath: '/api/rescue/drafts',
      keyHash: '1'.repeat(64),
      requestHash: 'a'.repeat(64),
      now: createNow,
    };
    const createInput = {
      ownerUserId,
      source: 'rescue_home' as const,
      now: createNow,
      idempotency: createIdempotency,
    };

    const createdDraft = await repository.createDraft(createInput);
    const replayedDraft = await repository.createDraft(createInput);

    expect(replayedDraft).toEqual(createdDraft);
    await expect(
      prisma.rescueCaseDraft.count({ where: { ownerUserId } }),
    ).resolves.toBe(1);
    await expect(
      prisma.idempotencyRecord.count({
        where: {
          userId: ownerUserId,
          method: 'POST',
          normalizedPath: '/api/rescue/drafts',
          keyHash: createIdempotency.keyHash,
        },
      }),
    ).resolves.toBe(1);

    await expect(
      repository.createDraft({
        ...createInput,
        source: 'deep_link',
        idempotency: {
          ...createIdempotency,
          requestHash: 'b'.repeat(64),
        },
      }),
    ).rejects.toMatchObject<Partial<RescuePersistenceDomainError>>({
      failure: 'idempotency_conflict',
    });
    await expect(
      prisma.rescueCaseDraft.count({ where: { ownerUserId } }),
    ).resolves.toBe(1);

    const mediaA = await repository.registerVerifiedMedia({
      ownerUserId,
      purpose: 'rescue_case',
      mimeType: 'image/webp',
      sizeBytes: 4_096,
      sha256: '1'.repeat(64),
      storageKey: `day36/${runId}/a.webp`,
      publicUrl: `https://example.invalid/day36/${runId}/a.webp`,
      width: 800,
      height: 600,
      now: new Date('2026-07-21T01:01:00.000Z'),
    });
    const mediaB = await repository.registerVerifiedMedia({
      ownerUserId,
      purpose: 'rescue_case',
      mimeType: 'image/webp',
      sizeBytes: 4_097,
      sha256: '2'.repeat(64),
      storageKey: `day36/${runId}/b.webp`,
      publicUrl: `https://example.invalid/day36/${runId}/b.webp`,
      width: 800,
      height: 600,
      now: new Date('2026-07-21T01:01:01.000Z'),
    });
    const mediaC = await repository.registerVerifiedMedia({
      ownerUserId,
      purpose: 'rescue_case',
      mimeType: 'image/webp',
      sizeBytes: 4_098,
      sha256: '3'.repeat(64),
      storageKey: `day36/${runId}/c.webp`,
      publicUrl: `https://example.invalid/day36/${runId}/c.webp`,
      width: 800,
      height: 600,
      now: new Date('2026-07-21T01:01:02.000Z'),
    });

    const populatedDraft = await repository.updateDraft({
      ownerUserId,
      draftId: createdDraft.draftId,
      expectedVersion: 1,
      patch: {
        petName: 'Milo',
        species: 'dog',
        breedOrColor: 'Poodle nâu nhạt',
        lostAt: '2026-07-20T14:30:00.000Z',
        location: {
          latitude: 10.776889,
          longitude: 106.700806,
          formattedAddress: '12 Nguyễn Huệ, Phường Sài Gòn, TP.HCM',
          areaLabel: 'Khu vực trung tâm Quận 1, TP.HCM',
          privacyRadiusMeters: 500,
        },
        identifyingFeatures: 'Đeo vòng cổ xanh, có đốm trắng ở chân trước.',
        behaviorHint: 'Phản ứng khi được gọi Milo.',
        contactPreference: 'in_app',
        mediaIds: [mediaA.mediaId, mediaB.mediaId],
      },
      now: new Date('2026-07-21T01:02:00.000Z'),
    });
    expect(populatedDraft.version).toBe(2);
    expect(populatedDraft.media.map(({ mediaId }) => mediaId)).toEqual([
      mediaA.mediaId,
      mediaB.mediaId,
    ]);

    const reorderedDraft = await repository.updateDraft({
      ownerUserId,
      draftId: createdDraft.draftId,
      expectedVersion: 2,
      patch: { mediaIds: [mediaB.mediaId, mediaC.mediaId] },
      now: new Date('2026-07-21T01:03:00.000Z'),
    });
    expect(reorderedDraft.version).toBe(3);
    expect(
      reorderedDraft.media.map(({ mediaId, position }) => [mediaId, position]),
    ).toEqual([
      [mediaB.mediaId, 0],
      [mediaC.mediaId, 1],
    ]);
    await expect(
      prisma.mediaAsset.findUniqueOrThrow({ where: { id: mediaA.mediaId } }),
    ).resolves.toMatchObject({
      status: 'verified',
      draftId: null,
      caseId: null,
      commentId: null,
      position: null,
    });

    await expect(
      repository.updateDraft({
        ownerUserId,
        draftId: createdDraft.draftId,
        expectedVersion: 3,
        patch: {
          petName: 'This write must roll back',
          mediaIds: [mediaB.mediaId, randomUUID()],
        },
        now: new Date('2026-07-21T01:04:00.000Z'),
      }),
    ).rejects.toMatchObject<Partial<RescuePersistenceDomainError>>({
      failure: 'invalid_media',
    });
    const draftAfterRejectedUpdate = await repository.findOwnedDraft(
      ownerUserId,
      createdDraft.draftId,
    );
    expect(draftAfterRejectedUpdate).toMatchObject({
      petName: 'Milo',
      version: 3,
    });
    expect(
      draftAfterRejectedUpdate?.media.map(({ mediaId, position }) => [
        mediaId,
        position,
      ]),
    ).toEqual([
      [mediaB.mediaId, 0],
      [mediaC.mediaId, 1],
    ]);

    const publishNow = new Date('2026-07-21T01:05:00.000Z');
    const publishIdempotency = {
      userId: ownerUserId,
      method: 'POST' as const,
      normalizedPath: `/api/rescue/drafts/${createdDraft.draftId}/publish`,
      keyHash: '2'.repeat(64),
      requestHash: 'b'.repeat(64),
      now: publishNow,
    };
    const publishInput = {
      ownerUserId,
      draftId: createdDraft.draftId,
      expectedVersion: 3,
      now: publishNow,
      idempotency: publishIdempotency,
    };
    const publishedCase = await repository.publishDraft(publishInput);
    const replayedCase = await repository.publishDraft(publishInput);

    expect(replayedCase).toEqual(publishedCase);
    expect(publishedCase.media.map(({ mediaId }) => mediaId)).toEqual([
      mediaB.mediaId,
      mediaC.mediaId,
    ]);
    await expect(
      prisma.rescueCase.count({
        where: { sourceDraftId: createdDraft.draftId },
      }),
    ).resolves.toBe(1);
    const privateLocation =
      await prisma.rescueCasePrivateLocation.findUniqueOrThrow({
        where: { caseId: publishedCase.caseId },
      });
    expect(privateLocation.latitude.toString()).toBe('10.776889');
    expect(privateLocation.longitude.toString()).toBe('106.700806');
    await expect(
      prisma.rescueStatusEvent.count({
        where: { caseId: publishedCase.caseId },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.outboxEvent.count({
        where: {
          eventType: 'rescue.case_published.v1',
          aggregateId: publishedCase.caseId,
        },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.idempotencyRecord.count({
        where: {
          userId: ownerUserId,
          normalizedPath: publishIdempotency.normalizedPath,
          keyHash: publishIdempotency.keyHash,
        },
      }),
    ).resolves.toBe(1);

    const commentNow = new Date('2026-07-21T01:06:00.000Z');
    const commentIdempotency = {
      userId: commenterUserId,
      method: 'POST' as const,
      normalizedPath: `/api/rescue/cases/${publishedCase.caseId}/comments`,
      keyHash: '3'.repeat(64),
      requestHash: 'c'.repeat(64),
      now: commentNow,
    };
    const commentInput = {
      authorUserId: commenterUserId,
      caseId: publishedCase.caseId,
      body: '  Mình sẽ để ý khu vực này.  ',
      now: commentNow,
      idempotency: commentIdempotency,
    };
    const createdComment = await repository.createComment(commentInput);
    const replayedComment = await repository.createComment(commentInput);

    expect(replayedComment).toEqual(createdComment);
    expect(createdComment.body).toBe('Mình sẽ để ý khu vực này.');
    await expect(
      prisma.rescueComment.count({
        where: { caseId: publishedCase.caseId },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.rescueCase.findUniqueOrThrow({
        where: { id: publishedCase.caseId },
        select: { commentCount: true },
      }),
    ).resolves.toEqual({ commentCount: 1 });
    await expect(
      prisma.outboxEvent.count({
        where: {
          eventType: 'rescue.comment_created.v1',
          aggregateId: publishedCase.caseId,
        },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.idempotencyRecord.count({
        where: {
          userId: commenterUserId,
          normalizedPath: commentIdempotency.normalizedPath,
          keyHash: commentIdempotency.keyHash,
        },
      }),
    ).resolves.toBe(1);

    const orderedIds = Array.from({ length: 5 }, () => randomUUID()).sort();
    const [visibleAId, visibleBId, visibleCId, hiddenId, deletedId] =
      orderedIds;
    const tiedCreatedAt = new Date('2026-07-21T01:07:00.000Z');
    await prisma.rescueComment.createMany({
      data: [
        {
          id: hiddenId,
          caseId: publishedCase.caseId,
          authorUserId: commenterUserId,
          body: 'Hidden comment',
          moderationState: 'hidden',
          createdAt: new Date('2026-07-21T01:05:30.000Z'),
          updatedAt: new Date('2026-07-21T01:05:30.000Z'),
        },
        {
          id: deletedId,
          caseId: publishedCase.caseId,
          authorUserId: commenterUserId,
          body: 'Deleted comment',
          moderationState: 'visible',
          createdAt: new Date('2026-07-21T01:06:30.000Z'),
          updatedAt: new Date('2026-07-21T01:06:30.000Z'),
          deletedAt: new Date('2026-07-21T01:06:31.000Z'),
        },
        {
          id: visibleAId,
          caseId: publishedCase.caseId,
          authorUserId: commenterUserId,
          body: 'Visible tied A',
          moderationState: 'visible',
          createdAt: tiedCreatedAt,
          updatedAt: tiedCreatedAt,
        },
        {
          id: visibleBId,
          caseId: publishedCase.caseId,
          authorUserId: commenterUserId,
          body: 'Visible tied B',
          moderationState: 'visible',
          createdAt: tiedCreatedAt,
          updatedAt: tiedCreatedAt,
        },
        {
          id: visibleCId,
          caseId: publishedCase.caseId,
          authorUserId: commenterUserId,
          body: 'Visible C',
          moderationState: 'visible',
          createdAt: new Date('2026-07-21T01:08:00.000Z'),
          updatedAt: new Date('2026-07-21T01:08:00.000Z'),
        },
      ],
    });

    const firstDiscussionPage = await repository.listComments({
      caseId: publishedCase.caseId,
      limit: 2,
    });
    expect(firstDiscussionPage.items.map(({ commentId }) => commentId)).toEqual(
      [createdComment.commentId, visibleAId],
    );
    expect(firstDiscussionPage.nextCursor).toEqual({
      createdAt: tiedCreatedAt.toISOString(),
      commentId: visibleAId,
    });
    const secondDiscussionPage = await repository.listComments({
      caseId: publishedCase.caseId,
      cursor: firstDiscussionPage.nextCursor,
      limit: 2,
    });
    expect(
      secondDiscussionPage.items.map(({ commentId }) => commentId),
    ).toEqual([visibleBId, visibleCId]);
    expect(secondDiscussionPage.nextCursor).toBeUndefined();
    expect(
      [...firstDiscussionPage.items, ...secondDiscussionPage.items].map(
        ({ commentId }) => commentId,
      ),
    ).not.toEqual(expect.arrayContaining([hiddenId, deletedId]));

    const statusNow = new Date('2026-07-21T01:09:00.000Z');
    const statusIdempotency = {
      userId: ownerUserId,
      method: 'PATCH' as const,
      normalizedPath: `/api/rescue/cases/${publishedCase.caseId}/status`,
      keyHash: '4'.repeat(64),
      requestHash: 'd'.repeat(64),
      now: statusNow,
    };
    const statusInput = {
      ownerUserId,
      caseId: publishedCase.caseId,
      expectedVersion: 1,
      status: 'found' as const,
      now: statusNow,
      idempotency: statusIdempotency,
    };
    const foundCase = await repository.updateCaseStatus(statusInput);
    const replayedFoundCase = await repository.updateCaseStatus(statusInput);

    expect(replayedFoundCase).toEqual(foundCase);
    expect(foundCase).toMatchObject({ status: 'found', version: 2 });
    await expect(
      prisma.rescueStatusEvent.count({
        where: { caseId: publishedCase.caseId },
      }),
    ).resolves.toBe(2);
    await expect(
      prisma.outboxEvent.count({
        where: {
          eventType: 'rescue.case_status_changed.v1',
          aggregateId: publishedCase.caseId,
        },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.idempotencyRecord.count({
        where: {
          userId: ownerUserId,
          normalizedPath: statusIdempotency.normalizedPath,
          keyHash: statusIdempotency.keyHash,
        },
      }),
    ).resolves.toBe(1);

    const concurrentNow = new Date('2026-07-21T01:10:00.000Z');
    const concurrentCreateInput = {
      ownerUserId: concurrentUserId,
      source: 'deep_link' as const,
      now: concurrentNow,
      idempotency: {
        userId: concurrentUserId,
        method: 'POST' as const,
        normalizedPath: '/api/rescue/drafts',
        keyHash: '5'.repeat(64),
        requestHash: 'e'.repeat(64),
        now: concurrentNow,
      },
    };
    const [concurrentDraftA, concurrentDraftB] = await Promise.all([
      repository.createDraft(concurrentCreateInput),
      repository.createDraft(concurrentCreateInput),
    ]);

    expect(concurrentDraftA).toEqual(concurrentDraftB);
    await expect(
      prisma.rescueCaseDraft.count({
        where: { ownerUserId: concurrentUserId },
      }),
    ).resolves.toBe(1);
    await expect(
      prisma.idempotencyRecord.count({
        where: {
          userId: concurrentUserId,
          normalizedPath: '/api/rescue/drafts',
          keyHash: concurrentCreateInput.idempotency.keyHash,
        },
      }),
    ).resolves.toBe(1);
  });

  it('persists the media request, verified terminal state and rejected terminal state', async () => {
    const mediaId = randomUUID();
    const requestNow = new Date('2026-07-21T02:00:00.000Z');
    const requestInput = {
      mediaId,
      ownerUserId,
      purpose: 'rescue_case' as const,
      mimeType: 'image/jpeg' as const,
      sizeBytes: 1234,
      sha256: '6'.repeat(64),
      stagingStorageKey: `${ownerUserId}/${mediaId}/original.jpg`,
      uploadExpiresAt: new Date('2026-07-21T03:00:00.000Z'),
      uploadUrl: 'https://storage.example.test/signed-upload',
      uploadHeaders: { 'content-type': 'image/jpeg' },
      idempotency: {
        userId: ownerUserId,
        method: 'POST' as const,
        normalizedPath: '/media/uploads',
        keyHash: '6'.repeat(64),
        requestHash: 'f'.repeat(64),
        now: requestNow,
      },
      now: requestNow,
    };

    const request = await repository.createMediaUploadRequest(requestInput);
    const requestReplay =
      await repository.createMediaUploadRequest(requestInput);
    expect(requestReplay).toEqual(request);
    expect(request.media).toMatchObject({
      mediaId,
      status: 'requested',
      verificationVersion: 0,
    });

    const completeNow = new Date('2026-07-21T02:01:00.000Z');
    const completeInput = {
      ownerUserId,
      mediaId,
      detectedMimeType: 'image/jpeg' as const,
      detectedSizeBytes: 1234,
      sanitizedStorageKey: `rescue_case/${mediaId}/${'7'.repeat(64)}/public.jpg`,
      sanitizedSha256: '8'.repeat(64),
      publicUrl: `https://cdn.example.test/${mediaId}/public.jpg`,
      idempotency: {
        userId: ownerUserId,
        method: 'POST' as const,
        normalizedPath: `/media/uploads/${mediaId}/complete`,
        keyHash: '7'.repeat(64),
        requestHash: '8'.repeat(64),
        now: completeNow,
      },
      now: completeNow,
    };
    const completed = await repository.completeMediaUpload(completeInput);
    const completedReplay = await repository.completeMediaUpload(completeInput);
    expect(completedReplay).toEqual(completed);
    expect(completed).toMatchObject({
      mediaId,
      status: 'verified',
      verificationVersion: 1,
      verifiedAt: completeNow.toISOString(),
      storageKey: completeInput.sanitizedStorageKey,
    });
    await expect(
      prisma.mediaUploadSession.findUniqueOrThrow({ where: { mediaId } }),
    ).resolves.toMatchObject({
      detectedMimeType: 'image/jpeg',
      detectedSizeBytes: BigInt(1234),
      sanitizedStorageKey: completeInput.sanitizedStorageKey,
      verificationStartedAt: completeNow,
      leaseUntil: null,
      completedAt: completeNow,
      rejectedAt: null,
    });

    await expect(
      repository.completeMediaUpload({
        ...completeInput,
        idempotency: {
          ...completeInput.idempotency,
          keyHash: '9'.repeat(64),
        },
      }),
    ).rejects.toMatchObject<Partial<RescuePersistenceDomainError>>({
      failure: 'invalid_media',
    });

    const rejectedMediaId = randomUUID();
    await repository.createMediaUploadRequest({
      ...requestInput,
      mediaId: rejectedMediaId,
      stagingStorageKey: `${ownerUserId}/${rejectedMediaId}/original.jpg`,
      idempotency: {
        ...requestInput.idempotency,
        keyHash: 'a'.repeat(64),
        requestHash: 'a'.repeat(64),
      },
    });
    const rejectedAt = new Date('2026-07-21T02:02:00.000Z');
    await repository.rejectMediaUpload({
      ownerUserId,
      mediaId: rejectedMediaId,
      rejectionCode: 'MEDIA_005',
      now: rejectedAt,
    });
    await expect(
      prisma.mediaUploadSession.findUniqueOrThrow({
        where: { mediaId: rejectedMediaId },
      }),
    ).resolves.toMatchObject({
      leaseUntil: null,
      completedAt: null,
      rejectedAt,
      rejectionCode: 'MEDIA_005',
    });
  });
});

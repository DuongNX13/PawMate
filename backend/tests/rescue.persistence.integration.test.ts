import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import { PrismaRescueRepository } from '../src/features/rescue/persistence/prisma-rescue-repository';
import { RescuePersistenceConflictError } from '../src/features/rescue/persistence/rescue-repository';
import { projectRescueCoordinateCell } from '../src/services/rescue/rescue-location-privacy';

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

if (
  enabled &&
  !isLocalDatabase &&
  process.env.PAWMATE_ALLOW_REMOTE_RESCUE_TEST !== '1'
) {
  throw new Error(
    'Remote Rescue integration tests are disabled. Use the local PostgreSQL database.',
  );
}

describeDatabase('Rescue PostgreSQL persistence integration', () => {
  jest.setTimeout(30_000);

  const ownerUserId = randomUUID();
  const intruderUserId = randomUUID();
  const runId = randomUUID();
  const ownerEmail = `day34-owner-${runId}@pawmate.local`;
  const intruderEmail = `day34-intruder-${runId}@pawmate.local`;
  let prisma: PrismaClient;
  let repository: PrismaRescueRepository;

  const cleanup = async () => {
    await prisma.rescueStatusEvent.deleteMany({
      where: { changedByUserId: { in: [ownerUserId, intruderUserId] } },
    });
    await prisma.mediaAsset.deleteMany({
      where: { ownerUserId: { in: [ownerUserId, intruderUserId] } },
    });
    await prisma.rescueComment.deleteMany({
      where: { authorUserId: { in: [ownerUserId, intruderUserId] } },
    });
    await prisma.rescueCasePrivateLocation.deleteMany({
      where: { ownerUserId: { in: [ownerUserId, intruderUserId] } },
    });
    await prisma.rescueCase.deleteMany({
      where: { ownerUserId: { in: [ownerUserId, intruderUserId] } },
    });
    await prisma.rescueCaseDraft.deleteMany({
      where: { ownerUserId: { in: [ownerUserId, intruderUserId] } },
    });
    await prisma.user.deleteMany({
      where: { id: { in: [ownerUserId, intruderUserId] } },
    });
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
    repository = new PrismaRescueRepository(prisma);
    await cleanup();
    await prisma.user.createMany({
      data: [
        {
          id: ownerUserId,
          email: ownerEmail,
          displayName: 'Day 34 Owner',
          emailVerified: true,
        },
        {
          id: intruderUserId,
          email: intruderEmail,
          displayName: 'Day 34 Intruder',
          emailVerified: true,
        },
      ],
    });
  });

  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  it('persists draft, verified media, private location, public case, comment and status event atomically', async () => {
    const draft = await repository.createDraft({
      ownerUserId,
      source: 'rescue_home',
      now: new Date('2026-07-17T07:00:00.000Z'),
    });
    const updatedDraft = await repository.updateDraft({
      ownerUserId,
      draftId: draft.draftId,
      expectedVersion: 1,
      patch: {
        petName: 'Milo',
        species: 'dog',
        breedOrColor: 'Poodle nâu nhạt',
        lostAt: '2026-07-16T14:30:00.000Z',
        location: {
          latitude: 10.776889,
          longitude: 106.700806,
          formattedAddress: '12 Nguyễn Huệ, Phường Sài Gòn, TP.HCM',
          // Deliberately stale/malicious draft label: publish must recompute
          // from the private formatted address instead of trusting this value.
          areaLabel: '12/3 Đường Lê Lợi, 10.776889, 106.700806',
          privacyRadiusMeters: 500,
        },
        identifyingFeatures: 'Đeo vòng cổ xanh, có đốm trắng ở chân trước.',
        behaviorHint: 'Phản ứng khi được gọi Milo.',
        contactPreference: 'in_app',
      },
      now: new Date('2026-07-17T07:01:00.000Z'),
    });
    expect(updatedDraft.version).toBe(2);

    const media = await repository.registerVerifiedMedia({
      ownerUserId,
      purpose: 'rescue_case',
      mimeType: 'image/webp',
      sizeBytes: 4096,
      sha256: 'b'.repeat(64),
      storageKey: `day34/integration/${runId}/milo.webp`,
      publicUrl: 'https://example.invalid/day34/milo.webp',
      width: 800,
      height: 600,
      now: new Date('2026-07-17T07:02:00.000Z'),
    });
    await repository.attachVerifiedMediaToDraft({
      ownerUserId,
      draftId: draft.draftId,
      mediaId: media.mediaId,
      position: 0,
      now: new Date('2026-07-17T07:03:00.000Z'),
    });

    const rescueCase = await repository.publishDraft({
      ownerUserId,
      draftId: draft.draftId,
      expectedVersion: 2,
      now: new Date('2026-07-17T07:04:00.000Z'),
    });
    const publicCoordinate = projectRescueCoordinateCell({
      latitude: 10.776889,
      longitude: 106.700806,
    });
    expect(rescueCase).toMatchObject({
      ownerUserId,
      petName: 'Milo',
      status: 'missing',
      version: 1,
      approximateLatitude: publicCoordinate.approximateLatitude,
      approximateLongitude: publicCoordinate.approximateLongitude,
      privacyRadiusMeters: 500,
      areaLabel: 'Phường Sài Gòn, TP.HCM',
      commentCount: 0,
      privateLocation: {
        latitude: 10.776889,
        longitude: 106.700806,
      },
    });
    expect(rescueCase.areaLabel).not.toMatch(
      /12\/3|Đường Lê Lợi|10\.776889|106\.700806/u,
    );
    expect(rescueCase.approximateLatitude).not.toBe(
      rescueCase.privateLocation?.latitude,
    );
    expect(rescueCase.media).toHaveLength(1);
    expect(rescueCase.media[0]).toMatchObject({
      caseId: rescueCase.caseId,
      draftId: undefined,
      status: 'attached',
    });
    await expect(
      repository.findOwnedCase(intruderUserId, rescueCase.caseId),
    ).resolves.toBeUndefined();

    const comment = await repository.createComment({
      authorUserId: ownerUserId,
      caseId: rescueCase.caseId,
      body: '  Mình sẽ để ý khu vực này.  ',
      now: new Date('2026-07-17T07:05:00.000Z'),
    });
    expect(comment.body).toBe('Mình sẽ để ý khu vực này.');
    expect(comment.media).toEqual([]);

    const foundCase = await repository.updateCaseStatus({
      ownerUserId,
      caseId: rescueCase.caseId,
      expectedVersion: 1,
      status: 'found',
      now: new Date('2026-07-17T07:06:00.000Z'),
    });
    expect(foundCase).toMatchObject({
      status: 'found',
      version: 2,
      commentCount: 1,
      foundAt: '2026-07-17T07:06:00.000Z',
    });
    await expect(
      repository.createComment({
        authorUserId: ownerUserId,
        caseId: rescueCase.caseId,
        body: 'Case đã đóng nên bình luận này phải bị chặn.',
      }),
    ).rejects.toBeInstanceOf(RescuePersistenceConflictError);

    await expect(
      prisma.rescueStatusEvent.count({
        where: { caseId: rescueCase.caseId },
      }),
    ).resolves.toBe(2);
    const publicCaseColumns = await prisma.$queryRaw<
      Array<{ column_name: string }>
    >`SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'rescue_cases'`;
    expect(publicCaseColumns.map((item) => item.column_name)).not.toEqual(
      expect.arrayContaining([
        'exact_latitude',
        'exact_longitude',
        'formatted_address',
        'phone',
      ]),
    );
  });
});

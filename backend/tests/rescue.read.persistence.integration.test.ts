import { randomUUID } from 'node:crypto';

import { $Enums, Prisma, PrismaClient } from '@prisma/client';

import { PrismaRescueRepository } from '../src/features/rescue/persistence/prisma-rescue-repository';
import { type RescueCaseReadCursor } from '../src/features/rescue/persistence/rescue-repository';

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

describeDatabase('Rescue public-read PostgreSQL integration', () => {
  jest.setTimeout(30_000);

  const ownerUserId = randomUUID();
  const runId = randomUUID();
  const ownerEmail = `day35-read-${runId}@pawmate.local`;
  const caseIds = {
    dogRecent: '',
    catFound: '',
    birdOther: '',
    rabbitOther: '',
    dogFar: '',
    deletedDog: '',
  };
  const mediaIds = {
    publicFirst: '',
    publicSecond: '',
    unverified: '',
    missingUrl: '',
    deleted: '',
  };
  let prisma: PrismaClient;
  let repository: PrismaRescueRepository;

  const cleanup = async () => {
    await prisma.mediaAsset.deleteMany({ where: { ownerUserId } });
    await prisma.rescueCasePrivateLocation.deleteMany({
      where: { ownerUserId },
    });
    await prisma.rescueCase.deleteMany({ where: { ownerUserId } });
    await prisma.rescueCaseDraft.deleteMany({ where: { ownerUserId } });
    await prisma.user.deleteMany({ where: { id: ownerUserId } });
  };

  const createCase = async (input: {
    petName: string;
    species: $Enums.PetSpecies;
    status?: $Enums.RescueCaseStatus;
    lostAt: Date;
    latitude: number;
    longitude: number;
    deletedAt?: Date;
  }) => {
    const draft = await prisma.rescueCaseDraft.create({
      data: {
        ownerUserId,
        source: 'rescue_home',
        petName: input.petName,
        species: input.species,
        breedOrColor: `${input.petName} test coat`,
        lostAt: input.lostAt,
        exactLatitude: new Prisma.Decimal(input.latitude.toFixed(6)),
        exactLongitude: new Prisma.Decimal(input.longitude.toFixed(6)),
        formattedAddress: `Private address for ${input.petName}`,
        areaLabel: 'Khu vực kiểm thử Day 35, TP.HCM',
        privacyRadiusMeters: 500,
        identifyingFeatures: `Dấu hiệu nhận biết ${input.petName}`,
        behaviorHint: `Hành vi ${input.petName}`,
        contactPreference: 'in_app',
        publishedAt: new Date('2026-07-21T02:00:00.000Z'),
      },
    });
    const rescueCase = await prisma.rescueCase.create({
      data: {
        sourceDraftId: draft.id,
        ownerUserId,
        petName: input.petName,
        species: input.species,
        breedOrColor: `${input.petName} test coat`,
        ageLabel: '2 tuổi',
        lostAt: input.lostAt,
        areaLabel: 'Khu vực kiểm thử Day 35, TP.HCM',
        approximateLatitude: new Prisma.Decimal(input.latitude.toFixed(3)),
        approximateLongitude: new Prisma.Decimal(input.longitude.toFixed(3)),
        privacyRadiusMeters: 500,
        identifyingFeatures: `Dấu hiệu nhận biết ${input.petName}`,
        behaviorHint: `Hành vi ${input.petName}`,
        contactPreference: 'in_app',
        status: input.status ?? 'missing',
        version: 1,
        commentCount: 0,
        foundAt:
          input.status === 'found'
            ? new Date('2026-07-21T02:30:00.000Z')
            : undefined,
        deletedAt: input.deletedAt,
      },
    });
    return rescueCase.id;
  };

  const readAllPages = async (input: {
    sort: 'recent' | 'distance';
    latitude?: number;
    longitude?: number;
    radiusMeters?: number;
  }) => {
    const caseIdResults: string[] = [];
    const distanceResults: number[] = [];
    const visitPage = async (
      cursor: RescueCaseReadCursor | undefined,
      pageNumber: number,
    ): Promise<RescueCaseReadCursor | undefined> => {
      if (pageNumber >= 10) return cursor;
      const page = await repository.listPublicCases({
        ...input,
        cursor,
        limit: 2,
      });
      caseIdResults.push(...page.items.map((item) => item.rescueCase.caseId));
      distanceResults.push(
        ...page.items.flatMap((item) =>
          item.distanceMeters === undefined ? [] : [item.distanceMeters],
        ),
      );
      return page.nextCursor
        ? visitPage(page.nextCursor, pageNumber + 1)
        : undefined;
    };
    const cursor = await visitPage(undefined, 0);

    return { caseIdResults, distanceResults, cursor };
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
    repository = new PrismaRescueRepository(prisma);
    await cleanup();
    await prisma.user.create({
      data: {
        id: ownerUserId,
        email: ownerEmail,
        displayName: 'Day 35 Read Owner',
        emailVerified: true,
      },
    });

    caseIds.dogRecent = await createCase({
      petName: 'Dog Recent',
      species: 'dog',
      lostAt: new Date('2026-07-20T10:00:00.000Z'),
      latitude: 10.777,
      longitude: 106.701,
    });
    caseIds.catFound = await createCase({
      petName: 'Cat Found',
      species: 'cat',
      status: 'found',
      lostAt: new Date('2026-07-19T10:00:00.000Z'),
      latitude: 10.789,
      longitude: 106.701,
    });
    caseIds.birdOther = await createCase({
      petName: 'Bird Other',
      species: 'bird',
      lostAt: new Date('2026-07-18T10:00:00.000Z'),
      latitude: 10.778,
      longitude: 106.701,
    });
    caseIds.rabbitOther = await createCase({
      petName: 'Rabbit Other',
      species: 'rabbit',
      lostAt: new Date('2026-07-17T10:00:00.000Z'),
      latitude: 10.78,
      longitude: 106.701,
    });
    caseIds.dogFar = await createCase({
      petName: 'Dog Far',
      species: 'dog',
      lostAt: new Date('2026-07-16T10:00:00.000Z'),
      latitude: 10.88,
      longitude: 106.78,
    });
    caseIds.deletedDog = await createCase({
      petName: 'Deleted Dog',
      species: 'dog',
      lostAt: new Date('2026-07-21T10:00:00.000Z'),
      latitude: 10.777,
      longitude: 106.701,
      deletedAt: new Date('2026-07-21T11:00:00.000Z'),
    });

    await prisma.rescueCasePrivateLocation.create({
      data: {
        caseId: caseIds.dogRecent,
        ownerUserId,
        latitude: new Prisma.Decimal('10.776889'),
        longitude: new Prisma.Decimal('106.700806'),
        formattedAddress: '12 Private Street, exact location',
      },
    });

    const media = await prisma.mediaAsset.createManyAndReturn({
      data: [
        {
          ownerUserId,
          purpose: 'rescue_case',
          mimeType: 'image/webp',
          sizeBytes: 4_096n,
          sha256: 'a'.repeat(64),
          status: 'attached',
          storageKey: `day35/${runId}/public-first.webp`,
          publicUrl: 'https://example.invalid/day35/public-first.webp',
          caseId: caseIds.dogRecent,
          position: 0,
          verifiedAt: new Date('2026-07-21T03:00:00.000Z'),
        },
        {
          ownerUserId,
          purpose: 'rescue_case',
          mimeType: 'image/webp',
          sizeBytes: 4_096n,
          sha256: 'b'.repeat(64),
          status: 'attached',
          storageKey: `day35/${runId}/public-second.webp`,
          publicUrl: 'https://example.invalid/day35/public-second.webp',
          caseId: caseIds.dogRecent,
          position: 2,
          verifiedAt: new Date('2026-07-21T03:01:00.000Z'),
        },
        {
          ownerUserId,
          purpose: 'rescue_case',
          mimeType: 'image/webp',
          sizeBytes: 4_096n,
          sha256: 'c'.repeat(64),
          status: 'verified',
          storageKey: `day35/${runId}/unverified.webp`,
          publicUrl: 'https://example.invalid/day35/unverified.webp',
          caseId: caseIds.dogRecent,
          verifiedAt: new Date('2026-07-21T03:02:00.000Z'),
        },
        {
          ownerUserId,
          purpose: 'rescue_case',
          mimeType: 'image/webp',
          sizeBytes: 4_096n,
          sha256: 'd'.repeat(64),
          status: 'attached',
          storageKey: `day35/${runId}/missing-url.webp`,
          caseId: caseIds.dogRecent,
          position: 1,
          verifiedAt: new Date('2026-07-21T03:03:00.000Z'),
        },
        {
          ownerUserId,
          purpose: 'rescue_case',
          mimeType: 'image/webp',
          sizeBytes: 4_096n,
          sha256: 'e'.repeat(64),
          status: 'attached',
          storageKey: `day35/${runId}/deleted.webp`,
          publicUrl: 'https://example.invalid/day35/deleted.webp',
          caseId: caseIds.dogRecent,
          position: 3,
          verifiedAt: new Date('2026-07-21T03:04:00.000Z'),
          deletedAt: new Date('2026-07-21T04:00:00.000Z'),
        },
      ],
    });
    mediaIds.publicFirst = media[0]?.id ?? '';
    mediaIds.publicSecond = media[1]?.id ?? '';
    mediaIds.unverified = media[2]?.id ?? '';
    mediaIds.missingUrl = media[3]?.id ?? '';
    mediaIds.deleted = media[4]?.id ?? '';
  });

  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  it('filters by status, public species and inclusive lost-date range', async () => {
    const dogs = await repository.listPublicCases({
      status: 'missing',
      species: 'dog',
      lostFrom: new Date('2026-07-19T00:00:00.000Z'),
      lostTo: new Date('2026-07-21T00:00:00.000Z'),
      sort: 'recent',
      limit: 50,
    });
    expect(dogs.items.map((item) => item.rescueCase.caseId)).toEqual([
      caseIds.dogRecent,
    ]);

    const found = await repository.listPublicCases({
      status: 'found',
      sort: 'recent',
      limit: 50,
    });
    expect(found.items.map((item) => item.rescueCase.caseId)).toEqual([
      caseIds.catFound,
    ]);

    const otherSpecies = await repository.listPublicCases({
      status: 'missing',
      species: 'other',
      sort: 'recent',
      limit: 50,
    });
    expect(otherSpecies.items.map((item) => item.rescueCase.caseId)).toEqual([
      caseIds.birdOther,
      caseIds.rabbitOther,
    ]);
  });

  it('applies the PostGIS radius and orders nearby cases by rounded distance', async () => {
    const nearby = await repository.listPublicCases({
      latitude: 10.777,
      longitude: 106.701,
      radiusMeters: 500,
      sort: 'distance',
      limit: 50,
    });

    expect(nearby.items.map((item) => item.rescueCase.caseId)).toEqual([
      caseIds.dogRecent,
      caseIds.birdOther,
      caseIds.rabbitOther,
    ]);
    const distances = nearby.items.map((item) => item.distanceMeters);
    expect(distances.every((distance) => distance !== undefined)).toBe(true);
    expect(distances).toEqual(
      [...distances].sort((left, right) => left! - right!),
    );
    expect(distances.at(-1)).toBeLessThanOrEqual(500);
  });

  it('paginates the recent feed without duplicates or soft-deleted cases', async () => {
    const result = await readAllPages({ sort: 'recent' });

    expect(result.caseIdResults).toEqual([
      caseIds.dogRecent,
      caseIds.catFound,
      caseIds.birdOther,
      caseIds.rabbitOther,
      caseIds.dogFar,
    ]);
    expect(new Set(result.caseIdResults).size).toBe(
      result.caseIdResults.length,
    );
    expect(result.caseIdResults).not.toContain(caseIds.deletedDog);
    expect(result.cursor).toBeUndefined();
  });

  it('paginates the distance feed without duplicates and preserves distance order', async () => {
    const result = await readAllPages({
      sort: 'distance',
      latitude: 10.777,
      longitude: 106.701,
      radiusMeters: 20_000,
    });

    expect(new Set(result.caseIdResults)).toEqual(
      new Set([
        caseIds.dogRecent,
        caseIds.catFound,
        caseIds.birdOther,
        caseIds.rabbitOther,
        caseIds.dogFar,
      ]),
    );
    expect(new Set(result.caseIdResults).size).toBe(
      result.caseIdResults.length,
    );
    expect(result.distanceResults).toEqual(
      [...result.distanceResults].sort((left, right) => left - right),
    );
    expect(result.cursor).toBeUndefined();
  });

  it('filters detail/list media, hides private location and rejects a deleted case', async () => {
    const detail = await repository.findPublicCase(caseIds.dogRecent);

    expect(detail?.privateLocation).toBeUndefined();
    expect(detail?.media.map((item) => item.mediaId)).toEqual([
      mediaIds.publicFirst,
      mediaIds.publicSecond,
    ]);
    expect(detail?.media.map((item) => item.mediaId)).not.toEqual(
      expect.arrayContaining([
        mediaIds.unverified,
        mediaIds.missingUrl,
        mediaIds.deleted,
      ]),
    );

    const list = await repository.listPublicCases({
      status: 'missing',
      species: 'dog',
      lostFrom: new Date('2026-07-20T00:00:00.000Z'),
      sort: 'recent',
      limit: 10,
    });
    expect(list.items).toHaveLength(1);
    expect(list.items[0]?.rescueCase.media.map((item) => item.mediaId)).toEqual(
      [mediaIds.publicFirst, mediaIds.publicSecond],
    );
    await expect(
      repository.findPublicCase(caseIds.deletedDog),
    ).resolves.toBeUndefined();
  });
});

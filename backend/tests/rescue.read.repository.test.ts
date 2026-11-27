import { Prisma, type PrismaClient } from '@prisma/client';

import { PrismaRescueRepository } from '../src/features/rescue/persistence/prisma-rescue-repository';

const ownerUserId = '35000000-0000-4000-8000-000000000100';
const firstCaseId = '35000000-0000-4000-8000-000000000201';
const secondCaseId = '35000000-0000-4000-8000-000000000202';
const firstDraftId = '35000000-0000-4000-8000-000000000301';
const now = new Date('2026-07-21T03:00:00.000Z');

const makeMediaRow = () => ({
  id: '35000000-0000-4000-8000-000000000401',
  ownerUserId,
  purpose: 'rescue_case' as const,
  mimeType: 'image/webp',
  sizeBytes: 4_096n,
  sha256: 'a'.repeat(64),
  status: 'attached' as const,
  storageKey: 'day35/unit/public.webp',
  publicUrl: 'https://example.invalid/day35/public.webp',
  width: 800,
  height: 600,
  durationSeconds: null,
  draftId: null,
  caseId: firstCaseId,
  commentId: null,
  position: 0,
  verifiedAt: now,
  createdAt: now,
  updatedAt: now,
  deletedAt: null,
});

const makePublicCaseRowBase = () => ({
  id: firstCaseId,
  sourceDraftId: firstDraftId,
  ownerUserId,
  petName: 'Milo',
  species: 'dog' as const,
  breedOrColor: 'Poodle nâu nhạt',
  ageLabel: '2 tuổi',
  lostAt: new Date('2026-07-20T10:00:00.000Z'),
  areaLabel: 'Quận 1, TP.HCM',
  approximateLatitude: new Prisma.Decimal('10.777000'),
  approximateLongitude: new Prisma.Decimal('106.701000'),
  privacyRadiusMeters: 500,
  identifyingFeatures: 'Đeo vòng cổ xanh.',
  behaviorHint: 'Phản ứng khi gọi Milo.',
  contactPreference: 'in_app' as const,
  status: 'missing' as const,
  version: 1,
  commentCount: 2,
  foundAt: null,
  createdAt: now,
  updatedAt: now,
  deletedAt: null,
  media: [makeMediaRow()],
});

const makePublicCaseRow = (
  overrides: Partial<ReturnType<typeof makePublicCaseRowBase>> = {},
) => ({ ...makePublicCaseRowBase(), ...overrides });

const readSql = (queryRaw: jest.Mock) => {
  const query = queryRaw.mock.calls[0]?.[0] as Prisma.Sql;
  return {
    text: query.strings.join(' '),
    values: query.values,
  };
};

const makeListPrisma = (queryRaw: jest.Mock, findMany: jest.Mock) => {
  const transactionClient = {
    $queryRaw: queryRaw,
    rescueCase: { findMany },
  };
  const transaction = jest.fn(
    async (callback: (client: typeof transactionClient) => Promise<unknown>) =>
      callback(transactionClient),
  );
  return {
    prisma: { $transaction: transaction } as unknown as PrismaClient,
    transaction,
  };
};

describe('PrismaRescueRepository public reads', () => {
  it('builds status/species/date/radius filters without selecting private location', async () => {
    const queryRaw = jest.fn().mockResolvedValue([]);
    const findMany = jest.fn();
    const { prisma, transaction } = makeListPrisma(queryRaw, findMany);
    const repository = new PrismaRescueRepository(prisma);
    const lostFrom = new Date('2026-07-01T00:00:00.000Z');
    const lostTo = new Date('2026-07-21T00:00:00.000Z');

    await repository.listPublicCases({
      status: 'missing',
      species: 'other',
      lostFrom,
      lostTo,
      latitude: 10.777,
      longitude: 106.701,
      radiusMeters: 750,
      sort: 'recent',
      cursor: {
        sort: 'recent',
        lostAt: '2026-07-15T10:00:00.000Z',
        caseId: firstCaseId,
      },
      limit: 10,
    });

    const sql = readSql(queryRaw);
    expect(sql.text).toContain('rc.deleted_at IS NULL');
    expect(sql.text).toContain('rc.status =  ::public."RescueCaseStatus"');
    expect(sql.text).toContain('rc.species NOT IN (');
    expect(sql.text).toContain('\'dog\'::public."PetSpecies"');
    expect(sql.text).not.toContain('rc.status::text');
    expect(sql.text).not.toContain('rc.species::text');
    expect(sql.text).toContain('rc.lost_at >=');
    expect(sql.text).toContain('rc.lost_at <=');
    expect(sql.text).toContain('ST_DWithin');
    expect(sql.text).toContain('ST_Distance');
    expect(sql.text).toContain('c."lostAt",');
    expect(sql.text).toContain('c."caseId"');
    expect(sql.text).toContain(') < (');
    expect(sql.text).not.toContain('private_location');
    expect(sql.values).toEqual(
      expect.arrayContaining([
        'missing',
        lostFrom,
        lostTo,
        10.777,
        106.701,
        750,
        firstCaseId,
        11,
      ]),
    );
    expect(findMany).not.toHaveBeenCalled();
    expect(transaction).toHaveBeenCalledWith(expect.any(Function), {
      isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead,
    });
  });

  it('keeps recent ordering, returns an opaque-ready cursor and filters public media', async () => {
    const queryRaw = jest.fn().mockResolvedValue([
      {
        caseId: firstCaseId,
        lostAt: new Date('2026-07-20T10:00:00.000Z'),
        distanceMeters: null,
      },
      {
        caseId: secondCaseId,
        lostAt: new Date('2026-07-19T10:00:00.000Z'),
        distanceMeters: null,
      },
    ]);
    const findMany = jest.fn().mockResolvedValue([makePublicCaseRow()]);
    const { prisma } = makeListPrisma(queryRaw, findMany);
    const repository = new PrismaRescueRepository(prisma);

    const result = await repository.listPublicCases({
      sort: 'recent',
      limit: 1,
    });

    expect(result).toMatchObject({
      limit: 1,
      nextCursor: {
        sort: 'recent',
        lostAt: '2026-07-20T10:00:00.000Z',
        caseId: firstCaseId,
      },
    });
    expect(result.items).toHaveLength(1);
    expect(result.items[0]).toMatchObject({
      rescueCase: {
        caseId: firstCaseId,
        petName: 'Milo',
        media: [{ publicUrl: 'https://example.invalid/day35/public.webp' }],
      },
    });
    expect(result.items[0]?.distanceMeters).toBeUndefined();
    expect(result.items[0]?.rescueCase.privateLocation).toBeUndefined();
    expect(findMany).toHaveBeenCalledWith({
      where: { id: { in: [firstCaseId] }, deletedAt: null },
      include: {
        media: {
          where: {
            status: 'attached',
            deletedAt: null,
            publicUrl: { not: null },
          },
          orderBy: { position: 'asc' },
        },
      },
    });
  });

  it('normalizes distance values and advances the distance cursor', async () => {
    const queryRaw = jest.fn().mockResolvedValue([
      {
        caseId: firstCaseId,
        lostAt: new Date('2026-07-20T10:00:00.000Z'),
        distanceMeters: '42',
      },
      {
        caseId: secondCaseId,
        lostAt: new Date('2026-07-19T10:00:00.000Z'),
        distanceMeters: 90,
      },
    ]);
    const findMany = jest.fn().mockResolvedValue([makePublicCaseRow()]);
    const { prisma } = makeListPrisma(queryRaw, findMany);
    const repository = new PrismaRescueRepository(prisma);

    const result = await repository.listPublicCases({
      latitude: 10.777,
      longitude: 106.701,
      radiusMeters: 1_000,
      sort: 'distance',
      limit: 1,
    });

    expect(result.items[0]?.distanceMeters).toBe(42);
    expect(result.nextCursor).toEqual({
      sort: 'distance',
      distanceMeters: 42,
      caseId: firstCaseId,
    });
    expect(readSql(queryRaw).text).toContain(
      'c."distanceMeters" ASC, c."caseId" ASC',
    );
  });

  it('loads public detail with only publishable media and no private-location join', async () => {
    const findFirst = jest.fn().mockResolvedValue(makePublicCaseRow());
    const prisma = {
      rescueCase: { findFirst },
    } as unknown as PrismaClient;
    const repository = new PrismaRescueRepository(prisma);

    const result = await repository.findPublicCase(firstCaseId);

    expect(result).toMatchObject({ caseId: firstCaseId, petName: 'Milo' });
    expect(result?.privateLocation).toBeUndefined();
    expect(findFirst).toHaveBeenCalledWith({
      where: { id: firstCaseId, deletedAt: null },
      include: {
        media: {
          where: {
            status: 'attached',
            deletedAt: null,
            publicUrl: { not: null },
          },
          orderBy: { position: 'asc' },
        },
      },
    });
  });

  it('returns undefined when the public case is absent or soft-deleted', async () => {
    const prisma = {
      rescueCase: { findFirst: jest.fn().mockResolvedValue(null) },
    } as unknown as PrismaClient;
    const repository = new PrismaRescueRepository(prisma);

    await expect(
      repository.findPublicCase(firstCaseId),
    ).resolves.toBeUndefined();
  });
});

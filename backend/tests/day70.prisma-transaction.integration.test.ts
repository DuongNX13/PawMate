import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import { PrismaAdoptionRepository } from '../src/features/adoption/persistence/prisma-adoption-repository';
import { PrismaRescueRepository } from '../src/features/rescue/persistence/prisma-rescue-repository';

const enabled = process.env.PAWMATE_DAY70_DB_INTEGRATION === '1';
const describeDatabase = enabled ? describe : describe.skip;
const databaseUrl =
  process.env.PAWMATE_DAY70_TEST_DATABASE_URL ??
  process.env.DATABASE_URL ??
  'postgresql://pawmate@127.0.0.1:5432/pawmate?schema=public';
const databaseHost = new URL(databaseUrl).hostname.toLowerCase();
const isLocalDatabase = ['localhost', '127.0.0.1', '::1'].includes(
  databaseHost,
);

if (
  enabled &&
  !isLocalDatabase &&
  process.env.PAWMATE_ALLOW_REMOTE_DAY70_TEST !== '1'
) {
  throw new Error(
    'Remote Day 70 integration tests are disabled. Use the local PostgreSQL database.',
  );
}

describeDatabase('Day 70 Prisma cold-transaction regression', () => {
  jest.setTimeout(30_000);

  const runId = randomUUID();
  const shelterId = randomUUID();
  const adopterId = randomUUID();
  const mediaId = randomUUID();
  const listingId = randomUUID();
  const normalizedPath = `/adoption/listings/${listingId}/requests`;
  const fixturePrisma = new PrismaClient({
    datasources: { db: { url: databaseUrl } },
  });

  const cleanup = async () => {
    await fixturePrisma.outboxEvent.deleteMany({
      where: {
        actorUserId: adopterId,
        eventType: 'adoption.request_submitted.v1',
      },
    });
    await fixturePrisma.idempotencyRecord.deleteMany({
      where: { userId: adopterId, normalizedPath },
    });
    await fixturePrisma.adoptionRequest.deleteMany({
      where: { listingId, adopterUserId: adopterId },
    });
    await fixturePrisma.adoptionDecisionRecord.deleteMany({
      where: { listingId, adopterUserId: adopterId },
    });
    await fixturePrisma.adoptionListing.deleteMany({
      where: { id: listingId },
    });
    await fixturePrisma.mediaAsset.deleteMany({ where: { id: mediaId } });
    await fixturePrisma.user.deleteMany({
      where: { id: { in: [shelterId, adopterId] } },
    });
  };

  beforeAll(async () => {
    await cleanup();
    await fixturePrisma.user.createMany({
      data: [
        {
          id: shelterId,
          email: `day70-shelter-${runId}@pawmate.local`,
          displayName: 'Day 70 Test Shelter',
          emailVerified: true,
        },
        {
          id: adopterId,
          email: `day70-adopter-${runId}@pawmate.local`,
          displayName: 'Day 70 Test Adopter',
          emailVerified: true,
        },
      ],
    });
    await fixturePrisma.mediaAsset.create({
      data: {
        id: mediaId,
        ownerUserId: shelterId,
        purpose: 'adoption_listing',
        mimeType: 'image/webp',
        sizeBytes: 4_096n,
        sha256: '7'.repeat(64),
        status: 'verified',
        storageKey: `day70/${runId}/golden.webp`,
        publicUrl: 'https://example.invalid/day70/golden.webp',
        width: 1_200,
        height: 900,
        verifiedAt: new Date('2026-07-31T00:00:00.000Z'),
      },
    });
    await fixturePrisma.adoptionListing.create({
      data: {
        id: listingId,
        shelterId,
        heroMediaId: mediaId,
        petName: 'Golden Day 70',
        species: 'dog',
        breed: 'Golden Retriever',
        ageLabel: '2 tuoi',
        description: 'Synthetic local-only Day 70 regression fixture.',
        traits: ['than thien'],
        healthBadges: ['da tiem phong'],
        verificationBadges: ['fixture da xac minh'],
        status: 'available',
      },
    });
  });

  afterAll(async () => {
    await cleanup();
    await fixturePrisma.$disconnect();
  });

  it('opens a cold Rescue repeatable-read transaction without P2028', async () => {
    const prisma = new PrismaClient({
      datasources: { db: { url: databaseUrl } },
    });
    try {
      const repository = new PrismaRescueRepository(prisma);
      await expect(
        repository.listPublicCases({ sort: 'recent', limit: 5 }),
      ).resolves.toMatchObject({
        items: expect.any(Array),
        limit: 5,
      });
    } finally {
      await prisma.$disconnect();
    }
  });

  it('opens a cold Adoption command transaction and creates its chat thread', async () => {
    const prisma = new PrismaClient({
      datasources: { db: { url: databaseUrl } },
    });
    try {
      const repository = new PrismaAdoptionRepository(prisma);
      await expect(
        repository.createRequest({
          listingId,
          adopterUserId: adopterId,
          livingCondition: 'Can ho co khong gian an toan.',
          petExperience: 'Da cham soc cho truong thanh.',
          carePlan: 'Kham dinh ky va van dong moi ngay.',
          commitmentAccepted: true,
          idempotency: {
            userId: adopterId,
            method: 'POST',
            normalizedPath,
            keyHash: '8'.repeat(64),
            requestHash: '9'.repeat(64),
            now: new Date('2026-07-31T01:00:00.000Z'),
          },
          now: new Date('2026-07-31T01:00:00.000Z'),
        }),
      ).resolves.toMatchObject({
        listingId,
        adopterUserId: adopterId,
        shelterId,
        commitmentAccepted: true,
        status: 'submitted',
        threadId: expect.any(String),
      });
    } finally {
      await prisma.$disconnect();
    }
  });
});

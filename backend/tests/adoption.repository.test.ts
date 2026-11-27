import { type PrismaClient } from '@prisma/client';

import { PrismaAdoptionRepository } from '../src/features/adoption/persistence/prisma-adoption-repository';
import {
  ADOPTER_USER_ID,
  LISTING_ID,
  MEDIA_ID,
  REQUEST_ID,
  SHELTER_USER_ID,
  THREAD_ID,
} from './helpers/adoption-fixtures';

const NOW = new Date('2026-07-27T08:00:00.000Z');

const makePrismaListing = () => ({
  id: LISTING_ID,
  shelterId: SHELTER_USER_ID,
  heroMediaId: MEDIA_ID,
  petName: 'Golden',
  species: 'dog',
  breed: 'Golden Retriever',
  ageLabel: '2 thang tuoi',
  description: 'Hien lanh.',
  traits: ['hien lanh'],
  healthBadges: ['da tiem phong'],
  verificationBadges: ['mai am da xac minh'],
  latitude: null,
  longitude: null,
  status: 'available',
  createdAt: NOW,
  updatedAt: NOW,
  deletedAt: null,
  heroMedia: {
    id: MEDIA_ID,
    ownerUserId: SHELTER_USER_ID,
    purpose: 'adoption_listing',
    mimeType: 'image/webp',
    sizeBytes: BigInt(4_096),
    sha256: '5'.repeat(64),
    status: 'verified',
    storageKey: 'adoption/golden.webp',
    publicUrl: 'https://cdn.example.test/adoption/golden.webp',
    width: 1_200,
    height: 900,
    durationSeconds: null,
    draftId: null,
    caseId: null,
    commentId: null,
    position: null,
    verificationVersion: 1,
    verifiedAt: NOW,
    createdAt: NOW,
    updatedAt: NOW,
    deletedAt: null,
  },
});

const idempotency = {
  userId: ADOPTER_USER_ID,
  method: 'POST' as const,
  normalizedPath: `/adoption/listings/${LISTING_ID}/requests`,
  keyHash: 'a'.repeat(64),
  requestHash: 'b'.repeat(64),
  now: NOW,
};

describe('Day 50 Prisma Adoption repository', () => {
  it('lists only safe request summaries owned by the adopter', async () => {
    const findMany = jest.fn().mockResolvedValue([
      {
        id: REQUEST_ID,
        listingId: LISTING_ID,
        status: 'reviewing',
        createdAt: NOW,
        updatedAt: NOW,
        listing: {
          petName: 'Golden',
          status: 'closed',
          deletedAt: null,
        },
        chatThread: { id: THREAD_ID },
      },
    ]);
    const repository = new PrismaAdoptionRepository({
      adoptionRequest: { findMany },
    } as unknown as PrismaClient);

    await expect(
      repository.listRequestsByAdopter(ADOPTER_USER_ID),
    ).resolves.toEqual([
      {
        requestId: REQUEST_ID,
        listingId: LISTING_ID,
        petName: 'Golden',
        status: 'reviewing',
        listingAvailability: 'expired',
        threadId: THREAD_ID,
        createdAt: NOW.toISOString(),
        updatedAt: NOW.toISOString(),
      },
    ]);
    expect(findMany).toHaveBeenCalledWith({
      where: { adopterUserId: ADOPTER_USER_ID },
      select: {
        id: true,
        listingId: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        listing: {
          select: { petName: true, status: true, deletedAt: true },
        },
        chatThread: { select: { id: true } },
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
    });
  });

  it.each([
    { status: 'available', deletedAt: null, expected: 'available' },
    { status: 'pending', deletedAt: null, expected: 'unavailable' },
    { status: 'adopted', deletedAt: null, expected: 'unavailable' },
    { status: 'closed', deletedAt: null, expected: 'expired' },
    { status: 'available', deletedAt: NOW, expected: 'deleted' },
  ] as const)(
    'derives server-authoritative listing availability $expected',
    async ({ status, deletedAt, expected }) => {
      const findMany = jest.fn().mockResolvedValue([
        {
          id: REQUEST_ID,
          listingId: LISTING_ID,
          status: 'submitted',
          createdAt: NOW,
          updatedAt: NOW,
          listing: { petName: 'Golden', status, deletedAt },
          chatThread: null,
        },
      ]);
      const repository = new PrismaAdoptionRepository({
        adoptionRequest: { findMany },
      } as unknown as PrismaClient);

      const requests = await repository.listRequestsByAdopter(ADOPTER_USER_ID);

      expect(requests[0]?.listingAvailability).toBe(expected);
    },
  );

  it('lists only available unseen non-owner candidates', async () => {
    const findMany = jest.fn().mockResolvedValue([makePrismaListing()]);
    const repository = new PrismaAdoptionRepository({
      adoptionListing: { findMany },
    } as unknown as PrismaClient);

    const page = await repository.listListings({
      viewerUserId: ADOPTER_USER_ID,
      species: 'dog',
      sort: 'curated',
      limit: 20,
    });

    expect(page.items).toHaveLength(1);
    expect(page.items[0]).toMatchObject({
      listingId: LISTING_ID,
      shelterId: SHELTER_USER_ID,
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          deletedAt: null,
          status: 'available',
          shelterId: { not: ADOPTER_USER_ID },
          decisions: { none: { adopterUserId: ADOPTER_USER_ID } },
        }),
      }),
    );
  });

  it('orders location candidates by distance and returns an opaque cursor', async () => {
    const queryRaw = jest.fn().mockResolvedValue([
      {
        listingId: LISTING_ID,
        createdAt: NOW,
        distanceMeters: 1_500,
      },
      {
        listingId: '52000000-0000-4000-8000-000000000099',
        createdAt: NOW,
        distanceMeters: 2_000,
      },
    ]);
    const findMany = jest.fn().mockResolvedValue([makePrismaListing()]);
    const repository = new PrismaAdoptionRepository({
      $queryRaw: queryRaw,
      adoptionListing: { findMany },
    } as unknown as PrismaClient);

    const page = await repository.listListings({
      viewerUserId: ADOPTER_USER_ID,
      species: 'other',
      sort: 'distance',
      latitude: 10.776889,
      longitude: 106.700806,
      distanceKm: 5,
      cursor: {
        sort: 'distance',
        distanceMeters: 1_000,
        listingId: '52000000-0000-4000-8000-000000000098',
      },
      limit: 1,
    });

    expect(queryRaw).toHaveBeenCalledTimes(1);
    expect(findMany).toHaveBeenCalledWith({
      where: { id: { in: [LISTING_ID] } },
      include: { heroMedia: true },
    });
    expect(page).toMatchObject({
      limit: 1,
      nextCursor: {
        sort: 'distance',
        distanceMeters: 1_500,
        listingId: LISTING_ID,
      },
    });
    expect(page.items[0]).toMatchObject({
      listingId: LISTING_ID,
      distanceMeters: 1_500,
    });
  });

  it('reads one listing and rejects a hero media purpose mismatch', async () => {
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce(makePrismaListing())
      .mockResolvedValueOnce({
        ...makePrismaListing(),
        heroMedia: {
          ...makePrismaListing().heroMedia,
          purpose: 'rescue_case',
        },
      })
      .mockResolvedValueOnce(undefined);
    const repository = new PrismaAdoptionRepository({
      adoptionListing: { findFirst },
    } as unknown as PrismaClient);

    await expect(repository.findListing(LISTING_ID)).resolves.toMatchObject({
      listingId: LISTING_ID,
    });
    await expect(repository.findListing(LISTING_ID)).rejects.toThrow(
      'Adoption listing hero media has an invalid purpose.',
    );
    await expect(repository.findListing(LISTING_ID)).resolves.toBeUndefined();
  });

  it('records the swipe outcome and idempotency snapshot in one transaction', async () => {
    const transaction = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue(undefined),
        delete: jest.fn(),
        create: jest.fn().mockResolvedValue({}),
      },
      adoptionListing: {
        findFirst: jest.fn().mockResolvedValue({
          id: LISTING_ID,
          shelterId: SHELTER_USER_ID,
          status: 'available',
        }),
      },
      adoptionDecisionRecord: {
        upsert: jest.fn().mockResolvedValue({
          listingId: LISTING_ID,
          adopterUserId: ADOPTER_USER_ID,
          decision: 'like',
          createdAt: NOW,
        }),
      },
    };
    const $transaction = jest.fn(async (work: (tx: unknown) => unknown) =>
      work(transaction),
    );
    const repository = new PrismaAdoptionRepository({
      $transaction,
    } as unknown as PrismaClient);

    const result = await repository.recordDecision({
      listingId: LISTING_ID,
      adopterUserId: ADOPTER_USER_ID,
      decision: 'like',
      idempotency: {
        ...idempotency,
        normalizedPath: `/adoption/listings/${LISTING_ID}/decisions`,
      },
      now: NOW,
    });

    expect(result).toEqual({
      listingId: LISTING_ID,
      adopterUserId: ADOPTER_USER_ID,
      decision: 'like',
      createdAt: NOW.toISOString(),
    });
    expect(transaction.adoptionDecisionRecord.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          listingId_adopterUserId: {
            listingId: LISTING_ID,
            adopterUserId: ADOPTER_USER_ID,
          },
        },
      }),
    );
    expect(transaction.idempotencyRecord.create).toHaveBeenCalledTimes(1);
  });

  it('creates request, participant thread and outbox event atomically', async () => {
    const transaction = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue(undefined),
        delete: jest.fn(),
        create: jest.fn().mockResolvedValue({}),
      },
      adoptionListing: {
        findFirst: jest.fn().mockResolvedValue({
          id: LISTING_ID,
          shelterId: SHELTER_USER_ID,
          status: 'available',
        }),
      },
      adoptionRequest: {
        findFirst: jest.fn().mockResolvedValue(undefined),
        create: jest.fn().mockResolvedValue({
          id: REQUEST_ID,
          listingId: LISTING_ID,
          adopterUserId: ADOPTER_USER_ID,
          shelterId: SHELTER_USER_ID,
          livingCondition: 'Can ho',
          petExperience: 'Da nuoi cho',
          carePlan: 'Kham dinh ky',
          commitmentAccepted: true,
          note: null,
          status: 'submitted',
          createdAt: NOW,
          updatedAt: NOW,
          chatThread: { id: THREAD_ID },
        }),
      },
      outboxEvent: {
        create: jest.fn().mockResolvedValue({}),
      },
    };
    const $transaction = jest.fn(async (work: (tx: unknown) => unknown) =>
      work(transaction),
    );
    const repository = new PrismaAdoptionRepository({
      $transaction,
    } as unknown as PrismaClient);

    const result = await repository.createRequest({
      listingId: LISTING_ID,
      adopterUserId: ADOPTER_USER_ID,
      livingCondition: 'Can ho',
      petExperience: 'Da nuoi cho',
      carePlan: 'Kham dinh ky',
      commitmentAccepted: true,
      idempotency,
      now: NOW,
    });

    expect(result).toMatchObject({
      requestId: REQUEST_ID,
      listingId: LISTING_ID,
      threadId: THREAD_ID,
      status: 'submitted',
    });
    expect(transaction.adoptionRequest.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          listingId: LISTING_ID,
          adopterUserId: ADOPTER_USER_ID,
          shelterId: SHELTER_USER_ID,
          chatThread: {
            create: expect.objectContaining({
              adopterUserId: ADOPTER_USER_ID,
              shelterId: SHELTER_USER_ID,
            }),
          },
        }),
        include: { chatThread: true },
      }),
    );
    expect(transaction.outboxEvent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          eventType: 'adoption.request_submitted.v1',
          aggregateId: REQUEST_ID,
        }),
      }),
    );
    expect(transaction.idempotencyRecord.create).toHaveBeenCalledTimes(1);
  });
});

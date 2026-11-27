import { type PrismaClient } from '@prisma/client';

import { PrismaRescueRepository } from '../src/features/rescue/persistence/prisma-rescue-repository';
import { projectRescueCoordinateCell } from '../src/services/rescue/rescue-location-privacy';
import { RescuePersistenceConflictError } from '../src/features/rescue/persistence/rescue-repository';

const now = new Date('2026-07-17T07:00:00.000Z');

describe('PrismaRescueRepository', () => {
  it('uses the deterministic 500 m uncertainty-cell projection', () => {
    const projection = projectRescueCoordinateCell({
      latitude: 10.776889,
      longitude: 106.700806,
    });
    expect(projection).toEqual({
      approximateLatitude: 10.7775,
      approximateLongitude: 106.6995,
      privacyRadiusMeters: 500,
    });
  });

  it('creates a server-side private draft without an in-memory fallback', async () => {
    const create = jest.fn().mockResolvedValue({
      id: '34000000-0000-4000-8000-000000000101',
      ownerUserId: '34000000-0000-4000-8000-000000000100',
      source: 'rescue_home',
      petName: null,
      species: null,
      breedOrColor: null,
      lostAt: null,
      exactLatitude: null,
      exactLongitude: null,
      formattedAddress: null,
      areaLabel: null,
      privacyRadiusMeters: 500,
      identifyingFeatures: null,
      behaviorHint: null,
      contactPreference: 'in_app',
      version: 1,
      publishedAt: null,
      discardedAt: null,
      createdAt: now,
      updatedAt: now,
      media: [],
    });
    const prisma = {
      rescueCaseDraft: { create },
    } as unknown as PrismaClient;
    const repository = new PrismaRescueRepository(prisma);

    await expect(
      repository.createDraft({
        ownerUserId: '34000000-0000-4000-8000-000000000100',
        source: 'rescue_home',
        now,
      }),
    ).resolves.toMatchObject({
      draftId: '34000000-0000-4000-8000-000000000101',
      ownerUserId: '34000000-0000-4000-8000-000000000100',
      source: 'rescue_home',
      version: 1,
      media: [],
    });
    expect(create).toHaveBeenCalledWith({
      data: {
        ownerUserId: '34000000-0000-4000-8000-000000000100',
        source: 'rescue_home',
        createdAt: now,
        updatedAt: now,
      },
      include: { media: true },
    });
  });

  it('fails closed when an owner/version scoped draft update affects no row', async () => {
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      rescueCaseDraft: {
        findUnique: jest.fn().mockResolvedValue({
          id: '34000000-0000-4000-8000-000000000101',
          ownerUserId: '34000000-0000-4000-8000-000000000100',
          version: 4,
          publishedAt: null,
          discardedAt: null,
          media: [],
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    };
    const prisma = {
      $transaction: jest.fn(
        async (callback: (transaction: typeof tx) => unknown) => callback(tx),
      ),
    } as unknown as PrismaClient;
    const repository = new PrismaRescueRepository(prisma);

    await expect(
      repository.updateDraft({
        ownerUserId: '34000000-0000-4000-8000-000000000100',
        draftId: '34000000-0000-4000-8000-000000000101',
        expectedVersion: 4,
        patch: { petName: 'Milo' },
        now,
      }),
    ).rejects.toBeInstanceOf(RescuePersistenceConflictError);
  });
});

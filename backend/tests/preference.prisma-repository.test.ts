import { type PrismaClient } from '@prisma/client';

import { PrismaPreferenceRepository } from '../src/features/preferences/persistence/prisma-preference-repository';

const USER_ID = '59000000-0000-4000-8000-000000000001';
const UPDATED_AT = new Date('2026-07-29T08:00:00.000Z');

const notificationRow = {
  userId: USER_ID,
  version: 1,
  nearbyLostCases: true,
  chatMessages: true,
  adoptionUpdates: true,
  quietHoursEnabled: false,
  quietHoursStart: null,
  quietHoursEnd: null,
  createdAt: UPDATED_AT,
  updatedAt: UPDATED_AT,
};

const privacyRow = {
  userId: USER_ID,
  version: 1,
  hideHouseNumber: true,
  hidePhoneByDefault: true,
  reviewMediaBeforePublish: true,
  createdAt: UPDATED_AT,
  updatedAt: UPDATED_AT,
};

const buildPrisma = () => {
  const notificationPreference = {
    upsert: jest.fn(async () => notificationRow),
    updateMany: jest.fn(async () => ({ count: 1 })),
    findUnique: jest.fn(async () => ({ ...notificationRow, version: 2 })),
  };
  const privacyDefault = {
    upsert: jest.fn(async () => privacyRow),
    updateMany: jest.fn(async () => ({ count: 1 })),
    findUnique: jest.fn(async () => ({ ...privacyRow, version: 2 })),
  };
  return {
    prisma: {
      notificationPreference,
      privacyDefault,
    } as unknown as PrismaClient,
    notificationPreference,
    privacyDefault,
  };
};

describe('Day 59 Prisma preference repository', () => {
  it('creates privacy-safe defaults for an existing owner', async () => {
    const { prisma, notificationPreference, privacyDefault } = buildPrisma();
    const repository = new PrismaPreferenceRepository(prisma);

    await expect(
      repository.getOrCreateNotificationPreferences(USER_ID),
    ).resolves.toMatchObject({ version: 1, nearbyLostCases: true });
    await expect(
      repository.getOrCreatePrivacyDefaults(USER_ID),
    ).resolves.toMatchObject({
      version: 1,
      hideHouseNumber: true,
      hidePhoneByDefault: true,
      reviewMediaBeforePublish: true,
    });
    expect(notificationPreference.upsert).toHaveBeenCalledWith({
      where: { userId: USER_ID },
      create: { userId: USER_ID },
      update: {},
    });
    expect(privacyDefault.upsert).toHaveBeenCalled();
  });

  it('uses expectedVersion for an atomic notification update', async () => {
    const { prisma, notificationPreference } = buildPrisma();
    const repository = new PrismaPreferenceRepository(prisma);

    await expect(
      repository.updateNotificationPreferences({
        userId: USER_ID,
        expectedVersion: 1,
        nearbyLostCases: true,
        chatMessages: false,
        adoptionUpdates: true,
        quietHoursEnabled: false,
      }),
    ).resolves.toMatchObject({ version: 2, chatMessages: true });
    expect(notificationPreference.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: USER_ID, version: 1 },
        data: expect.objectContaining({
          chatMessages: false,
          quietHoursStart: null,
          quietHoursEnd: null,
          version: { increment: 1 },
        }),
      }),
    );
  });

  it('rejects stale writes instead of silently overwriting', async () => {
    const { prisma, privacyDefault } = buildPrisma();
    privacyDefault.updateMany.mockResolvedValueOnce({ count: 0 });
    const repository = new PrismaPreferenceRepository(prisma);

    await expect(
      repository.updatePrivacyDefaults({
        userId: USER_ID,
        expectedVersion: 7,
        hideHouseNumber: false,
        hidePhoneByDefault: false,
        reviewMediaBeforePublish: false,
      }),
    ).rejects.toMatchObject({ reason: 'version_conflict' });
    expect(privacyDefault.findUnique).not.toHaveBeenCalled();
  });
});

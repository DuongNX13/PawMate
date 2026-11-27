import {
  Prisma,
  type NotificationPreference,
  type PrismaClient,
  type PrivacyDefault,
} from '@prisma/client';

import {
  PreferencePersistenceDomainError,
  type NotificationPreferencesRecord,
  type PreferenceRepository,
  type PrivacyDefaultsRecord,
} from './preference-repository';

const toIso = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapNotification = (
  row: NotificationPreference,
): NotificationPreferencesRecord => ({
  userId: row.userId,
  version: row.version,
  nearbyLostCases: row.nearbyLostCases,
  chatMessages: row.chatMessages,
  adoptionUpdates: row.adoptionUpdates,
  quietHoursEnabled: row.quietHoursEnabled,
  ...(row.quietHoursStart ? { quietHoursStart: row.quietHoursStart } : {}),
  ...(row.quietHoursEnd ? { quietHoursEnd: row.quietHoursEnd } : {}),
  updatedAt: toIso(row.updatedAt),
});

const mapPrivacy = (row: PrivacyDefault): PrivacyDefaultsRecord => ({
  userId: row.userId,
  version: row.version,
  hideHouseNumber: row.hideHouseNumber,
  hidePhoneByDefault: row.hidePhoneByDefault,
  reviewMediaBeforePublish: row.reviewMediaBeforePublish,
  updatedAt: toIso(row.updatedAt),
});

const mapPersistenceError = (error: unknown): never => {
  if (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    (error.code === 'P2003' || error.code === 'P2025')
  ) {
    throw new PreferencePersistenceDomainError(
      'not_found',
      'Preference owner was not found.',
    );
  }
  throw error;
};

export class PrismaPreferenceRepository implements PreferenceRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async getOrCreateNotificationPreferences(userId: string) {
    try {
      const row = await this.prisma.notificationPreference.upsert({
        where: { userId },
        create: { userId },
        update: {},
      });
      return mapNotification(row);
    } catch (error) {
      return mapPersistenceError(error);
    }
  }

  async updateNotificationPreferences(
    input: Parameters<
      PreferenceRepository['updateNotificationPreferences']
    >[0],
  ) {
    await this.getOrCreateNotificationPreferences(input.userId);
    const result = await this.prisma.notificationPreference.updateMany({
      where: { userId: input.userId, version: input.expectedVersion },
      data: {
        nearbyLostCases: input.nearbyLostCases,
        chatMessages: input.chatMessages,
        adoptionUpdates: input.adoptionUpdates,
        quietHoursEnabled: input.quietHoursEnabled,
        quietHoursStart: input.quietHoursEnabled
          ? input.quietHoursStart
          : null,
        quietHoursEnd: input.quietHoursEnabled ? input.quietHoursEnd : null,
        version: { increment: 1 },
      },
    });
    if (result.count !== 1) {
      throw new PreferencePersistenceDomainError(
        'version_conflict',
        'Notification preferences changed since they were loaded.',
      );
    }
    const row = await this.prisma.notificationPreference.findUnique({
      where: { userId: input.userId },
    });
    if (!row) {
      throw new PreferencePersistenceDomainError(
        'not_found',
        'Notification preferences were not found.',
      );
    }
    return mapNotification(row);
  }

  async getOrCreatePrivacyDefaults(userId: string) {
    try {
      const row = await this.prisma.privacyDefault.upsert({
        where: { userId },
        create: { userId },
        update: {},
      });
      return mapPrivacy(row);
    } catch (error) {
      return mapPersistenceError(error);
    }
  }

  async updatePrivacyDefaults(
    input: Parameters<PreferenceRepository['updatePrivacyDefaults']>[0],
  ) {
    await this.getOrCreatePrivacyDefaults(input.userId);
    const result = await this.prisma.privacyDefault.updateMany({
      where: { userId: input.userId, version: input.expectedVersion },
      data: {
        hideHouseNumber: input.hideHouseNumber,
        hidePhoneByDefault: input.hidePhoneByDefault,
        reviewMediaBeforePublish: input.reviewMediaBeforePublish,
        version: { increment: 1 },
      },
    });
    if (result.count !== 1) {
      throw new PreferencePersistenceDomainError(
        'version_conflict',
        'Privacy defaults changed since they were loaded.',
      );
    }
    const row = await this.prisma.privacyDefault.findUnique({
      where: { userId: input.userId },
    });
    if (!row) {
      throw new PreferencePersistenceDomainError(
        'not_found',
        'Privacy defaults were not found.',
      );
    }
    return mapPrivacy(row);
  }
}

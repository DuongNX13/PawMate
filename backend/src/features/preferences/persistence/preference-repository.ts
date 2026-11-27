export type NotificationPreferencesRecord = {
  userId: string;
  version: number;
  nearbyLostCases: boolean;
  chatMessages: boolean;
  adoptionUpdates: boolean;
  quietHoursEnabled: boolean;
  quietHoursStart?: string;
  quietHoursEnd?: string;
  updatedAt: string;
};

export type PrivacyDefaultsRecord = {
  userId: string;
  version: number;
  hideHouseNumber: boolean;
  hidePhoneByDefault: boolean;
  reviewMediaBeforePublish: boolean;
  updatedAt: string;
};

export type PreferencePersistenceFailure =
  | 'not_found'
  | 'version_conflict';

export class PreferencePersistenceDomainError extends Error {
  constructor(
    readonly reason: PreferencePersistenceFailure,
    message: string,
  ) {
    super(message);
    this.name = 'PreferencePersistenceDomainError';
  }
}

export interface PreferenceRepository {
  getOrCreateNotificationPreferences(
    userId: string,
  ): Promise<NotificationPreferencesRecord>;

  updateNotificationPreferences(input: {
    userId: string;
    expectedVersion: number;
    nearbyLostCases: boolean;
    chatMessages: boolean;
    adoptionUpdates: boolean;
    quietHoursEnabled: boolean;
    quietHoursStart?: string;
    quietHoursEnd?: string;
  }): Promise<NotificationPreferencesRecord>;

  getOrCreatePrivacyDefaults(userId: string): Promise<PrivacyDefaultsRecord>;

  updatePrivacyDefaults(input: {
    userId: string;
    expectedVersion: number;
    hideHouseNumber: boolean;
    hidePhoneByDefault: boolean;
    reviewMediaBeforePublish: boolean;
  }): Promise<PrivacyDefaultsRecord>;
}

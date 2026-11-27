import { AppError } from '../../errors/app-error';
import { PREFERENCE_ERROR_CODES } from '../../errors/error-codes';
import {
  PreferencePersistenceDomainError,
  type NotificationPreferencesRecord,
  type PreferenceRepository,
  type PrivacyDefaultsRecord,
} from '../../features/preferences/persistence/preference-repository';

type UnknownRecord = Record<string, unknown>;
export type NotificationCategory =
  | 'nearby_lost_case'
  | 'chat_message'
  | 'adoption_update';
export type PrivacySurface =
  | 'rescue_create'
  | 'rescue_comment'
  | 'adoption_chat';

export type PrivacySurfaceDefaults = {
  hidePhoneByDefault: boolean;
  reviewMediaBeforePublish: boolean;
  hideHouseNumber?: boolean;
};

export interface PreferenceService {
  getNotificationPreferences(
    userId: string,
  ): Promise<NotificationPreferencesRecord>;
  updateNotificationPreferences(
    userId: string,
    body: unknown,
  ): Promise<NotificationPreferencesRecord>;
  getPrivacyDefaults(userId: string): Promise<PrivacyDefaultsRecord>;
  updatePrivacyDefaults(
    userId: string,
    body: unknown,
  ): Promise<PrivacyDefaultsRecord>;
  shouldDeliverNotification(
    userId: string,
    category: NotificationCategory,
    localTime: string,
  ): Promise<boolean>;
  getPrivacyDefaultsForSurface(
    userId: string,
    surface: PrivacySurface,
  ): Promise<PrivacySurfaceDefaults>;
}

const invalidInput = (field: string, message: string): never => {
  throw new AppError(
    PREFERENCE_ERROR_CODES.invalidInput,
    message,
    400,
    field,
  );
};

const asObject = (value: unknown) => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalidInput('body', 'Body phai la JSON object.');
  }
  return value as UnknownRecord;
};

const assertKnownKeys = (value: UnknownRecord, allowed: readonly string[]) => {
  const unexpected = Object.keys(value).find((key) => !allowed.includes(key));
  if (unexpected) {
    invalidInput(unexpected, `Truong ${unexpected} khong duoc ho tro.`);
  }
};

const requireBoolean = (
  value: unknown,
  field: string,
): boolean => {
  if (typeof value !== 'boolean') {
    return invalidInput(field, `${field} phai la boolean.`);
  }
  return value;
};

const requireVersion = (value: unknown) => {
  if (!Number.isSafeInteger(value) || Number(value) < 1) {
    return invalidInput(
      'expectedVersion',
      'expectedVersion phai la so nguyen tu 1 tro len.',
    );
  }
  return Number(value);
};

const TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
const requireTime = (value: unknown, field: string) => {
  if (typeof value !== 'string' || !TIME_PATTERN.test(value)) {
    return invalidInput(field, `${field} phai theo dinh dang HH:mm.`);
  }
  return value;
};

const mapPersistenceError = (error: unknown): never => {
  if (error instanceof PreferencePersistenceDomainError) {
    if (error.reason === 'version_conflict') {
      throw new AppError(
        PREFERENCE_ERROR_CODES.versionConflict,
        'Cai dat da thay doi tren thiet bi khac. Vui long tai lai.',
        409,
      );
    }
    throw new AppError(
      PREFERENCE_ERROR_CODES.notFound,
      'Khong tim thay tai khoan de luu cai dat.',
      404,
    );
  }
  throw error;
};

const callRepository = async <T>(operation: () => Promise<T>) => {
  try {
    return await operation();
  } catch (error) {
    return mapPersistenceError(error);
  }
};

const requireRepository = (repository?: PreferenceRepository) => {
  if (!repository) throw new Error('Preference persistence is unavailable.');
  return repository;
};

const parseNotificationUpdate = (body: unknown) => {
  const value = asObject(body);
  assertKnownKeys(value, [
    'expectedVersion',
    'nearbyLostCases',
    'chatMessages',
    'adoptionUpdates',
    'quietHoursEnabled',
    'quietHoursStart',
    'quietHoursEnd',
  ]);
  const expectedVersion = requireVersion(value.expectedVersion);
  const nearbyLostCases = requireBoolean(
    value.nearbyLostCases,
    'nearbyLostCases',
  );
  const chatMessages = requireBoolean(value.chatMessages, 'chatMessages');
  const adoptionUpdates = requireBoolean(
    value.adoptionUpdates,
    'adoptionUpdates',
  );
  const quietHoursEnabled = requireBoolean(
    value.quietHoursEnabled,
    'quietHoursEnabled',
  );
  const quietHoursStart = quietHoursEnabled
    ? requireTime(value.quietHoursStart, 'quietHoursStart')
    : undefined;
  const quietHoursEnd = quietHoursEnabled
    ? requireTime(value.quietHoursEnd, 'quietHoursEnd')
    : undefined;
  if (
    quietHoursEnabled &&
    quietHoursStart === quietHoursEnd
  ) {
    invalidInput(
      'quietHoursEnd',
      'Gio bat dau va ket thuc khong duoc trung nhau.',
    );
  }
  return {
    expectedVersion,
    nearbyLostCases,
    chatMessages,
    adoptionUpdates,
    quietHoursEnabled,
    quietHoursStart,
    quietHoursEnd,
  };
};

const parsePrivacyUpdate = (body: unknown) => {
  const value = asObject(body);
  assertKnownKeys(value, [
    'expectedVersion',
    'hideHouseNumber',
    'hidePhoneByDefault',
    'reviewMediaBeforePublish',
  ]);
  return {
    expectedVersion: requireVersion(value.expectedVersion),
    hideHouseNumber: requireBoolean(
      value.hideHouseNumber,
      'hideHouseNumber',
    ),
    hidePhoneByDefault: requireBoolean(
      value.hidePhoneByDefault,
      'hidePhoneByDefault',
    ),
    reviewMediaBeforePublish: requireBoolean(
      value.reviewMediaBeforePublish,
      'reviewMediaBeforePublish',
    ),
  };
};

const timeToMinutes = (value: string) => {
  const [hours, minutes] = value.split(':').map(Number);
  return hours * 60 + minutes;
};

const isQuietTime = (
  localTime: string,
  start: string,
  end: string,
) => {
  const current = timeToMinutes(localTime);
  const startMinutes = timeToMinutes(start);
  const endMinutes = timeToMinutes(end);
  return startMinutes < endMinutes
    ? current >= startMinutes && current < endMinutes
    : current >= startMinutes || current < endMinutes;
};

export const createPreferenceService = (options: {
  repository?: PreferenceRepository;
}): PreferenceService => {
  const repository = () => requireRepository(options.repository);

  return {
    getNotificationPreferences: (userId) =>
      callRepository(() =>
        repository().getOrCreateNotificationPreferences(userId),
      ),

    async updateNotificationPreferences(userId, body) {
      const input = parseNotificationUpdate(body);
      return callRepository(() =>
        repository().updateNotificationPreferences({ userId, ...input }),
      );
    },

    getPrivacyDefaults: (userId) =>
      callRepository(() => repository().getOrCreatePrivacyDefaults(userId)),

    async updatePrivacyDefaults(userId, body) {
      const input = parsePrivacyUpdate(body);
      return callRepository(() =>
        repository().updatePrivacyDefaults({ userId, ...input }),
      );
    },

    async shouldDeliverNotification(userId, category, localTime) {
      const normalizedTime = requireTime(localTime, 'localTime');
      const preferences = await this.getNotificationPreferences(userId);
      const categoryEnabled = {
        nearby_lost_case: preferences.nearbyLostCases,
        chat_message: preferences.chatMessages,
        adoption_update: preferences.adoptionUpdates,
      }[category];
      if (!categoryEnabled) return false;
      if (
        !preferences.quietHoursEnabled ||
        !preferences.quietHoursStart ||
        !preferences.quietHoursEnd
      ) {
        return true;
      }
      return !isQuietTime(
        normalizedTime,
        preferences.quietHoursStart,
        preferences.quietHoursEnd,
      );
    },

    async getPrivacyDefaultsForSurface(userId, surface) {
      const defaults = await this.getPrivacyDefaults(userId);
      return {
        ...(surface === 'rescue_create'
          ? { hideHouseNumber: defaults.hideHouseNumber }
          : {}),
        hidePhoneByDefault: defaults.hidePhoneByDefault,
        reviewMediaBeforePublish: defaults.reviewMediaBeforePublish,
      };
    },
  };
};

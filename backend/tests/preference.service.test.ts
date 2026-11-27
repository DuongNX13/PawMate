import { PREFERENCE_ERROR_CODES } from '../src/errors/error-codes';
import {
  PreferencePersistenceDomainError,
  type PreferenceRepository,
} from '../src/features/preferences/persistence/preference-repository';
import { createPreferenceService } from '../src/services/preferences/preference-service';

const USER_ID = '59000000-0000-4000-8000-000000000001';
const UPDATED_AT = '2026-07-29T08:00:00.000Z';

const buildRepository = () => {
  const getOrCreateNotificationPreferences = jest.fn(async () => ({
    userId: USER_ID,
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: false,
    quietHoursEnabled: true,
    quietHoursStart: '22:00',
    quietHoursEnd: '06:00',
    updatedAt: UPDATED_AT,
  }));
  const updateNotificationPreferences = jest.fn(async (input) => ({
    userId: USER_ID,
    version: input.expectedVersion + 1,
    nearbyLostCases: input.nearbyLostCases,
    chatMessages: input.chatMessages,
    adoptionUpdates: input.adoptionUpdates,
    quietHoursEnabled: input.quietHoursEnabled,
    ...(input.quietHoursStart
      ? { quietHoursStart: input.quietHoursStart }
      : {}),
    ...(input.quietHoursEnd ? { quietHoursEnd: input.quietHoursEnd } : {}),
    updatedAt: UPDATED_AT,
  }));
  const getOrCreatePrivacyDefaults = jest.fn(async () => ({
    userId: USER_ID,
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: UPDATED_AT,
  }));
  const updatePrivacyDefaults = jest.fn(async (input) => ({
    userId: USER_ID,
    version: input.expectedVersion + 1,
    hideHouseNumber: input.hideHouseNumber,
    hidePhoneByDefault: input.hidePhoneByDefault,
    reviewMediaBeforePublish: input.reviewMediaBeforePublish,
    updatedAt: UPDATED_AT,
  }));
  return {
    repository: {
      getOrCreateNotificationPreferences,
      updateNotificationPreferences,
      getOrCreatePrivacyDefaults,
      updatePrivacyDefaults,
    } as PreferenceRepository,
    getOrCreateNotificationPreferences,
    updateNotificationPreferences,
    getOrCreatePrivacyDefaults,
    updatePrivacyDefaults,
  };
};

describe('Day 59 preference service', () => {
  it('loads persisted safe defaults for notification and privacy settings', async () => {
    const { repository } = buildRepository();
    const service = createPreferenceService({ repository });

    await expect(
      service.getNotificationPreferences(USER_ID),
    ).resolves.toMatchObject({
      userId: USER_ID,
      version: 1,
      nearbyLostCases: true,
      chatMessages: true,
    });
    await expect(service.getPrivacyDefaults(USER_ID)).resolves.toMatchObject({
      hideHouseNumber: true,
      hidePhoneByDefault: true,
      reviewMediaBeforePublish: true,
    });
  });

  it('normalizes quiet-hour updates and clears optional hours when disabled', async () => {
    const { repository, updateNotificationPreferences } = buildRepository();
    const service = createPreferenceService({ repository });

    await service.updateNotificationPreferences(USER_ID, {
      expectedVersion: 1,
      nearbyLostCases: true,
      chatMessages: false,
      adoptionUpdates: true,
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '06:00',
    });

    expect(updateNotificationPreferences).toHaveBeenCalledWith({
      userId: USER_ID,
      expectedVersion: 1,
      nearbyLostCases: true,
      chatMessages: false,
      adoptionUpdates: true,
      quietHoursEnabled: false,
      quietHoursStart: undefined,
      quietHoursEnd: undefined,
    });
  });

  it.each([
    [{}, 'expectedVersion'],
    [
      {
        expectedVersion: 1,
        nearbyLostCases: true,
        chatMessages: true,
        adoptionUpdates: true,
        quietHoursEnabled: true,
      },
      'quietHoursStart',
    ],
    [
      {
        expectedVersion: 1,
        nearbyLostCases: true,
        chatMessages: true,
        adoptionUpdates: true,
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '22:00',
      },
      'quietHoursEnd',
    ],
  ])('rejects invalid notification payload %#', async (body, field) => {
    const { repository, updateNotificationPreferences } = buildRepository();
    const service = createPreferenceService({ repository });

    await expect(
      service.updateNotificationPreferences(USER_ID, body),
    ).rejects.toMatchObject({
      code: PREFERENCE_ERROR_CODES.invalidInput,
      field,
    });
    expect(updateNotificationPreferences).not.toHaveBeenCalled();
  });

  it('enforces category switches and overnight quiet hours', async () => {
    const { repository } = buildRepository();
    const service = createPreferenceService({ repository });

    await expect(
      service.shouldDeliverNotification(USER_ID, 'chat_message', '21:59'),
    ).resolves.toBe(true);
    await expect(
      service.shouldDeliverNotification(USER_ID, 'chat_message', '22:00'),
    ).resolves.toBe(false);
    await expect(
      service.shouldDeliverNotification(USER_ID, 'chat_message', '05:59'),
    ).resolves.toBe(false);
    await expect(
      service.shouldDeliverNotification(USER_ID, 'chat_message', '06:00'),
    ).resolves.toBe(true);
    await expect(
      service.shouldDeliverNotification(USER_ID, 'adoption_update', '12:00'),
    ).resolves.toBe(false);
  });

  it.each([
    [
      'rescue_create',
      {
        hideHouseNumber: true,
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: true,
      },
    ],
    [
      'rescue_comment',
      {
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: true,
      },
    ],
    [
      'adoption_chat',
      {
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: true,
      },
    ],
  ] as const)(
    'propagates privacy defaults to %s',
    async (surface, expected) => {
      const { repository } = buildRepository();
      const service = createPreferenceService({ repository });

      await expect(
        service.getPrivacyDefaultsForSurface(USER_ID, surface),
      ).resolves.toEqual(expected);
    },
  );

  it('maps stale writes to PREFERENCE_004', async () => {
    const { repository, updatePrivacyDefaults } = buildRepository();
    updatePrivacyDefaults.mockRejectedValueOnce(
      new PreferencePersistenceDomainError('version_conflict', 'stale'),
    );
    const service = createPreferenceService({ repository });

    await expect(
      service.updatePrivacyDefaults(USER_ID, {
        expectedVersion: 1,
        hideHouseNumber: true,
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: false,
      }),
    ).rejects.toEqual(
      expect.objectContaining({
        code: PREFERENCE_ERROR_CODES.versionConflict,
        statusCode: 409,
      }),
    );
  });

  it('fails closed when production persistence is absent', async () => {
    const service = createPreferenceService({});

    await expect(service.getPrivacyDefaults(USER_ID)).rejects.toThrow(
      'Preference persistence is unavailable.',
    );
  });
});

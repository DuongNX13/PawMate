import { buildApp } from '../src/app';
import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { type AuthService } from '../src/services/auth/auth-service';
import { type PreferenceService } from '../src/services/preferences/preference-service';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const USER_ID = '59000000-0000-4000-8000-000000000001';
const UPDATED_AT = '2026-07-29T08:00:00.000Z';
const openApps: Array<ReturnType<typeof buildApp>> = [];

afterEach(async () => {
  await Promise.all(openApps.splice(0).map(async (app) => app.close()));
});

const buildHarness = async () => {
  const verifyAccessToken = jest.fn(async (token: string) => {
    if (token !== 'owner-token') {
      throw new AppError(
        AUTH_ERROR_CODES.unauthorized,
        'Access token khong hop le.',
        401,
      );
    }
    return { userId: USER_ID, email: 'owner@example.test' };
  });
  const getNotificationPreferences = jest.fn(async () => ({
    userId: USER_ID,
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: UPDATED_AT,
  }));
  const updateNotificationPreferences = jest.fn(async () => ({
    userId: USER_ID,
    version: 2,
    nearbyLostCases: true,
    chatMessages: false,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: UPDATED_AT,
  }));
  const getPrivacyDefaults = jest.fn(async () => ({
    userId: USER_ID,
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: UPDATED_AT,
  }));
  const updatePrivacyDefaults = jest.fn(async () => ({
    userId: USER_ID,
    version: 2,
    hideHouseNumber: true,
    hidePhoneByDefault: false,
    reviewMediaBeforePublish: true,
    updatedAt: UPDATED_AT,
  }));
  const app = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      authService: { verifyAccessToken } as unknown as AuthService,
      preferenceService: {
        getNotificationPreferences,
        updateNotificationPreferences,
        getPrivacyDefaults,
        updatePrivacyDefaults,
      } as unknown as PreferenceService,
    },
  );
  openApps.push(app);
  await app.ready();
  return {
    app,
    verifyAccessToken,
    getNotificationPreferences,
    updateNotificationPreferences,
    getPrivacyDefaults,
    updatePrivacyDefaults,
  };
};

describe('Day 59 preference routes', () => {
  it.each([
    ['GET', '/me/notification-preferences'],
    ['PUT', '/me/notification-preferences'],
    ['GET', '/me/privacy-defaults'],
    ['PUT', '/me/privacy-defaults'],
  ] as const)('requires owner auth for %s %s', async (method, url) => {
    const { app } = await buildHarness();
    const response = await app.inject({ method, url });

    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({
      success: false,
      error: { code: AUTH_ERROR_CODES.unauthorized },
    });
  });

  it('loads both owner-scoped preference resources', async () => {
    const { app, getNotificationPreferences, getPrivacyDefaults } =
      await buildHarness();

    const [notification, privacy] = await Promise.all([
      app.inject({
        method: 'GET',
        url: '/me/notification-preferences',
        headers: { authorization: 'Bearer owner-token' },
      }),
      app.inject({
        method: 'GET',
        url: '/me/privacy-defaults',
        headers: { authorization: 'Bearer owner-token' },
      }),
    ]);

    expect(notification.statusCode).toBe(200);
    expect(privacy.statusCode).toBe(200);
    expect(notification.headers['cache-control']).toBe('no-store');
    expect(notification.json()).toMatchObject({
      data: { userId: USER_ID, nearbyLostCases: true },
    });
    expect(privacy.json()).toMatchObject({
      data: { userId: USER_ID, hideHouseNumber: true },
    });
    expect(getNotificationPreferences).toHaveBeenCalledWith(USER_ID);
    expect(getPrivacyDefaults).toHaveBeenCalledWith(USER_ID);
  });

  it('forwards notification and privacy writes without changing the DTO', async () => {
    const {
      app,
      updateNotificationPreferences,
      updatePrivacyDefaults,
    } = await buildHarness();
    const notificationBody = {
      expectedVersion: 1,
      nearbyLostCases: true,
      chatMessages: false,
      adoptionUpdates: true,
      quietHoursEnabled: false,
    };
    const privacyBody = {
      expectedVersion: 1,
      hideHouseNumber: true,
      hidePhoneByDefault: false,
      reviewMediaBeforePublish: true,
    };

    const [notification, privacy] = await Promise.all([
      app.inject({
        method: 'PUT',
        url: '/me/notification-preferences',
        headers: { authorization: 'Bearer owner-token' },
        payload: notificationBody,
      }),
      app.inject({
        method: 'PUT',
        url: '/me/privacy-defaults',
        headers: { authorization: 'Bearer owner-token' },
        payload: privacyBody,
      }),
    ]);

    expect(notification.statusCode).toBe(200);
    expect(privacy.statusCode).toBe(200);
    expect(updateNotificationPreferences).toHaveBeenCalledWith(
      USER_ID,
      notificationBody,
    );
    expect(updatePrivacyDefaults).toHaveBeenCalledWith(USER_ID, privacyBody);
  });
});

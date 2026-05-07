import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
import { createAuthService } from '../src/services/auth/auth-service';
import { createNotificationService } from '../src/services/notifications/notification-service';
import { createPetService } from '../src/services/pets/pet-service';
import { createReminderService } from '../src/services/reminders/reminder-service';

const buildConfig = (): AppConfig => ({
  appName: 'PawMate Backend',
  nodeEnv: 'test',
  host: '127.0.0.1',
  port: 3000,
  logLevel: 'error',
  auth: {
    accessTokenSecret: 'test-access-secret',
    refreshTokenSecret: 'test-refresh-secret',
    accessTokenTtlMinutes: 15,
    refreshTokenTtlDays: 30,
    maxLoginAttempts: 5,
    lockoutMinutes: 15,
    maxActiveSessions: 3,
    socialLoginEnabled: true,
    emailRateLimitAutoVerifyFallback: false,
  },
  databaseUrl: undefined,
  redisUrl: undefined,
  supabaseProjectRef: undefined,
  supabaseUrl: undefined,
  supabaseAnonKey: undefined,
  supabaseServiceRoleKey: undefined,
  supabaseAuthRedirectUrl: undefined,
  supabaseAuthMobileRedirectUrl: undefined,
  oauthVerification: {
    googleAllowedAudiences: [],
    appleAllowedAudiences: [],
  },
  supabaseBuckets: {
    avatars: 'avatars',
    petPhotos: 'pet-photos',
    posts: 'posts',
  },
});

const registerAndLogin = async (
  app: ReturnType<typeof buildApp>,
  authService: ReturnType<typeof createAuthService>,
  email: string,
) => {
  const registerResponse = await app.inject({
    method: 'POST',
    url: '/auth/register',
    payload: {
      email,
      password: 'Pawmate123',
    },
  });
  await authService.markEmailVerified(registerResponse.json().userId);

  const loginResponse = await app.inject({
    method: 'POST',
    url: '/auth/login',
    payload: {
      email,
      password: 'Pawmate123',
    },
  });

  return {
    userId: loginResponse.json().user.id as string,
    auth: {
      authorization: `Bearer ${loginResponse.json().accessToken}`,
    },
  };
};

describe('Reminder and notification routes', () => {
  it('runs reminder CRUD, due processing, notification read state, and ownership checks', async () => {
    const config = buildConfig();
    const authService = createAuthService({ config });
    const petService = createPetService(config);
    const notificationService = createNotificationService();
    const reminderService = createReminderService({
      petReader: petService,
      notificationService,
    });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService,
        notificationService,
        reminderService,
      },
    );
    await app.ready();

    const owner = await registerAndLogin(
      app,
      authService,
      'reminder-owner@pawmate.vn',
    );
    const intruder = await registerAndLogin(
      app,
      authService,
      'reminder-intruder@pawmate.vn',
    );

    const createPet = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: owner.auth,
      payload: {
        name: 'Bap',
        species: 'dog',
        gender: 'male',
      },
    });
    const petId = createPet.json().data.id;

    const unauthorizedList = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/reminders`,
    });
    expect(unauthorizedList.statusCode).toBe(401);

    const invalidReminder = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/reminders`,
      headers: owner.auth,
      payload: {
        reminderAt: '2026-04-20T09:30:00.000Z',
      },
    });
    expect(invalidReminder.statusCode).toBe(400);
    expect(invalidReminder.json().error.code).toBe('REMINDER_002');
    expect(invalidReminder.json().error.field).toBe('title');

    const createReminder = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/reminders`,
      headers: owner.auth,
      payload: {
        title: 'Tiem nhac lai 5 benh',
        note: 'Theo doi phan ung trong 24 gio.',
        reminderAt: '2026-04-20T09:30:00.000Z',
        repeatRule: 'weekly',
        timezone: 'Asia/Bangkok',
      },
    });
    expect(createReminder.statusCode).toBe(201);
    const reminder = createReminder.json().data;
    expect(reminder).toMatchObject({
      petId,
      title: 'Tiem nhac lai 5 benh',
      repeatRule: 'weekly',
      status: 'scheduled',
    });

    const forbiddenList = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/reminders`,
      headers: intruder.auth,
    });
    expect(forbiddenList.statusCode).toBe(403);
    expect(forbiddenList.json().error.code).toBe('PET_006');

    const listFirstPage = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/reminders?limit=1`,
      headers: owner.auth,
    });
    expect(listFirstPage.statusCode).toBe(200);
    expect(listFirstPage.json().data.items).toHaveLength(1);

    const malformedNotificationLimit = await app.inject({
      method: 'GET',
      url: '/notifications?limit=abc',
      headers: owner.auth,
    });
    expect(malformedNotificationLimit.statusCode).toBe(400);
    expect(malformedNotificationLimit.json().error.code).toBe(
      'NOTIFICATION_002',
    );

    const updateReminder = await app.inject({
      method: 'PATCH',
      url: `/pets/${petId}/reminders/${reminder.id}`,
      headers: owner.auth,
      payload: {
        title: 'Tiem phong cap nhat',
        note: 'Da doi lich theo phong kham.',
      },
    });
    expect(updateReminder.statusCode).toBe(200);
    expect(updateReminder.json().data).toMatchObject({
      id: reminder.id,
      title: 'Tiem phong cap nhat',
    });

    const snoozeReminder = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/reminders/${reminder.id}/snooze`,
      headers: owner.auth,
      payload: {
        snoozedUntil: '2026-04-21T09:30:00.000Z',
      },
    });
    expect(snoozeReminder.statusCode).toBe(200);
    expect(snoozeReminder.json().data.snoozedUntil).toBe(
      '2026-04-21T09:30:00.000Z',
    );

    const earlyProcess = await reminderService.processDueReminders(
      new Date('2026-04-20T10:00:00.000Z'),
    );
    expect(earlyProcess.processedCount).toBe(0);

    const dueProcess = await app.inject({
      method: 'POST',
      url: '/notifications/process-due-reminders',
      headers: owner.auth,
    });
    expect(dueProcess.statusCode).toBe(200);
    expect(dueProcess.json().data.processedCount).toBe(1);
    expect(dueProcess.json().data.items[0]).toMatchObject({
      id: reminder.id,
      status: 'scheduled',
    });
    expect(dueProcess.json().data.items[0].nextTriggerAt).toBeTruthy();

    const notificationList = await app.inject({
      method: 'GET',
      url: '/notifications?unreadOnly=true',
      headers: owner.auth,
    });
    expect(notificationList.statusCode).toBe(200);
    expect(notificationList.json().data.items).toHaveLength(1);
    expect(notificationList.json().data.unreadCount).toBe(1);
    const notificationId = notificationList.json().data.items[0].id;

    const forbiddenNotificationRead = await app.inject({
      method: 'PATCH',
      url: `/notifications/${notificationId}/read`,
      headers: intruder.auth,
    });
    expect(forbiddenNotificationRead.statusCode).toBe(404);
    expect(forbiddenNotificationRead.json().error.code).toBe(
      'NOTIFICATION_003',
    );

    const readNotification = await app.inject({
      method: 'PATCH',
      url: `/notifications/${notificationId}/read`,
      headers: owner.auth,
    });
    expect(readNotification.statusCode).toBe(200);
    expect(readNotification.json().data.readAt).toBeTruthy();

    const readAll = await app.inject({
      method: 'POST',
      url: '/notifications/read-all',
      headers: owner.auth,
    });
    expect(readAll.statusCode).toBe(200);
    expect(readAll.json().data.updatedCount).toBe(0);

    const dismissNotification = await app.inject({
      method: 'PATCH',
      url: `/notifications/${notificationId}/dismiss`,
      headers: owner.auth,
    });
    expect(dismissNotification.statusCode).toBe(200);
    expect(dismissNotification.json().data.dismissedAt).toBeTruthy();

    const listAfterDismiss = await app.inject({
      method: 'GET',
      url: '/notifications',
      headers: owner.auth,
    });
    expect(listAfterDismiss.statusCode).toBe(200);
    expect(listAfterDismiss.json().data.items).toHaveLength(0);

    const markDone = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/reminders/${reminder.id}/mark-done`,
      headers: owner.auth,
    });
    expect(markDone.statusCode).toBe(200);
    expect(markDone.json().data.status).toBe('done');

    const deleteReminder = await app.inject({
      method: 'DELETE',
      url: `/pets/${petId}/reminders/${reminder.id}`,
      headers: owner.auth,
    });
    expect(deleteReminder.statusCode).toBe(204);

    await app.close();
  });
});

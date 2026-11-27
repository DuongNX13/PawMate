import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
import { createAuthService } from '../src/services/auth/auth-service';
import { createPetService } from '../src/services/pets/pet-service';

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
  const registration = await app.inject({
    method: 'POST',
    url: '/auth/register',
    payload: { email, password: 'Pawmate123' },
  });
  const userId = registration.json().userId as string;
  await authService.markEmailVerified(userId);
  const login = await app.inject({
    method: 'POST',
    url: '/auth/login',
    payload: { email, password: 'Pawmate123' },
  });
  return {
    userId,
    headers: {
      authorization: `Bearer ${login.json().accessToken as string}`,
    },
  };
};

describe('Day 135 field-level authorization', () => {
  it('derives pet, health and reminder ownership/state from the verified caller', async () => {
    const config = buildConfig();
    const authService = createAuthService({ config });
    const petService = createPetService(config);
    const app = buildApp(
      { logger: false },
      { config, authService, petService },
    );
    await app.ready();

    const owner = await registerAndLogin(
      app,
      authService,
      'day135-owner@pawmate.vn',
    );
    const outsider = await registerAndLogin(
      app,
      authService,
      'day135-outsider@pawmate.vn',
    );

    const petResponse = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: owner.headers,
      payload: {
        name: 'Bao',
        species: 'dog',
        breed: 'Corgi',
        color: 'Vang trang',
        userId: outsider.userId,
        ownerUserId: outsider.userId,
        createdByUserId: outsider.userId,
        status: 'admin',
      },
    });
    expect(petResponse.statusCode).toBe(201);
    expect(petResponse.json().data).toMatchObject({ userId: owner.userId });
    expect(petResponse.json().data).not.toHaveProperty('ownerUserId');
    expect(petResponse.json().data).not.toHaveProperty('createdByUserId');
    expect(petResponse.json().data).not.toHaveProperty('status');
    const petId = petResponse.json().data.id as string;

    const healthResponse = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/health-records`,
      headers: owner.headers,
      payload: {
        type: 'checkup',
        date: '2026-09-28',
        title: 'Kham tong quat',
        createdByUserId: outsider.userId,
        ownerUserId: outsider.userId,
        status: 'verified',
      },
    });
    expect(healthResponse.statusCode).toBe(201);
    expect(healthResponse.json().data).toMatchObject({
      petId,
      createdByUserId: owner.userId,
    });
    expect(healthResponse.json().data).not.toHaveProperty('ownerUserId');
    expect(healthResponse.json().data).not.toHaveProperty('status');

    const reminderResponse = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/reminders`,
      headers: owner.headers,
      payload: {
        title: 'Nhac tiem phong',
        reminderAt: '2026-10-01T02:30:00.000Z',
        timezone: 'Asia/Bangkok',
        repeatRule: 'none',
        createdByUserId: outsider.userId,
        ownerUserId: outsider.userId,
        status: 'done',
      },
    });
    expect(reminderResponse.statusCode).toBe(201);
    expect(reminderResponse.json().data).toMatchObject({
      petId,
      createdByUserId: owner.userId,
      status: 'scheduled',
    });
    expect(reminderResponse.json().data).not.toHaveProperty('ownerUserId');

    const outsiderRead = await app.inject({
      method: 'GET',
      url: `/pets/${petId}`,
      headers: outsider.headers,
    });
    expect(outsiderRead.statusCode).toBe(403);

    await app.close();
  });
});

import { rm } from 'node:fs/promises';
import path from 'node:path';

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

describe('Pet routes', () => {
  afterEach(async () => {
    await rm(path.resolve(process.cwd(), 'storage'), {
      recursive: true,
      force: true,
    });
  });

  it('creates, lists, updates, uploads a photo reference, and soft deletes a pet', async () => {
    const config = buildConfig();
    const authService = createAuthService({ config });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService: createPetService(config),
      },
    );
    await app.ready();

    const registerResponse = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'pet-owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const registerPayload = registerResponse.json();
    await authService.markEmailVerified(registerPayload.userId);

    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'pet-owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const { accessToken } = loginResponse.json();
    const authorization = { authorization: `Bearer ${accessToken}` };

    const createResponse = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: authorization,
      payload: {
        name: 'Milo',
        species: 'dog',
        gender: 'male',
        weight: 12.5,
        healthStatus: 'healthy',
      },
    });

    expect(createResponse.statusCode).toBe(201);
    const createPayload = createResponse.json();
    const petId = createPayload.data.id;

    const listResponse = await app.inject({
      method: 'GET',
      url: '/pets',
      headers: authorization,
    });

    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data).toHaveLength(1);

    const updateResponse = await app.inject({
      method: 'PUT',
      url: `/pets/${petId}`,
      headers: authorization,
      payload: {
        weight: 13,
        color: 'brown',
      },
    });

    expect(updateResponse.statusCode).toBe(200);
    expect(updateResponse.json().data.weight).toBe(13);

    const uploadResponse = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/photo`,
      headers: authorization,
      payload: {
        fileName: 'milo.png',
        contentType: 'image/png',
        base64Data:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5XtWQAAAAASUVORK5CYII=',
      },
    });

    expect(uploadResponse.statusCode).toBe(200);
    const uploadPayload = uploadResponse.json();
    expect(uploadPayload.avatarUrl).toContain('/assets/pet-photos/');

    const assetPath = new URL(uploadPayload.avatarUrl).pathname;
    const assetResponse = await app.inject({
      method: 'GET',
      url: assetPath,
    });

    expect(assetResponse.statusCode).toBe(200);
    expect(assetResponse.headers['content-type']).toContain('image/png');

    const deleteResponse = await app.inject({
      method: 'DELETE',
      url: `/pets/${petId}`,
      headers: authorization,
    });

    expect(deleteResponse.statusCode).toBe(204);

    const listAfterDelete = await app.inject({
      method: 'GET',
      url: '/pets',
      headers: authorization,
    });

    expect(listAfterDelete.statusCode).toBe(200);
    expect(listAfterDelete.json().data).toHaveLength(0);

    await app.close();
  });

  it('rejects invalid species and ownership violations', async () => {
    const config = buildConfig();
    const authService = createAuthService({ config });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService: createPetService(config),
      },
    );
    await app.ready();

    const ownerRegister = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const ownerPayload = ownerRegister.json();
    await authService.markEmailVerified(ownerPayload.userId);

    const intruderRegister = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'intruder@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const intruderPayload = intruderRegister.json();
    await authService.markEmailVerified(intruderPayload.userId);

    const ownerLogin = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const intruderLogin = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'intruder@pawmate.vn',
        password: 'Pawmate123',
      },
    });

    const ownerAuth = {
      authorization: `Bearer ${ownerLogin.json().accessToken}`,
    };
    const intruderAuth = {
      authorization: `Bearer ${intruderLogin.json().accessToken}`,
    };

    const invalidCreate = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: ownerAuth,
      payload: {
        name: 'Bad Pet',
        species: 'dragon',
      },
    });

    expect(invalidCreate.statusCode).toBe(400);
    expect(invalidCreate.json().error.code).toBe('PET_002');

    const createResponse = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: ownerAuth,
      payload: {
        name: 'Lucky',
        species: 'cat',
        gender: 'female',
      },
    });

    const petId = createResponse.json().data.id;

    const forbiddenUpdate = await app.inject({
      method: 'PUT',
      url: `/pets/${petId}`,
      headers: intruderAuth,
      payload: {
        color: 'black',
      },
    });

    expect(forbiddenUpdate.statusCode).toBe(403);
    expect(forbiddenUpdate.json().error.code).toBe('PET_006');

    await app.close();
  });

  it('creates, lists, updates, and soft deletes health records with ownership checks', async () => {
    const config = buildConfig();
    const authService = createAuthService({ config });
    const petService = createPetService(config);
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService,
      },
    );
    await app.ready();

    const ownerRegister = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'health-owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    await authService.markEmailVerified(ownerRegister.json().userId);

    const intruderRegister = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'health-intruder@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    await authService.markEmailVerified(intruderRegister.json().userId);

    const ownerLogin = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'health-owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const intruderLogin = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'health-intruder@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    const ownerAuth = {
      authorization: `Bearer ${ownerLogin.json().accessToken}`,
    };
    const intruderAuth = {
      authorization: `Bearer ${intruderLogin.json().accessToken}`,
    };

    const createPet = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: ownerAuth,
      payload: {
        name: 'Bap',
        species: 'dog',
        gender: 'male',
      },
    });
    const petId = createPet.json().data.id;

    const unauthorizedList = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/health-records`,
    });
    expect(unauthorizedList.statusCode).toBe(401);

    const invalidType = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/health-records`,
      headers: ownerAuth,
      payload: {
        type: 'spa',
        date: '2026-04-20',
      },
    });
    expect(invalidType.statusCode).toBe(400);
    expect(invalidType.json().error.code).toBe('HEALTH_002');
    expect(invalidType.json().error.field).toBe('type');

    const impossibleDate = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/health-records`,
      headers: ownerAuth,
      payload: {
        type: 'vaccination',
        date: '2026-02-31',
      },
    });
    expect(impossibleDate.statusCode).toBe(400);
    expect(impossibleDate.json().error.code).toBe('HEALTH_002');
    expect(impossibleDate.json().error.field).toBe('date');

    const dateTimeValue = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/health-records`,
      headers: ownerAuth,
      payload: {
        type: 'vaccination',
        date: '2026-04-20T09:30:00.000Z',
      },
    });
    expect(dateTimeValue.statusCode).toBe(400);
    expect(dateTimeValue.json().error.field).toBe('date');

    const deworming = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/health-records`,
      headers: ownerAuth,
      payload: {
        type: 'deworming',
        date: '2026-04-24',
        title: 'Tay giun dinh ky',
        note: 'Lap moi 3 thang.',
        attachments: ['https://cdn.pawmate.test/health/deworming.png'],
      },
    });
    expect(deworming.statusCode).toBe(201);
    const dewormingRecord = deworming.json().data;
    expect(dewormingRecord).toMatchObject({
      petId,
      type: 'deworming',
      date: '2026-04-24',
      title: 'Tay giun dinh ky',
    });

    const vaccination = await app.inject({
      method: 'POST',
      url: `/pets/${petId}/health-records`,
      headers: ownerAuth,
      payload: {
        type: 'vaccination',
        date: '2026-04-20',
        title: 'Tiem nhac lai 5 benh',
      },
    });
    expect(vaccination.statusCode).toBe(201);

    const listFirstPage = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/health-records?limit=1`,
      headers: ownerAuth,
    });
    expect(listFirstPage.statusCode).toBe(200);
    expect(listFirstPage.json().data.items).toHaveLength(1);
    expect(listFirstPage.json().data.items[0].type).toBe('deworming');
    expect(listFirstPage.json().data.total).toBe(2);
    expect(listFirstPage.json().data.nextCursor).toBeTruthy();

    const malformedLimit = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/health-records?limit=1abc`,
      headers: ownerAuth,
    });
    expect(malformedLimit.statusCode).toBe(400);
    expect(malformedLimit.json().error.code).toBe('HEALTH_002');
    expect(malformedLimit.json().error.field).toBe('limit');

    const filteredList = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/health-records?type=vaccination`,
      headers: ownerAuth,
    });
    expect(filteredList.statusCode).toBe(200);
    expect(filteredList.json().data.items).toHaveLength(1);
    expect(filteredList.json().data.items[0].type).toBe('vaccination');

    const forbiddenList = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/health-records`,
      headers: intruderAuth,
    });
    expect(forbiddenList.statusCode).toBe(403);
    expect(forbiddenList.json().error.code).toBe('PET_006');

    const updateResponse = await app.inject({
      method: 'PUT',
      url: `/pets/${petId}/health-records/${dewormingRecord.id}`,
      headers: ownerAuth,
      payload: {
        type: 'grooming',
        date: '2026-04-25',
        note: 'Da cap nhat thanh grooming.',
      },
    });
    expect(updateResponse.statusCode).toBe(200);
    expect(updateResponse.json().data).toMatchObject({
      id: dewormingRecord.id,
      type: 'grooming',
      date: '2026-04-25',
      note: 'Da cap nhat thanh grooming.',
    });

    const deleteResponse = await app.inject({
      method: 'DELETE',
      url: `/pets/${petId}/health-records/${dewormingRecord.id}`,
      headers: ownerAuth,
    });
    expect(deleteResponse.statusCode).toBe(204);

    const listAfterDelete = await app.inject({
      method: 'GET',
      url: `/pets/${petId}/health-records`,
      headers: ownerAuth,
    });
    expect(listAfterDelete.statusCode).toBe(200);
    expect(listAfterDelete.json().data.items).toHaveLength(1);
    expect(listAfterDelete.json().data.items[0].type).toBe('vaccination');

    await app.close();
  });
});

import { type AppConfig } from '../src/config/env';
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

const validPet = {
  name: 'Mochi',
  species: 'cat',
  breed: 'Mèo tam thể',
  color: 'Tam thể',
};

describe('Pet service P1-05/P1-06 contract', () => {
  it('keeps optional date and weight absent instead of fabricating values', async () => {
    const service = createPetService(buildConfig());

    const pet = await service.create('owner-1', validPet);

    expect(pet.dob).toBeUndefined();
    expect(pet.weight).toBeUndefined();
    expect(pet.gender).toBe('unknown');
    expect(pet.healthStatus).toBe('healthy');
  });

  it.each([
    [{ ...validPet, dob: '2030-01-01' }, 'PET_008', 'dob'],
    [{ ...validPet, weight: 100 }, 'PET_004', 'weight'],
    [{ ...validPet, microchip: 'chip has spaces' }, 'PET_014', 'microchip'],
  ])('rejects invalid SRS field ranges', async (input, code, field) => {
    const service = createPetService(buildConfig());

    await expect(service.create('owner-1', input)).rejects.toMatchObject({
      code,
      field,
      statusCode: 400,
    });
  });

  it('does not publish an avatar URL when storage fails', async () => {
    const service = createPetService(buildConfig(), {
      savePhoto: async () => {
        throw new Error('storage unavailable');
      },
      buildPhotoUrl: () =>
        'http://localhost/assets/pet-photos/should-not-exist.png',
    });
    const pet = await service.create('owner-1', validPet);

    await expect(
      service.attachPhoto('owner-1', pet.id, {
        fileName: 'mochi.png',
        contentType: 'image/png',
        base64Data:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5XtWQAAAAASUVORK5CYII=',
      }),
    ).rejects.toMatchObject({
      code: 'PET_015',
      field: 'base64Data',
      statusCode: 503,
    });

    const savedPet = await service.get('owner-1', pet.id);
    expect(savedPet.id).toBe(pet.id);
    expect(savedPet.avatarUrl).toBeUndefined();
  });
});

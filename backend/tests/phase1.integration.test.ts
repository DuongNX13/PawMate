import { rm } from 'node:fs/promises';
import path from 'node:path';

import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { createAuthService } from '../src/services/auth/auth-service';
import { createPetService } from '../src/services/pets/pet-service';
import { createVetService } from '../src/services/vets/vet-service';

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
    socialLoginEnabled: false,
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

const seedData = {
  clinics: [
    {
      id: 'hn-001',
      name: 'Gaia Hanoi Pet Clinic',
      city: 'Hà Nội',
      district: 'Tây Hồ',
      address: '38 Đường 1, Yên Phụ',
      phone: '02437956956',
      latitude: null,
      longitude: null,
      website: null,
      is24h: false,
      openHours: [],
      services: [],
      photoUrls: [],
      averageRating: 4.7,
      reviewCount: 18,
      sourceUrl: 'https://example.com/hn',
      sourceList: 'Danh sách Hà Nội',
      sourceRank: 1,
      priorityTier: 'high',
      selectionReason: 'curated-toplist-seed',
      enrichmentStatus: 'needs-geo-hours-services',
      readyForMap: false,
    },
    {
      id: 'hcm-031',
      name: 'New Pet Hospital',
      city: 'TP Hồ Chí Minh',
      district: 'Quận 1',
      address: '53 Đặng Dung',
      phone: '02862693939',
      latitude: null,
      longitude: null,
      website: 'https://example.com/hcm',
      is24h: false,
      openHours: [],
      services: [],
      photoUrls: [],
      averageRating: 4.8,
      reviewCount: 12,
      sourceUrl: 'https://example.com/hcm',
      sourceList: 'Danh sách HCM',
      sourceRank: 2,
      priorityTier: 'high',
      selectionReason: 'curated-toplist-seed',
      enrichmentStatus: 'needs-geo-hours-services',
      readyForMap: false,
    },
  ],
};

const pilotSeedData = {
  clinics: [
    {
      id: 'hn-001',
      latitude: 21.060822,
      longitude: 105.8359417,
      readyForMap: true,
      openHours: ['Mon-Sun 08:00-20:00'],
      services: ['Khám tổng quát', 'Tiêm phòng'],
      enrichmentStatus: 'pilot-geo-hours-services-ready',
    },
    {
      id: 'hcm-031',
      latitude: 10.792682,
      longitude: 106.6904944,
      readyForMap: true,
      openHours: ['Mon-Sun 08:00-20:00'],
      services: ['Khám tổng quát', 'Cấp cứu ban ngày'],
      enrichmentStatus: 'pilot-geo-hours-services-ready',
    },
  ],
};

describe('Phase 1 Day 1-3 integration', () => {
  afterEach(async () => {
    await rm(path.resolve(process.cwd(), 'storage'), {
      recursive: true,
      force: true,
    });
  });

  it('keeps health, email auth, pet profile, and vet finder contracts working together', async () => {
    const config = buildConfig();
    const emailVerificationGateway = {
      sendEmailVerification: jest.fn().mockResolvedValue({
        status: 'verification-email-sent' as const,
      }),
      verifyEmailToken: jest.fn().mockResolvedValue({
        email: 'phase1-owner@pawmate.vn',
      }),
      resendEmailVerification: jest.fn().mockResolvedValue(undefined),
    };
    const authService = createAuthService({
      config,
      emailVerificationGateway,
    });
    const app = buildApp(
      { logger: false },
      {
        config,
        authService,
        petService: createPetService(config),
        vetService: createVetService({
          seedData,
          pilotSeedData,
          now: () => new Date('2026-04-23T03:30:00.000Z'),
        }),
      },
    );
    await app.ready();

    const healthResponse = await app.inject({ method: 'GET', url: '/health' });
    expect(healthResponse.statusCode).toBe(200);
    expect(healthResponse.json()).toEqual({ status: 'ok' });

    const unauthorizedPetsResponse = await app.inject({
      method: 'GET',
      url: '/pets',
    });
    expect(unauthorizedPetsResponse.statusCode).toBe(401);

    const registerResponse = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'phase1-owner@pawmate.vn',
        password: 'Pawmate123',
        displayName: 'Phase 1 Owner',
      },
    });
    expect(registerResponse.statusCode).toBe(201);
    expect(emailVerificationGateway.sendEmailVerification).toHaveBeenCalled();

    const loginBeforeVerifyResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'phase1-owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    expect(loginBeforeVerifyResponse.statusCode).toBe(403);

    const verifyResponse = await app.inject({
      method: 'POST',
      url: '/auth/verify-email',
      payload: { tokenHash: 'phase1-signup-token' },
    });
    expect(verifyResponse.statusCode).toBe(200);

    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'phase1-owner@pawmate.vn',
        password: 'Pawmate123',
      },
    });
    expect(loginResponse.statusCode).toBe(200);
    const { accessToken, refreshToken } = loginResponse.json();
    const authorization = { authorization: `Bearer ${accessToken}` };

    const createPetResponse = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: authorization,
      payload: {
        name: 'Bắp',
        species: 'dog',
        breed: 'Golden Retriever',
        gender: 'male',
        weight: 12.4,
        healthStatus: 'healthy',
      },
    });
    expect(createPetResponse.statusCode).toBe(201);
    const petId = createPetResponse.json().data.id;

    const listPetsResponse = await app.inject({
      method: 'GET',
      url: '/pets',
      headers: authorization,
    });
    expect(listPetsResponse.statusCode).toBe(200);
    expect(listPetsResponse.json().data).toHaveLength(1);

    const refreshResponse = await app.inject({
      method: 'POST',
      url: '/auth/refresh',
      payload: { refreshToken },
    });
    expect(refreshResponse.statusCode).toBe(200);
    expect(refreshResponse.json().refreshToken).not.toBe(refreshToken);

    const searchResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?q=tiem phong&city=Ha Noi',
    });
    expect(searchResponse.statusCode).toBe(200);
    expect(searchResponse.json().data[0]).toMatchObject({
      id: 'hn-001',
      readyForMap: true,
    });

    const nearbyResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=21.0609&lng=105.8360&radius=3000&limit=5',
    });
    expect(nearbyResponse.statusCode).toBe(200);
    const nearbyItems = nearbyResponse.json().data;
    expect(nearbyItems).toHaveLength(1);
    expect(nearbyItems[0].id).toBe('hn-001');
    expect(nearbyItems[0].services).toContain('Tiêm phòng');
    expect(nearbyItems.some((item: { id: string }) => item.id.startsWith('perf-'))).toBe(false);

    const detailResponse = await app.inject({
      method: 'GET',
      url: `/vets/${nearbyItems[0].id}`,
    });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json().data.openHours).toContain('Mon-Sun 08:00-20:00');

    const oauthResponse = await app.inject({
      method: 'POST',
      url: '/auth/oauth',
      payload: {
        provider: 'google',
        credential: 'google-id-token',
      },
    });
    expect(oauthResponse.statusCode).toBe(403);
    expect(oauthResponse.json().error.code).toBe(AUTH_ERROR_CODES.providerDisabled);

    const deletePetResponse = await app.inject({
      method: 'DELETE',
      url: `/pets/${petId}`,
      headers: authorization,
    });
    expect(deletePetResponse.statusCode).toBe(204);

    await app.close();
  });
});

import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
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
      is24h: true,
      openHours: ['00:00-23:59'],
      services: ['Tiêm phòng', 'Khám tổng quát'],
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
      id: 'hcm-001',
      name: 'New Pet Hospital',
      city: 'TP Hồ Chí Minh',
      district: 'Quận 1',
      address: '53 Đặng Dung',
      phone: '02862693939',
      latitude: null,
      longitude: null,
      website: 'https://example.com/hcm',
      is24h: false,
      openHours: ['Thu 08:00-20:00'],
      services: ['Cấp cứu 24/7', 'Khám tổng quát'],
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
    {
      id: 'hcm-002',
      name: 'Sai Gon Pet Clinic',
      city: 'TP Hồ Chí Minh',
      district: 'Quận 2',
      address: '12 Nguyễn Cơ Thạch',
      phone: '02838222222',
      latitude: null,
      longitude: null,
      website: null,
      is24h: true,
      openHours: ['00:00-23:59'],
      services: ['Khám tổng quát', 'Tẩy giun'],
      photoUrls: [],
      averageRating: 4.2,
      reviewCount: 7,
      sourceUrl: 'https://example.com/hcm-2',
      sourceList: 'Danh sách HCM',
      sourceRank: 3,
      priorityTier: 'medium',
      selectionReason: 'pilot-map-seed',
      enrichmentStatus: 'needs-geo-hours-services',
      readyForMap: false,
    },
    {
      id: 'hp-001',
      name: 'Hai Phong Vet Care',
      city: 'Hải Phòng',
      district: 'Lê Chân',
      address: '10 Tô Hiệu',
      phone: '0225123456',
      latitude: null,
      longitude: null,
      website: null,
      is24h: false,
      openHours: ['Thu 18:00-23:00'],
      services: [],
      photoUrls: [],
      averageRating: 3.6,
      reviewCount: 4,
      sourceUrl: 'https://example.com/hp',
      sourceList: 'Danh sách Hải Phòng',
      sourceRank: 4,
      priorityTier: 'medium',
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
      latitude: 21.07182,
      longitude: 105.82854,
      readyForMap: true,
      openHours: ['Thu 00:00-23:59'],
      photoUrls: ['https://example.com/gaia-1.jpg'],
      enrichmentStatus: 'pilot-geo-ready',
    },
    {
      id: 'hcm-001',
      latitude: 10.78798,
      longitude: 106.69231,
      readyForMap: true,
      openHours: ['Thu 08:00-20:00'],
      services: ['Cấp cứu 24/7', 'Khám tổng quát'],
      photoUrls: ['https://example.com/new-pet.jpg'],
      enrichmentStatus: 'pilot-geo-ready',
    },
    {
      id: 'hcm-002',
      latitude: 10.78742,
      longitude: 106.73629,
      readyForMap: true,
      openHours: ['Thu 00:00-23:59'],
      services: ['Khám tổng quát', 'Tẩy giun'],
      enrichmentStatus: 'pilot-geo-ready',
    },
    {
      id: 'hp-001',
      latitude: 20.85483,
      longitude: 106.68218,
      readyForMap: true,
      openHours: ['Thu 18:00-23:00'],
      enrichmentStatus: 'pilot-geo-ready',
    },
  ],
};

const buildTestApp = async () => {
  const config = buildConfig();
  const app = buildApp(
    { logger: false },
    {
      config,
      vetService: createVetService({
        seedData,
        pilotSeedData,
        now: () => new Date('2026-04-23T03:30:00.000Z'),
      }),
    },
  );
  await app.ready();
  return app;
};

describe('Vet routes', () => {
  it('returns search results, pagination, and accent-insensitive matching from seed-backed data', async () => {
    const app = await buildTestApp();

    const searchResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?q=tiem phong&city=Ha Noi&limit=1',
    });

    expect(searchResponse.statusCode).toBe(200);
    expect(searchResponse.json().data).toHaveLength(1);
    expect(searchResponse.json().data[0].id).toBe('hn-001');
    expect(searchResponse.json().pagination.limit).toBe(1);
    expect(searchResponse.json().data[0].isOpen).toBe(true);

    const pagedResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?limit=1&cursor=1',
    });

    expect(pagedResponse.statusCode).toBe(200);
    expect(pagedResponse.json().data[0].id).toBe('hcm-001');

    await app.close();
  });

  it('applies 24h, open-now, rating, and empty-result filters with stable sorting', async () => {
    const app = await buildTestApp();

    const only24hResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?is24h=true',
    });
    expect(only24hResponse.statusCode).toBe(200);
    expect(only24hResponse.json().data).toHaveLength(2);
    expect(only24hResponse.json().data[0].id).toBe('hn-001');
    expect(only24hResponse.json().data[1].id).toBe('hcm-002');

    const openNowResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?isOpenNow=true&sort=rating-desc',
    });
    expect(openNowResponse.statusCode).toBe(200);
    expect(openNowResponse.json().data).toHaveLength(3);
    expect(openNowResponse.json().data[0].id).toBe('hcm-001');
    expect(openNowResponse.json().data[1].id).toBe('hn-001');

    const ratingResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?minRating=4.5',
    });
    expect(ratingResponse.statusCode).toBe(200);
    expect(ratingResponse.json().data).toHaveLength(2);
    expect(ratingResponse.json().data[0].id).toBe('hn-001');

    const emptyResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?city=Hai Phong&minRating=4.5',
    });
    expect(emptyResponse.statusCode).toBe(200);
    expect(emptyResponse.json().data).toHaveLength(0);
    expect(emptyResponse.json().pagination.total).toBe(0);

    await app.close();
  });

  it('returns nearby vets sorted by distance and keeps external ids compatible with detail routes', async () => {
    const app = await buildTestApp();

    const nearbyResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=10.7880&lng=106.6920&radius=6000',
    });

    expect(nearbyResponse.statusCode).toBe(200);
    expect(nearbyResponse.json().data).toHaveLength(2);
    expect(nearbyResponse.json().data[0].id).toBe('hcm-001');
    expect(nearbyResponse.json().data[1].id).toBe('hcm-002');
    expect(nearbyResponse.json().data[0].distanceMeters).toBeGreaterThanOrEqual(0);
    expect(nearbyResponse.json().data[0].latitude).toBeCloseTo(10.78798, 4);

    const only24hNearbyResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=10.7880&lng=106.6920&radius=6000&is24h=true',
    });
    expect(only24hNearbyResponse.statusCode).toBe(200);
    expect(only24hNearbyResponse.json().data).toHaveLength(1);
    expect(only24hNearbyResponse.json().data[0].id).toBe('hcm-002');

    const ratingNearbyResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=10.7880&lng=106.6920&radius=6000&minRating=4.5',
    });
    expect(ratingNearbyResponse.statusCode).toBe(200);
    expect(ratingNearbyResponse.json().data).toHaveLength(1);
    expect(ratingNearbyResponse.json().data[0].id).toBe('hcm-001');

    const noResultNearbyResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=16.0600&lng=108.2000&radius=1000',
    });
    expect(noResultNearbyResponse.statusCode).toBe(200);
    expect(noResultNearbyResponse.json().data).toHaveLength(0);

    const detailResponse = await app.inject({
      method: 'GET',
      url: '/vets/hcm-001',
    });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json().data.latitude).toBeCloseTo(10.78798, 4);
    expect(detailResponse.json().data.readyForMap).toBe(true);

    await app.close();
  });

  it('opens detail for map-ready records that come from the nearby directory store', async () => {
    const dbOnlyClinic = {
      id: 'db-map-001',
      name: 'Directory Vet Care',
      city: 'TP Hồ Chí Minh',
      district: 'Quận 1',
      address: '1 Nguyễn Huệ',
      phone: '0280000000',
      latitude: 10.7769,
      longitude: 106.7009,
      website: null,
      is24h: false,
      openHours: ['Thu 08:00-20:00'],
      services: ['Khám tổng quát'],
      photoUrls: [],
      averageRating: 4.6,
      reviewCount: 9,
      sourceUrl: '',
      sourceList: 'runtime-vet-directory',
      sourceRank: 12,
      priorityTier: 'map-ready',
      selectionReason: 'runtime-map-record',
      enrichmentStatus: 'runtime-db-ready',
      readyForMap: true,
    };
    const config = buildConfig();
    const app = buildApp(
      { logger: false },
      {
        config,
        vetService: createVetService({
          seedData: { clinics: [] },
          nearbyStore: {
            listNearby: async () => [
              {
                ...dbOnlyClinic,
                distanceMeters: 42.5,
              },
            ],
            getDetailById: async (vetId) =>
              vetId === dbOnlyClinic.id ? dbOnlyClinic : undefined,
          },
          now: () => new Date('2026-04-23T03:30:00.000Z'),
        }),
      },
    );
    await app.ready();

    const nearbyResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=10.7769&lng=106.7009&radius=3000',
    });
    expect(nearbyResponse.statusCode).toBe(200);
    expect(nearbyResponse.json().data[0].id).toBe(dbOnlyClinic.id);

    const detailResponse = await app.inject({
      method: 'GET',
      url: `/vets/${dbOnlyClinic.id}`,
    });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json().data.name).toBe(dbOnlyClinic.name);
    expect(detailResponse.json().data.latitude).toBeCloseTo(10.7769, 4);
    expect(detailResponse.json().data.source.list).toBe('runtime-vet-directory');

    await app.close();
  });

  it('rejects invalid filter and nearby query values with field-level errors', async () => {
    const app = await buildTestApp();

    const invalidLimitResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?limit=0',
    });
    expect(invalidLimitResponse.statusCode).toBe(400);
    expect(invalidLimitResponse.json().error.code).toBe('VET_001');
    expect(invalidLimitResponse.json().error.field).toBe('limit');

    const invalidBooleanResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?isOpenNow=maybe',
    });
    expect(invalidBooleanResponse.statusCode).toBe(400);
    expect(invalidBooleanResponse.json().error.field).toBe('isOpenNow');

    const invalidRatingResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?minRating=0.5',
    });
    expect(invalidRatingResponse.statusCode).toBe(400);
    expect(invalidRatingResponse.json().error.field).toBe('minRating');

    const invalidSortResponse = await app.inject({
      method: 'GET',
      url: '/vets/search?sort=distance',
    });
    expect(invalidSortResponse.statusCode).toBe(400);
    expect(invalidSortResponse.json().error.field).toBe('sort');

    const missingLatitudeResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lng=106.7',
    });
    expect(missingLatitudeResponse.statusCode).toBe(400);
    expect(missingLatitudeResponse.json().error.field).toBe('lat');

    const invalidLongitudeResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=10.8&lng=111',
    });
    expect(invalidLongitudeResponse.statusCode).toBe(400);
    expect(invalidLongitudeResponse.json().error.field).toBe('lng');

    const invalidRadiusResponse = await app.inject({
      method: 'GET',
      url: '/vets/nearby?lat=10.8&lng=106.7&radius=250',
    });
    expect(invalidRadiusResponse.statusCode).toBe(400);
    expect(invalidRadiusResponse.json().error.field).toBe('radius');

    await app.close();
  });
});

import { type AppConfig } from '../../src/config/env';
import {
  type RescueCaseRecord,
  type RescueMediaAssetRecord,
} from '../../src/features/rescue/persistence/rescue-repository';

export const CASE_ID = '11111111-1111-4111-8111-111111111111';
export const OWNER_USER_ID = '22222222-2222-4222-8222-222222222222';
export const DRAFT_ID = '33333333-3333-4333-8333-333333333333';
export const MEDIA_ID = '44444444-4444-4444-8444-444444444444';

export const buildTestConfig = (): AppConfig => ({
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

export const makeRescueMedia = (
  overrides: Partial<RescueMediaAssetRecord> = {},
): RescueMediaAssetRecord => ({
  mediaId: MEDIA_ID,
  ownerUserId: OWNER_USER_ID,
  purpose: 'rescue_case',
  mimeType: 'image/jpeg',
  sizeBytes: 12_345,
  sha256: 'a'.repeat(64),
  status: 'attached',
  storageKey: 'private/rescue/golden.jpg',
  publicUrl: 'https://cdn.example.test/rescue/golden.jpg',
  width: 1_200,
  height: 800,
  draftId: DRAFT_ID,
  caseId: CASE_ID,
  position: 0,
  verifiedAt: '2026-07-20T08:30:00.000Z',
  verificationVersion: 1,
  createdAt: '2026-07-20T08:00:00.000Z',
  updatedAt: '2026-07-20T08:30:00.000Z',
  ...overrides,
});

export const makeRescueCase = (
  overrides: Partial<RescueCaseRecord> = {},
): RescueCaseRecord => ({
  caseId: CASE_ID,
  sourceDraftId: DRAFT_ID,
  ownerUserId: OWNER_USER_ID,
  petName: 'Golden',
  species: 'dog',
  breedOrColor: 'Golden Retriever mau vang',
  ageLabel: '2 tuoi',
  lostAt: '2026-07-20T09:00:00.000Z',
  areaLabel: 'Thao Dien, Thu Duc',
  approximateLatitude: 10.8021,
  approximateLongitude: 106.7339,
  privacyRadiusMeters: 500,
  identifyingFeatures: 'Deo vong co mau xanh mint.',
  behaviorHint: 'Than thien nhung de hoang so.',
  contactPreference: 'phone_with_consent',
  status: 'missing',
  version: 1,
  commentCount: 3,
  privateLocation: {
    latitude: 10.801234,
    longitude: 106.734567,
    formattedAddress: '12 Duong bi mat, Thao Dien',
  },
  media: [makeRescueMedia()],
  createdAt: '2026-07-20T09:05:00.000Z',
  updatedAt: '2026-07-20T09:10:00.000Z',
  ...overrides,
});

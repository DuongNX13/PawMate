import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import path from 'node:path';
import { type FastifyInstance } from 'fastify';

import { buildApp } from '../src/app';
import { type AppConfig } from '../src/config/env';
import { REVIEW_ERROR_CODES } from '../src/errors/error-codes';
import { createAuthService } from '../src/services/auth/auth-service';
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

jest.setTimeout(30000);

const seedData = {
  clinics: [
    {
      id: 'hcm-001',
      name: 'New Pet Hospital',
      city: 'TP Ho Chi Minh',
      district: 'Quan 1',
      address: '53 Dang Dung',
      phone: '02862693939',
      latitude: 10.78798,
      longitude: 106.69231,
      website: 'https://example.com/hcm',
      is24h: false,
      openHours: ['Mon-Sun 08:00-20:00'],
      services: ['Kham tong quat', 'Tiem phong'],
      photoUrls: [],
      averageRating: 4.8,
      reviewCount: 12,
      sourceUrl: 'https://example.com/hcm',
      sourceList: 'Danh sach HCM',
      sourceRank: 1,
      priorityTier: 'high',
      selectionReason: 'review-test-seed',
      enrichmentStatus: 'review-ready',
      readyForMap: true,
    },
  ],
};

const buildTestApp = async () => {
  const config = buildConfig();
  const authService = createAuthService({
    config,
    emailVerificationGateway: {
      sendEmailVerification: jest.fn().mockResolvedValue({
        status: 'auto-verified' as const,
      }),
      verifyEmailToken: jest.fn().mockResolvedValue({
        email: 'unused@pawmate.vn',
      }),
      resendEmailVerification: jest.fn().mockResolvedValue(undefined),
    },
  });
  const app = buildApp(
    { logger: false },
    {
      config,
      authService,
      vetService: createVetService({
        seedData,
        now: () => new Date('2026-04-23T03:30:00.000Z'),
      }),
    },
  );
  await app.ready();
  return app;
};

const registerAndLogin = async (app: FastifyInstance, emailPrefix: string) => {
  const email = `${emailPrefix}-${randomUUID()}@pawmate.vn`;
  const password = 'Pawmate123';
  const registerResponse = await app.inject({
    method: 'POST',
    url: '/auth/register',
    payload: {
      email,
      password,
      displayName: emailPrefix,
    },
  });
  expect(registerResponse.statusCode).toBe(201);

  const loginResponse = await app.inject({
    method: 'POST',
    url: '/auth/login',
    payload: {
      email,
      password,
    },
  });
  expect(loginResponse.statusCode).toBe(200);

  return {
    accessToken: loginResponse.json().accessToken as string,
    authorization: {
      authorization: `Bearer ${loginResponse.json().accessToken as string}`,
    },
  };
};

describe('Review routes', () => {
  afterEach(async () => {
    await rm(path.resolve(process.cwd(), 'storage', 'review-photos'), {
      recursive: true,
      force: true,
    });
  });

  it('enforces auth, validation, duplicate-review rule, and rating aggregate', async () => {
    const app = await buildTestApp();
    const owner = await registerAndLogin(app, 'review-owner');
    const secondOwner = await registerAndLogin(app, 'review-second');

    const unauthorizedResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      payload: {
        rating: 5,
        body: 'This clinic handled my pet very carefully.',
      },
    });
    expect(unauthorizedResponse.statusCode).toBe(401);
    expect(unauthorizedResponse.json().error.code).toBe(
      REVIEW_ERROR_CODES.unauthorized,
    );

    const invalidRatingResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: owner.authorization,
      payload: {
        rating: 6,
        body: 'This clinic handled my pet very carefully.',
      },
    });
    expect(invalidRatingResponse.statusCode).toBe(400);
    expect(invalidRatingResponse.json().error.code).toBe(
      REVIEW_ERROR_CODES.invalidRating,
    );

    const invalidBodyResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: owner.authorization,
      payload: {
        rating: 5,
        body: 'short',
      },
    });
    expect(invalidBodyResponse.statusCode).toBe(400);
    expect(invalidBodyResponse.json().error.field).toBe('body');

    const createResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: owner.authorization,
      payload: {
        rating: 5,
        title: 'Great first visit',
        body: 'The doctor explained the vaccine schedule clearly.',
        photoUrls: ['https://example.com/review-1.jpg'],
      },
    });
    expect(createResponse.statusCode).toBe(201);
    expect(createResponse.json().data).toMatchObject({
      vetId: 'hcm-001',
      rating: 5,
      status: 'visible',
      helpfulCount: 0,
      reportCount: 0,
      sentiment: 'UNPROCESSED',
    });

    const duplicateResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: owner.authorization,
      payload: {
        rating: 4,
        body: 'Trying to submit another review should be blocked.',
      },
    });
    expect(duplicateResponse.statusCode).toBe(409);
    expect(duplicateResponse.json().error.code).toBe(
      REVIEW_ERROR_CODES.duplicateReview,
    );

    const secondCreateResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: secondOwner.authorization,
      payload: {
        rating: 4,
        body: 'A different user can still add an independent review.',
      },
    });
    expect(secondCreateResponse.statusCode).toBe(201);

    const listResponse = await app.inject({
      method: 'GET',
      url: '/vets/hcm-001/reviews?sort=rating-desc',
    });
    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data).toHaveLength(2);
    expect(listResponse.json().summary).toEqual({
      averageRating: 4.5,
      reviewCount: 2,
      distribution: {
        1: 0,
        2: 0,
        3: 0,
        4: 1,
        5: 1,
      },
    });

    await app.close();
  });

  it('uploads review image binaries and attaches returned URLs to reviews', async () => {
    const app = await buildTestApp();
    const owner = await registerAndLogin(app, 'review-photo-owner');

    const unauthorizedUpload = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews/photos',
      payload: {
        fileName: 'visit.png',
        contentType: 'image/png',
        base64Data:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5XtWQAAAAASUVORK5CYII=',
      },
    });
    expect(unauthorizedUpload.statusCode).toBe(401);

    const invalidUpload = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews/photos',
      headers: owner.authorization,
      payload: {
        fileName: 'visit.gif',
        contentType: 'image/gif',
        base64Data: 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
      },
    });
    expect(invalidUpload.statusCode).toBe(400);
    expect(invalidUpload.json().error.field).toBe('contentType');

    const uploadResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews/photos',
      headers: owner.authorization,
      payload: {
        fileName: 'visit.png',
        contentType: 'image/png',
        base64Data:
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5XtWQAAAAASUVORK5CYII=',
      },
    });
    expect(uploadResponse.statusCode).toBe(201);
    const uploadedPhoto = uploadResponse.json().data;
    expect(uploadedPhoto).toMatchObject({
      contentType: 'image/png',
      storage: 'local',
    });
    expect(uploadedPhoto.url).toContain('/assets/review-photos/');

    const assetPath = new URL(uploadedPhoto.url).pathname;
    const assetResponse = await app.inject({
      method: 'GET',
      url: assetPath,
    });
    expect(assetResponse.statusCode).toBe(200);
    expect(assetResponse.headers['content-type']).toContain('image/png');

    const createResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: owner.authorization,
      payload: {
        rating: 5,
        body: 'Anh review duoc upload va dinh kem thanh cong.',
        photoUrls: [uploadedPhoto.url],
      },
    });
    expect(createResponse.statusCode).toBe(201);
    expect(createResponse.json().data.photoUrls).toEqual([uploadedPhoto.url]);

    await app.close();
  });

  it('handles helpful toggle and report auto-hide without corrupting aggregate', async () => {
    const app = await buildTestApp();
    const reviewOwner = await registerAndLogin(app, 'review-author');
    const voter = await registerAndLogin(app, 'review-voter');

    const createResponse = await app.inject({
      method: 'POST',
      url: '/vets/hcm-001/reviews',
      headers: reviewOwner.authorization,
      payload: {
        rating: 5,
        body: 'The consultation was detailed and my dog recovered well.',
      },
    });
    expect(createResponse.statusCode).toBe(201);
    const reviewId = createResponse.json().data.id as string;

    const helpfulResponse = await app.inject({
      method: 'PUT',
      url: `/reviews/${reviewId}/helpful`,
      headers: voter.authorization,
    });
    expect(helpfulResponse.statusCode).toBe(200);
    expect(helpfulResponse.json().data).toMatchObject({
      reviewId,
      helpfulCount: 1,
      hasVoted: true,
    });

    const unhelpfulResponse = await app.inject({
      method: 'PUT',
      url: `/reviews/${reviewId}/helpful`,
      headers: voter.authorization,
    });
    expect(unhelpfulResponse.statusCode).toBe(200);
    expect(unhelpfulResponse.json().data).toMatchObject({
      reviewId,
      helpfulCount: 0,
      hasVoted: false,
    });

    const duplicateReporter = await registerAndLogin(app, 'report-duplicate');
    const reportResponse = await app.inject({
      method: 'POST',
      url: `/reviews/${reviewId}/report`,
      headers: duplicateReporter.authorization,
      payload: {
        reason: 'spam',
        description: 'This looks promotional.',
      },
    });
    expect(reportResponse.statusCode).toBe(201);
    expect(reportResponse.json().data).toMatchObject({
      reviewId,
      reportCount: 1,
      reviewStatus: 'visible',
    });

    const duplicateReportResponse = await app.inject({
      method: 'POST',
      url: `/reviews/${reviewId}/report`,
      headers: duplicateReporter.authorization,
      payload: {
        reason: 'spam',
      },
    });
    expect(duplicateReportResponse.statusCode).toBe(409);
    expect(duplicateReportResponse.json().error.code).toBe(
      REVIEW_ERROR_CODES.duplicateReport,
    );

    const reporterPrefixes = ['report-a', 'report-b', 'report-c', 'report-d'];
    const reporters = await Promise.all(
      reporterPrefixes.map((prefix) => registerAndLogin(app, prefix)),
    );
    const finalReports = await Promise.all(
      reporters.map((reporter) =>
        app.inject({
          method: 'POST',
          url: `/reviews/${reviewId}/report`,
          headers: reporter.authorization,
          payload: {
            reason: 'false_information',
          },
        }),
      ),
    );
    expect(finalReports.map((response) => response.statusCode)).toEqual([
      201, 201, 201, 201,
    ]);
    expect(finalReports[3]?.json().data).toMatchObject({
      reportCount: 5,
      reviewStatus: 'hidden',
    });

    const listAfterHideResponse = await app.inject({
      method: 'GET',
      url: '/vets/hcm-001/reviews',
    });
    expect(listAfterHideResponse.statusCode).toBe(200);
    expect(listAfterHideResponse.json().data).toHaveLength(0);
    expect(listAfterHideResponse.json().summary.reviewCount).toBe(0);
    expect(listAfterHideResponse.json().summary.averageRating).toBeNull();

    await app.close();
  });

  it('keeps concurrent duplicate-review attempts to one created review', async () => {
    const app = await buildTestApp();
    const owner = await registerAndLogin(app, 'review-race');

    const responses = await Promise.all([
      app.inject({
        method: 'POST',
        url: '/vets/hcm-001/reviews',
        headers: owner.authorization,
        payload: {
          rating: 5,
          body: 'First concurrent review request for the same vet.',
        },
      }),
      app.inject({
        method: 'POST',
        url: '/vets/hcm-001/reviews',
        headers: owner.authorization,
        payload: {
          rating: 4,
          body: 'Second concurrent review request for the same vet.',
        },
      }),
    ]);

    const statusCodes = responses
      .map((response) => response.statusCode)
      .sort((left, right) => left - right);
    expect(statusCodes).toEqual([201, 409]);

    const listResponse = await app.inject({
      method: 'GET',
      url: '/vets/hcm-001/reviews',
    });
    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().summary.reviewCount).toBe(1);

    await app.close();
  });
});

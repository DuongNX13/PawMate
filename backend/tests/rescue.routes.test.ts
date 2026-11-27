import { buildApp } from '../src/app';
import { RESCUE_ERROR_CODES } from '../src/errors/error-codes';
import { type RescueRepository } from '../src/features/rescue/persistence/rescue-repository';
import { type AuthService } from '../src/services/auth/auth-service';
import { createRescueReadService } from '../src/services/rescue/rescue-read-service';
import {
  buildTestConfig,
  CASE_ID,
  makeRescueCase,
  OWNER_USER_ID,
} from './helpers/rescue-read-fixtures';

type ReadRepository = Pick<
  RescueRepository,
  'listPublicCases' | 'findPublicCase'
>;

const openApps: Array<ReturnType<typeof buildApp>> = [];

afterEach(async () => {
  await Promise.all(openApps.splice(0).map(async (app) => app.close()));
});

const buildHarness = async (
  options: {
    listFailure?: Error;
    detailFailure?: Error;
    caseFound?: boolean;
  } = {},
) => {
  const rescueCase = makeRescueCase();
  const listPublicCases = jest.fn(async () => {
    if (options.listFailure) throw options.listFailure;
    return {
      items: [{ rescueCase, distanceMeters: 42 }],
      nextCursor: {
        sort: 'recent' as const,
        lostAt: rescueCase.lostAt,
        caseId: rescueCase.caseId,
      },
      limit: 1,
    };
  });
  const findPublicCase = jest.fn(async () => {
    if (options.detailFailure) throw options.detailFailure;
    return options.caseFound === false ? undefined : rescueCase;
  });
  const repository: ReadRepository = {
    listPublicCases,
    findPublicCase,
  };
  const verifyAccessToken = jest.fn(async (accessToken: string) => {
    if (accessToken !== 'owner-token') {
      throw new Error('invalid optional bearer');
    }
    return { userId: OWNER_USER_ID, email: 'owner@example.test' };
  });
  const authService = { verifyAccessToken } as unknown as AuthService;
  const app = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      authService,
      rescueReadService: createRescueReadService({ repository }),
    },
  );
  openApps.push(app);
  await app.ready();
  return {
    app,
    findPublicCase,
    listPublicCases,
    verifyAccessToken,
  };
};

const expectedCommonFields = {
  caseId: CASE_ID,
  petName: 'Golden',
  species: 'dog',
  status: 'missing',
  lostAt: '2026-07-20T09:00:00.000Z',
  publicLocation: {
    areaLabel: 'Thao Dien, Thu Duc',
    approximateLatitude: 10.8021,
    approximateLongitude: 106.7339,
    privacyRadiusMeters: 500,
  },
  media: [
    {
      mediaId: '44444444-4444-4444-8444-444444444444',
      mimeType: 'image/jpeg',
      publicUrl: 'https://cdn.example.test/rescue/golden.jpg',
      createdAt: '2026-07-20T08:00:00.000Z',
      width: 1_200,
      height: 800,
    },
  ],
  commentCount: 3,
  createdAt: '2026-07-20T09:05:00.000Z',
  updatedAt: '2026-07-20T09:10:00.000Z',
  breedOrColor: 'Golden Retriever mau vang',
  ageLabel: '2 tuoi',
};

const expectedAnonymousSummary = {
  ...expectedCommonFields,
  distanceMeters: 42,
};

describe('Day 35 rescue read routes', () => {
  it('returns the exact anonymous list envelope and public cache headers', async () => {
    const { app, listPublicCases, verifyAccessToken } = await buildHarness();

    const response = await app.inject({
      method: 'GET',
      url: '/rescue/cases?limit=1',
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.headers.vary).toBe('Authorization');
    expect(response.json()).toEqual({
      data: [expectedAnonymousSummary],
      pageInfo: {
        nextCursor: expect.any(String),
        hasMore: true,
        limit: 1,
      },
    });
    expect(listPublicCases).toHaveBeenCalledWith(
      expect.objectContaining({ sort: 'recent', limit: 1 }),
    );
    expect(verifyAccessToken).not.toHaveBeenCalled();
    expect(JSON.stringify(response.json())).not.toMatch(
      /ownerUserId|sourceDraftId|privateLocation|contactPreference|storageKey|sha256/,
    );
  });

  it('treats an invalid optional bearer as anonymous', async () => {
    const { app, verifyAccessToken } = await buildHarness();

    const listResponse = await app.inject({
      method: 'GET',
      url: '/rescue/cases?limit=1',
      headers: { authorization: 'Bearer invalid-token' },
    });
    const detailResponse = await app.inject({
      method: 'GET',
      url: `/rescue/cases/${CASE_ID}`,
      headers: { authorization: 'Bearer invalid-token' },
    });

    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data[0]).not.toHaveProperty('viewerPermissions');
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.json().data.viewerPermissions).toEqual({
      canComment: false,
      canUpdateStatus: false,
      canViewPrivateContact: false,
    });
    expect(verifyAccessToken).toHaveBeenCalledTimes(2);
    expect(verifyAccessToken).toHaveBeenCalledWith('invalid-token');
  });

  it('returns owner-scoped permissions for a valid bearer without exposing private contact', async () => {
    const { app, verifyAccessToken } = await buildHarness();

    const listResponse = await app.inject({
      method: 'GET',
      url: '/rescue/cases?limit=1',
      headers: { authorization: 'Bearer owner-token' },
    });
    const detailResponse = await app.inject({
      method: 'GET',
      url: `/rescue/cases/${CASE_ID}`,
      headers: { authorization: 'Bearer owner-token' },
    });

    expect(listResponse.statusCode).toBe(200);
    expect(listResponse.json().data[0].viewerPermissions).toEqual({
      canComment: true,
      canUpdateStatus: true,
      canViewPrivateContact: false,
    });
    expect(detailResponse.statusCode).toBe(200);
    expect(detailResponse.headers['cache-control']).toBe('no-store');
    expect(detailResponse.headers.vary).toBe('Authorization');
    expect(detailResponse.json()).toEqual({
      data: {
        ...expectedCommonFields,
        version: 1,
        identifyingFeatures: 'Deo vong co mau xanh mint.',
        behaviorHint: 'Than thien nhung de hoang so.',
        viewerPermissions: {
          canComment: true,
          canUpdateStatus: true,
          canViewPrivateContact: false,
        },
      },
    });
    expect(detailResponse.json().data).not.toHaveProperty('contactChannel');
    expect(JSON.stringify(detailResponse.json())).not.toMatch(
      /ownerUserId|privateLocation|contactPreference|formattedAddress/,
    );
    expect(verifyAccessToken).toHaveBeenCalledTimes(2);
    expect(verifyAccessToken).toHaveBeenCalledWith('owner-token');
  });

  it('returns exact RESCUE_004 and RESCUE_003 error envelopes', async () => {
    const { app } = await buildHarness({ caseFound: false });

    const invalidList = await app.inject({
      method: 'GET',
      url: '/rescue/cases?status=open',
    });
    const missingDetail = await app.inject({
      method: 'GET',
      url: `/rescue/cases/${CASE_ID}`,
    });

    expect(invalidList.statusCode).toBe(400);
    expect(invalidList.json()).toEqual({
      success: false,
      error: {
        code: RESCUE_ERROR_CODES.invalidInput,
        message: 'status chi nhan missing hoac found.',
        field: 'status',
      },
      requestId: expect.any(String),
    });
    expect(missingDetail.statusCode).toBe(404);
    expect(missingDetail.json()).toEqual({
      success: false,
      error: {
        code: RESCUE_ERROR_CODES.notFound,
        message: 'Khong tim thay tin tim thu cung.',
      },
      requestId: expect.any(String),
    });
  });

  it('sanitizes unexpected repository failures as SYS_001 without leaking details', async () => {
    const secretFailure = new Error(
      'postgresql://admin:super-secret@private-db.internal/pawmate',
    );
    const { app } = await buildHarness({ listFailure: secretFailure });

    const response = await app.inject({
      method: 'GET',
      url: '/rescue/cases',
    });

    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({
      success: false,
      error: {
        code: 'SYS_001',
        message: 'Da co loi he thong. Vui long thu lai.',
      },
      requestId: expect.any(String),
    });
    expect(response.body).not.toContain('super-secret');
    expect(response.body).not.toContain('private-db.internal');
  });
});

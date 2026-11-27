import { buildApp } from '../src/app';
import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { type AdoptionService } from '../src/services/adoption/adoption-service';
import { type AuthService } from '../src/services/auth/auth-service';
import { buildTestConfig } from './helpers/rescue-read-fixtures';
import {
  ADOPTER_USER_ID,
  LISTING_ID,
  makeAdoptionListing,
  REQUEST_ID,
  SHELTER_USER_ID,
  THREAD_ID,
} from './helpers/adoption-fixtures';

const openApps: Array<ReturnType<typeof buildApp>> = [];
const protectedEndpoints: Array<{
  method: 'GET' | 'POST';
  url: string;
}> = [
  { method: 'GET', url: '/adoption/requests' },
  { method: 'GET', url: '/adoption/listings' },
  { method: 'GET', url: `/adoption/listings/${LISTING_ID}` },
  { method: 'POST', url: `/adoption/listings/${LISTING_ID}/decisions` },
  { method: 'POST', url: `/adoption/listings/${LISTING_ID}/requests` },
];

afterEach(async () => {
  await Promise.all(openApps.splice(0).map(async (app) => app.close()));
});

const buildHarness = async () => {
  const verifyAccessToken = jest.fn(async (token: string) => {
    if (token !== 'adopter-token') {
      throw new AppError(
        AUTH_ERROR_CODES.unauthorized,
        'Access token khong hop le.',
        401,
      );
    }
    return { userId: ADOPTER_USER_ID, email: 'adopter@example.test' };
  });
  const listListings = jest.fn(async () => ({
    items: [makeAdoptionListing()],
    nextCursor: 'next-listing',
    limit: 1,
  }));
  const listRequests = jest.fn(async () => [
    {
      requestId: REQUEST_ID,
      listingId: LISTING_ID,
      petName: 'Golden',
      status: 'submitted' as const,
      listingAvailability: 'available' as const,
      threadId: THREAD_ID,
      createdAt: '2026-07-27T08:00:00.000Z',
      updatedAt: '2026-07-27T08:00:00.000Z',
    },
  ]);
  const getListing = jest.fn(async () => makeAdoptionListing());
  const recordDecision = jest.fn(async () => ({
    listingId: LISTING_ID,
    adopterUserId: ADOPTER_USER_ID,
    decision: 'like' as const,
    createdAt: '2026-07-27T08:00:00.000Z',
  }));
  const createRequest = jest.fn(async () => ({
    requestId: REQUEST_ID,
    listingId: LISTING_ID,
    adopterUserId: ADOPTER_USER_ID,
    shelterId: SHELTER_USER_ID,
    livingCondition: 'Can ho',
    petExperience: 'Da nuoi cho',
    carePlan: 'Kham dinh ky',
    commitmentAccepted: true as const,
    status: 'submitted' as const,
    threadId: THREAD_ID,
    createdAt: '2026-07-27T08:00:00.000Z',
  }));
  const app = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      authService: { verifyAccessToken } as unknown as AuthService,
      adoptionService: {
        listRequests,
        listListings,
        getListing,
        recordDecision,
        createRequest,
      } as unknown as AdoptionService,
    },
  );
  openApps.push(app);
  await app.ready();
  return {
    app,
    verifyAccessToken,
    listRequests,
    listListings,
    getListing,
    recordDecision,
    createRequest,
  };
};

describe('Day 50 Adoption routes', () => {
  it.each(protectedEndpoints)(
    'requires authentication for $method $url',
    async ({ method, url }) => {
      const { app } = await buildHarness();

      const response = await app.inject({ method, url });

      expect(response.statusCode).toBe(401);
      expect(response.json()).toMatchObject({
        success: false,
        error: { code: AUTH_ERROR_CODES.unauthorized },
      });
    },
  );

  it('returns only the authenticated adopter request summaries', async () => {
    const { app, listRequests } = await buildHarness();

    const response = await app.inject({
      method: 'GET',
      url: '/adoption/requests',
      headers: { authorization: 'Bearer adopter-token' },
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toEqual({
      data: [
        {
          requestId: REQUEST_ID,
          listingId: LISTING_ID,
          petName: 'Golden',
          status: 'submitted',
          listingAvailability: 'available',
          threadId: THREAD_ID,
          createdAt: '2026-07-27T08:00:00.000Z',
          updatedAt: '2026-07-27T08:00:00.000Z',
        },
      ],
    });
    expect(listRequests).toHaveBeenCalledWith(ADOPTER_USER_ID);
  });

  it('returns the authenticated swipe deck with opaque pageInfo', async () => {
    const { app, listListings } = await buildHarness();

    const response = await app.inject({
      method: 'GET',
      url: '/adoption/listings?species=dog&limit=1',
      headers: { authorization: 'Bearer adopter-token' },
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toMatchObject({
      data: [{ listingId: LISTING_ID }],
      pageInfo: { nextCursor: 'next-listing', hasMore: true, limit: 1 },
    });
    expect(listListings).toHaveBeenCalledWith(
      ADOPTER_USER_ID,
      expect.objectContaining({ species: 'dog', limit: '1' }),
    );
  });

  it('returns canonical profile detail', async () => {
    const { app, getListing } = await buildHarness();

    const response = await app.inject({
      method: 'GET',
      url: `/adoption/listings/${LISTING_ID}`,
      headers: { authorization: 'Bearer adopter-token' },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      data: { listingId: LISTING_ID, shelterId: SHELTER_USER_ID },
    });
    expect(getListing).toHaveBeenCalledWith(ADOPTER_USER_ID, LISTING_ID);
  });

  it('forwards decision Idempotency-Key and returns 201', async () => {
    const { app, recordDecision } = await buildHarness();

    const response = await app.inject({
      method: 'POST',
      url: `/adoption/listings/${LISTING_ID}/decisions`,
      headers: {
        authorization: 'Bearer adopter-token',
        'idempotency-key': 'decision-key',
      },
      payload: { decision: 'like' },
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      data: { listingId: LISTING_ID, decision: 'like' },
    });
    expect(recordDecision).toHaveBeenCalledWith(
      ADOPTER_USER_ID,
      LISTING_ID,
      { decision: 'like' },
      'decision-key',
    );
  });

  it('creates a persisted request and minimal participant thread', async () => {
    const { app, createRequest } = await buildHarness();
    const payload = {
      livingCondition: 'Can ho',
      petExperience: 'Da nuoi cho',
      carePlan: 'Kham dinh ky',
      commitmentAccepted: true,
    };

    const response = await app.inject({
      method: 'POST',
      url: `/adoption/listings/${LISTING_ID}/requests`,
      headers: {
        authorization: 'Bearer adopter-token',
        'idempotency-key': 'request-key',
      },
      payload,
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      data: {
        requestId: REQUEST_ID,
        listingId: LISTING_ID,
        threadId: THREAD_ID,
        status: 'submitted',
      },
    });
    expect(createRequest).toHaveBeenCalledWith(
      ADOPTER_USER_ID,
      LISTING_ID,
      payload,
      'request-key',
    );
  });
});

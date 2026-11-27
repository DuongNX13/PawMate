import { AppError } from '../src/errors/app-error';
import {
  ADOPTION_ERROR_CODES,
  IDEMPOTENCY_ERROR_CODES,
} from '../src/errors/error-codes';
import { AdoptionPersistenceDomainError } from '../src/features/adoption/persistence/adoption-repository';
import {
  toAdoptionListingDetail,
  toAdoptionListingSummary,
} from '../src/services/adoption/adoption-mapper';
import { createAdoptionService } from '../src/services/adoption/adoption-service';
import {
  ADOPTER_USER_ID,
  buildAdoptionRepositoryMock,
  LISTING_ID,
  makeAdoptionListing,
  REQUEST_ID,
  SHELTER_USER_ID,
  THREAD_ID,
} from './helpers/adoption-fixtures';

const NOW = new Date('2026-07-27T08:00:00.000Z');

describe('Day 50 Adoption mapper', () => {
  it('normalizes legacy persistence species and emits the canonical listingId', () => {
    const summary = toAdoptionListingSummary(
      makeAdoptionListing({ species: 'rabbit', distanceMeters: 1_230 }),
    );

    expect(summary).toMatchObject({
      listingId: LISTING_ID,
      species: 'other',
      distanceKm: 1.2,
      shelterId: SHELTER_USER_ID,
    });
    expect(summary).not.toHaveProperty('id');
    expect(summary).not.toHaveProperty('petId');
  });

  it('derives viewer permissions from listing ownership and status', () => {
    expect(
      toAdoptionListingDetail(makeAdoptionListing(), ADOPTER_USER_ID)
        .viewerPermissions,
    ).toEqual({
      canLike: true,
      canRequest: true,
      canManageListing: false,
    });
    expect(
      toAdoptionListingDetail(makeAdoptionListing(), SHELTER_USER_ID)
        .viewerPermissions,
    ).toEqual({
      canLike: false,
      canRequest: false,
      canManageListing: true,
    });
  });
});

describe('Day 50 Adoption service', () => {
  it('returns the authenticated adopter request summaries unchanged', async () => {
    const { repository, listRequestsByAdopter } = buildAdoptionRepositoryMock();
    listRequestsByAdopter.mockResolvedValue([
      {
        requestId: REQUEST_ID,
        listingId: LISTING_ID,
        petName: 'Golden',
        status: 'submitted',
        listingAvailability: 'available',
        threadId: THREAD_ID,
        createdAt: NOW.toISOString(),
        updatedAt: NOW.toISOString(),
      },
    ]);
    const service = createAdoptionService({ repository });

    await expect(service.listRequests(ADOPTER_USER_ID)).resolves.toEqual([
      expect.objectContaining({
        requestId: REQUEST_ID,
        petName: 'Golden',
      }),
    ]);
    expect(listRequestsByAdopter).toHaveBeenCalledWith(ADOPTER_USER_ID);
  });

  it('normalizes filters and binds the opaque cursor to the original filters', async () => {
    const { repository, listListings } = buildAdoptionRepositoryMock();
    listListings.mockResolvedValueOnce({
      items: [makeAdoptionListing()],
      nextCursor: {
        sort: 'curated',
        createdAt: '2026-07-27T00:02:00.000Z',
        listingId: LISTING_ID,
      },
      limit: 1,
    });
    const service = createAdoptionService({ repository });

    const firstPage = await service.listListings(ADOPTER_USER_ID, {
      species: 'dog',
      limit: '1',
    });

    expect(firstPage.items[0]).toMatchObject({ listingId: LISTING_ID });
    expect(firstPage.nextCursor).toEqual(expect.any(String));
    expect(listListings).toHaveBeenCalledWith(
      expect.objectContaining({
        viewerUserId: ADOPTER_USER_ID,
        species: 'dog',
        sort: 'curated',
        limit: 1,
      }),
    );
    await expect(
      service.listListings(ADOPTER_USER_ID, {
        species: 'cat',
        cursor: firstPage.nextCursor,
      }),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      field: 'cursor',
    });
    expect(listListings).toHaveBeenCalledTimes(1);
  });

  it.each([
    [{ lat: 10 }, 'lat'],
    [{ sort: 'distance' }, 'sort'],
    [{ distanceKm: 10 }, 'distanceKm'],
    [{ limit: 51 }, 'limit'],
  ])('rejects invalid list query %p', async (query, field) => {
    const { repository } = buildAdoptionRepositoryMock();
    const service = createAdoptionService({ repository });

    await expect(
      service.listListings(ADOPTER_USER_ID, query),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      field,
    });
  });

  it('requires canonical UUID listingId for profile reads', async () => {
    const { repository, findListing } = buildAdoptionRepositoryMock();
    const service = createAdoptionService({ repository });

    await expect(
      service.getListing(ADOPTER_USER_ID, 'pet-123'),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.notFound,
    });
    expect(findListing).not.toHaveBeenCalled();
  });

  it('requires Idempotency-Key before recording a swipe outcome', async () => {
    const { repository, recordDecision } = buildAdoptionRepositoryMock();
    const service = createAdoptionService({ repository, now: () => NOW });

    await expect(
      service.recordDecision(
        ADOPTER_USER_ID,
        LISTING_ID,
        { decision: 'like' },
        undefined,
      ),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      field: 'Idempotency-Key',
    });
    expect(recordDecision).not.toHaveBeenCalled();
  });

  it('creates a normalized persistent request with a participant thread', async () => {
    const { repository, createRequest } = buildAdoptionRepositoryMock();
    createRequest.mockResolvedValue({
      requestId: REQUEST_ID,
      listingId: LISTING_ID,
      adopterUserId: ADOPTER_USER_ID,
      shelterId: SHELTER_USER_ID,
      livingCondition: 'Can ho rong rai',
      petExperience: 'Da cham soc cho',
      carePlan: 'Kham dinh ky',
      commitmentAccepted: true,
      status: 'submitted',
      threadId: THREAD_ID,
      createdAt: NOW.toISOString(),
      updatedAt: NOW.toISOString(),
    });
    const service = createAdoptionService({ repository, now: () => NOW });

    const result = await service.createRequest(
      ADOPTER_USER_ID,
      LISTING_ID,
      {
        livingCondition: '  Can ho rong rai  ',
        petExperience: ' Da cham soc cho ',
        carePlan: ' Kham dinh ky ',
        commitmentAccepted: true,
      },
      'request-key',
    );

    expect(result).toMatchObject({
      requestId: REQUEST_ID,
      listingId: LISTING_ID,
      threadId: THREAD_ID,
      status: 'submitted',
    });
    expect(createRequest).toHaveBeenCalledWith(
      expect.objectContaining({
        livingCondition: 'Can ho rong rai',
        petExperience: 'Da cham soc cho',
        carePlan: 'Kham dinh ky',
        commitmentAccepted: true,
        idempotency: expect.objectContaining({
          normalizedPath: `/adoption/listings/${LISTING_ID}/requests`,
        }),
      }),
    );
  });

  it('rejects false commitment before touching persistence', async () => {
    const { repository, createRequest } = buildAdoptionRepositoryMock();
    const service = createAdoptionService({ repository });

    await expect(
      service.createRequest(
        ADOPTER_USER_ID,
        LISTING_ID,
        {
          livingCondition: 'Can ho',
          petExperience: 'Da nuoi cho',
          carePlan: 'Kham dinh ky',
          commitmentAccepted: false,
        },
        'request-key',
      ),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      field: 'commitmentAccepted',
    });
    expect(createRequest).not.toHaveBeenCalled();
  });

  it.each([
    [
      new AdoptionPersistenceDomainError(
        'duplicate_active_request',
        'duplicate',
      ),
      ADOPTION_ERROR_CODES.duplicateActiveRequest,
    ],
    [
      new AdoptionPersistenceDomainError('idempotency_conflict', 'conflict'),
      IDEMPOTENCY_ERROR_CODES.payloadConflict,
    ],
    [
      new AdoptionPersistenceDomainError('self_listing', 'self'),
      ADOPTION_ERROR_CODES.selfListing,
    ],
  ])(
    'maps persistence failure %s to the public contract',
    async (error, code) => {
      const { repository, createRequest } = buildAdoptionRepositoryMock();
      createRequest.mockRejectedValue(error);
      const service = createAdoptionService({ repository });

      await expect(
        service.createRequest(
          ADOPTER_USER_ID,
          LISTING_ID,
          {
            livingCondition: 'Can ho',
            petExperience: 'Da nuoi cho',
            carePlan: 'Kham dinh ky',
            commitmentAccepted: true,
          },
          'request-key',
        ),
      ).rejects.toMatchObject({ code });
    },
  );

  it('fails closed when production persistence is absent', async () => {
    const service = createAdoptionService({});

    await expect(service.listRequests(ADOPTER_USER_ID)).rejects.toThrow(
      'Adoption persistence is unavailable.',
    );
    await expect(service.listListings(ADOPTER_USER_ID)).rejects.toThrow(
      'Adoption persistence is unavailable.',
    );
  });
});

describe('Day 50 Adoption AppError contract', () => {
  it('keeps public errors typed as AppError', () => {
    const error = new AppError(
      ADOPTION_ERROR_CODES.invalidInput,
      'invalid',
      400,
      'field',
    );

    expect(error).toBeInstanceOf(AppError);
  });
});

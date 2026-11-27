import {
  type AdoptionListingRecord,
  type AdoptionRepository,
} from '../../src/features/adoption/persistence/adoption-repository';

export const ADOPTER_USER_ID = '51000000-0000-4000-8000-000000000001';
export const SHELTER_USER_ID = '51000000-0000-4000-8000-000000000002';
export const LISTING_ID = '51000000-0000-4000-8000-000000000003';
export const MEDIA_ID = '51000000-0000-4000-8000-000000000004';
export const REQUEST_ID = '51000000-0000-4000-8000-000000000005';
export const THREAD_ID = '51000000-0000-4000-8000-000000000006';

export const makeAdoptionListing = (
  overrides: Partial<AdoptionListingRecord> = {},
): AdoptionListingRecord => ({
  listingId: LISTING_ID,
  shelterId: SHELTER_USER_ID,
  petName: 'Golden',
  species: 'dog',
  breed: 'Golden Retriever',
  ageLabel: '2 thang tuoi',
  description: 'Hien lanh va than thien.',
  traits: ['hien lanh', 'than thien'],
  healthBadges: ['da tiem phong'],
  verificationBadges: ['mai am da xac minh'],
  heroMedia: {
    mediaId: MEDIA_ID,
    ownerUserId: SHELTER_USER_ID,
    purpose: 'adoption_listing',
    mimeType: 'image/webp',
    sizeBytes: 4_096,
    sha256: '5'.repeat(64),
    status: 'verified',
    publicUrl: 'https://cdn.example.test/adoption/golden.webp',
    width: 1_200,
    height: 900,
    createdAt: '2026-07-27T00:01:00.000Z',
  },
  status: 'available',
  createdAt: '2026-07-27T00:02:00.000Z',
  updatedAt: '2026-07-27T00:02:00.000Z',
  ...overrides,
});

export const buildAdoptionRepositoryMock = () => {
  const listListings = jest.fn<
    ReturnType<AdoptionRepository['listListings']>,
    Parameters<AdoptionRepository['listListings']>
  >();
  listListings.mockResolvedValue({ items: [], limit: 20 });
  const findListing = jest.fn<
    ReturnType<AdoptionRepository['findListing']>,
    Parameters<AdoptionRepository['findListing']>
  >();
  findListing.mockResolvedValue(undefined);
  const listRequestsByAdopter = jest.fn<
    ReturnType<AdoptionRepository['listRequestsByAdopter']>,
    Parameters<AdoptionRepository['listRequestsByAdopter']>
  >();
  listRequestsByAdopter.mockResolvedValue([]);
  const recordDecision = jest.fn<
    ReturnType<AdoptionRepository['recordDecision']>,
    Parameters<AdoptionRepository['recordDecision']>
  >();
  const createRequest = jest.fn<
    ReturnType<AdoptionRepository['createRequest']>,
    Parameters<AdoptionRepository['createRequest']>
  >();
  const repository: AdoptionRepository = {
    listListings,
    findListing,
    listRequestsByAdopter,
    recordDecision,
    createRequest,
  };
  return {
    repository,
    listListings,
    findListing,
    listRequestsByAdopter,
    recordDecision,
    createRequest,
  };
};

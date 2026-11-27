export type AdoptionReadSpecies = 'dog' | 'cat' | 'other';
export type AdoptionReadSort = 'curated' | 'distance';
export type AdoptionReadAgeGroup = 'under_1' | 'one_to_three' | 'over_three';
export type AdoptionListingStatus =
  | 'available'
  | 'pending'
  | 'adopted'
  | 'closed';
export type AdoptionDecision = 'skip' | 'like';
export type AdoptionRequestStatus =
  | 'submitted'
  | 'reviewing'
  | 'approved'
  | 'rejected'
  | 'cancelled';
export type AdoptionRequestListingAvailability =
  | 'available'
  | 'unavailable'
  | 'expired'
  | 'deleted';

export type AdoptionMediaRecord = {
  mediaId: string;
  ownerUserId: string;
  purpose: 'adoption_listing';
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  status:
    | 'requested'
    | 'uploaded'
    | 'verified'
    | 'attached'
    | 'rejected'
    | 'deleted';
  publicUrl?: string;
  width?: number;
  height?: number;
  durationSeconds?: number;
  createdAt: string;
};

export type AdoptionListingRecord = {
  listingId: string;
  shelterId: string;
  petName: string;
  species: 'dog' | 'cat' | 'bird' | 'rabbit' | 'other';
  breed?: string;
  ageLabel: string;
  description?: string;
  traits: string[];
  healthBadges: string[];
  verificationBadges: string[];
  heroMedia: AdoptionMediaRecord;
  status: AdoptionListingStatus;
  createdAt: string;
  updatedAt: string;
  distanceMeters?: number;
};

export type AdoptionListingCursor =
  | {
      sort: 'curated';
      createdAt: string;
      listingId: string;
    }
  | {
      sort: 'distance';
      distanceMeters: number;
      listingId: string;
    };

export type AdoptionListingPage = {
  items: AdoptionListingRecord[];
  nextCursor?: AdoptionListingCursor;
  limit: number;
};

export type AdoptionDecisionRecord = {
  listingId: string;
  adopterUserId: string;
  decision: AdoptionDecision;
  createdAt: string;
};

export type AdoptionRequestRecord = {
  requestId: string;
  listingId: string;
  adopterUserId: string;
  shelterId: string;
  livingCondition: string;
  petExperience: string;
  carePlan: string;
  commitmentAccepted: true;
  status: AdoptionRequestStatus;
  threadId: string;
  createdAt: string;
  updatedAt?: string;
  note?: string;
};

export type AdoptionRequestSummaryRecord = {
  requestId: string;
  listingId: string;
  petName: string;
  status: AdoptionRequestStatus;
  listingAvailability: AdoptionRequestListingAvailability;
  threadId?: string;
  createdAt: string;
  updatedAt: string;
};

export type AdoptionIdempotencyInput = {
  userId: string;
  method: 'POST';
  normalizedPath: string;
  keyHash: string;
  requestHash: string;
  now?: Date;
};

export type AdoptionPersistenceFailure =
  | 'not_found'
  | 'self_listing'
  | 'listing_unavailable'
  | 'duplicate_active_request'
  | 'idempotency_conflict';

export class AdoptionPersistenceDomainError extends Error {
  constructor(
    readonly reason: AdoptionPersistenceFailure,
    message: string,
  ) {
    super(message);
    this.name = 'AdoptionPersistenceDomainError';
  }
}

export interface AdoptionRepository {
  listListings(input: {
    viewerUserId: string;
    species?: AdoptionReadSpecies;
    ageGroup?: AdoptionReadAgeGroup;
    latitude?: number;
    longitude?: number;
    distanceKm?: number;
    sort: AdoptionReadSort;
    cursor?: AdoptionListingCursor;
    limit: number;
  }): Promise<AdoptionListingPage>;

  findListing(listingId: string): Promise<AdoptionListingRecord | undefined>;

  listRequestsByAdopter(
    adopterUserId: string,
  ): Promise<AdoptionRequestSummaryRecord[]>;

  recordDecision(input: {
    listingId: string;
    adopterUserId: string;
    decision: AdoptionDecision;
    idempotency: AdoptionIdempotencyInput;
    now: Date;
  }): Promise<AdoptionDecisionRecord>;

  createRequest(input: {
    listingId: string;
    adopterUserId: string;
    livingCondition: string;
    petExperience: string;
    carePlan: string;
    commitmentAccepted: true;
    note?: string;
    idempotency: AdoptionIdempotencyInput;
    now: Date;
  }): Promise<AdoptionRequestRecord>;
}

export type RescueSpecies = 'dog' | 'cat' | 'bird' | 'rabbit' | 'other';
export type RescueCaseStatus = 'missing' | 'found';
export type RescueReadSpecies = 'dog' | 'cat' | 'other';
export type RescueReadSort = 'recent' | 'distance';
export type RescueContactPreference = 'in_app' | 'phone_with_consent';
export type RescueMediaPurpose =
  | 'pet_profile'
  | 'rescue_case'
  | 'rescue_comment'
  | 'adoption_listing'
  | 'adoption_chat';
export type RescueMediaMimeType =
  | 'image/jpeg'
  | 'image/png'
  | 'image/webp'
  | 'video/mp4';

export type RescuePrivateLocation = {
  latitude: number;
  longitude: number;
  formattedAddress?: string;
};

export type RescueDraftLocation = RescuePrivateLocation & {
  areaLabel: string;
  privacyRadiusMeters: number;
};

export type RescueMediaAssetRecord = {
  mediaId: string;
  ownerUserId: string;
  purpose: RescueMediaPurpose;
  mimeType: RescueMediaMimeType;
  sizeBytes: number;
  sha256: string;
  status:
    | 'requested'
    | 'uploaded'
    | 'verified'
    | 'attached'
    | 'rejected'
    | 'deleted';
  storageKey: string;
  publicUrl?: string;
  width?: number;
  height?: number;
  durationSeconds?: number;
  draftId?: string;
  caseId?: string;
  commentId?: string;
  position?: number;
  verifiedAt?: string;
  verificationVersion: number;
  createdAt: string;
  updatedAt: string;
};

export type RescueCaseDraftRecord = {
  draftId: string;
  ownerUserId: string;
  source?: 'rescue_home' | 'deep_link';
  petName?: string;
  species?: RescueSpecies;
  breedOrColor?: string;
  lostAt?: string;
  exactLocation?: RescuePrivateLocation;
  areaLabel?: string;
  privacyRadiusMeters: number;
  identifyingFeatures?: string;
  behaviorHint?: string;
  contactPreference: RescueContactPreference;
  version: number;
  publishedAt?: string;
  discardedAt?: string;
  media: RescueMediaAssetRecord[];
  createdAt: string;
  updatedAt: string;
};

export type RescueCaseRecord = {
  caseId: string;
  sourceDraftId: string;
  ownerUserId: string;
  petName: string;
  species: RescueSpecies;
  breedOrColor: string;
  ageLabel?: string;
  lostAt: string;
  areaLabel: string;
  approximateLatitude: number;
  approximateLongitude: number;
  privacyRadiusMeters: number;
  identifyingFeatures: string;
  behaviorHint?: string;
  contactPreference: RescueContactPreference;
  status: RescueCaseStatus;
  version: number;
  commentCount: number;
  foundAt?: string;
  privateLocation?: RescuePrivateLocation;
  media: RescueMediaAssetRecord[];
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
};

export type RescueCaseReadCursor =
  | {
      sort: 'recent';
      lostAt: string;
      caseId: string;
    }
  | {
      sort: 'distance';
      distanceMeters: number;
      caseId: string;
    };

export type RescueCaseReadItem = {
  rescueCase: RescueCaseRecord;
  distanceMeters?: number;
};

export type RescueCaseReadPage = {
  items: RescueCaseReadItem[];
  nextCursor?: RescueCaseReadCursor;
  limit: number;
};

export type RescueCommentRecord = {
  commentId: string;
  caseId: string;
  authorUserId: string;
  author: RescueUserSummaryRecord;
  body: string;
  replyToCommentId?: string;
  moderationState: 'visible' | 'pending' | 'hidden';
  media: RescueMediaAssetRecord[];
  createdAt: string;
  updatedAt: string;
};

export type RescueUserSummaryRecord = {
  userId: string;
  displayName: string;
  avatarUrl?: string;
};

export type RescueCommentCursor = {
  createdAt: string;
  commentId: string;
};

export type RescueCommentPage = {
  items: RescueCommentRecord[];
  nextCursor?: RescueCommentCursor;
  limit: number;
};

export type RescueIdempotencyInput = {
  userId: string;
  method: 'POST' | 'PATCH';
  normalizedPath: string;
  keyHash: string;
  requestHash: string;
  now?: Date;
};

export type RescueStoredIdempotencyResponse = {
  responseStatus: number;
  responseBody: unknown;
};

export type RescueMediaUploadSessionRecord = {
  mediaId: string;
  stagingStorageKey: string;
  uploadExpiresAt: string;
  detectedMimeType?: string;
  detectedSizeBytes?: number;
  sanitizedStorageKey?: string;
  sanitizedSha256?: string;
  completedAt?: string;
  rejectedAt?: string;
  rejectionCode?: string;
};

export type RescueMediaUploadRequestRecord = {
  media: RescueMediaAssetRecord;
  uploadUrl: string;
  uploadHeaders: Record<string, string>;
  expiresAt: string;
};

export type UpdateRescueDraftPatch = {
  petName?: string | null;
  species?: RescueSpecies | null;
  breedOrColor?: string | null;
  lostAt?: string | null;
  location?: RescueDraftLocation | null;
  identifyingFeatures?: string | null;
  behaviorHint?: string | null;
  contactPreference?: RescueContactPreference;
  mediaIds?: string[];
};

export { RescuePersistenceConflictError } from './rescue-persistence-conflict-error';
export { RescuePersistenceInvariantError } from './rescue-persistence-invariant-error';
export { RescuePersistenceNotFoundError } from './rescue-persistence-not-found-error';
export {
  RescuePersistenceDomainError,
  type RescuePersistenceDomainFailure,
} from './rescue-persistence-domain-error';

export interface RescueRepository {
  listPublicCases(input: {
    status?: RescueCaseStatus;
    species?: RescueReadSpecies;
    lostFrom?: Date;
    lostTo?: Date;
    latitude?: number;
    longitude?: number;
    radiusMeters?: number;
    sort: RescueReadSort;
    cursor?: RescueCaseReadCursor;
    limit: number;
  }): Promise<RescueCaseReadPage>;

  findPublicCase(caseId: string): Promise<RescueCaseRecord | undefined>;

  createDraft(input: {
    ownerUserId: string;
    source?: 'rescue_home' | 'deep_link';
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }): Promise<RescueCaseDraftRecord>;

  findOwnedDraft(
    ownerUserId: string,
    draftId: string,
  ): Promise<RescueCaseDraftRecord | undefined>;

  updateDraft(input: {
    ownerUserId: string;
    draftId: string;
    expectedVersion: number;
    patch: UpdateRescueDraftPatch;
    now?: Date;
  }): Promise<RescueCaseDraftRecord>;

  registerVerifiedMedia(input: {
    ownerUserId: string;
    purpose: 'rescue_case' | 'rescue_comment';
    mimeType: RescueMediaMimeType;
    sizeBytes: number;
    sha256: string;
    storageKey: string;
    publicUrl?: string;
    width?: number;
    height?: number;
    durationSeconds?: number;
    now?: Date;
  }): Promise<RescueMediaAssetRecord>;

  attachVerifiedMediaToDraft(input: {
    ownerUserId: string;
    draftId: string;
    mediaId: string;
    position: number;
    now?: Date;
  }): Promise<RescueMediaAssetRecord>;

  publishDraft(input: {
    ownerUserId: string;
    draftId: string;
    expectedVersion: number;
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }): Promise<RescueCaseRecord>;

  findOwnedCase(
    ownerUserId: string,
    caseId: string,
  ): Promise<RescueCaseRecord | undefined>;

  createComment(input: {
    authorUserId: string;
    caseId: string;
    body: string;
    replyToCommentId?: string;
    mediaIds?: string[];
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }): Promise<RescueCommentRecord>;

  listComments(input: {
    caseId: string;
    cursor?: RescueCommentCursor;
    limit: number;
  }): Promise<RescueCommentPage>;

  updateCaseStatus(input: {
    ownerUserId: string;
    caseId: string;
    expectedVersion: number;
    status: 'found';
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }): Promise<RescueCaseRecord>;

  findIdempotencyResponse(
    input: RescueIdempotencyInput,
  ): Promise<RescueStoredIdempotencyResponse | undefined>;

  createMediaUploadRequest(input: {
    mediaId: string;
    ownerUserId: string;
    purpose: RescueMediaPurpose;
    mimeType: RescueMediaMimeType;
    sizeBytes: number;
    sha256: string;
    stagingStorageKey: string;
    uploadExpiresAt: Date;
    uploadUrl: string;
    uploadHeaders: Record<string, string>;
    idempotency: RescueIdempotencyInput;
    now?: Date;
  }): Promise<RescueMediaUploadRequestRecord>;

  findOwnedMediaUpload(
    ownerUserId: string,
    mediaId: string,
  ): Promise<
    | {
        media: RescueMediaAssetRecord;
        session: RescueMediaUploadSessionRecord;
      }
    | undefined
  >;

  completeMediaUpload(input: {
    ownerUserId: string;
    mediaId: string;
    detectedMimeType: RescueMediaMimeType;
    detectedSizeBytes: number;
    sanitizedStorageKey: string;
    sanitizedSha256: string;
    publicUrl?: string;
    width?: number;
    height?: number;
    durationSeconds?: number;
    idempotency: RescueIdempotencyInput;
    now?: Date;
  }): Promise<RescueMediaAssetRecord>;

  rejectMediaUpload(input: {
    ownerUserId: string;
    mediaId: string;
    rejectionCode: string;
    now?: Date;
  }): Promise<void>;
}

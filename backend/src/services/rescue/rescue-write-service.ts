import { createHash } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import {
  IDEMPOTENCY_ERROR_CODES,
  RESCUE_ERROR_CODES,
} from '../../errors/error-codes';
import {
  RescuePersistenceConflictError,
  RescuePersistenceDomainError,
  RescuePersistenceInvariantError,
  RescuePersistenceNotFoundError,
  type RescueCaseDraftRecord,
  type RescueCommentCursor,
  type RescueCommentRecord,
  type RescueIdempotencyInput,
  type RescueMediaAssetRecord,
  type RescueRepository,
  type UpdateRescueDraftPatch,
} from '../../features/rescue/persistence/rescue-repository';
import {
  toRescueCaseDetail,
  type PublicRescueMediaAsset,
  type RescueCaseDetail,
} from './rescue-read-mapper';
import { projectRescueLocationPrivacy } from './rescue-location-privacy';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_DATE_TIME_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?(?:Z|[+-]\d{2}:\d{2})$/;
const MAX_DISCUSSION_LIMIT = 50;
const DEFAULT_DISCUSSION_LIMIT = 20;

type UnknownRecord = Record<string, unknown>;

export type LostCaseDraftDto = {
  draftId: string;
  ownerUserId: string;
  version: number;
  createdAt: string;
  updatedAt: string;
  petName?: string;
  species?: 'dog' | 'cat' | 'other';
  breedOrColor?: string;
  lostAt?: string;
  exactLocation?: {
    latitude: number;
    longitude: number;
    formattedAddress?: string;
  };
  mediaIds?: string[];
  identifyingFeatures?: string;
  behaviorHint?: string;
  contactPreference?: 'in_app' | 'phone_with_consent';
};

export type CaseCommentDto = {
  commentId: string;
  caseId: string;
  author: {
    userId: string;
    displayName: string;
    avatarUrl?: string;
  };
  body: string;
  media: PublicRescueMediaAsset[];
  createdAt: string;
  replyToCommentId?: string;
  moderationState?: 'visible' | 'pending' | 'hidden';
  updatedAt?: string;
};

export type DiscussionResult = {
  items: CaseCommentDto[];
  nextCursor?: string;
  limit: number;
};

const invalidInput = (field: string, message: string): never => {
  throw new AppError(RESCUE_ERROR_CODES.invalidInput, message, 400, field);
};

const asObject = (value: unknown, field = 'body'): UnknownRecord => {
  if (value === undefined) return {};
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalidInput(field, `${field} phai la object hop le.`);
  }
  return value as UnknownRecord;
};

const assertKnownKeys = (value: UnknownRecord, allowed: readonly string[]) => {
  const unexpected = Object.keys(value).find((key) => !allowed.includes(key));
  if (unexpected) {
    invalidInput(unexpected, `Truong ${unexpected} khong duoc ho tro.`);
  }
};

const requireUuid = (value: unknown, field: string, notFound = false) => {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!UUID_PATTERN.test(raw)) {
    if (notFound) {
      throw new AppError(
        RESCUE_ERROR_CODES.notFound,
        'Khong tim thay tai nguyen Rescue.',
        404,
      );
    }
    return invalidInput(field, `${field} khong hop le.`);
  }
  return raw;
};

const requireVersion = (value: unknown, field = 'expectedVersion') => {
  if (!Number.isSafeInteger(value) || Number(value) < 1) {
    return invalidInput(field, `${field} phai la so nguyen tu 1 tro len.`);
  }
  return Number(value);
};

const readBoundedString = (
  value: unknown,
  field: string,
  min: number,
  max: number,
) => {
  if (typeof value !== 'string') {
    return invalidInput(field, `${field} phai la chuoi.`);
  }
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max) {
    return invalidInput(field, `${field} phai dai tu ${min} den ${max} ky tu.`);
  }
  return normalized;
};

const readUuidArray = (value: unknown, field: string) => {
  if (!Array.isArray(value) || value.length > 5) {
    return invalidInput(field, `${field} phai la mang toi da 5 UUID.`);
  }
  const result = value.map((item) => requireUuid(item, field));
  if (new Set(result).size !== result.length) {
    return invalidInput(field, `${field} khong duoc chua phan tu trung.`);
  }
  return result;
};

const readIsoDate = (value: unknown, field: string) => {
  const raw = readBoundedString(value, field, 1, 64);
  if (!ISO_DATE_TIME_PATTERN.test(raw)) {
    return invalidInput(field, `${field} phai la thoi gian ISO-8601.`);
  }
  const parsed = new Date(raw);
  if (!Number.isFinite(parsed.getTime())) {
    return invalidInput(field, `${field} phai la thoi gian ISO-8601.`);
  }
  return parsed.toISOString();
};

const canonicalize = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as UnknownRecord)
        .filter(([, item]) => item !== undefined)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, item]) => [key, canonicalize(item)]),
    );
  }
  return value;
};

const sha256 = (value: string) =>
  createHash('sha256').update(value, 'utf8').digest('hex');

export const buildRescueIdempotencyInput = (input: {
  userId: string;
  method: 'POST' | 'PATCH';
  normalizedPath: string;
  idempotencyKey: unknown;
  payload: unknown;
  now?: Date;
}): RescueIdempotencyInput => {
  const rawKey = input.idempotencyKey;
  if (typeof rawKey !== 'string') {
    invalidInput('Idempotency-Key', 'Thieu header Idempotency-Key.');
  }
  const key = (rawKey as string).trim();
  if (key.length < 1 || key.length > 128) {
    invalidInput(
      'Idempotency-Key',
      'Idempotency-Key phai dai tu 1 den 128 ky tu.',
    );
  }
  return {
    userId: input.userId,
    method: input.method,
    normalizedPath: input.normalizedPath,
    keyHash: sha256(key),
    requestHash: sha256(JSON.stringify(canonicalize(input.payload))),
    now: input.now,
  };
};

const isKnownSpecies = (species: string | undefined) =>
  species === 'dog' || species === 'cat' || species === 'other';

const toDraftDto = (draft: RescueCaseDraftRecord): LostCaseDraftDto => ({
  draftId: draft.draftId,
  ownerUserId: draft.ownerUserId,
  version: draft.version,
  createdAt: draft.createdAt,
  updatedAt: draft.updatedAt,
  ...(draft.petName ? { petName: draft.petName } : {}),
  ...(isKnownSpecies(draft.species)
    ? { species: draft.species as 'dog' | 'cat' | 'other' }
    : {}),
  ...(draft.breedOrColor ? { breedOrColor: draft.breedOrColor } : {}),
  ...(draft.lostAt ? { lostAt: draft.lostAt } : {}),
  ...(draft.exactLocation ? { exactLocation: draft.exactLocation } : {}),
  ...(draft.media.length
    ? { mediaIds: draft.media.map((item) => item.mediaId) }
    : {}),
  ...(draft.identifyingFeatures
    ? { identifyingFeatures: draft.identifyingFeatures }
    : {}),
  ...(draft.behaviorHint ? { behaviorHint: draft.behaviorHint } : {}),
  contactPreference: draft.contactPreference,
});

const toPublicMedia = (
  media: RescueMediaAssetRecord[],
): PublicRescueMediaAsset[] =>
  media.flatMap((item) => {
    if (
      item.status !== 'attached' ||
      item.verificationVersion < 1 ||
      !item.publicUrl
    ) {
      return [];
    }
    return [
      {
        mediaId: item.mediaId,
        mimeType: item.mimeType,
        publicUrl: item.publicUrl,
        createdAt: item.createdAt,
        ...(item.width === undefined ? {} : { width: item.width }),
        ...(item.height === undefined ? {} : { height: item.height }),
        ...(item.durationSeconds === undefined
          ? {}
          : { durationSeconds: item.durationSeconds }),
      },
    ];
  });

const toCommentDto = (comment: RescueCommentRecord): CaseCommentDto => ({
  commentId: comment.commentId,
  caseId: comment.caseId,
  author: comment.author,
  body: comment.body,
  media: toPublicMedia(comment.media),
  createdAt: comment.createdAt,
  ...(comment.replyToCommentId
    ? { replyToCommentId: comment.replyToCommentId }
    : {}),
  moderationState: comment.moderationState,
  updatedAt: comment.updatedAt,
});

const domainPersistenceError = (error: RescuePersistenceDomainError): never => {
  if (error.failure === 'forbidden') {
    throw new AppError(RESCUE_ERROR_CODES.forbidden, error.message, 403);
  }
  if (error.failure === 'not_found') {
    throw new AppError(RESCUE_ERROR_CODES.notFound, error.message, 404);
  }
  if (error.failure === 'invalid_transition') {
    throw new AppError(
      RESCUE_ERROR_CODES.invalidStatusTransition,
      error.message,
      409,
    );
  }
  if (error.failure === 'comments_closed') {
    throw new AppError(RESCUE_ERROR_CODES.commentsClosed, error.message, 409);
  }
  if (error.failure === 'idempotency_conflict') {
    throw new AppError(
      IDEMPOTENCY_ERROR_CODES.payloadConflict,
      error.message,
      409,
    );
  }
  if (error.failure === 'invalid_media') {
    throw new AppError(
      RESCUE_ERROR_CODES.invalidInput,
      error.message,
      400,
      'mediaIds',
    );
  }
  throw new AppError(RESCUE_ERROR_CODES.versionConflict, error.message, 409);
};

const persistenceError = (error: unknown): never => {
  if (error instanceof RescuePersistenceDomainError)
    return domainPersistenceError(error);
  if (error instanceof RescuePersistenceNotFoundError) {
    throw new AppError(RESCUE_ERROR_CODES.notFound, error.message, 404);
  }
  if (error instanceof RescuePersistenceInvariantError) {
    throw new AppError(RESCUE_ERROR_CODES.invalidInput, error.message, 400);
  }
  if (error instanceof RescuePersistenceConflictError) {
    throw new AppError(RESCUE_ERROR_CODES.versionConflict, error.message, 409);
  }
  throw error;
};

const callRepository = async <T>(action: () => Promise<T>) => {
  try {
    return await action();
  } catch (error) {
    return persistenceError(error);
  }
};

const encodeDiscussionCursor = (caseId: string, cursor: RescueCommentCursor) =>
  Buffer.from(
    JSON.stringify({ version: 1, caseId, ...cursor }),
    'utf8',
  ).toString('base64url');

const isDiscussionCursor = (parsed: UnknownRecord, caseId: string) =>
  parsed.version === 1 &&
  parsed.caseId === caseId &&
  typeof parsed.createdAt === 'string' &&
  Number.isFinite(new Date(parsed.createdAt).getTime()) &&
  typeof parsed.commentId === 'string' &&
  UUID_PATTERN.test(parsed.commentId);

const decodeDiscussionCursor = (
  value: unknown,
  caseId: string,
): RescueCommentCursor | undefined => {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !value.trim()) {
    return invalidInput('cursor', 'cursor khong hop le.');
  }
  try {
    const parsed = JSON.parse(
      Buffer.from(value.trim(), 'base64url').toString('utf8'),
    ) as UnknownRecord;
    if (!isDiscussionCursor(parsed, caseId)) {
      return invalidInput('cursor', 'cursor khong hop le cho case nay.');
    }
    return {
      createdAt: new Date(parsed.createdAt as string).toISOString(),
      commentId: parsed.commentId as string,
    };
  } catch {
    return invalidInput('cursor', 'cursor khong hop le.');
  }
};

const requireRepository = (repository?: RescueRepository) => {
  if (!repository) throw new Error('Rescue persistence is unavailable.');
  return repository;
};

const readDraftPetPatch = (body: UnknownRecord): UpdateRescueDraftPatch => {
  const patch: UpdateRescueDraftPatch = {};
  if ('petName' in body)
    patch.petName = readBoundedString(body.petName, 'petName', 1, 50);
  if ('species' in body) {
    if (!['dog', 'cat', 'other'].includes(String(body.species))) {
      invalidInput('species', 'species chi nhan dog, cat hoac other.');
    }
    patch.species = body.species as 'dog' | 'cat' | 'other';
  }
  if ('breedOrColor' in body)
    patch.breedOrColor = readBoundedString(
      body.breedOrColor,
      'breedOrColor',
      1,
      100,
    );
  if ('lostAt' in body) patch.lostAt = readIsoDate(body.lostAt, 'lostAt');
  if ('identifyingFeatures' in body)
    patch.identifyingFeatures = readBoundedString(
      body.identifyingFeatures,
      'identifyingFeatures',
      1,
      500,
    );
  return patch;
};

const readDraftBehavior = (value: unknown) => {
  if (typeof value !== 'string')
    invalidInput('behaviorHint', 'behaviorHint phai la chuoi.');
  const hint = (value as string).trim();
  if (hint.length > 500)
    invalidInput('behaviorHint', 'behaviorHint toi da 500 ky tu.');
  return hint || null;
};

const readDraftContact = (value: unknown) => {
  if (value !== 'in_app' && value !== 'phone_with_consent') {
    invalidInput('contactPreference', 'contactPreference khong hop le.');
  }
  return value as 'in_app' | 'phone_with_consent';
};

const readDraftLocation = (value: unknown) => {
  const location = asObject(value, 'exactLocation');
  assertKnownKeys(location, ['latitude', 'longitude', 'formattedAddress']);
  const { latitude, longitude } = location;
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    invalidInput(
      'exactLocation',
      'exactLocation can latitude va longitude dang so.',
    );
  }
  const formattedAddress =
    location.formattedAddress === undefined
      ? undefined
      : readBoundedString(
          location.formattedAddress,
          'formattedAddress',
          1,
          500,
        );
  try {
    const privacy = projectRescueLocationPrivacy({
      latitude: latitude as number,
      longitude: longitude as number,
      formattedAddress,
    });
    return {
      latitude: latitude as number,
      longitude: longitude as number,
      formattedAddress,
      ...privacy,
    };
  } catch {
    return invalidInput('exactLocation', 'Toa do exactLocation khong hop le.');
  }
};

export const createRescueWriteService = (options: {
  repository?: RescueRepository;
  now?: () => Date;
}) => {
  const now = options.now ?? (() => new Date());
  const repository = () => requireRepository(options.repository);

  return {
    async createDraft(
      userId: string,
      payload: unknown,
      idempotencyKey: unknown,
    ): Promise<LostCaseDraftDto> {
      const body = asObject(payload);
      assertKnownKeys(body, ['source']);
      const { source } = body;
      if (
        source !== undefined &&
        source !== 'rescue_home' &&
        source !== 'deep_link'
      ) {
        invalidInput('source', 'source chi nhan rescue_home hoac deep_link.');
      }
      const commandNow = now();
      const idempotency = buildRescueIdempotencyInput({
        userId,
        method: 'POST',
        normalizedPath: '/rescue/case-drafts',
        idempotencyKey,
        payload: body,
        now: commandNow,
      });
      const draft = await callRepository(() =>
        repository().createDraft({
          ownerUserId: userId,
          source: source as 'rescue_home' | 'deep_link' | undefined,
          idempotency,
          now: commandNow,
        }),
      );
      return toDraftDto(draft);
    },

    async updateDraft(
      userId: string,
      draftId: unknown,
      payload: unknown,
    ): Promise<LostCaseDraftDto> {
      const normalizedDraftId = requireUuid(draftId, 'draftId', true);
      const body = asObject(payload);
      const mutableFields = [
        'petName',
        'species',
        'breedOrColor',
        'lostAt',
        'exactLocation',
        'mediaIds',
        'identifyingFeatures',
        'behaviorHint',
        'contactPreference',
      ] as const;
      assertKnownKeys(body, ['expectedVersion', ...mutableFields]);
      const expectedVersion = requireVersion(body.expectedVersion);
      if (!mutableFields.some((field) => field in body)) {
        invalidInput('body', 'Can it nhat mot truong draft can cap nhat.');
      }

      const patch = readDraftPetPatch(body);
      if ('behaviorHint' in body)
        patch.behaviorHint = readDraftBehavior(body.behaviorHint);
      if ('contactPreference' in body)
        patch.contactPreference = readDraftContact(body.contactPreference);
      if ('mediaIds' in body) {
        patch.mediaIds = readUuidArray(body.mediaIds, 'mediaIds');
      }
      if ('exactLocation' in body) {
        patch.location = readDraftLocation(body.exactLocation);
      }

      const draft = await callRepository(() =>
        repository().updateDraft({
          ownerUserId: userId,
          draftId: normalizedDraftId,
          expectedVersion,
          patch,
          now: now(),
        }),
      );
      return toDraftDto(draft);
    },

    async publishDraft(
      userId: string,
      draftId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ): Promise<RescueCaseDetail> {
      const normalizedDraftId = requireUuid(draftId, 'draftId', true);
      const body = asObject(payload);
      assertKnownKeys(body, ['expectedVersion']);
      const expectedVersion = requireVersion(body.expectedVersion);
      const commandNow = now();
      const idempotency = buildRescueIdempotencyInput({
        userId,
        method: 'POST',
        normalizedPath: `/rescue/case-drafts/${normalizedDraftId}/publish`,
        idempotencyKey,
        payload: body,
        now: commandNow,
      });
      const rescueCase = await callRepository(() =>
        repository().publishDraft({
          ownerUserId: userId,
          draftId: normalizedDraftId,
          expectedVersion,
          idempotency,
          now: commandNow,
        }),
      );
      return toRescueCaseDetail(rescueCase, userId);
    },

    async createComment(
      userId: string,
      caseId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ): Promise<CaseCommentDto> {
      const normalizedCaseId = requireUuid(caseId, 'caseId', true);
      const body = asObject(payload);
      assertKnownKeys(body, ['body', 'mediaIds', 'replyToCommentId']);
      const commentBody = readBoundedString(body.body, 'body', 1, 500);
      const mediaIds =
        body.mediaIds === undefined
          ? undefined
          : readUuidArray(body.mediaIds, 'mediaIds');
      const replyToCommentId =
        body.replyToCommentId === undefined
          ? undefined
          : requireUuid(body.replyToCommentId, 'replyToCommentId');
      const normalizedPayload = {
        body: commentBody,
        ...(mediaIds ? { mediaIds } : {}),
        ...(replyToCommentId ? { replyToCommentId } : {}),
      };
      const commandNow = now();
      const idempotency = buildRescueIdempotencyInput({
        userId,
        method: 'POST',
        normalizedPath: `/rescue/cases/${normalizedCaseId}/comments`,
        idempotencyKey,
        payload: normalizedPayload,
        now: commandNow,
      });
      const comment = await callRepository(() =>
        repository().createComment({
          authorUserId: userId,
          caseId: normalizedCaseId,
          body: commentBody,
          mediaIds,
          replyToCommentId,
          idempotency,
          now: commandNow,
        }),
      );
      return toCommentDto(comment);
    },

    async listDiscussion(
      caseId: unknown,
      query: { cursor?: unknown; limit?: unknown } = {},
    ): Promise<DiscussionResult> {
      const normalizedCaseId = requireUuid(caseId, 'caseId', true);
      let limit: unknown = DEFAULT_DISCUSSION_LIMIT;
      if (query.limit !== undefined) {
        limit =
          typeof query.limit === 'string' && /^\d+$/u.test(query.limit.trim())
            ? Number(query.limit)
            : query.limit;
      }
      if (
        !Number.isSafeInteger(limit) ||
        Number(limit) < 1 ||
        Number(limit) > MAX_DISCUSSION_LIMIT
      ) {
        invalidInput('limit', 'limit phai tu 1 den 50.');
      }
      const cursor = decodeDiscussionCursor(query.cursor, normalizedCaseId);
      const page = await callRepository(() =>
        repository().listComments({
          caseId: normalizedCaseId,
          cursor,
          limit: Number(limit),
        }),
      );
      return {
        items: page.items.map(toCommentDto),
        ...(page.nextCursor
          ? {
              nextCursor: encodeDiscussionCursor(
                normalizedCaseId,
                page.nextCursor,
              ),
            }
          : {}),
        limit: page.limit,
      };
    },

    async updateStatus(
      userId: string,
      caseId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ): Promise<RescueCaseDetail> {
      const normalizedCaseId = requireUuid(caseId, 'caseId', true);
      const body = asObject(payload);
      assertKnownKeys(body, [
        'newStatus',
        'expectedStatus',
        'expectedVersion',
        'confirmedSafe',
      ]);
      if (
        body.newStatus !== 'found' ||
        body.expectedStatus !== 'missing' ||
        body.confirmedSafe !== true
      ) {
        throw new AppError(
          RESCUE_ERROR_CODES.invalidStatusTransition,
          'Chi cho phep missing sang found sau khi xac nhan an toan.',
          409,
        );
      }
      const expectedVersion = requireVersion(body.expectedVersion);
      const normalizedPayload = {
        newStatus: 'found',
        expectedStatus: 'missing',
        expectedVersion,
        confirmedSafe: true,
      };
      const commandNow = now();
      const idempotency = buildRescueIdempotencyInput({
        userId,
        method: 'PATCH',
        normalizedPath: `/rescue/cases/${normalizedCaseId}/status`,
        idempotencyKey,
        payload: normalizedPayload,
        now: commandNow,
      });
      const rescueCase = await callRepository(() =>
        repository().updateCaseStatus({
          ownerUserId: userId,
          caseId: normalizedCaseId,
          expectedVersion,
          status: 'found',
          idempotency,
          now: commandNow,
        }),
      );
      return toRescueCaseDetail(rescueCase, userId);
    },
  };
};

export type RescueWriteService = ReturnType<typeof createRescueWriteService>;

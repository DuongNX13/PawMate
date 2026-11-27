import { $Enums, Prisma, type PrismaClient } from '@prisma/client';

import {
  RescuePersistenceConflictError,
  RescuePersistenceDomainError,
  RescuePersistenceInvariantError,
  RescuePersistenceNotFoundError,
  type RescueCommentCursor,
  type RescueCommentPage,
  type RescueCaseReadCursor,
  type RescueCaseReadPage,
  type RescueCaseDraftRecord,
  type RescueCaseRecord,
  type RescueCommentRecord,
  type RescueIdempotencyInput,
  type RescueMediaAssetRecord,
  type RescueMediaUploadRequestRecord,
  type RescueMediaUploadSessionRecord,
  type RescueRepository,
  type RescueStoredIdempotencyResponse,
  type UpdateRescueDraftPatch,
} from './rescue-repository';
import {
  projectRescueCoordinateCell,
  projectRescueLocationPrivacy,
} from '../../../services/rescue/rescue-location-privacy';

type DraftRow = Prisma.RescueCaseDraftGetPayload<{
  include: { media: true };
}>;
type CaseRow = Prisma.RescueCaseGetPayload<{
  include: { privateLocation: true; media: true };
}>;
type PublicCaseRow = Prisma.RescueCaseGetPayload<{
  include: { media: true };
}>;
type PublicCaseOrderRow = {
  caseId: string;
  lostAt: Date | string;
  distanceMeters: number | string | null;
};
type CommentRow = Prisma.RescueCommentGetPayload<{
  include: {
    media: true;
    author: { select: { id: true; displayName: true; avatarUrl: true } };
  };
}>;

type TransactionClient = Prisma.TransactionClient;

const toIso = (value: Date | null | undefined) => value?.toISOString();
const toNumber = (value: Prisma.Decimal | null | undefined) =>
  value === null || value === undefined ? undefined : value.toNumber();

const mapMedia = (
  row: Prisma.MediaAssetGetPayload<Record<string, never>>,
): RescueMediaAssetRecord => ({
  mediaId: row.id,
  ownerUserId: row.ownerUserId,
  purpose: row.purpose as RescueMediaAssetRecord['purpose'],
  mimeType: row.mimeType as RescueMediaAssetRecord['mimeType'],
  sizeBytes: Number(row.sizeBytes),
  sha256: row.sha256,
  status: row.status,
  storageKey: row.storageKey,
  publicUrl: row.publicUrl ?? undefined,
  width: row.width ?? undefined,
  height: row.height ?? undefined,
  durationSeconds: toNumber(row.durationSeconds),
  draftId: row.draftId ?? undefined,
  caseId: row.caseId ?? undefined,
  commentId: row.commentId ?? undefined,
  position: row.position ?? undefined,
  verifiedAt: toIso(row.verifiedAt),
  verificationVersion: row.verificationVersion,
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
});

const mapDraftLocation = (row: DraftRow) => {
  const latitude = toNumber(row.exactLatitude);
  const longitude = toNumber(row.exactLongitude);
  return latitude !== undefined && longitude !== undefined
    ? {
        latitude,
        longitude,
        formattedAddress: row.formattedAddress ?? undefined,
      }
    : undefined;
};

const mapDraft = (row: DraftRow): RescueCaseDraftRecord => ({
  draftId: row.id,
  ownerUserId: row.ownerUserId,
  source: (row.source as RescueCaseDraftRecord['source']) ?? undefined,
  petName: row.petName ?? undefined,
  species: (row.species as RescueCaseDraftRecord['species']) ?? undefined,
  breedOrColor: row.breedOrColor ?? undefined,
  lostAt: toIso(row.lostAt),
  exactLocation: mapDraftLocation(row),
  areaLabel: row.areaLabel ?? undefined,
  privacyRadiusMeters: row.privacyRadiusMeters,
  identifyingFeatures: row.identifyingFeatures ?? undefined,
  behaviorHint: row.behaviorHint ?? undefined,
  contactPreference: row.contactPreference,
  version: row.version,
  publishedAt: toIso(row.publishedAt),
  discardedAt: toIso(row.discardedAt),
  media: row.media.map(mapMedia),
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
});

const mapCase = (row: CaseRow): RescueCaseRecord => ({
  caseId: row.id,
  sourceDraftId: row.sourceDraftId,
  ownerUserId: row.ownerUserId,
  petName: row.petName,
  species: row.species,
  breedOrColor: row.breedOrColor,
  ageLabel: row.ageLabel ?? undefined,
  lostAt: row.lostAt.toISOString(),
  areaLabel: row.areaLabel,
  approximateLatitude: row.approximateLatitude.toNumber(),
  approximateLongitude: row.approximateLongitude.toNumber(),
  privacyRadiusMeters: row.privacyRadiusMeters,
  identifyingFeatures: row.identifyingFeatures,
  behaviorHint: row.behaviorHint ?? undefined,
  contactPreference: row.contactPreference,
  status: row.status,
  version: row.version,
  commentCount: row.commentCount,
  foundAt: toIso(row.foundAt),
  privateLocation: row.privateLocation
    ? {
        latitude: row.privateLocation.latitude.toNumber(),
        longitude: row.privateLocation.longitude.toNumber(),
        formattedAddress: row.privateLocation.formattedAddress ?? undefined,
      }
    : undefined,
  media: row.media.map(mapMedia),
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
  deletedAt: toIso(row.deletedAt),
});

const mapPublicCase = (row: PublicCaseRow): RescueCaseRecord =>
  mapCase({ ...row, privateLocation: null });

const readDistanceMeters = (value: number | string | null) => {
  if (value === null) return undefined;
  const parsed = typeof value === 'number' ? value : Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? Math.max(0, Math.round(parsed)) : undefined;
};

const readIsoDate = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const mapComment = (row: CommentRow): RescueCommentRecord => ({
  commentId: row.id,
  caseId: row.caseId,
  authorUserId: row.authorUserId,
  author: {
    userId: row.author.id,
    displayName: row.author.displayName?.trim() || 'Thanh vien PawMate',
    avatarUrl: row.author.avatarUrl ?? undefined,
  },
  body: row.body,
  replyToCommentId: row.replyToCommentId ?? undefined,
  moderationState: row.moderationState,
  media: row.media.map(mapMedia),
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
});

const mapUploadSession = (
  row: Prisma.MediaUploadSessionGetPayload<Record<string, never>>,
): RescueMediaUploadSessionRecord => ({
  mediaId: row.mediaId,
  stagingStorageKey: row.stagingStorageKey,
  uploadExpiresAt: row.uploadExpiresAt.toISOString(),
  detectedMimeType: row.detectedMimeType ?? undefined,
  detectedSizeBytes:
    row.detectedSizeBytes === null ? undefined : Number(row.detectedSizeBytes),
  sanitizedStorageKey: row.sanitizedStorageKey ?? undefined,
  sanitizedSha256: row.sanitizedSha256 ?? undefined,
  completedAt: toIso(row.completedAt),
  rejectedAt: toIso(row.rejectedAt),
  rejectionCode: row.rejectionCode ?? undefined,
});

const hasOwn = <T extends object>(value: T, key: keyof T) =>
  Object.prototype.hasOwnProperty.call(value, key);

const buildDraftLocationUpdate = (
  patch: UpdateRescueDraftPatch,
): Prisma.RescueCaseDraftUpdateManyMutationInput => {
  if (!hasOwn(patch, 'location')) return {};
  return {
    exactLatitude: patch.location?.latitude ?? null,
    exactLongitude: patch.location?.longitude ?? null,
    formattedAddress: patch.location?.formattedAddress ?? null,
    areaLabel: patch.location?.areaLabel ?? null,
    privacyRadiusMeters: patch.location?.privacyRadiusMeters ?? 500,
  };
};

const buildDraftUpdate = (patch: UpdateRescueDraftPatch) => {
  const data: Prisma.RescueCaseDraftUpdateManyMutationInput = {};
  if (hasOwn(patch, 'petName')) data.petName = patch.petName;
  if (hasOwn(patch, 'species')) {
    data.species = patch.species as $Enums.PetSpecies | null;
  }
  if (hasOwn(patch, 'breedOrColor')) {
    data.breedOrColor = patch.breedOrColor;
  }
  if (hasOwn(patch, 'lostAt')) {
    data.lostAt = patch.lostAt ? new Date(patch.lostAt) : null;
  }
  if (hasOwn(patch, 'identifyingFeatures')) {
    data.identifyingFeatures = patch.identifyingFeatures;
  }
  if (hasOwn(patch, 'behaviorHint')) {
    data.behaviorHint = patch.behaviorHint;
  }
  if (hasOwn(patch, 'contactPreference')) {
    data.contactPreference = patch.contactPreference;
  }
  return { ...data, ...buildDraftLocationUpdate(patch) };
};

const missingDraftPublishField = (draft: DraftRow) =>
  !draft.petName ||
  !draft.species ||
  !draft.breedOrColor ||
  !draft.lostAt ||
  draft.exactLatitude === null ||
  draft.exactLongitude === null ||
  !draft.areaLabel ||
  !draft.identifyingFeatures;

const requirePublishableDraft = (draft: DraftRow) => {
  if (missingDraftPublishField(draft)) {
    throw new RescuePersistenceInvariantError(
      'Draft is missing a required publish field.',
    );
  }
  const verifiedMedia = draft.media.filter(
    (item) =>
      item.purpose === 'rescue_case' &&
      item.status === 'attached' &&
      item.verifiedAt !== null &&
      item.verificationVersion >= 1 &&
      item.publicUrl !== null &&
      item.deletedAt === null,
  );
  if (verifiedMedia.length < 1 || verifiedMedia.length > 5) {
    throw new RescuePersistenceInvariantError(
      'Draft publish requires between one and five verified media assets.',
    );
  }
  return verifiedMedia;
};

type PublicCaseListInput = Parameters<RescueRepository['listPublicCases']>[0];
const publicCaseFilters = (
  input: PublicCaseListInput,
  locationPoint: Prisma.Sql | undefined,
) => {
  const filters: Prisma.Sql[] = [Prisma.sql`rc.deleted_at IS NULL`];
  if (input.status)
    filters.push(
      Prisma.sql`rc.status = ${input.status}::public."RescueCaseStatus"`,
    );
  if (input.species === 'other') {
    filters.push(
      Prisma.sql`rc.species NOT IN ('dog'::public."PetSpecies", 'cat'::public."PetSpecies")`,
    );
  } else if (input.species) {
    filters.push(
      Prisma.sql`rc.species = ${input.species}::public."PetSpecies"`,
    );
  }
  if (input.lostFrom) filters.push(Prisma.sql`rc.lost_at >= ${input.lostFrom}`);
  if (input.lostTo) filters.push(Prisma.sql`rc.lost_at <= ${input.lostTo}`);
  if (locationPoint)
    filters.push(
      Prisma.sql`ST_DWithin(rc.public_location, ${locationPoint}, ${input.radiusMeters ?? 1_000})`,
    );
  return filters;
};

const requireEditableDraft = (
  current: DraftRow | null,
  input: { ownerUserId: string; expectedVersion: number },
) => {
  if (!current)
    throw new RescuePersistenceDomainError(
      'not_found',
      'Rescue draft was not found.',
    );
  if (current.ownerUserId !== input.ownerUserId) {
    throw new RescuePersistenceDomainError(
      'forbidden',
      'Only the draft owner can update this Rescue draft.',
    );
  }
  if (
    current.version !== input.expectedVersion ||
    current.publishedAt !== null ||
    current.discardedAt !== null
  ) {
    throw new RescuePersistenceDomainError(
      'version_conflict',
      'The Rescue draft changed or is no longer editable.',
    );
  }
};

const mediaCanAttachToDraft = (
  item: Prisma.MediaAssetGetPayload<Record<string, never>>,
  draftId: string,
) =>
  (item.draftId === null && item.status === 'verified') ||
  (item.draftId === draftId && item.status === 'attached');

const isEligibleDraftMedia = (
  item: Prisma.MediaAssetGetPayload<Record<string, never>>,
  ownerUserId: string,
  draftId: string,
) =>
  item.ownerUserId === ownerUserId &&
  item.purpose === 'rescue_case' &&
  item.deletedAt === null &&
  item.verifiedAt !== null &&
  item.verificationVersion >= 1 &&
  item.publicUrl !== null &&
  item.caseId === null &&
  item.commentId === null &&
  mediaCanAttachToDraft(item, draftId);

export class PrismaRescueRepository implements RescueRepository {
  constructor(private readonly prisma: PrismaClient) {}

  private async executeCommand<T>(
    idempotency: RescueIdempotencyInput | undefined,
    responseStatus: number,
    execute: (transaction: TransactionClient) => Promise<T>,
  ): Promise<T> {
    return this.prisma.$transaction(async (transaction) => {
      if (!idempotency) return execute(transaction);

      const now = idempotency.now ?? new Date();
      const lockScope = [
        idempotency.userId,
        idempotency.method,
        idempotency.normalizedPath,
        idempotency.keyHash,
      ].join(':');
      await transaction.$queryRaw<Array<{ locked: boolean }>>`
        SELECT true AS locked
        FROM pg_advisory_xact_lock(hashtextextended(${lockScope}, 0))
      `;

      const identity = {
        userId: idempotency.userId,
        method: idempotency.method,
        normalizedPath: idempotency.normalizedPath,
        keyHash: idempotency.keyHash,
      };
      const existing = await transaction.idempotencyRecord.findUnique({
        where: {
          userId_method_normalizedPath_keyHash: identity,
        },
      });
      if (existing && existing.expiresAt > now) {
        if (existing.requestHash !== idempotency.requestHash) {
          throw new RescuePersistenceDomainError(
            'idempotency_conflict',
            'Idempotency key was already used with a different payload.',
          );
        }
        return existing.responseBody as unknown as T;
      }
      if (existing) {
        await transaction.idempotencyRecord.delete({
          where: { id: existing.id },
        });
      }

      const result = await execute(transaction);
      const responseSnapshot = JSON.parse(
        JSON.stringify(result),
      ) as Prisma.InputJsonValue;
      await transaction.idempotencyRecord.create({
        data: {
          ...identity,
          requestHash: idempotency.requestHash,
          responseStatus,
          responseBody: responseSnapshot,
          createdAt: now,
          expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1_000),
        },
      });
      return result;
    });
  }

  async findIdempotencyResponse(
    input: RescueIdempotencyInput,
  ): Promise<RescueStoredIdempotencyResponse | undefined> {
    const now = input.now ?? new Date();
    const existing = await this.prisma.idempotencyRecord.findUnique({
      where: {
        userId_method_normalizedPath_keyHash: {
          userId: input.userId,
          method: input.method,
          normalizedPath: input.normalizedPath,
          keyHash: input.keyHash,
        },
      },
    });
    if (!existing || existing.expiresAt <= now) return undefined;
    if (existing.requestHash !== input.requestHash) {
      throw new RescuePersistenceDomainError(
        'idempotency_conflict',
        'Idempotency key was already used with a different payload.',
      );
    }
    return {
      responseStatus: existing.responseStatus,
      responseBody: existing.responseBody,
    };
  }

  async listPublicCases(
    input: Parameters<RescueRepository['listPublicCases']>[0],
  ): Promise<RescueCaseReadPage> {
    const hasLocation =
      input.latitude !== undefined && input.longitude !== undefined;
    const locationPoint = hasLocation
      ? Prisma.sql`ST_SetSRID(ST_MakePoint(${input.longitude}, ${input.latitude}), 4326)::geography`
      : undefined;
    const filters = publicCaseFilters(input, locationPoint);

    const distanceExpression = locationPoint
      ? Prisma.sql`ROUND(ST_Distance(rc.public_location, ${locationPoint}))::integer`
      : Prisma.sql`NULL::integer`;
    let cursorPredicate = Prisma.sql`TRUE`;
    if (input.cursor?.sort === 'recent') {
      const cursorLostAt = new Date(input.cursor.lostAt);
      cursorPredicate = Prisma.sql`(
        c."lostAt",
        c."caseId"
      ) < (${cursorLostAt}, ${input.cursor.caseId}::uuid)`;
    } else if (input.cursor?.sort === 'distance') {
      cursorPredicate = Prisma.sql`(
        c."distanceMeters" > ${input.cursor.distanceMeters}
        OR (
          c."distanceMeters" = ${input.cursor.distanceMeters}
          AND c."caseId" > ${input.cursor.caseId}::uuid
        )
      )`;
    }

    const orderBy =
      input.sort === 'distance'
        ? Prisma.sql`c."distanceMeters" ASC, c."caseId" ASC`
        : Prisma.sql`c."lostAt" DESC, c."caseId" DESC`;
    return this.prisma.$transaction(
      async (transaction) => {
        const orderedRows = await transaction.$queryRaw<PublicCaseOrderRow[]>(
          Prisma.sql`
            WITH candidates AS (
              SELECT
                rc.id AS "caseId",
                rc.lost_at AS "lostAt",
                ${distanceExpression} AS "distanceMeters"
              FROM public.rescue_cases rc
              WHERE ${Prisma.join(filters, ' AND ')}
            )
            SELECT c."caseId", c."lostAt", c."distanceMeters"
            FROM candidates c
            WHERE ${cursorPredicate}
            ORDER BY ${orderBy}
            LIMIT ${input.limit + 1}
          `,
        );
        const hasMore = orderedRows.length > input.limit;
        const pageRows = orderedRows.slice(0, input.limit);
        const caseIds = pageRows.map((row) => row.caseId);
        const cases = caseIds.length
          ? await transaction.rescueCase.findMany({
              where: { id: { in: caseIds }, deletedAt: null },
              include: {
                media: {
                  where: {
                    status: 'attached',
                    deletedAt: null,
                    publicUrl: { not: null },
                  },
                  orderBy: { position: 'asc' },
                },
              },
            })
          : [];
        const casesById = new Map(cases.map((row) => [row.id, row]));
        const items = pageRows.flatMap((row) => {
          const rescueCase = casesById.get(row.caseId);
          if (!rescueCase) return [];
          const distanceMeters = readDistanceMeters(row.distanceMeters);
          return [
            {
              rescueCase: mapPublicCase(rescueCase),
              ...(distanceMeters === undefined ? {} : { distanceMeters }),
            },
          ];
        });
        const lastRow = pageRows.at(-1);
        let nextCursor: RescueCaseReadCursor | undefined;
        if (hasMore && lastRow) {
          if (input.sort === 'distance') {
            const distanceMeters = readDistanceMeters(lastRow.distanceMeters);
            if (distanceMeters !== undefined) {
              nextCursor = {
                sort: 'distance',
                distanceMeters,
                caseId: lastRow.caseId,
              };
            }
          } else {
            nextCursor = {
              sort: 'recent',
              lostAt: readIsoDate(lastRow.lostAt),
              caseId: lastRow.caseId,
            };
          }
        }

        return { items, nextCursor, limit: input.limit };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async findPublicCase(caseId: string) {
    const rescueCase = await this.prisma.rescueCase.findFirst({
      where: { id: caseId, deletedAt: null },
      include: {
        media: {
          where: {
            status: 'attached',
            deletedAt: null,
            publicUrl: { not: null },
          },
          orderBy: { position: 'asc' },
        },
      },
    });
    return rescueCase ? mapPublicCase(rescueCase) : undefined;
  }

  async createDraft(input: {
    ownerUserId: string;
    source?: 'rescue_home' | 'deep_link';
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }) {
    const now = input.now ?? new Date();
    if (!input.idempotency) {
      const draft = await this.prisma.rescueCaseDraft.create({
        data: {
          ownerUserId: input.ownerUserId,
          source: input.source,
          createdAt: now,
          updatedAt: now,
        },
        include: { media: true },
      });
      return mapDraft(draft);
    }
    return this.executeCommand(input.idempotency, 201, async (transaction) => {
      const draft = await transaction.rescueCaseDraft.create({
        data: {
          ownerUserId: input.ownerUserId,
          source: input.source,
          createdAt: now,
          updatedAt: now,
        },
        include: { media: true },
      });
      return mapDraft(draft);
    });
  }

  async findOwnedDraft(ownerUserId: string, draftId: string) {
    const draft = await this.prisma.rescueCaseDraft.findFirst({
      where: { id: draftId, ownerUserId },
      include: { media: { orderBy: { position: 'asc' } } },
    });
    return draft ? mapDraft(draft) : undefined;
  }

  async updateDraft(input: {
    ownerUserId: string;
    draftId: string;
    expectedVersion: number;
    patch: UpdateRescueDraftPatch;
    now?: Date;
  }) {
    const now = input.now ?? new Date();
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT true AS locked
        FROM pg_advisory_xact_lock(hashtextextended(${`rescue-draft:${input.draftId}`}, 0))
      `;
      const current = await tx.rescueCaseDraft.findUnique({
        where: { id: input.draftId },
        include: { media: { orderBy: { position: 'asc' } } },
      });
      requireEditableDraft(current, input);

      if (hasOwn(input.patch, 'mediaIds')) {
        const mediaIds = input.patch.mediaIds ?? [];
        if (mediaIds.length > 5 || new Set(mediaIds).size !== mediaIds.length) {
          throw new RescuePersistenceDomainError(
            'invalid_media',
            'Draft media must contain at most five unique assets.',
          );
        }

        const media = mediaIds.length
          ? await tx.mediaAsset.findMany({
              where: { id: { in: mediaIds } },
            })
          : [];
        const eligible = media.every((item) =>
          isEligibleDraftMedia(item, input.ownerUserId, input.draftId),
        );
        if (media.length !== mediaIds.length || !eligible) {
          throw new RescuePersistenceDomainError(
            'invalid_media',
            'Draft media must be verified, unclaimed, and owned by the draft owner.',
          );
        }

        await tx.mediaAsset.updateMany({
          where: { draftId: input.draftId },
          data: {
            draftId: null,
            status: 'verified',
            position: null,
            updatedAt: now,
          },
        });
        await Promise.all(
          mediaIds.map(async (mediaId, position) => {
            const claimed = await tx.mediaAsset.updateMany({
              where: {
                id: mediaId,
                ownerUserId: input.ownerUserId,
                purpose: 'rescue_case',
                verificationVersion: { gte: 1 },
                verifiedAt: { not: null },
                publicUrl: { not: null },
                caseId: null,
                commentId: null,
                deletedAt: null,
                OR: [
                  { draftId: null, status: 'verified' },
                  { draftId: input.draftId, status: 'attached' },
                ],
              },
              data: {
                draftId: input.draftId,
                status: 'attached',
                position,
                updatedAt: now,
              },
            });
            if (claimed.count !== 1) {
              throw new RescuePersistenceDomainError(
                'invalid_media',
                'A draft media asset could not be claimed atomically.',
              );
            }
          }),
        );
      }

      const updated = await tx.rescueCaseDraft.updateMany({
        where: {
          id: input.draftId,
          ownerUserId: input.ownerUserId,
          version: input.expectedVersion,
          publishedAt: null,
          discardedAt: null,
        },
        data: {
          ...buildDraftUpdate(input.patch),
          version: { increment: 1 },
          updatedAt: now,
        },
      });
      if (updated.count !== 1) {
        throw new RescuePersistenceDomainError(
          'version_conflict',
          'The Rescue draft changed while it was being updated.',
        );
      }
      const draft = await tx.rescueCaseDraft.findFirst({
        where: { id: input.draftId, ownerUserId: input.ownerUserId },
        include: { media: { orderBy: { position: 'asc' } } },
      });
      if (!draft) throw new RescuePersistenceNotFoundError();
      return mapDraft(draft);
    });
  }

  async registerVerifiedMedia(input: {
    ownerUserId: string;
    purpose: 'rescue_case' | 'rescue_comment';
    mimeType: 'image/jpeg' | 'image/png' | 'image/webp' | 'video/mp4';
    sizeBytes: number;
    sha256: string;
    storageKey: string;
    publicUrl?: string;
    width?: number;
    height?: number;
    durationSeconds?: number;
    now?: Date;
  }) {
    const now = input.now ?? new Date();
    const media = await this.prisma.mediaAsset.create({
      data: {
        ownerUserId: input.ownerUserId,
        purpose: input.purpose,
        mimeType: input.mimeType,
        sizeBytes: BigInt(input.sizeBytes),
        sha256: input.sha256,
        status: 'verified',
        verificationVersion: 1,
        storageKey: input.storageKey,
        publicUrl: input.publicUrl,
        width: input.width,
        height: input.height,
        durationSeconds: input.durationSeconds,
        verifiedAt: now,
        createdAt: now,
        updatedAt: now,
      },
    });
    return mapMedia(media);
  }

  async attachVerifiedMediaToDraft(input: {
    ownerUserId: string;
    draftId: string;
    mediaId: string;
    position: number;
    now?: Date;
  }) {
    const now = input.now ?? new Date();
    return this.prisma.$transaction(async (tx) => {
      const draft = await tx.rescueCaseDraft.findFirst({
        where: {
          id: input.draftId,
          ownerUserId: input.ownerUserId,
          publishedAt: null,
          discardedAt: null,
        },
        select: { id: true },
      });
      if (!draft) throw new RescuePersistenceNotFoundError();

      const updated = await tx.mediaAsset.updateMany({
        where: {
          id: input.mediaId,
          ownerUserId: input.ownerUserId,
          purpose: 'rescue_case',
          status: 'verified',
          verificationVersion: { gte: 1 },
          verifiedAt: { not: null },
          publicUrl: { not: null },
          draftId: null,
          caseId: null,
          commentId: null,
          deletedAt: null,
        },
        data: {
          draftId: input.draftId,
          position: input.position,
          status: 'attached',
          updatedAt: now,
        },
      });
      if (updated.count !== 1) {
        throw new RescuePersistenceConflictError(
          'Media is not verified, unclaimed, or owned by the draft owner.',
        );
      }
      const media = await tx.mediaAsset.findUnique({
        where: { id: input.mediaId },
      });
      if (!media) throw new RescuePersistenceNotFoundError();
      return mapMedia(media);
    });
  }

  async publishDraft(input: {
    ownerUserId: string;
    draftId: string;
    expectedVersion: number;
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }) {
    const now = input.now ?? new Date();
    return this.executeCommand(input.idempotency, 201, async (tx) => {
      await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT true AS locked
        FROM pg_advisory_xact_lock(hashtextextended(${`rescue-draft:${input.draftId}`}, 0))
      `;
      const draft = await tx.rescueCaseDraft.findUnique({
        where: { id: input.draftId },
        include: { media: { orderBy: { position: 'asc' } } },
      });
      if (!draft) {
        throw new RescuePersistenceDomainError(
          'not_found',
          'Rescue draft was not found.',
        );
      }
      if (draft.ownerUserId !== input.ownerUserId) {
        throw new RescuePersistenceDomainError(
          'forbidden',
          'Only the draft owner can publish this Rescue draft.',
        );
      }
      if (
        draft.version !== input.expectedVersion ||
        draft.publishedAt !== null ||
        draft.discardedAt !== null
      ) {
        throw new RescuePersistenceDomainError(
          'version_conflict',
          'The Rescue draft changed or is no longer publishable.',
        );
      }
      requirePublishableDraft(draft);

      const exactLatitude = draft.exactLatitude!.toNumber();
      const exactLongitude = draft.exactLongitude!.toNumber();
      const publicCoordinate = projectRescueCoordinateCell({
        latitude: exactLatitude,
        longitude: exactLongitude,
      });
      // Recompute the public area from the exact private location at the
      // publish boundary. A stale or directly-mutated draft label must never
      // become the public case label.
      const publicLocation = projectRescueLocationPrivacy({
        latitude: exactLatitude,
        longitude: exactLongitude,
        formattedAddress: draft.formattedAddress ?? undefined,
      });
      const createdCase = await tx.rescueCase.create({
        data: {
          sourceDraftId: draft.id,
          ownerUserId: draft.ownerUserId,
          petName: draft.petName!,
          species: draft.species!,
          breedOrColor: draft.breedOrColor!,
          lostAt: draft.lostAt!,
          areaLabel: publicLocation.areaLabel,
          approximateLatitude: publicCoordinate.approximateLatitude,
          approximateLongitude: publicCoordinate.approximateLongitude,
          privacyRadiusMeters: publicCoordinate.privacyRadiusMeters,
          identifyingFeatures: draft.identifyingFeatures!,
          behaviorHint: draft.behaviorHint,
          contactPreference: draft.contactPreference,
          status: 'missing',
          version: 1,
          commentCount: 0,
          createdAt: now,
          updatedAt: now,
        },
      });

      await tx.rescueCasePrivateLocation.create({
        data: {
          caseId: createdCase.id,
          ownerUserId: draft.ownerUserId,
          latitude: exactLatitude,
          longitude: exactLongitude,
          formattedAddress: draft.formattedAddress,
          createdAt: now,
          updatedAt: now,
        },
      });
      await tx.mediaAsset.updateMany({
        where: {
          draftId: draft.id,
          ownerUserId: draft.ownerUserId,
          status: 'attached',
          purpose: 'rescue_case',
          deletedAt: null,
        },
        data: { draftId: null, caseId: createdCase.id, updatedAt: now },
      });
      const finalizedDraft = await tx.rescueCaseDraft.updateMany({
        where: {
          id: draft.id,
          ownerUserId: draft.ownerUserId,
          version: input.expectedVersion,
          publishedAt: null,
          discardedAt: null,
        },
        data: {
          version: { increment: 1 },
          publishedAt: now,
          updatedAt: now,
        },
      });
      if (finalizedDraft.count !== 1) {
        throw new RescuePersistenceConflictError();
      }
      await tx.rescueStatusEvent.create({
        data: {
          caseId: createdCase.id,
          changedByUserId: draft.ownerUserId,
          fromStatus: null,
          toStatus: 'missing',
          expectedVersion: 0,
          newVersion: 1,
          createdAt: now,
        },
      });
      await tx.outboxEvent.create({
        data: {
          topic: 'rescue.notifications',
          eventType: 'rescue.case_published.v1',
          aggregateType: 'rescue_case',
          aggregateId: createdCase.id,
          actorUserId: draft.ownerUserId,
          dedupeKey: `rescue.case_published:${createdCase.id}`,
          schemaVersion: 1,
          payload: {
            caseId: createdCase.id,
            ownerUserId: draft.ownerUserId,
            status: 'missing',
            version: 1,
          },
          occurredAt: now,
          availableAt: now,
        },
      });
      const result = await tx.rescueCase.findUnique({
        where: { id: createdCase.id },
        include: {
          privateLocation: true,
          media: { orderBy: { position: 'asc' } },
        },
      });
      if (!result) throw new RescuePersistenceNotFoundError();
      return mapCase(result);
    });
  }

  async findOwnedCase(ownerUserId: string, caseId: string) {
    const rescueCase = await this.prisma.rescueCase.findFirst({
      where: { id: caseId, ownerUserId, deletedAt: null },
      include: {
        privateLocation: true,
        media: { where: { deletedAt: null }, orderBy: { position: 'asc' } },
      },
    });
    return rescueCase ? mapCase(rescueCase) : undefined;
  }

  async createComment(input: {
    authorUserId: string;
    caseId: string;
    body: string;
    replyToCommentId?: string;
    mediaIds?: string[];
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }) {
    const now = input.now ?? new Date();
    const body = input.body.trim();
    const mediaIds = input.mediaIds ?? [];
    if (mediaIds.length > 5) {
      throw new RescuePersistenceInvariantError(
        'A Rescue comment accepts at most five media assets.',
      );
    }
    return this.executeCommand(input.idempotency, 201, async (tx) => {
      const rescueCase = await tx.rescueCase.findFirst({
        where: { id: input.caseId, deletedAt: null },
        select: { id: true, status: true, ownerUserId: true },
      });
      if (!rescueCase) {
        throw new RescuePersistenceDomainError(
          'not_found',
          'Rescue case was not found.',
        );
      }
      if (rescueCase.status !== 'missing') {
        throw new RescuePersistenceDomainError(
          'comments_closed',
          'The Rescue case is closed for new comments.',
        );
      }

      if (input.replyToCommentId) {
        const parent = await tx.rescueComment.findFirst({
          where: {
            id: input.replyToCommentId,
            caseId: input.caseId,
            deletedAt: null,
            moderationState: 'visible',
          },
          select: { id: true },
        });
        if (!parent) {
          throw new RescuePersistenceDomainError(
            'not_found',
            'The parent Rescue comment was not found in this case.',
          );
        }
      }

      if (mediaIds.length > 0) {
        const mediaCount = await tx.mediaAsset.count({
          where: {
            id: { in: mediaIds },
            ownerUserId: input.authorUserId,
            purpose: 'rescue_comment',
            status: 'verified',
            verificationVersion: { gte: 1 },
            verifiedAt: { not: null },
            publicUrl: { not: null },
            draftId: null,
            caseId: null,
            commentId: null,
            deletedAt: null,
          },
        });
        if (mediaCount !== mediaIds.length) {
          throw new RescuePersistenceConflictError(
            'Comment media must be verified, unclaimed, and owned by the author.',
          );
        }
      }

      const comment = await tx.rescueComment.create({
        data: {
          caseId: input.caseId,
          authorUserId: input.authorUserId,
          body,
          replyToCommentId: input.replyToCommentId,
          createdAt: now,
          updatedAt: now,
        },
      });
      await Promise.all(
        mediaIds.map((mediaId, position) =>
          tx.mediaAsset.update({
            where: { id: mediaId },
            data: {
              commentId: comment.id,
              position,
              status: 'attached',
              updatedAt: now,
            },
          }),
        ),
      );
      const counted = await tx.rescueCase.updateMany({
        where: { id: input.caseId, status: 'missing', deletedAt: null },
        data: { commentCount: { increment: 1 }, updatedAt: now },
      });
      if (counted.count !== 1) {
        throw new RescuePersistenceConflictError(
          'The Rescue case closed while the comment was being created.',
        );
      }
      const result = await tx.rescueComment.findUnique({
        where: { id: comment.id },
        include: {
          author: { select: { id: true, displayName: true, avatarUrl: true } },
          media: { orderBy: { position: 'asc' } },
        },
      });
      if (!result) throw new RescuePersistenceNotFoundError();
      await tx.outboxEvent.create({
        data: {
          topic: 'rescue.notifications',
          eventType: 'rescue.comment_created.v1',
          aggregateType: 'rescue_case',
          aggregateId: input.caseId,
          actorUserId: input.authorUserId,
          dedupeKey: `rescue.comment_created:${comment.id}`,
          schemaVersion: 1,
          payload: {
            caseId: input.caseId,
            commentId: comment.id,
            authorUserId: input.authorUserId,
            ownerUserId: rescueCase.ownerUserId,
          },
          occurredAt: now,
          availableAt: now,
        },
      });
      return mapComment(result);
    });
  }

  async listComments(input: {
    caseId: string;
    cursor?: RescueCommentCursor;
    limit: number;
  }): Promise<RescueCommentPage> {
    const rescueCase = await this.prisma.rescueCase.findFirst({
      where: { id: input.caseId, deletedAt: null },
      select: { id: true },
    });
    if (!rescueCase) {
      throw new RescuePersistenceDomainError(
        'not_found',
        'Rescue case was not found.',
      );
    }

    const rows = await this.prisma.rescueComment.findMany({
      where: {
        caseId: input.caseId,
        deletedAt: null,
        moderationState: 'visible',
        ...(input.cursor
          ? {
              OR: [
                { createdAt: { gt: new Date(input.cursor.createdAt) } },
                {
                  createdAt: new Date(input.cursor.createdAt),
                  id: { gt: input.cursor.commentId },
                },
              ],
            }
          : {}),
      },
      include: {
        author: { select: { id: true, displayName: true, avatarUrl: true } },
        media: {
          where: {
            status: 'attached',
            verificationVersion: { gte: 1 },
            publicUrl: { not: null },
            deletedAt: null,
          },
          orderBy: { position: 'asc' },
        },
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: input.limit + 1,
    });
    const hasMore = rows.length > input.limit;
    const pageRows = rows.slice(0, input.limit);
    const last = pageRows.at(-1);
    return {
      items: pageRows.map(mapComment),
      ...(hasMore && last
        ? {
            nextCursor: {
              createdAt: last.createdAt.toISOString(),
              commentId: last.id,
            },
          }
        : {}),
      limit: input.limit,
    };
  }

  async updateCaseStatus(input: {
    ownerUserId: string;
    caseId: string;
    expectedVersion: number;
    status: 'found';
    now?: Date;
    idempotency?: RescueIdempotencyInput;
  }) {
    const now = input.now ?? new Date();
    return this.executeCommand(input.idempotency, 200, async (tx) => {
      await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT true AS locked
        FROM pg_advisory_xact_lock(hashtextextended(${`rescue-case:${input.caseId}`}, 0))
      `;
      const current = await tx.rescueCase.findFirst({
        where: { id: input.caseId, deletedAt: null },
        select: { id: true, ownerUserId: true, status: true, version: true },
      });
      if (!current) {
        throw new RescuePersistenceDomainError(
          'not_found',
          'Rescue case was not found.',
        );
      }
      if (current.ownerUserId !== input.ownerUserId) {
        throw new RescuePersistenceDomainError(
          'forbidden',
          'Only the Rescue case owner can update its status.',
        );
      }
      if (current.status !== 'missing') {
        throw new RescuePersistenceDomainError(
          'invalid_transition',
          'Only a missing Rescue case can transition to found.',
        );
      }
      if (current.version !== input.expectedVersion) {
        throw new RescuePersistenceDomainError(
          'version_conflict',
          'The Rescue case version changed.',
        );
      }
      const updated = await tx.rescueCase.updateMany({
        where: {
          id: input.caseId,
          ownerUserId: input.ownerUserId,
          status: 'missing',
          version: input.expectedVersion,
          deletedAt: null,
        },
        data: {
          status: input.status,
          version: { increment: 1 },
          foundAt: now,
          updatedAt: now,
        },
      });
      if (updated.count !== 1) {
        throw new RescuePersistenceDomainError(
          'version_conflict',
          'The Rescue case changed while its status was being updated.',
        );
      }
      await tx.rescueStatusEvent.create({
        data: {
          caseId: input.caseId,
          changedByUserId: input.ownerUserId,
          fromStatus: 'missing',
          toStatus: input.status,
          expectedVersion: input.expectedVersion,
          newVersion: input.expectedVersion + 1,
          createdAt: now,
        },
      });
      await tx.outboxEvent.create({
        data: {
          topic: 'rescue.notifications',
          eventType: 'rescue.case_status_changed.v1',
          aggregateType: 'rescue_case',
          aggregateId: input.caseId,
          actorUserId: input.ownerUserId,
          dedupeKey: `rescue.case_status_changed:${input.caseId}:${input.expectedVersion + 1}`,
          schemaVersion: 1,
          payload: {
            caseId: input.caseId,
            ownerUserId: input.ownerUserId,
            fromStatus: 'missing',
            toStatus: input.status,
            version: input.expectedVersion + 1,
          },
          occurredAt: now,
          availableAt: now,
        },
      });
      const result = await tx.rescueCase.findUnique({
        where: { id: input.caseId },
        include: {
          privateLocation: true,
          media: { where: { deletedAt: null }, orderBy: { position: 'asc' } },
        },
      });
      if (!result) throw new RescuePersistenceNotFoundError();
      return mapCase(result);
    });
  }

  async createMediaUploadRequest(input: {
    mediaId: string;
    ownerUserId: string;
    purpose: RescueMediaAssetRecord['purpose'];
    mimeType: RescueMediaAssetRecord['mimeType'];
    sizeBytes: number;
    sha256: string;
    stagingStorageKey: string;
    uploadExpiresAt: Date;
    uploadUrl: string;
    uploadHeaders: Record<string, string>;
    idempotency: RescueIdempotencyInput;
    now?: Date;
  }): Promise<RescueMediaUploadRequestRecord> {
    const now = input.now ?? new Date();
    return this.executeCommand(input.idempotency, 201, async (tx) => {
      const media = await tx.mediaAsset.create({
        data: {
          id: input.mediaId,
          ownerUserId: input.ownerUserId,
          purpose: input.purpose,
          mimeType: input.mimeType,
          sizeBytes: BigInt(input.sizeBytes),
          sha256: input.sha256,
          status: 'requested',
          storageKey: input.stagingStorageKey,
          verificationVersion: 0,
          createdAt: now,
          updatedAt: now,
        },
      });
      await tx.mediaUploadSession.create({
        data: {
          mediaId: media.id,
          stagingStorageKey: input.stagingStorageKey,
          uploadExpiresAt: input.uploadExpiresAt,
          createdAt: now,
          updatedAt: now,
        },
      });
      return {
        media: mapMedia(media),
        uploadUrl: input.uploadUrl,
        uploadHeaders: input.uploadHeaders,
        expiresAt: input.uploadExpiresAt.toISOString(),
      };
    });
  }

  async findOwnedMediaUpload(ownerUserId: string, mediaId: string) {
    const media = await this.prisma.mediaAsset.findUnique({
      where: { id: mediaId },
      include: { uploadSession: true },
    });
    if (!media || media.ownerUserId !== ownerUserId || !media.uploadSession) {
      return undefined;
    }
    return {
      media: mapMedia(media),
      session: mapUploadSession(media.uploadSession),
    };
  }

  async completeMediaUpload(input: {
    ownerUserId: string;
    mediaId: string;
    detectedMimeType: RescueMediaAssetRecord['mimeType'];
    detectedSizeBytes: number;
    sanitizedStorageKey: string;
    sanitizedSha256: string;
    publicUrl?: string;
    width?: number;
    height?: number;
    durationSeconds?: number;
    idempotency: RescueIdempotencyInput;
    now?: Date;
  }): Promise<RescueMediaAssetRecord> {
    const now = input.now ?? new Date();
    return this.executeCommand(input.idempotency, 200, async (tx) => {
      await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT true AS locked
        FROM pg_advisory_xact_lock(hashtextextended(${`rescue-media:${input.mediaId}`}, 0))
      `;
      const current = await tx.mediaAsset.findUnique({
        where: { id: input.mediaId },
        include: { uploadSession: true },
      });
      if (!current || !current.uploadSession) {
        throw new RescuePersistenceDomainError(
          'not_found',
          'Media upload was not found.',
        );
      }
      if (current.ownerUserId !== input.ownerUserId) {
        throw new RescuePersistenceDomainError(
          'forbidden',
          'Only the media owner can complete this upload.',
        );
      }
      if (current.uploadSession.uploadExpiresAt <= now) {
        throw new RescuePersistenceDomainError(
          'media_expired',
          'Media upload ticket expired.',
        );
      }
      if (current.status !== 'requested' && current.status !== 'uploaded') {
        throw new RescuePersistenceDomainError(
          'invalid_media',
          'Media is not awaiting verification.',
        );
      }

      const updated = await tx.mediaAsset.update({
        where: { id: input.mediaId },
        data: {
          status: 'verified',
          mimeType: input.detectedMimeType,
          storageKey: input.sanitizedStorageKey,
          publicUrl: input.publicUrl,
          width: input.width,
          height: input.height,
          durationSeconds: input.durationSeconds,
          verificationVersion: 1,
          verifiedAt: now,
          updatedAt: now,
        },
      });
      await tx.mediaUploadSession.update({
        where: { mediaId: input.mediaId },
        data: {
          detectedMimeType: input.detectedMimeType,
          detectedSizeBytes: BigInt(input.detectedSizeBytes),
          sanitizedStorageKey: input.sanitizedStorageKey,
          sanitizedSha256: input.sanitizedSha256,
          verificationStartedAt: now,
          leaseUntil: null,
          completedAt: now,
          updatedAt: now,
        },
      });
      return mapMedia(updated);
    });
  }

  async rejectMediaUpload(input: {
    ownerUserId: string;
    mediaId: string;
    rejectionCode: string;
    now?: Date;
  }): Promise<void> {
    const now = input.now ?? new Date();
    await this.prisma.$transaction(async (tx) => {
      const current = await tx.mediaAsset.findUnique({
        where: { id: input.mediaId },
        include: { uploadSession: true },
      });
      if (!current || !current.uploadSession) return;
      if (current.ownerUserId !== input.ownerUserId) {
        throw new RescuePersistenceDomainError(
          'forbidden',
          'Only the media owner can reject this upload.',
        );
      }
      await tx.mediaAsset.update({
        where: { id: input.mediaId },
        data: { status: 'rejected', updatedAt: now },
      });
      await tx.mediaUploadSession.update({
        where: { mediaId: input.mediaId },
        data: {
          rejectedAt: now,
          rejectionCode: input.rejectionCode,
          leaseUntil: null,
          updatedAt: now,
        },
      });
    });
  }
}

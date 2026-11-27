/* eslint-disable no-bitwise -- Deterministic UUID version and variant bits require exact masks. */
import { createHash } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import {
  IDEMPOTENCY_ERROR_CODES,
  MEDIA_ERROR_CODES,
  RESCUE_ERROR_CODES,
} from '../../errors/error-codes';
import { type AppFeatureAvailability } from '../../config/env';
import {
  RescuePersistenceDomainError,
  type RescueMediaAssetRecord,
  type RescueMediaMimeType,
  type RescueMediaPurpose,
  type RescueMediaUploadRequestRecord,
  type RescueRepository,
} from '../../features/rescue/persistence/rescue-repository';
import { type ChatRepository } from '../../features/chat/persistence/chat-repository';
import {
  RESCUE_IMAGE_MAX_BYTES,
  RESCUE_VIDEO_MAX_BYTES,
} from '../../features/rescue/rescue-media-policy';
import {
  RescueMediaSanitizationError,
  sanitizeRescueMedia,
} from '../../infrastructure/rescue-media-sanitizer';
import {
  RescueMediaStorageError,
  type RescueMediaStorage,
} from '../../infrastructure/rescue-media-storage';
import { buildRescueIdempotencyInput } from './rescue-write-service';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/i;
const UPLOAD_TICKET_TTL_MS = 60 * 60 * 1_000;

type UnknownRecord = Record<string, unknown>;
type OwnedMediaUpload = NonNullable<
  Awaited<ReturnType<RescueRepository['findOwnedMediaUpload']>>
>;

export type MediaUploadTicketDto = {
  mediaId: string;
  uploadUrl: string;
  uploadHeaders: Record<string, string>;
  expiresAt: string;
};

export type MediaAssetDto = {
  mediaId: string;
  ownerUserId: string;
  purpose: RescueMediaPurpose;
  mimeType: RescueMediaMimeType;
  sizeBytes: number;
  sha256: string;
  status: RescueMediaAssetRecord['status'];
  createdAt: string;
  publicUrl?: string;
  width?: number;
  height?: number;
  durationSeconds?: number;
};

const invalidMedia = (
  code: (typeof MEDIA_ERROR_CODES)[keyof typeof MEDIA_ERROR_CODES],
  field: string,
  message: string,
  statusCode = 400,
): never => {
  throw new AppError(code, message, statusCode, field);
};

const asObject = (value: unknown): UnknownRecord => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalidMedia(
      MEDIA_ERROR_CODES.invalidRequest,
      'body',
      'Body media upload khong hop le.',
    );
  }
  return value as UnknownRecord;
};

const assertKnownKeys = (value: UnknownRecord, allowed: readonly string[]) => {
  const unexpected = Object.keys(value).find((key) => !allowed.includes(key));
  if (unexpected) {
    invalidMedia(
      MEDIA_ERROR_CODES.invalidRequest,
      unexpected,
      `Truong ${unexpected} khong duoc ho tro.`,
    );
  }
};

const normalizeSha256 = (value: unknown, field: string) => {
  const normalized =
    typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (!SHA256_PATTERN.test(normalized)) {
    return invalidMedia(
      MEDIA_ERROR_CODES.invalidRequest,
      field,
      `${field} phai la SHA-256 hex 64 ky tu.`,
    );
  }
  return normalized;
};

const deterministicUuid = (scope: string) => {
  const bytes = createHash('sha256')
    .update(scope, 'utf8')
    .digest()
    .subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join('-');
};

const extensionByMime: Record<RescueMediaMimeType, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'video/mp4': 'mp4',
};

const boundChatThreadId = (
  stagingStorageKey: string,
  ownerUserId: string,
  mediaId: string,
): string => {
  const match =
    /^adoption_chat\/([0-9a-f-]{36})\/([0-9a-f-]{36})\/([0-9a-f-]{36})\/original\.(?:jpg|png|webp|mp4)$/.exec(
      stagingStorageKey,
    );
  if (
    !match ||
    !UUID_PATTERN.test(match[1]) ||
    match[2] !== ownerUserId ||
    match[3] !== mediaId
  ) {
    throw new AppError(
      MEDIA_ERROR_CODES.objectMissingOrExpired,
      'Media chat khong thuoc cuoc tro chuyen hop le.',
      404,
    );
  }
  return match[1];
};

const toTicketDto = (
  record: RescueMediaUploadRequestRecord,
): MediaUploadTicketDto => ({
  mediaId: record.media.mediaId,
  uploadUrl: record.uploadUrl,
  uploadHeaders: record.uploadHeaders,
  expiresAt: record.expiresAt,
});

const toMediaAssetDto = (record: RescueMediaAssetRecord): MediaAssetDto => ({
  mediaId: record.mediaId,
  ownerUserId: record.ownerUserId,
  purpose: record.purpose,
  mimeType: record.mimeType,
  sizeBytes: record.sizeBytes,
  sha256: record.sha256,
  status: record.status,
  createdAt: record.createdAt,
  ...(record.purpose !== 'adoption_chat' && record.publicUrl
    ? { publicUrl: record.publicUrl }
    : {}),
  ...(record.width === undefined ? {} : { width: record.width }),
  ...(record.height === undefined ? {} : { height: record.height }),
  ...(record.durationSeconds === undefined
    ? {}
    : { durationSeconds: record.durationSeconds }),
});

const mapPersistenceError = (error: unknown): never => {
  if (error instanceof RescuePersistenceDomainError) {
    if (error.failure === 'idempotency_conflict') {
      throw new AppError(
        IDEMPOTENCY_ERROR_CODES.payloadConflict,
        error.message,
        409,
      );
    }
    if (error.failure === 'media_expired' || error.failure === 'not_found') {
      throw new AppError(
        MEDIA_ERROR_CODES.objectMissingOrExpired,
        error.message,
        404,
      );
    }
    if (error.failure === 'forbidden') {
      throw new AppError(MEDIA_ERROR_CODES.invalidRequest, error.message, 403);
    }
    throw new AppError(MEDIA_ERROR_CODES.invalidRequest, error.message, 409);
  }
  throw error;
};

const callRepository = async <T>(action: () => Promise<T>) => {
  try {
    return await action();
  } catch (error) {
    return mapPersistenceError(error);
  }
};

const mapStorageError = (error: unknown): never => {
  if (error instanceof RescueMediaStorageError) {
    if (error.failure === 'object_missing') {
      throw new AppError(
        MEDIA_ERROR_CODES.objectMissingOrExpired,
        error.message,
        404,
      );
    }
    throw new AppError(MEDIA_ERROR_CODES.invalidRequest, error.message, 502);
  }
  throw error;
};

const requireRepository = (repository?: RescueRepository) => {
  if (!repository) throw new Error('Rescue persistence is unavailable.');
  return repository;
};

const requireStorage = (storage?: RescueMediaStorage) => {
  if (!storage) {
    throw new AppError(
      MEDIA_ERROR_CODES.invalidRequest,
      'Rescue media storage is unavailable.',
      503,
    );
  }
  return storage;
};

export const createRescueMediaService = (options: {
  repository?: RescueRepository;
  chatRepository?: ChatRepository;
  storage?: RescueMediaStorage;
  now?: () => Date;
  featureAvailability?: AppFeatureAvailability;
}) => {
  const now = options.now ?? (() => new Date());
  const featureAvailability = options.featureAvailability ?? {
    rescueBrowse: true,
    rescueCreate: true,
  };
  const repository = () => requireRepository(options.repository);
  const storage = () => requireStorage(options.storage);

  const requirePurposeEnabled = (purpose: RescueMediaPurpose) => {
    const unavailable =
      (purpose === 'rescue_case' && !featureAvailability.rescueCreate) ||
      (purpose === 'rescue_comment' && !featureAvailability.rescueBrowse);
    if (unavailable) {
      throw new AppError(
        RESCUE_ERROR_CODES.featureUnavailable,
        'Tinh nang Rescue chua duoc bat.',
        503,
      );
    }
  };

  const validateUploadMime = (body: UnknownRecord) => {
    const mimeTypes: RescueMediaMimeType[] = [
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
    ];
    if (!mimeTypes.includes(body.mimeType as RescueMediaMimeType)) {
      invalidMedia(
        MEDIA_ERROR_CODES.unsupportedMimeType,
        'mimeType',
        'MIME type media khong duoc ho tro.',
      );
    }
    if (!Number.isSafeInteger(body.sizeBytes) || Number(body.sizeBytes) < 1) {
      invalidMedia(
        MEDIA_ERROR_CODES.invalidRequest,
        'sizeBytes',
        'sizeBytes phai la so nguyen duong.',
      );
    }
    const mimeType = body.mimeType as RescueMediaMimeType;
    const maxBytes =
      mimeType === 'video/mp4'
        ? RESCUE_VIDEO_MAX_BYTES
        : RESCUE_IMAGE_MAX_BYTES;
    if (Number(body.sizeBytes) > maxBytes) {
      invalidMedia(
        MEDIA_ERROR_CODES.sizeExceeded,
        'sizeBytes',
        'Kich thuoc media vuot gioi han.',
      );
    }
    return mimeType;
  };

  const resolveRequestChatThread = async (
    userId: string,
    body: UnknownRecord,
  ) => {
    const privateChat = body.purpose === 'adoption_chat';
    let chatThreadId: string | undefined;
    if (privateChat) {
      if (
        typeof body.threadId !== 'string' ||
        !UUID_PATTERN.test(body.threadId)
      ) {
        invalidMedia(
          MEDIA_ERROR_CODES.invalidRequest,
          'threadId',
          'threadId hop le la bat buoc cho media chat.',
        );
      }
      chatThreadId = body.threadId as string;
      if (!options.chatRepository) {
        throw new AppError(
          MEDIA_ERROR_CODES.invalidRequest,
          'Chat media unavailable.',
          503,
        );
      }
      if (
        !(await options.chatRepository.isCurrentParticipant({
          participantUserId: userId,
          threadId: chatThreadId,
        }))
      ) {
        throw new AppError(
          MEDIA_ERROR_CODES.objectMissingOrExpired,
          'Khong tim thay cuoc tro chuyen.',
          404,
        );
      }
    } else if (body.threadId !== undefined) {
      invalidMedia(
        MEDIA_ERROR_CODES.invalidRequest,
        'threadId',
        'threadId chi dung cho media chat.',
      );
    }
    return chatThreadId;
  };

  const readUploadFileName = (body: UnknownRecord) => {
    let fileName: string | undefined;
    if (body.fileName !== undefined) {
      if (
        typeof body.fileName !== 'string' ||
        body.fileName.trim().length < 1 ||
        body.fileName.trim().length > 255
      ) {
        invalidMedia(
          MEDIA_ERROR_CODES.invalidRequest,
          'fileName',
          'fileName phai dai tu 1 den 255 ky tu.',
        );
      }
      fileName = (body.fileName as string).trim();
    }
    return fileName;
  };

  const normalizeCompletionMediaId = (mediaId: unknown) => {
    const normalizedMediaId =
      typeof mediaId === 'string' && UUID_PATTERN.test(mediaId.trim())
        ? mediaId.trim()
        : invalidMedia(
            MEDIA_ERROR_CODES.invalidRequest,
            'mediaId',
            'mediaId khong hop le.',
          );
    return normalizedMediaId;
  };

  const replayCompletion = async (
    replayMedia: RescueMediaAssetRecord,
    userId: string,
    normalizedMediaId: string,
  ) => {
    requirePurposeEnabled(replayMedia.purpose);
    if (replayMedia.purpose === 'adoption_chat') {
      const replayUpload = await repository().findOwnedMediaUpload(
        userId,
        normalizedMediaId,
      );
      if (!replayUpload || !options.chatRepository) {
        throw new AppError(
          MEDIA_ERROR_CODES.objectMissingOrExpired,
          'Media chat unavailable.',
          404,
        );
      }
      const threadId = boundChatThreadId(
        replayUpload.session.stagingStorageKey,
        userId,
        normalizedMediaId,
      );
      if (
        !(await options.chatRepository.isCurrentParticipant({
          participantUserId: userId,
          threadId,
        }))
      ) {
        throw new AppError(
          MEDIA_ERROR_CODES.objectMissingOrExpired,
          'Media chat unavailable.',
          404,
        );
      }
    }
    return toMediaAssetDto(replayMedia);
  };

  const resolveCompletionChatThread = async (
    upload: OwnedMediaUpload,
    userId: string,
    normalizedMediaId: string,
  ) => {
    let chatThreadId: string | undefined;
    if (upload.media.purpose === 'adoption_chat') {
      chatThreadId = boundChatThreadId(
        upload.session.stagingStorageKey,
        userId,
        normalizedMediaId,
      );
      if (
        !options.chatRepository ||
        !(await options.chatRepository.isCurrentParticipant({
          participantUserId: userId,
          threadId: chatThreadId,
        }))
      ) {
        throw new AppError(
          MEDIA_ERROR_CODES.objectMissingOrExpired,
          'Media chat unavailable.',
          404,
        );
      }
    }
    return chatThreadId;
  };

  const readAndSanitizeUpload = async (
    upload: OwnedMediaUpload,
    userId: string,
    normalizedMediaId: string,
    commandNow: Date,
  ) => {
    let uploadedBytes: Buffer;
    try {
      uploadedBytes = await storage().readStagingObject(
        upload.session.stagingStorageKey,
      );
    } catch (error) {
      return mapStorageError(error);
    }
    let sanitized;
    try {
      sanitized = sanitizeRescueMedia({
        bytes: uploadedBytes,
        declaredMimeType: upload.media.mimeType,
      });
    } catch (error) {
      if (error instanceof RescueMediaSanitizationError) {
        await repository().rejectMediaUpload({
          ownerUserId: userId,
          mediaId: normalizedMediaId,
          rejectionCode: MEDIA_ERROR_CODES.integrityMismatch,
          now: commandNow,
        });
        throw new AppError(
          MEDIA_ERROR_CODES.integrityMismatch,
          error.message,
          422,
        );
      }
      throw error;
    }
    if (
      sanitized.originalSizeBytes !== upload.media.sizeBytes ||
      sanitized.originalSha256 !== upload.media.sha256
    ) {
      await repository().rejectMediaUpload({
        ownerUserId: userId,
        mediaId: normalizedMediaId,
        rejectionCode: MEDIA_ERROR_CODES.integrityMismatch,
        now: commandNow,
      });
      throw new AppError(
        MEDIA_ERROR_CODES.integrityMismatch,
        'Kich thuoc hoac SHA-256 object khong khop upload ticket.',
        422,
      );
    }
    return sanitized;
  };

  const commitVerifiedDerivative = async (
    upload: OwnedMediaUpload,
    userId: string,
    normalizedMediaId: string,
    commandNow: Date,
    sanitized: ReturnType<typeof sanitizeRescueMedia>,
    sanitizedStorageKey: string,
    sanitizedSha256: string,
    publicUrl: string | undefined,
    privateChat: boolean,
    idempotency: ReturnType<typeof buildRescueIdempotencyInput>,
  ) => {
    let completed: RescueMediaAssetRecord;
    try {
      completed = await callRepository(() =>
        repository().completeMediaUpload({
          ownerUserId: userId,
          mediaId: normalizedMediaId,
          detectedMimeType: sanitized.detectedMimeType,
          detectedSizeBytes: sanitized.originalSizeBytes,
          sanitizedStorageKey,
          sanitizedSha256,
          ...(publicUrl ? { publicUrl } : {}),
          idempotency,
          now: commandNow,
        }),
      );
    } catch (error) {
      try {
        if (privateChat) {
          await storage().deletePrivateObject(sanitizedStorageKey);
        } else {
          await storage().deletePublicObject(sanitizedStorageKey);
        }
      } catch {
        // The key is unique to this idempotent completion command, so a
        // later retry can safely overwrite and compensate it again.
      }
      throw error;
    }
    try {
      await storage().deleteStagingObject(upload.session.stagingStorageKey);
    } catch {
      // The original object is private. Cleanup can be retried without
      // invalidating the already committed verified derivative.
    }
    return toMediaAssetDto(completed);
  };

  return {
    async requestUpload(
      userId: string,
      payload: unknown,
      idempotencyKey: unknown,
    ): Promise<MediaUploadTicketDto> {
      const body = asObject(payload);
      assertKnownKeys(body, [
        'purpose',
        'mimeType',
        'sizeBytes',
        'sha256',
        'fileName',
        'threadId',
      ]);
      const purposes: RescueMediaPurpose[] = [
        'pet_profile',
        'rescue_case',
        'rescue_comment',
        'adoption_listing',
        'adoption_chat',
      ];
      if (!purposes.includes(body.purpose as RescueMediaPurpose)) {
        invalidMedia(
          MEDIA_ERROR_CODES.invalidRequest,
          'purpose',
          'purpose media khong hop le.',
        );
      }
      requirePurposeEnabled(body.purpose as RescueMediaPurpose);
      const mimeType = validateUploadMime(body);

      const originalSha256 = normalizeSha256(body.sha256, 'sha256');
      const chatThreadId = await resolveRequestChatThread(userId, body);

      const fileName = readUploadFileName(body);

      const normalizedPayload = {
        purpose: body.purpose,
        mimeType,
        sizeBytes: Number(body.sizeBytes),
        sha256: originalSha256,
        ...(chatThreadId ? { threadId: chatThreadId } : {}),
        ...(fileName === undefined ? {} : { fileName }),
      };
      const commandNow = now();
      const idempotency = buildRescueIdempotencyInput({
        userId,
        method: 'POST',
        normalizedPath: '/media/uploads',
        idempotencyKey,
        payload: normalizedPayload,
        now: commandNow,
      });
      const replay = await callRepository(() =>
        repository().findIdempotencyResponse(idempotency),
      );
      if (replay) {
        return toTicketDto(
          replay.responseBody as RescueMediaUploadRequestRecord,
        );
      }

      const mediaId = deterministicUuid(
        [userId, idempotency.normalizedPath, idempotency.keyHash].join(':'),
      );
      const stagingStorageKey = [
        ...(chatThreadId ? ['adoption_chat', chatThreadId] : []),
        userId,
        mediaId,
        `original.${extensionByMime[mimeType]}`,
      ].join('/');
      let ticket;
      try {
        ticket = await storage().createUploadTicket(
          stagingStorageKey,
          mimeType,
        );
      } catch (error) {
        return mapStorageError(error);
      }
      const uploadExpiresAt = new Date(
        commandNow.getTime() + UPLOAD_TICKET_TTL_MS,
      );
      const record = await callRepository(() =>
        repository().createMediaUploadRequest({
          mediaId,
          ownerUserId: userId,
          purpose: body.purpose as RescueMediaPurpose,
          mimeType,
          sizeBytes: Number(body.sizeBytes),
          sha256: originalSha256,
          stagingStorageKey,
          uploadExpiresAt,
          uploadUrl: ticket.uploadUrl,
          uploadHeaders: ticket.uploadHeaders,
          idempotency,
          now: commandNow,
        }),
      );
      return toTicketDto(record);
    },

    async completeUpload(
      userId: string,
      mediaId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ): Promise<MediaAssetDto> {
      const normalizedMediaId = normalizeCompletionMediaId(mediaId);

      const body = asObject(payload);
      assertKnownKeys(body, ['sha256']);
      const completionSha256 = normalizeSha256(body.sha256, 'sha256');
      const commandNow = now();
      const idempotency = buildRescueIdempotencyInput({
        userId,
        method: 'POST',
        normalizedPath: `/media/uploads/${normalizedMediaId}/complete`,
        idempotencyKey,
        payload: { sha256: completionSha256 },
        now: commandNow,
      });
      const replay = await callRepository(() =>
        repository().findIdempotencyResponse(idempotency),
      );
      if (replay)
        return replayCompletion(
          replay.responseBody as RescueMediaAssetRecord,
          userId,
          normalizedMediaId,
        );

      const upload = await repository().findOwnedMediaUpload(
        userId,
        normalizedMediaId,
      );
      if (!upload) {
        throw new AppError(
          MEDIA_ERROR_CODES.objectMissingOrExpired,
          'Khong tim thay media upload.',
          404,
        );
      }
      requirePurposeEnabled(upload.media.purpose);
      const chatThreadId = await resolveCompletionChatThread(
        upload,
        userId,
        normalizedMediaId,
      );

      if (new Date(upload.session.uploadExpiresAt) <= commandNow) {
        await repository().rejectMediaUpload({
          ownerUserId: userId,
          mediaId: normalizedMediaId,
          rejectionCode: MEDIA_ERROR_CODES.objectMissingOrExpired,
          now: commandNow,
        });
        throw new AppError(
          MEDIA_ERROR_CODES.objectMissingOrExpired,
          'Media upload da het han.',
          404,
        );
      }
      if (completionSha256 !== upload.media.sha256) {
        throw new AppError(
          MEDIA_ERROR_CODES.integrityMismatch,
          'SHA-256 complete khong khop upload ticket.',
          422,
        );
      }

      const sanitized = await readAndSanitizeUpload(
        upload,
        userId,
        normalizedMediaId,
        commandNow,
      );

      const privateChat = upload.media.purpose === 'adoption_chat';
      const sanitizedStorageKey = [
        upload.media.purpose,
        ...(chatThreadId ? [chatThreadId] : []),
        normalizedMediaId,
        idempotency.keyHash,
        `${privateChat ? 'private' : 'public'}.${extensionByMime[sanitized.detectedMimeType]}`,
      ].join('/');
      let publicUrl: string | undefined;
      try {
        if (privateChat) {
          await storage().writePrivateObject(
            sanitizedStorageKey,
            sanitized.bytes,
            sanitized.detectedMimeType,
          );
        } else {
          publicUrl = await storage().writePublicObject(
            sanitizedStorageKey,
            sanitized.bytes,
            sanitized.detectedMimeType,
          );
        }
      } catch (error) {
        return mapStorageError(error);
      }
      const sanitizedSha256 = createHash('sha256')
        .update(sanitized.bytes)
        .digest('hex');
      return commitVerifiedDerivative(
        upload,
        userId,
        normalizedMediaId,
        commandNow,
        sanitized,
        sanitizedStorageKey,
        sanitizedSha256,
        publicUrl,
        privateChat,
        idempotency,
      );
    },
  };
};

export type RescueMediaService = ReturnType<typeof createRescueMediaService>;

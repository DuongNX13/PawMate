import { createHash } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import {
  ADOPTION_ERROR_CODES,
  IDEMPOTENCY_ERROR_CODES,
} from '../../errors/error-codes';
import {
  ChatPersistenceDomainError,
  type ChatMessageCursor,
  type ChatRepository,
} from '../../features/chat/persistence/chat-repository';
import {
  RescueMediaStorageError,
  type RescueMediaStorage,
} from '../../infrastructure/rescue-media-storage';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type UnknownRecord = Record<string, unknown>;
type ChatCursorEnvelope = {
  version: 1;
  threadId: string;
  position: ChatMessageCursor;
};

export type ChatQuery = {
  cursor?: unknown;
  limit?: unknown;
};

const invalidInput = (field: string, message: string): never => {
  throw new AppError(ADOPTION_ERROR_CODES.invalidInput, message, 400, field);
};

const asObject = (value: unknown): UnknownRecord => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalidInput('body', 'Body phai la JSON object.');
  }
  return value as UnknownRecord;
};

const assertKnownKeys = (value: UnknownRecord, allowed: readonly string[]) => {
  const unexpected = Object.keys(value).find((key) => !allowed.includes(key));
  if (unexpected) {
    invalidInput(unexpected, `Truong ${unexpected} khong duoc ho tro.`);
  }
};

const requireChatUuid = (value: unknown) => {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!UUID_PATTERN.test(normalized)) {
    throw new AppError(
      ADOPTION_ERROR_CODES.chatNotFound,
      'Khong tim thay cuoc tro chuyen.',
      404,
    );
  }
  return normalized;
};

const readUuid = (value: unknown, field: string) => {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!UUID_PATTERN.test(normalized)) {
    return invalidInput(field, `${field} khong hop le.`);
  }
  return normalized;
};

const readOptionalString = (value: unknown, field: string) => {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || value.trim().length === 0) {
    return invalidInput(field, `${field} khong hop le.`);
  }
  return value.trim();
};

const readLimit = (value: unknown) => {
  if (value === undefined) return DEFAULT_LIMIT;
  let limit = Number.NaN;
  if (typeof value === 'number') {
    limit = value;
  } else if (typeof value === 'string') {
    limit = Number(value);
  }
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > MAX_LIMIT) {
    return invalidInput('limit', `limit phai tu 1 den ${MAX_LIMIT}.`);
  }
  return limit;
};

const readMessageBody = (value: unknown) => {
  if (typeof value !== 'string') {
    return invalidInput('body', 'body phai la chuoi.');
  }
  const body = value.trim();
  if (body.length < 1 || body.length > 1_000) {
    return invalidInput('body', 'body phai dai tu 1 den 1000 ky tu.');
  }
  return body;
};

const readMediaIds = (value: unknown) => {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 5) {
    return invalidInput('mediaIds', 'mediaIds phai la mang toi da 5 UUID.');
  }
  if (
    value.some(
      (mediaId) =>
        typeof mediaId !== 'string' || !UUID_PATTERN.test(mediaId.trim()),
    )
  ) {
    return invalidInput('mediaIds', 'mediaIds chua UUID khong hop le.');
  }
  const mediaIds = value.map((mediaId) => (mediaId as string).trim());
  if (new Set(mediaIds).size !== mediaIds.length) {
    return invalidInput('mediaIds', 'mediaIds khong duoc trung lap.');
  }
  return mediaIds;
};

const sha256 = (value: string) =>
  createHash('sha256').update(value).digest('hex');

const buildIdempotency = (input: {
  userId: string;
  normalizedPath: string;
  key: unknown;
  payload: unknown;
  now: Date;
}) => {
  if (
    typeof input.key !== 'string' ||
    input.key.trim().length < 8 ||
    input.key.trim().length > 128
  ) {
    return invalidInput(
      'Idempotency-Key',
      'Idempotency-Key phai dai tu 8 den 128 ky tu.',
    );
  }
  return {
    userId: input.userId,
    method: 'POST' as const,
    normalizedPath: input.normalizedPath,
    keyHash: sha256(input.key.trim()),
    requestHash: sha256(JSON.stringify(input.payload)),
    now: input.now,
  };
};

const encodeCursor = (threadId: string, position: ChatMessageCursor) =>
  Buffer.from(
    JSON.stringify({ version: 1, threadId, position }),
    'utf8',
  ).toString('base64url');

const parseCursorEnvelope = (value: string): Partial<ChatCursorEnvelope> => {
  if (value.length > 2_048 || !/^[A-Za-z0-9_-]+$/.test(value)) {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  try {
    const parsed = JSON.parse(
      Buffer.from(value, 'base64url').toString('utf8'),
    ) as unknown;
    if (!parsed || typeof parsed !== 'object') {
      return invalidInput('cursor', 'Cursor khong hop le.');
    }
    return parsed as Partial<ChatCursorEnvelope>;
  } catch {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
};

const decodeCursor = (
  value: string,
  expectedThreadId: string,
): ChatMessageCursor => {
  const candidate = parseCursorEnvelope(value);
  const { position } = candidate;
  if (
    candidate.version !== 1 ||
    candidate.threadId !== expectedThreadId ||
    !position
  ) {
    return invalidInput('cursor', 'Cursor khong khop voi cuoc tro chuyen.');
  }
  const date = new Date(position.createdAt);
  if (
    !/^[1-9][0-9]{0,19}$/.test(position.sequence) ||
    !UUID_PATTERN.test(position.messageId) ||
    !Number.isFinite(date.getTime()) ||
    date.toISOString() !== position.createdAt
  ) {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  return position;
};

const requireRepository = (repository?: ChatRepository) => {
  if (!repository) throw new Error('Adoption chat persistence is unavailable.');
  return repository;
};

const mapPersistenceError = (error: unknown): never => {
  if (!(error instanceof ChatPersistenceDomainError)) throw error;
  switch (error.reason) {
    case 'thread_not_found':
    case 'message_not_found':
      throw new AppError(
        ADOPTION_ERROR_CODES.chatNotFound,
        'Khong tim thay cuoc tro chuyen.',
        404,
      );
    case 'chat_closed':
      throw new AppError(
        ADOPTION_ERROR_CODES.chatClosed,
        'Cuoc tro chuyen da dong.',
        409,
      );
    case 'media_invalid':
      throw new AppError(
        ADOPTION_ERROR_CODES.invalidInput,
        'Media khong hop le, chua verified hoac khong thuoc nguoi gui.',
        400,
        'mediaIds',
      );
    case 'idempotency_conflict':
      throw new AppError(
        IDEMPOTENCY_ERROR_CODES.payloadConflict,
        'Idempotency-Key da duoc dung voi payload khac.',
        409,
        'Idempotency-Key',
      );
    default:
      throw error;
  }
};

const withPersistenceMapping = async <T>(work: () => Promise<T>) => {
  try {
    return await work();
  } catch (error) {
    return mapPersistenceError(error);
  }
};

const withoutLegacyPublicChatUrls = <T extends { media: Array<{
  mediaId: string;
  publicUrl?: string;
  downloadPath?: string;
}>; threadId: string }>(message: T): T => ({
  ...message,
  media: message.media.map((media) => {
    const safe = { ...media };
    delete safe.publicUrl;
    const expectedPath =
      `/adoption/chat/${message.threadId}/media/${media.mediaId}`;
    if (safe.downloadPath !== expectedPath) delete safe.downloadPath;
    return safe;
  }),
});

export const createAdoptionChatService = (options: {
  repository?: ChatRepository;
  storage?: RescueMediaStorage;
  now?: () => Date;
}) => {
  const repository = () => requireRepository(options.repository);
  const now = options.now ?? (() => new Date());

  return {
    async readMedia(participantUserId: string, threadId: unknown, mediaId: unknown) {
      const normalizedThreadId = requireChatUuid(threadId);
      const normalizedMediaId = requireChatUuid(mediaId);
      const media = await repository().findReadableMedia({
        participantUserId,
        threadId: normalizedThreadId,
        mediaId: normalizedMediaId,
      });
      if (!media) {
        throw new AppError(
          ADOPTION_ERROR_CODES.chatNotFound,
          'Khong tim thay tep dinh kem.',
          404,
        );
      }
      if (!['image/jpeg', 'image/png', 'image/webp', 'video/mp4'].includes(media.mimeType)) {
        throw new AppError(
          ADOPTION_ERROR_CODES.chatNotFound,
          'Khong tim thay tep dinh kem.',
          404,
        );
      }
      if (!options.storage) {
        throw new AppError(ADOPTION_ERROR_CODES.chatNotFound, 'Tep chua san sang.', 503);
      }
      try {
        const bytes = await options.storage.readPrivateObject(media.storageKey);
        return { bytes, mimeType: media.mimeType };
      } catch (error) {
        if (error instanceof RescueMediaStorageError && error.failure === 'object_missing') {
          throw new AppError(ADOPTION_ERROR_CODES.chatNotFound, 'Khong tim thay tep dinh kem.', 404);
        }
        if (error instanceof RescueMediaStorageError) {
          throw new AppError(ADOPTION_ERROR_CODES.chatNotFound, 'Tep tam thoi khong tai duoc.', 503);
        }
        throw error;
      }
    },

    async readThread(
      participantUserId: string,
      threadId: unknown,
      query: ChatQuery = {},
    ) {
      const normalizedThreadId = requireChatUuid(threadId);
      const limit = readLimit(query.limit);
      const cursorRaw = readOptionalString(query.cursor, 'cursor');
      const cursor = cursorRaw
        ? decodeCursor(cursorRaw, normalizedThreadId)
        : undefined;
      const page = await withPersistenceMapping(() =>
        repository().readThread({
          threadId: normalizedThreadId,
          participantUserId,
          cursor,
          limit,
        }),
      );
      return {
        thread: page.thread,
        items: page.items.map(withoutLegacyPublicChatUrls),
        ...(page.nextCursor
          ? {
              nextCursor: encodeCursor(normalizedThreadId, page.nextCursor),
            }
          : {}),
        limit: page.limit,
      };
    },

    async sendMessage(
      senderUserId: string,
      threadId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ) {
      const normalizedThreadId = requireChatUuid(threadId);
      const body = asObject(payload);
      assertKnownKeys(body, ['body', 'mediaIds']);
      const normalizedPayload = {
        body: readMessageBody(body.body),
        mediaIds: readMediaIds(body.mediaIds),
      };
      const timestamp = now();
      const idempotency = buildIdempotency({
        userId: senderUserId,
        normalizedPath: `/adoption/chat/${normalizedThreadId}/messages`,
        key: idempotencyKey,
        payload: normalizedPayload,
        now: timestamp,
      });
      const message = await withPersistenceMapping(() =>
        repository().sendMessage({
          threadId: normalizedThreadId,
          senderUserId,
          ...normalizedPayload,
          idempotency,
          now: timestamp,
        }),
      );
      return withoutLegacyPublicChatUrls(message);
    },

    async markRead(
      participantUserId: string,
      threadId: unknown,
      payload: unknown,
    ) {
      const normalizedThreadId = requireChatUuid(threadId);
      const body = asObject(payload);
      assertKnownKeys(body, ['throughMessageId']);
      const throughMessageId = readUuid(
        body.throughMessageId,
        'throughMessageId',
      );
      return withPersistenceMapping(() =>
        repository().markRead({
          threadId: normalizedThreadId,
          participantUserId,
          throughMessageId,
          now: now(),
        }),
      );
    },
  };
};

export type AdoptionChatService = ReturnType<typeof createAdoptionChatService>;

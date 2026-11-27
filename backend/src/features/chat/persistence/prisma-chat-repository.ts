import { Prisma, type PrismaClient } from '@prisma/client';

import {
  ChatPersistenceDomainError,
  type ChatIdempotencyInput,
  type ChatMediaRecord,
  type ChatMessageCursor,
  type ChatMessageRecord,
  type ChatRepository,
  type ChatThreadPage,
} from './chat-repository';

type TransactionClient = Omit<
  PrismaClient,
  '$connect' | '$disconnect' | '$on' | '$transaction' | '$use' | '$extends'
>;

type ChatMessageRow = Prisma.AdoptionChatMessageGetPayload<{
  include: { media: true };
}>;

const toMediaRecord = (
  media: ChatMessageRow['media'][number],
): ChatMediaRecord => {
  if (media.purpose !== 'adoption_chat') {
    throw new Error('Chat message media has an invalid purpose.');
  }
  return {
    mediaId: media.id,
    ownerUserId: media.ownerUserId,
    purpose: media.purpose,
    mimeType: media.mimeType,
    sizeBytes: Number(media.sizeBytes),
    sha256: media.sha256,
    status: media.status,
    ...(media.width !== null ? { width: media.width } : {}),
    ...(media.height !== null ? { height: media.height } : {}),
    ...(media.durationSeconds !== null
      ? { durationSeconds: Number(media.durationSeconds) }
      : {}),
    createdAt: media.createdAt.toISOString(),
  };
};

const toMessageRecord = (message: ChatMessageRow): ChatMessageRecord => ({
  messageId: message.id,
  threadId: message.threadId,
  senderUserId: message.senderUserId,
  body: message.body,
  media: [...message.media]
    .sort((left, right) => (left.position ?? 0) - (right.position ?? 0))
    .map((media) => ({
      ...toMediaRecord(media),
      ...(media.status === 'attached' &&
      !media.publicUrl &&
      new RegExp(
        `^adoption_chat/${message.threadId}/${media.id}/[0-9a-f]{64}/private\\.(?:jpg|png|webp|mp4)$`,
      ).test(media.storageKey)
        ? {
            downloadPath: `/adoption/chat/${message.threadId}/media/${media.id}`,
          }
        : {}),
    })),
  createdAt: message.createdAt.toISOString(),
  updatedAt: message.updatedAt.toISOString(),
});

const requireParticipant = async (
  transaction: TransactionClient,
  threadId: string,
  userId: string,
) => {
  const participant = await transaction.adoptionChatParticipant.findUnique({
    where: { threadId_userId: { threadId, userId } },
    include: { thread: true },
  });
  if (!participant) {
    throw new ChatPersistenceDomainError(
      'thread_not_found',
      'Chat thread was not found.',
    );
  }
  return participant;
};

const buildMessageCursor = (
  message: ChatMessageRow | undefined,
  hasMore: boolean,
): ChatMessageCursor | undefined =>
  message && hasMore
    ? {
        sequence: message.sequence.toString(),
        createdAt: message.createdAt.toISOString(),
        messageId: message.id,
      }
    : undefined;

const attachMedia = async (
  transaction: TransactionClient,
  messageId: string,
  threadId: string,
  senderUserId: string,
  mediaIds: string[],
) => {
  if (mediaIds.length === 0) return;
  const results = await Promise.all(
    mediaIds.map((mediaId, position) =>
      transaction.mediaAsset.updateMany({
        where: {
          id: mediaId,
          ownerUserId: senderUserId,
          purpose: 'adoption_chat',
          status: 'verified',
          publicUrl: null,
          storageKey: { startsWith: `adoption_chat/${threadId}/` },
          deletedAt: null,
          adoptionChatMessageId: null,
        },
        data: {
          adoptionChatMessageId: messageId,
          position,
          status: 'attached',
        },
      }),
    ),
  );
  if (results.some((result) => result.count !== 1)) {
    throw new ChatPersistenceDomainError(
      'media_invalid',
      'Chat media is unavailable or not owned by the sender.',
    );
  }
};

export class PrismaChatRepository implements ChatRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async isCurrentParticipant(
    input: Parameters<ChatRepository['isCurrentParticipant']>[0],
  ) {
    const participant = await this.prisma.adoptionChatParticipant.findUnique({
      where: {
        threadId_userId: {
          threadId: input.threadId,
          userId: input.participantUserId,
        },
      },
      select: { thread: { select: { closedAt: true } } },
    });
    return participant !== null && participant.thread.closedAt === null;
  }

  async findReadableMedia(
    input: Parameters<ChatRepository['findReadableMedia']>[0],
  ) {
    const media = await this.prisma.mediaAsset.findFirst({
      where: {
        id: input.mediaId,
        purpose: 'adoption_chat',
        status: 'attached',
        deletedAt: null,
        publicUrl: null,
        storageKey: { startsWith: `adoption_chat/${input.threadId}/` },
        adoptionChatMessage: {
          threadId: input.threadId,
          thread: {
            participants: { some: { userId: input.participantUserId } },
          },
        },
      },
      select: { storageKey: true, mimeType: true },
    });
    if (
      !media ||
      !new RegExp(
        `^adoption_chat/${input.threadId}/${input.mediaId}/[0-9a-f]{64}/private\\.(?:jpg|png|webp|mp4)$`,
      ).test(media.storageKey)
    ) {
      return undefined;
    }
    return media;
  }

  private async executeCommand<T>(
    idempotency: ChatIdempotencyInput,
    execute: (transaction: TransactionClient) => Promise<T>,
  ): Promise<T> {
    return this.prisma.$transaction(async (transaction) => {
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
        where: { userId_method_normalizedPath_keyHash: identity },
      });
      if (existing && existing.expiresAt > now) {
        if (existing.requestHash !== idempotency.requestHash) {
          throw new ChatPersistenceDomainError(
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
      await transaction.idempotencyRecord.create({
        data: {
          ...identity,
          requestHash: idempotency.requestHash,
          responseStatus: 201,
          responseBody: JSON.parse(
            JSON.stringify(result),
          ) as Prisma.InputJsonValue,
          createdAt: now,
          expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1_000),
        },
      });
      return result;
    });
  }

  async readThread(
    input: Parameters<ChatRepository['readThread']>[0],
  ): Promise<ChatThreadPage> {
    const participant = await requireParticipant(
      this.prisma,
      input.threadId,
      input.participantUserId,
    );
    const rows = await this.prisma.adoptionChatMessage.findMany({
      where: {
        threadId: input.threadId,
        ...(input.cursor
          ? { sequence: { lt: BigInt(input.cursor.sequence) } }
          : {}),
      },
      include: { media: true },
      orderBy: { sequence: 'desc' },
      take: input.limit + 1,
    });
    const unreadCount = await this.prisma.adoptionChatMessage.count({
      where: {
        threadId: input.threadId,
        senderUserId: { not: input.participantUserId },
        sequence: { gt: participant.lastReadSequence },
      },
    });
    const hasMore = rows.length > input.limit;
    const visibleRows = rows.slice(0, input.limit);
    const nextCursor = buildMessageCursor(visibleRows.at(-1), hasMore);
    return {
      thread: {
        threadId: participant.threadId,
        requestId: participant.thread.requestId,
        participantRole: participant.role,
        lastReadAt: participant.lastReadAt.toISOString(),
        unreadCount,
        ...(participant.thread.closedAt
          ? { closedAt: participant.thread.closedAt.toISOString() }
          : {}),
      },
      items: [...visibleRows].reverse().map(toMessageRecord),
      ...(nextCursor ? { nextCursor } : {}),
      limit: input.limit,
    };
  }

  async sendMessage(
    input: Parameters<ChatRepository['sendMessage']>[0],
  ): Promise<ChatMessageRecord> {
    return this.executeCommand(input.idempotency, async (transaction) => {
      const participant = await requireParticipant(
        transaction,
        input.threadId,
        input.senderUserId,
      );
      if (participant.thread.closedAt) {
        throw new ChatPersistenceDomainError(
          'chat_closed',
          'Chat thread is closed.',
        );
      }
      const message = await transaction.adoptionChatMessage.create({
        data: {
          threadId: input.threadId,
          senderUserId: input.senderUserId,
          body: input.body,
          createdAt: input.now,
          updatedAt: input.now,
        },
      });
      await attachMedia(
        transaction,
        message.id,
        input.threadId,
        input.senderUserId,
        input.mediaIds,
      );
      await transaction.adoptionChatThread.update({
        where: { id: input.threadId },
        data: { updatedAt: input.now },
      });
      const recipientUserId =
        participant.role === 'adopter'
          ? participant.thread.shelterId
          : participant.thread.adopterUserId;
      await transaction.outboxEvent.create({
        data: {
          topic: 'adoption.chat',
          eventType: 'adoption.chat_message_created.v1',
          aggregateType: 'adoption_chat_message',
          aggregateId: message.id,
          actorUserId: input.senderUserId,
          payload: {
            messageId: message.id,
            threadId: input.threadId,
            requestId: participant.thread.requestId,
            senderUserId: input.senderUserId,
            recipientUserId,
            mediaCount: input.mediaIds.length,
          },
          dedupeKey: `adoption.chat_message_created.v1:${message.id}`,
          occurredAt: input.now,
          availableAt: input.now,
        },
      });
      const persisted = await transaction.adoptionChatMessage.findUnique({
        where: { id: message.id },
        include: { media: true },
      });
      if (!persisted) {
        throw new Error('Chat message was not persisted.');
      }
      return toMessageRecord(persisted);
    });
  }

  async markRead(input: Parameters<ChatRepository['markRead']>[0]): Promise<{
    threadId: string;
    lastReadAt: string;
    unreadCount: number;
  }> {
    return this.prisma.$transaction(async (transaction) => {
      await requireParticipant(
        transaction,
        input.threadId,
        input.participantUserId,
      );
      const throughMessage = await transaction.adoptionChatMessage.findFirst({
        where: {
          id: input.throughMessageId,
          threadId: input.threadId,
        },
        select: { sequence: true, createdAt: true },
      });
      if (!throughMessage) {
        throw new ChatPersistenceDomainError(
          'message_not_found',
          'Chat message was not found.',
        );
      }
      await transaction.adoptionChatParticipant.updateMany({
        where: {
          threadId: input.threadId,
          userId: input.participantUserId,
          lastReadSequence: { lt: throughMessage.sequence },
        },
        data: {
          lastReadAt: throughMessage.createdAt,
          lastReadSequence: throughMessage.sequence,
          updatedAt: input.now,
        },
      });
      const currentReadState =
        await transaction.adoptionChatParticipant.findUnique({
          where: {
            threadId_userId: {
              threadId: input.threadId,
              userId: input.participantUserId,
            },
          },
          select: { lastReadAt: true, lastReadSequence: true },
        });
      if (!currentReadState) {
        throw new ChatPersistenceDomainError(
          'thread_not_found',
          'Chat thread was not found.',
        );
      }
      const unreadCount = await transaction.adoptionChatMessage.count({
        where: {
          threadId: input.threadId,
          senderUserId: { not: input.participantUserId },
          sequence: { gt: currentReadState.lastReadSequence },
        },
      });
      return {
        threadId: input.threadId,
        lastReadAt: currentReadState.lastReadAt.toISOString(),
        unreadCount,
      };
    });
  }
}

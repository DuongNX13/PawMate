import { type PrismaClient } from '@prisma/client';

import { ChatPersistenceDomainError } from '../src/features/chat/persistence/chat-repository';
import { PrismaChatRepository } from '../src/features/chat/persistence/prisma-chat-repository';
import {
  ADOPTER_USER_ID,
  REQUEST_ID,
  SHELTER_USER_ID,
  THREAD_ID,
} from './helpers/adoption-fixtures';
import {
  CHAT_MEDIA_ID,
  CHAT_MESSAGE_ID,
  CHAT_MESSAGE_ID_2,
} from './helpers/adoption-chat-fixtures';

const NOW = new Date('2026-07-27T11:00:00.000Z');

const makeParticipant = (overrides: Record<string, unknown> = {}) => ({
  threadId: THREAD_ID,
  userId: ADOPTER_USER_ID,
  role: 'adopter',
  lastReadAt: new Date('2026-07-27T09:00:00.000Z'),
  lastReadSequence: BigInt(1),
  createdAt: new Date('2026-07-27T09:00:00.000Z'),
  updatedAt: new Date('2026-07-27T09:00:00.000Z'),
  thread: {
    id: THREAD_ID,
    requestId: REQUEST_ID,
    adopterUserId: ADOPTER_USER_ID,
    shelterId: SHELTER_USER_ID,
    createdAt: new Date('2026-07-27T09:00:00.000Z'),
    updatedAt: new Date('2026-07-27T09:00:00.000Z'),
    closedAt: null,
  },
  ...overrides,
});

const makePrismaMessage = (overrides: Record<string, unknown> = {}) => ({
  id: CHAT_MESSAGE_ID,
  sequence: BigInt(2),
  threadId: THREAD_ID,
  senderUserId: SHELTER_USER_ID,
  body: 'Xin chao nguoi nhan nuoi.',
  createdAt: new Date('2026-07-27T10:00:00.000Z'),
  updatedAt: new Date('2026-07-27T10:00:00.000Z'),
  media: [],
  ...overrides,
});

const makePrismaMedia = () => ({
  id: CHAT_MEDIA_ID,
  ownerUserId: ADOPTER_USER_ID,
  purpose: 'adoption_chat',
  mimeType: 'image/webp',
  sizeBytes: BigInt(4_096),
  sha256: '6'.repeat(64),
  status: 'attached',
  storageKey: 'day51/chat/proof.webp',
  publicUrl: 'https://cdn.example.test/day51/chat/proof.webp',
  width: 800,
  height: 600,
  durationSeconds: null,
  draftId: null,
  caseId: null,
  commentId: null,
  position: 0,
  verificationVersion: 1,
  verifiedAt: NOW,
  createdAt: NOW,
  updatedAt: NOW,
  deletedAt: null,
  adoptionChatMessageId: CHAT_MESSAGE_ID,
});

describe('Day 51 Prisma chat repository', () => {
  it('only allows an active participant to allocate chat media', async () => {
    const findUnique = jest
      .fn()
      .mockResolvedValueOnce(makeParticipant())
      .mockResolvedValueOnce(
        makeParticipant({
          thread: {
            ...makeParticipant().thread,
            closedAt: NOW,
          },
        }),
      )
      .mockResolvedValueOnce(null);
    const repository = new PrismaChatRepository({
      adoptionChatParticipant: { findUnique },
    } as unknown as PrismaClient);
    const input = { participantUserId: ADOPTER_USER_ID, threadId: THREAD_ID };

    await expect(repository.isCurrentParticipant(input)).resolves.toBe(true);
    await expect(repository.isCurrentParticipant(input)).resolves.toBe(false);
    await expect(repository.isCurrentParticipant(input)).resolves.toBe(false);
    expect(findUnique).toHaveBeenCalledWith({
      where: {
        threadId_userId: { threadId: THREAD_ID, userId: ADOPTER_USER_ID },
      },
      select: { thread: { select: { closedAt: true } } },
    });
  });

  it('requires thread membership and bound private path on every media read', async () => {
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        storageKey: `adoption_chat/${THREAD_ID}/${CHAT_MEDIA_ID}/${'a'.repeat(64)}/private.jpg`,
        mimeType: 'image/jpeg',
      })
      .mockResolvedValueOnce({
        storageKey: `adoption_chat/other-thread/${CHAT_MEDIA_ID}/${'a'.repeat(64)}/private.jpg`,
        mimeType: 'image/jpeg',
      });
    const repository = new PrismaChatRepository({
      mediaAsset: { findFirst },
    } as unknown as PrismaClient);
    const input = {
      participantUserId: ADOPTER_USER_ID,
      threadId: THREAD_ID,
      mediaId: CHAT_MEDIA_ID,
    };

    await expect(repository.findReadableMedia(input)).resolves.toMatchObject({
      mimeType: 'image/jpeg',
    });
    await expect(repository.findReadableMedia(input)).resolves.toBeUndefined();
    expect(findFirst).toHaveBeenCalledWith({
      where: expect.objectContaining({
        id: CHAT_MEDIA_ID,
        publicUrl: null,
        storageKey: { startsWith: `adoption_chat/${THREAD_ID}/` },
        adoptionChatMessage: {
          threadId: THREAD_ID,
          thread: { participants: { some: { userId: ADOPTER_USER_ID } } },
        },
      }),
      select: { storageKey: true, mimeType: true },
    });
  });
  it('returns oldest-to-newest items with an opaque older-page cursor and unread count', async () => {
    const findParticipant = jest.fn().mockResolvedValue(makeParticipant());
    const findMany = jest.fn().mockResolvedValue([
      makePrismaMessage({
        id: CHAT_MESSAGE_ID_2,
        sequence: BigInt(3),
        createdAt: new Date('2026-07-27T10:01:00.000Z'),
      }),
      makePrismaMessage(),
    ]);
    const count = jest.fn().mockResolvedValue(2);
    const repository = new PrismaChatRepository({
      adoptionChatParticipant: { findUnique: findParticipant },
      adoptionChatMessage: { findMany, count },
    } as unknown as PrismaClient);

    const page = await repository.readThread({
      threadId: THREAD_ID,
      participantUserId: ADOPTER_USER_ID,
      limit: 1,
    });

    expect(page.items.map((message) => message.messageId)).toEqual([
      CHAT_MESSAGE_ID_2,
    ]);
    expect(page.nextCursor).toEqual({
      sequence: '3',
      createdAt: '2026-07-27T10:01:00.000Z',
      messageId: CHAT_MESSAGE_ID_2,
    });
    expect(page.thread).toMatchObject({
      threadId: THREAD_ID,
      participantRole: 'adopter',
      unreadCount: 2,
    });
    expect(count).toHaveBeenCalledWith({
      where: {
        threadId: THREAD_ID,
        senderUserId: { not: ADOPTER_USER_ID },
        sequence: { gt: BigInt(1) },
      },
    });
  });

  it('only advertises a private download when its object key matches the media ID', async () => {
    const mismatchedId = '52000000-0000-4000-8000-000000000099';
    const privateMedia = {
      ...makePrismaMedia(),
      publicUrl: null,
      storageKey: `adoption_chat/${THREAD_ID}/${CHAT_MEDIA_ID}/${'a'.repeat(64)}/private.webp`,
    };
    const repository = new PrismaChatRepository({
      adoptionChatParticipant: {
        findUnique: jest.fn().mockResolvedValue(makeParticipant()),
      },
      adoptionChatMessage: {
        findMany: jest.fn().mockResolvedValue([
          makePrismaMessage({
            media: [
              privateMedia,
              {
                ...privateMedia,
                id: mismatchedId,
              },
            ],
          }),
        ]),
        count: jest.fn().mockResolvedValue(0),
      },
    } as unknown as PrismaClient);

    const page = await repository.readThread({
      threadId: THREAD_ID,
      participantUserId: ADOPTER_USER_ID,
      limit: 20,
    });

    expect(page.items[0]?.media[0]?.downloadPath).toBe(
      `/adoption/chat/${THREAD_ID}/media/${CHAT_MEDIA_ID}`,
    );
    expect(page.items[0]?.media[1]?.downloadPath).toBeUndefined();
  });

  it('collapses a nonparticipant thread lookup to thread_not_found', async () => {
    const repository = new PrismaChatRepository({
      adoptionChatParticipant: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaClient);

    await expect(
      repository.readThread({
        threadId: THREAD_ID,
        participantUserId: ADOPTER_USER_ID,
        limit: 20,
      }),
    ).rejects.toEqual(
      expect.objectContaining<Partial<ChatPersistenceDomainError>>({
        reason: 'thread_not_found',
      }),
    );
  });

  it('rejects a nonparticipant before creating a message or claiming chat media', async () => {
    const createMessage = jest.fn();
    const claimMedia = jest.fn();
    const createOutbox = jest.fn();
    const transaction = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue(null),
        delete: jest.fn(),
        create: jest.fn(),
      },
      adoptionChatParticipant: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
      adoptionChatMessage: { create: createMessage },
      mediaAsset: { updateMany: claimMedia },
      adoptionChatThread: { update: jest.fn() },
      outboxEvent: { create: createOutbox },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    await expect(
      repository.sendMessage({
        threadId: THREAD_ID,
        senderUserId: ADOPTER_USER_ID,
        body: 'Khong duoc gui.',
        mediaIds: [CHAT_MEDIA_ID],
        idempotency: {
          userId: ADOPTER_USER_ID,
          method: 'POST',
          normalizedPath: `/adoption/chat/${THREAD_ID}/messages`,
          keyHash: 'a'.repeat(64),
          requestHash: 'b'.repeat(64),
          now: NOW,
        },
        now: NOW,
      }),
    ).rejects.toEqual(
      expect.objectContaining<Partial<ChatPersistenceDomainError>>({
        reason: 'thread_not_found',
      }),
    );
    expect(createMessage).not.toHaveBeenCalled();
    expect(claimMedia).not.toHaveBeenCalled();
    expect(createOutbox).not.toHaveBeenCalled();
  });

  it('rejects a nonparticipant before changing any read cursor', async () => {
    const findThroughMessage = jest.fn();
    const updateReadCursor = jest.fn();
    const transaction = {
      adoptionChatParticipant: {
        findUnique: jest.fn().mockResolvedValue(null),
        updateMany: updateReadCursor,
      },
      adoptionChatMessage: {
        findFirst: findThroughMessage,
        count: jest.fn(),
      },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    await expect(
      repository.markRead({
        threadId: THREAD_ID,
        participantUserId: ADOPTER_USER_ID,
        throughMessageId: CHAT_MESSAGE_ID,
        now: NOW,
      }),
    ).rejects.toEqual(
      expect.objectContaining<Partial<ChatPersistenceDomainError>>({
        reason: 'thread_not_found',
      }),
    );
    expect(findThroughMessage).not.toHaveBeenCalled();
    expect(updateReadCursor).not.toHaveBeenCalled();
  });

  it('persists message, claims verified sender media and emits a privacy-safe outbox event atomically', async () => {
    const transaction = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue(null),
        delete: jest.fn(),
        create: jest.fn().mockResolvedValue({}),
      },
      adoptionChatParticipant: {
        findUnique: jest.fn().mockResolvedValue(makeParticipant()),
      },
      adoptionChatMessage: {
        create: jest.fn().mockResolvedValue(makePrismaMessage()),
        findUnique: jest.fn().mockResolvedValue(
          makePrismaMessage({
            senderUserId: ADOPTER_USER_ID,
            body: 'Xin chao mai am.',
            media: [makePrismaMedia()],
          }),
        ),
      },
      mediaAsset: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      adoptionChatThread: {
        update: jest.fn().mockResolvedValue({}),
      },
      outboxEvent: {
        create: jest.fn().mockResolvedValue({}),
      },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    const result = await repository.sendMessage({
      threadId: THREAD_ID,
      senderUserId: ADOPTER_USER_ID,
      body: 'Xin chao mai am.',
      mediaIds: [CHAT_MEDIA_ID],
      idempotency: {
        userId: ADOPTER_USER_ID,
        method: 'POST',
        normalizedPath: `/adoption/chat/${THREAD_ID}/messages`,
        keyHash: 'a'.repeat(64),
        requestHash: 'b'.repeat(64),
        now: NOW,
      },
      now: NOW,
    });

    expect(result).toMatchObject({
      messageId: CHAT_MESSAGE_ID,
      senderUserId: ADOPTER_USER_ID,
      media: [{ mediaId: CHAT_MEDIA_ID, status: 'attached' }],
    });
    expect(transaction.mediaAsset.updateMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        id: CHAT_MEDIA_ID,
        ownerUserId: ADOPTER_USER_ID,
        purpose: 'adoption_chat',
        status: 'verified',
        publicUrl: null,
        storageKey: { startsWith: `adoption_chat/${THREAD_ID}/` },
        adoptionChatMessageId: null,
      }),
      data: {
        adoptionChatMessageId: CHAT_MESSAGE_ID,
        position: 0,
        status: 'attached',
      },
    });
    expect(transaction.outboxEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        eventType: 'adoption.chat_message_created.v1',
        payload: expect.objectContaining({
          recipientUserId: SHELTER_USER_ID,
          mediaCount: 1,
        }),
      }),
    });
    expect(
      transaction.outboxEvent.create.mock.calls[0]?.[0],
    ).not.toHaveProperty('data.payload.body');
    expect(transaction.idempotencyRecord.create).toHaveBeenCalledTimes(1);
  });

  it('fails before outbox when one media claim loses a concurrent race', async () => {
    const transaction = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue(null),
        delete: jest.fn(),
        create: jest.fn(),
      },
      adoptionChatParticipant: {
        findUnique: jest.fn().mockResolvedValue(makeParticipant()),
      },
      adoptionChatMessage: {
        create: jest.fn().mockResolvedValue(makePrismaMessage()),
      },
      mediaAsset: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      adoptionChatThread: { update: jest.fn() },
      outboxEvent: { create: jest.fn() },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    await expect(
      repository.sendMessage({
        threadId: THREAD_ID,
        senderUserId: ADOPTER_USER_ID,
        body: 'Xin chao.',
        mediaIds: [CHAT_MEDIA_ID],
        idempotency: {
          userId: ADOPTER_USER_ID,
          method: 'POST',
          normalizedPath: `/adoption/chat/${THREAD_ID}/messages`,
          keyHash: 'a'.repeat(64),
          requestHash: 'b'.repeat(64),
          now: NOW,
        },
        now: NOW,
      }),
    ).rejects.toMatchObject({ reason: 'media_invalid' });
    expect(transaction.outboxEvent.create).not.toHaveBeenCalled();
    expect(transaction.idempotencyRecord.create).not.toHaveBeenCalled();
  });

  it('replays the original message without repeating side effects', async () => {
    const replay = {
      messageId: CHAT_MESSAGE_ID,
      threadId: THREAD_ID,
      senderUserId: ADOPTER_USER_ID,
      body: 'Replay',
      media: [],
      createdAt: NOW.toISOString(),
      updatedAt: NOW.toISOString(),
    };
    const transaction = {
      $queryRaw: jest.fn().mockResolvedValue([{ locked: true }]),
      idempotencyRecord: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'idempotency-record',
          requestHash: 'b'.repeat(64),
          responseBody: replay,
          expiresAt: new Date('2026-07-28T11:00:00.000Z'),
        }),
        delete: jest.fn(),
        create: jest.fn(),
      },
      adoptionChatParticipant: { findUnique: jest.fn() },
      adoptionChatMessage: { create: jest.fn() },
      outboxEvent: { create: jest.fn() },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    const result = await repository.sendMessage({
      threadId: THREAD_ID,
      senderUserId: ADOPTER_USER_ID,
      body: 'Replay',
      mediaIds: [],
      idempotency: {
        userId: ADOPTER_USER_ID,
        method: 'POST',
        normalizedPath: `/adoption/chat/${THREAD_ID}/messages`,
        keyHash: 'a'.repeat(64),
        requestHash: 'b'.repeat(64),
        now: NOW,
      },
      now: NOW,
    });

    expect(result).toEqual(replay);
    expect(transaction.adoptionChatMessage.create).not.toHaveBeenCalled();
    expect(transaction.outboxEvent.create).not.toHaveBeenCalled();
  });

  it('advances the monotonic read sequence and returns remaining unread count', async () => {
    const transaction = {
      adoptionChatParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(makeParticipant())
          .mockResolvedValueOnce({
            lastReadAt: NOW,
            lastReadSequence: BigInt(5),
          }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      adoptionChatMessage: {
        findFirst: jest.fn().mockResolvedValue({
          sequence: BigInt(5),
          createdAt: NOW,
        }),
        count: jest.fn().mockResolvedValue(1),
      },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    const result = await repository.markRead({
      threadId: THREAD_ID,
      participantUserId: ADOPTER_USER_ID,
      throughMessageId: CHAT_MESSAGE_ID,
      now: NOW,
    });

    expect(result).toEqual({
      threadId: THREAD_ID,
      lastReadAt: NOW.toISOString(),
      unreadCount: 1,
    });
    expect(transaction.adoptionChatParticipant.updateMany).toHaveBeenCalledWith(
      {
        where: {
          threadId: THREAD_ID,
          userId: ADOPTER_USER_ID,
          lastReadSequence: { lt: BigInt(5) },
        },
        data: {
          lastReadAt: NOW,
          lastReadSequence: BigInt(5),
          updatedAt: NOW,
        },
      },
    );
    expect(transaction.adoptionChatMessage.count).toHaveBeenCalledWith({
      where: {
        threadId: THREAD_ID,
        senderUserId: { not: ADOPTER_USER_ID },
        sequence: { gt: BigInt(5) },
      },
    });
  });

  it('does not regress a read cursor when a newer update wins concurrently', async () => {
    const latestReadAt = new Date('2026-07-27T11:05:00.000Z');
    const transaction = {
      adoptionChatParticipant: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(makeParticipant())
          .mockResolvedValueOnce({
            lastReadAt: latestReadAt,
            lastReadSequence: BigInt(10),
          }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      adoptionChatMessage: {
        findFirst: jest.fn().mockResolvedValue({
          sequence: BigInt(5),
          createdAt: NOW,
        }),
        count: jest.fn().mockResolvedValue(0),
      },
    };
    const repository = new PrismaChatRepository({
      $transaction: jest.fn(async (work) => work(transaction)),
    } as unknown as PrismaClient);

    const result = await repository.markRead({
      threadId: THREAD_ID,
      participantUserId: ADOPTER_USER_ID,
      throughMessageId: CHAT_MESSAGE_ID,
      now: NOW,
    });

    expect(result).toEqual({
      threadId: THREAD_ID,
      lastReadAt: latestReadAt.toISOString(),
      unreadCount: 0,
    });
    expect(transaction.adoptionChatMessage.count).toHaveBeenCalledWith({
      where: {
        threadId: THREAD_ID,
        senderUserId: { not: ADOPTER_USER_ID },
        sequence: { gt: BigInt(10) },
      },
    });
  });
});

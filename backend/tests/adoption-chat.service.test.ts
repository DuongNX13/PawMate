import {
  ADOPTION_ERROR_CODES,
  IDEMPOTENCY_ERROR_CODES,
} from '../src/errors/error-codes';
import { ChatPersistenceDomainError } from '../src/features/chat/persistence/chat-repository';
import {
  RescueMediaStorageError,
  type RescueMediaStorage,
} from '../src/infrastructure/rescue-media-storage';
import { createAdoptionChatService } from '../src/services/adoption/adoption-chat-service';
import {
  ADOPTER_USER_ID,
  SHELTER_USER_ID,
  THREAD_ID,
} from './helpers/adoption-fixtures';
import {
  buildChatRepositoryMock,
  CHAT_MEDIA_ID,
  CHAT_MESSAGE_ID,
  makeChatMessage,
  NON_PARTICIPANT_USER_ID,
} from './helpers/adoption-chat-fixtures';

const NOW = new Date('2026-07-27T11:00:00.000Z');
const OTHER_THREAD_ID = '53000000-0000-4000-8000-000000000001';

describe('Day 51 Adoption chat service', () => {
  it.each([ADOPTER_USER_ID, SHELTER_USER_ID])(
    'authorizes current participant %s before reading private bytes',
    async (participantUserId) => {
      const { repository, findReadableMedia } = buildChatRepositoryMock();
      const storageKey = `adoption_chat/${CHAT_MEDIA_ID}/${'a'.repeat(64)}/private.jpg`;
      findReadableMedia.mockResolvedValueOnce({ storageKey, mimeType: 'image/jpeg' });
      const readPrivateObject = jest.fn().mockResolvedValue(Buffer.from('chat-photo'));
      const service = createAdoptionChatService({
        repository,
        storage: { readPrivateObject } as unknown as RescueMediaStorage,
      });

      await expect(
        service.readMedia(participantUserId, THREAD_ID, CHAT_MEDIA_ID),
      ).resolves.toEqual({
        bytes: Buffer.from('chat-photo'),
        mimeType: 'image/jpeg',
      });
      expect(findReadableMedia).toHaveBeenCalledWith({
        participantUserId,
        threadId: THREAD_ID,
        mediaId: CHAT_MEDIA_ID,
      });
      expect(readPrivateObject).toHaveBeenCalledWith(storageKey);
    },
  );

  it('never reads storage for a nonparticipant or revoked participant', async () => {
    const { repository, findReadableMedia } = buildChatRepositoryMock();
    const readPrivateObject = jest.fn();
    const service = createAdoptionChatService({
      repository,
      storage: { readPrivateObject } as unknown as RescueMediaStorage,
    });

    await expect(
      service.readMedia(NON_PARTICIPANT_USER_ID, THREAD_ID, CHAT_MEDIA_ID),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.chatNotFound,
      statusCode: 404,
    });
    expect(findReadableMedia).toHaveBeenCalledWith({
      participantUserId: NON_PARTICIPANT_USER_ID,
      threadId: THREAD_ID,
      mediaId: CHAT_MEDIA_ID,
    });
    expect(readPrivateObject).not.toHaveBeenCalled();
  });

  it('does not query media for an invalid thread or media identifier', async () => {
    const { repository, findReadableMedia } = buildChatRepositoryMock();
    const readPrivateObject = jest.fn();
    const service = createAdoptionChatService({
      repository,
      storage: { readPrivateObject } as unknown as RescueMediaStorage,
    });

    await expect(service.readMedia(ADOPTER_USER_ID, 'wrong', CHAT_MEDIA_ID)).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.chatNotFound,
      statusCode: 404,
    });
    await expect(service.readMedia(ADOPTER_USER_ID, THREAD_ID, 'wrong')).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.chatNotFound,
      statusCode: 404,
    });
    expect(findReadableMedia).not.toHaveBeenCalled();
    expect(readPrivateObject).not.toHaveBeenCalled();
  });

  it('returns a generic not-found error when the private object is absent', async () => {
    const { repository, findReadableMedia } = buildChatRepositoryMock();
    findReadableMedia.mockResolvedValueOnce({
      storageKey: `adoption_chat/${CHAT_MEDIA_ID}/${'a'.repeat(64)}/private.jpg`,
      mimeType: 'image/jpeg',
    });
    const readPrivateObject = jest.fn().mockRejectedValue(
      new RescueMediaStorageError('object_missing', 'sensitive bucket detail'),
    );
    const service = createAdoptionChatService({
      repository,
      storage: { readPrivateObject } as unknown as RescueMediaStorage,
    });

    await expect(
      service.readMedia(ADOPTER_USER_ID, THREAD_ID, CHAT_MEDIA_ID),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.chatNotFound,
      statusCode: 404,
      message: expect.not.stringContaining('sensitive bucket detail'),
    });
  });

  it('binds an opaque reverse-pagination cursor to the thread', async () => {
    const { repository, readThread } = buildChatRepositoryMock();
    readThread.mockResolvedValueOnce({
      thread: {
        threadId: THREAD_ID,
        requestId: '51000000-0000-4000-8000-000000000005',
        participantRole: 'adopter',
        lastReadAt: '2026-07-27T09:00:00.000Z',
        unreadCount: 1,
      },
      items: [makeChatMessage({ senderUserId: SHELTER_USER_ID })],
      nextCursor: {
        sequence: '7',
        createdAt: '2026-07-27T10:00:00.000Z',
        messageId: CHAT_MESSAGE_ID,
      },
      limit: 1,
    });
    const service = createAdoptionChatService({ repository });

    const first = await service.readThread(ADOPTER_USER_ID, THREAD_ID, {
      limit: '1',
    });
    expect(first.nextCursor).toEqual(expect.any(String));
    expect(first.nextCursor).not.toContain(CHAT_MESSAGE_ID);

    await service.readThread(ADOPTER_USER_ID, THREAD_ID, {
      cursor: first.nextCursor,
      limit: 1,
    });
    expect(readThread).toHaveBeenLastCalledWith({
      threadId: THREAD_ID,
      participantUserId: ADOPTER_USER_ID,
      cursor: {
        sequence: '7',
        createdAt: '2026-07-27T10:00:00.000Z',
        messageId: CHAT_MESSAGE_ID,
      },
      limit: 1,
    });

    await expect(
      service.readThread(ADOPTER_USER_ID, OTHER_THREAD_ID, {
        cursor: first.nextCursor,
      }),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      field: 'cursor',
    });
  });

  it.each([
    [{ limit: 0 }, 'limit'],
    [{ limit: 51 }, 'limit'],
    [{ cursor: 'not-json' }, 'cursor'],
  ])('rejects invalid chat query %p', async (query, field) => {
    const { repository } = buildChatRepositoryMock();
    const service = createAdoptionChatService({ repository });

    await expect(
      service.readThread(ADOPTER_USER_ID, THREAD_ID, query),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      field,
    });
  });

  it('normalizes message input and builds stable message idempotency scope', async () => {
    const { repository, sendMessage } = buildChatRepositoryMock();
    const service = createAdoptionChatService({
      repository,
      now: () => NOW,
    });

    await service.sendMessage(
      ADOPTER_USER_ID,
      THREAD_ID,
      {
        body: '  Xin chao mai am  ',
        mediaIds: [CHAT_MEDIA_ID],
      },
      'message-key-01',
    );

    expect(sendMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        threadId: THREAD_ID,
        senderUserId: ADOPTER_USER_ID,
        body: 'Xin chao mai am',
        mediaIds: [CHAT_MEDIA_ID],
        now: NOW,
        idempotency: expect.objectContaining({
          userId: ADOPTER_USER_ID,
          method: 'POST',
          normalizedPath: `/adoption/chat/${THREAD_ID}/messages`,
          keyHash: expect.stringMatching(/^[0-9a-f]{64}$/),
          requestHash: expect.stringMatching(/^[0-9a-f]{64}$/),
          now: NOW,
        }),
      }),
    );
  });

  it.each([
    [{ body: ' ' }, 'message-key-01', 'body'],
    [
      { body: 'x', mediaIds: [CHAT_MEDIA_ID, CHAT_MEDIA_ID] },
      'message-key-01',
      'mediaIds',
    ],
    [{ body: 'x', mediaIds: ['bad'] }, 'message-key-01', 'mediaIds'],
    [{ body: 'x', unexpected: true }, 'message-key-01', 'unexpected'],
    [{ body: 'x' }, 'short', 'Idempotency-Key'],
  ])(
    'rejects invalid message payload %p',
    async (payload, idempotencyKey, field) => {
      const { repository } = buildChatRepositoryMock();
      const service = createAdoptionChatService({ repository });

      await expect(
        service.sendMessage(
          ADOPTER_USER_ID,
          THREAD_ID,
          payload,
          idempotencyKey,
        ),
      ).rejects.toMatchObject({
        code: ADOPTION_ERROR_CODES.invalidInput,
        field,
      });
    },
  );

  it.each([
    ['thread_not_found', ADOPTION_ERROR_CODES.chatNotFound, 404],
    ['message_not_found', ADOPTION_ERROR_CODES.chatNotFound, 404],
    ['chat_closed', ADOPTION_ERROR_CODES.chatClosed, 409],
    ['media_invalid', ADOPTION_ERROR_CODES.invalidInput, 400],
    ['idempotency_conflict', IDEMPOTENCY_ERROR_CODES.payloadConflict, 409],
  ] as const)(
    'maps persistence failure %s without leaking participant data',
    async (reason, code, statusCode) => {
      const { repository, sendMessage } = buildChatRepositoryMock();
      sendMessage.mockRejectedValueOnce(
        new ChatPersistenceDomainError(reason, 'private detail'),
      );
      const service = createAdoptionChatService({ repository });

      await expect(
        service.sendMessage(
          ADOPTER_USER_ID,
          THREAD_ID,
          { body: 'Xin chao' },
          'message-key-01',
        ),
      ).rejects.toMatchObject({ code, statusCode });
    },
  );

  it('marks a validated message cursor as read', async () => {
    const { repository, markRead } = buildChatRepositoryMock();
    const service = createAdoptionChatService({
      repository,
      now: () => NOW,
    });

    const result = await service.markRead(ADOPTER_USER_ID, THREAD_ID, {
      throughMessageId: CHAT_MESSAGE_ID,
    });

    expect(result).toMatchObject({ threadId: THREAD_ID, unreadCount: 0 });
    expect(markRead).toHaveBeenCalledWith({
      threadId: THREAD_ID,
      participantUserId: ADOPTER_USER_ID,
      throughMessageId: CHAT_MESSAGE_ID,
      now: NOW,
    });
  });

  it('rejects a malformed read cursor as an input error', async () => {
    const { repository } = buildChatRepositoryMock();
    const service = createAdoptionChatService({ repository });

    await expect(
      service.markRead(ADOPTER_USER_ID, THREAD_ID, {
        throughMessageId: 'not-a-uuid',
      }),
    ).rejects.toMatchObject({
      code: ADOPTION_ERROR_CODES.invalidInput,
      statusCode: 400,
      field: 'throughMessageId',
    });
  });
});

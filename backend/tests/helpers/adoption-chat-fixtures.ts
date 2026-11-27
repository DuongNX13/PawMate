import {
  type ChatMessageRecord,
  type ChatRepository,
} from '../../src/features/chat/persistence/chat-repository';
import {
  ADOPTER_USER_ID,
  SHELTER_USER_ID,
  THREAD_ID,
} from './adoption-fixtures';

export const CHAT_MESSAGE_ID = '52000000-0000-4000-8000-000000000001';
export const CHAT_MESSAGE_ID_2 = '52000000-0000-4000-8000-000000000002';
export const CHAT_MEDIA_ID = '52000000-0000-4000-8000-000000000003';
export const NON_PARTICIPANT_USER_ID = '52000000-0000-4000-8000-000000000004';

export const makeChatMessage = (
  overrides: Partial<ChatMessageRecord> = {},
): ChatMessageRecord => ({
  messageId: CHAT_MESSAGE_ID,
  threadId: THREAD_ID,
  senderUserId: ADOPTER_USER_ID,
  body: 'Toi co the hen phong van vao thu Bay khong?',
  media: [],
  createdAt: '2026-07-27T10:00:00.000Z',
  updatedAt: '2026-07-27T10:00:00.000Z',
  ...overrides,
});

export const buildChatRepositoryMock = () => {
  const isCurrentParticipant = jest.fn<
    ReturnType<ChatRepository['isCurrentParticipant']>,
    Parameters<ChatRepository['isCurrentParticipant']>
  >().mockResolvedValue(true);
  const findReadableMedia = jest.fn<
    ReturnType<ChatRepository['findReadableMedia']>,
    Parameters<ChatRepository['findReadableMedia']>
  >();
  findReadableMedia.mockResolvedValue(undefined);
  const readThread = jest.fn<
    ReturnType<ChatRepository['readThread']>,
    Parameters<ChatRepository['readThread']>
  >();
  readThread.mockResolvedValue({
    thread: {
      threadId: THREAD_ID,
      requestId: '51000000-0000-4000-8000-000000000005',
      participantRole: 'adopter',
      lastReadAt: '2026-07-27T09:00:00.000Z',
      unreadCount: 1,
    },
    items: [makeChatMessage({ senderUserId: SHELTER_USER_ID })],
    limit: 20,
  });
  const sendMessage = jest.fn<
    ReturnType<ChatRepository['sendMessage']>,
    Parameters<ChatRepository['sendMessage']>
  >();
  sendMessage.mockResolvedValue(makeChatMessage());
  const markRead = jest.fn<
    ReturnType<ChatRepository['markRead']>,
    Parameters<ChatRepository['markRead']>
  >();
  markRead.mockResolvedValue({
    threadId: THREAD_ID,
    lastReadAt: '2026-07-27T10:00:00.000Z',
    unreadCount: 0,
  });
  const repository: ChatRepository = {
    isCurrentParticipant,
    findReadableMedia,
    readThread,
    sendMessage,
    markRead,
  };
  return { repository, isCurrentParticipant, findReadableMedia, readThread, sendMessage, markRead };
};

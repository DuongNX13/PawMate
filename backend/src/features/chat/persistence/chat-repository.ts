export type ChatParticipantRole = 'adopter' | 'shelter';

export type ChatMediaRecord = {
  mediaId: string;
  ownerUserId: string;
  purpose: 'adoption_chat';
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
  downloadPath?: string;
  width?: number;
  height?: number;
  durationSeconds?: number;
  createdAt: string;
};

export type ChatMessageRecord = {
  messageId: string;
  threadId: string;
  senderUserId: string;
  body: string;
  media: ChatMediaRecord[];
  createdAt: string;
  updatedAt?: string;
};

export type ChatMessageCursor = {
  sequence: string;
  createdAt: string;
  messageId: string;
};

export type ChatThreadState = {
  threadId: string;
  requestId: string;
  participantRole: ChatParticipantRole;
  lastReadAt: string;
  unreadCount: number;
  closedAt?: string;
};

export type ChatThreadPage = {
  thread: ChatThreadState;
  items: ChatMessageRecord[];
  nextCursor?: ChatMessageCursor;
  limit: number;
};

export type ChatReadState = {
  threadId: string;
  lastReadAt: string;
  unreadCount: number;
};

export type ChatIdempotencyInput = {
  userId: string;
  method: 'POST';
  normalizedPath: string;
  keyHash: string;
  requestHash: string;
  now?: Date;
};

export type ChatPersistenceFailure =
  | 'thread_not_found'
  | 'message_not_found'
  | 'chat_closed'
  | 'media_invalid'
  | 'idempotency_conflict';

export class ChatPersistenceDomainError extends Error {
  constructor(
    readonly reason: ChatPersistenceFailure,
    message: string,
  ) {
    super(message);
    this.name = 'ChatPersistenceDomainError';
  }
}

export interface ChatRepository {
  isCurrentParticipant(input: {
    participantUserId: string;
    threadId: string;
  }): Promise<boolean>;

  findReadableMedia(input: {
    participantUserId: string;
    threadId: string;
    mediaId: string;
  }): Promise<{ storageKey: string; mimeType: string } | undefined>;

  readThread(input: {
    threadId: string;
    participantUserId: string;
    cursor?: ChatMessageCursor;
    limit: number;
  }): Promise<ChatThreadPage>;

  sendMessage(input: {
    threadId: string;
    senderUserId: string;
    body: string;
    mediaIds: string[];
    idempotency: ChatIdempotencyInput;
    now: Date;
  }): Promise<ChatMessageRecord>;

  markRead(input: {
    threadId: string;
    participantUserId: string;
    throughMessageId: string;
    now: Date;
  }): Promise<ChatReadState>;
}

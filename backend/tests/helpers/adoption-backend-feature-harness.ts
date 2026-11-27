import { buildApp } from '../../src/app';
import {
  AdoptionPersistenceDomainError,
  type AdoptionDecisionRecord,
  type AdoptionIdempotencyInput,
  type AdoptionListingRecord,
  type AdoptionRepository,
  type AdoptionRequestRecord,
} from '../../src/features/adoption/persistence/adoption-repository';
import {
  ChatPersistenceDomainError,
  type ChatIdempotencyInput,
  type ChatMediaRecord,
  type ChatMessageRecord,
  type ChatRepository,
} from '../../src/features/chat/persistence/chat-repository';
import { createAdoptionChatService } from '../../src/services/adoption/adoption-chat-service';
import { createAdoptionService } from '../../src/services/adoption/adoption-service';
import { type AuthService } from '../../src/services/auth/auth-service';
import { buildTestConfig } from './rescue-read-fixtures';

export const D52_ADOPTER_ID = '54000000-0000-4000-8000-000000000001';
export const D52_SHELTER_ID = '54000000-0000-4000-8000-000000000002';
export const D52_OUTSIDER_ID = '54000000-0000-4000-8000-000000000003';
export const D52_LISTING_ID = '54000000-0000-4000-8000-000000000004';
export const D52_LISTING_MEDIA_ID = '54000000-0000-4000-8000-000000000005';
export const D52_REQUEST_ID = '54000000-0000-4000-8000-000000000006';
export const D52_THREAD_ID = '54000000-0000-4000-8000-000000000007';
export const D52_CHAT_MEDIA_ID = '54000000-0000-4000-8000-000000000008';
export const D52_UNKNOWN_THREAD_ID = '54000000-0000-4000-8000-000000000009';

const NOW = new Date('2026-07-28T01:30:00.000Z');
const MESSAGE_ID_PREFIX = '55000000-0000-4000-8000-';

type OutboxEvent = {
  type: 'adoption_request_submitted' | 'adoption_chat_message_created';
  payload: Record<string, unknown>;
};

type MessageState = {
  record: ChatMessageRecord;
  sequence: number;
};

type ThreadState = {
  requestId: string;
  adopterUserId: string;
  shelterUserId: string;
  closedAt?: string;
  lastReadSequence: Map<string, number>;
  messages: MessageState[];
};

type IdempotencySnapshot<T> = {
  requestHash: string;
  response: T;
};

const idempotencyScope = (
  input: AdoptionIdempotencyInput | ChatIdempotencyInput,
) =>
  [input.userId, input.method, input.normalizedPath, input.keyHash].join(':');

const clone = <T>(value: T): T => structuredClone(value);

const makeListing = (): AdoptionListingRecord => ({
  listingId: D52_LISTING_ID,
  shelterId: D52_SHELTER_ID,
  petName: 'Golden Day 52',
  species: 'dog',
  breed: 'Golden Retriever',
  ageLabel: '2 thang tuoi',
  description: 'Hien lanh va than thien.',
  traits: ['hien lanh', 'than thien'],
  healthBadges: ['da tiem phong'],
  verificationBadges: ['mai am da xac minh'],
  heroMedia: {
    mediaId: D52_LISTING_MEDIA_ID,
    ownerUserId: D52_SHELTER_ID,
    purpose: 'adoption_listing',
    mimeType: 'image/webp',
    sizeBytes: 4_096,
    sha256: '5'.repeat(64),
    status: 'verified',
    publicUrl: 'https://example.invalid/day52/golden.webp',
    width: 1_200,
    height: 900,
    createdAt: NOW.toISOString(),
  },
  status: 'available',
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
});

const makeChatMedia = (): ChatMediaRecord => ({
  mediaId: D52_CHAT_MEDIA_ID,
  ownerUserId: D52_ADOPTER_ID,
  purpose: 'adoption_chat',
  mimeType: 'image/webp',
  sizeBytes: 2_048,
  sha256: '6'.repeat(64),
  status: 'verified',
  publicUrl: 'https://example.invalid/day52/chat.webp',
  width: 800,
  height: 600,
  createdAt: NOW.toISOString(),
});

const buildMessageId = (sequence: number) =>
  `${MESSAGE_ID_PREFIX}${sequence.toString().padStart(12, '0')}`;

const participantRole = (thread: ThreadState, userId: string) => {
  if (userId === thread.adopterUserId) return 'adopter' as const;
  if (userId === thread.shelterUserId) return 'shelter' as const;
  return undefined;
};

export const buildAdoptionBackendFeatureHarness = async () => {
  let listing = makeListing();
  let request: AdoptionRequestRecord | undefined;
  let thread: ThreadState | undefined;
  const decisions: AdoptionDecisionRecord[] = [];
  const outbox: OutboxEvent[] = [];
  const adoptionIdempotency = new Map<
    string,
    IdempotencySnapshot<AdoptionDecisionRecord | AdoptionRequestRecord>
  >();
  const chatIdempotency = new Map<
    string,
    IdempotencySnapshot<ChatMessageRecord>
  >();
  const chatMedia = new Map([[D52_CHAT_MEDIA_ID, makeChatMedia()]]);

  const replayAdoption = <
    T extends AdoptionDecisionRecord | AdoptionRequestRecord,
  >(
    input: AdoptionIdempotencyInput,
  ) => {
    const snapshot = adoptionIdempotency.get(idempotencyScope(input));
    if (!snapshot) return undefined;
    if (snapshot.requestHash !== input.requestHash) {
      throw new AdoptionPersistenceDomainError(
        'idempotency_conflict',
        'Day 52 payload conflict',
      );
    }
    return clone(snapshot.response) as T;
  };

  const rememberAdoption = (
    input: AdoptionIdempotencyInput,
    response: AdoptionDecisionRecord | AdoptionRequestRecord,
  ) => {
    adoptionIdempotency.set(idempotencyScope(input), {
      requestHash: input.requestHash,
      response: clone(response),
    });
  };

  const adoptionRepository: AdoptionRepository = {
    async listRequestsByAdopter(adopterUserId) {
      return (request ? [request] : [])
        .filter((item) => item.adopterUserId === adopterUserId)
        .map((item) => {
          let listingAvailability:
            | 'available'
            | 'unavailable'
            | 'expired' = 'unavailable';
          if (listing.status === 'available') {
            listingAvailability = 'available';
          } else if (listing.status === 'closed') {
            listingAvailability = 'expired';
          }
          return {
            requestId: item.requestId,
            listingId: item.listingId,
            petName: listing.petName,
            status: item.status,
            listingAvailability,
            threadId: item.threadId,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt ?? item.createdAt,
          };
        });
    },

    async listListings(input) {
      const alreadyDecided = decisions.some(
        (item) =>
          item.listingId === listing.listingId &&
          item.adopterUserId === input.viewerUserId,
      );
      const visible =
        listing.status === 'available' &&
        listing.shelterId !== input.viewerUserId &&
        !alreadyDecided &&
        (!input.species || input.species === listing.species);
      return {
        items: visible ? [clone(listing)] : [],
        limit: input.limit,
      };
    },

    async findListing(listingId) {
      return listingId === listing.listingId ? clone(listing) : undefined;
    },

    async recordDecision(input) {
      const replay = replayAdoption<AdoptionDecisionRecord>(input.idempotency);
      if (replay) return replay;
      if (input.listingId !== listing.listingId) {
        throw new AdoptionPersistenceDomainError(
          'not_found',
          'Missing listing',
        );
      }
      if (input.adopterUserId === listing.shelterId) {
        throw new AdoptionPersistenceDomainError(
          'self_listing',
          'Owner decision',
        );
      }
      if (listing.status !== 'available') {
        throw new AdoptionPersistenceDomainError(
          'listing_unavailable',
          'Listing closed',
        );
      }
      const decision: AdoptionDecisionRecord = {
        listingId: listing.listingId,
        adopterUserId: input.adopterUserId,
        decision: input.decision,
        createdAt: input.now.toISOString(),
      };
      decisions.push(clone(decision));
      rememberAdoption(input.idempotency, decision);
      return clone(decision);
    },

    async createRequest(input) {
      const replay = replayAdoption<AdoptionRequestRecord>(input.idempotency);
      if (replay) return replay;
      if (input.listingId !== listing.listingId) {
        throw new AdoptionPersistenceDomainError(
          'not_found',
          'Missing listing',
        );
      }
      if (input.adopterUserId === listing.shelterId) {
        throw new AdoptionPersistenceDomainError(
          'self_listing',
          'Owner request',
        );
      }
      if (listing.status !== 'available') {
        throw new AdoptionPersistenceDomainError(
          'listing_unavailable',
          'Listing closed',
        );
      }
      if (
        request &&
        request.adopterUserId === input.adopterUserId &&
        request.listingId === input.listingId &&
        ['submitted', 'reviewing', 'approved'].includes(request.status)
      ) {
        throw new AdoptionPersistenceDomainError(
          'duplicate_active_request',
          'Duplicate active request',
        );
      }
      const created: AdoptionRequestRecord = {
        requestId: D52_REQUEST_ID,
        listingId: listing.listingId,
        adopterUserId: input.adopterUserId,
        shelterId: listing.shelterId,
        livingCondition: input.livingCondition,
        petExperience: input.petExperience,
        carePlan: input.carePlan,
        commitmentAccepted: true,
        status: 'submitted',
        threadId: D52_THREAD_ID,
        createdAt: input.now.toISOString(),
        updatedAt: input.now.toISOString(),
        ...(input.note !== undefined ? { note: input.note } : {}),
      };
      request = clone(created);
      thread = {
        requestId: created.requestId,
        adopterUserId: created.adopterUserId,
        shelterUserId: created.shelterId,
        lastReadSequence: new Map([
          [created.adopterUserId, 0],
          [created.shelterId, 0],
        ]),
        messages: [],
      };
      outbox.push({
        type: 'adoption_request_submitted',
        payload: {
          requestId: created.requestId,
          listingId: created.listingId,
          threadId: created.threadId,
          adopterUserId: created.adopterUserId,
          shelterId: created.shelterId,
        },
      });
      rememberAdoption(input.idempotency, created);
      return clone(created);
    },
  };

  const requireParticipant = (threadId: string, userId: string) => {
    if (!thread || threadId !== D52_THREAD_ID) {
      throw new ChatPersistenceDomainError(
        'thread_not_found',
        'Unknown thread',
      );
    }
    const role = participantRole(thread, userId);
    if (!role) {
      throw new ChatPersistenceDomainError(
        'thread_not_found',
        'Private participant mismatch',
      );
    }
    return { thread, role };
  };

  const unreadCount = (current: ThreadState, userId: string) => {
    const lastRead = current.lastReadSequence.get(userId) ?? 0;
    return current.messages.filter(
      (message) =>
        message.sequence > lastRead && message.record.senderUserId !== userId,
    ).length;
  };

  const chatRepository: ChatRepository = {
    async isCurrentParticipant(input) {
      try {
        const participant = requireParticipant(input.threadId, input.participantUserId);
        return !participant.thread.closedAt;
      } catch (error) {
        if (error instanceof ChatPersistenceDomainError && error.reason === 'thread_not_found') {
          return false;
        }
        throw error;
      }
    },
    async findReadableMedia() {
      return undefined;
    },
    async readThread(input) {
      const participant = requireParticipant(
        input.threadId,
        input.participantUserId,
      );
      const beforeSequence = input.cursor
        ? Number(input.cursor.sequence)
        : Number.POSITIVE_INFINITY;
      const eligible = participant.thread.messages.filter(
        (message) => message.sequence < beforeSequence,
      );
      const selected = eligible.slice(-input.limit);
      const hasOlder = eligible.length > selected.length;
      const first = selected[0];
      return {
        thread: {
          threadId: D52_THREAD_ID,
          requestId: participant.thread.requestId,
          participantRole: participant.role,
          lastReadAt: NOW.toISOString(),
          unreadCount: unreadCount(participant.thread, input.participantUserId),
          ...(participant.thread.closedAt
            ? { closedAt: participant.thread.closedAt }
            : {}),
        },
        items: selected.map((message) => clone(message.record)),
        ...(hasOlder && first
          ? {
              nextCursor: {
                sequence: first.sequence.toString(),
                createdAt: first.record.createdAt,
                messageId: first.record.messageId,
              },
            }
          : {}),
        limit: input.limit,
      };
    },

    async sendMessage(input) {
      const participant = requireParticipant(
        input.threadId,
        input.senderUserId,
      );
      if (participant.thread.closedAt) {
        throw new ChatPersistenceDomainError('chat_closed', 'Thread closed');
      }
      const scope = idempotencyScope(input.idempotency);
      const replay = chatIdempotency.get(scope);
      if (replay) {
        if (replay.requestHash !== input.idempotency.requestHash) {
          throw new ChatPersistenceDomainError(
            'idempotency_conflict',
            'Day 52 message payload conflict',
          );
        }
        return clone(replay.response);
      }
      const claimedMedia = input.mediaIds.map((mediaId) => {
        const media = chatMedia.get(mediaId);
        if (
          !media ||
          media.ownerUserId !== input.senderUserId ||
          media.purpose !== 'adoption_chat' ||
          media.status !== 'verified'
        ) {
          throw new ChatPersistenceDomainError(
            'media_invalid',
            'Invalid media ownership or lifecycle',
          );
        }
        return media;
      });
      const sequence = participant.thread.messages.length + 1;
      const message: ChatMessageRecord = {
        messageId: buildMessageId(sequence),
        threadId: D52_THREAD_ID,
        senderUserId: input.senderUserId,
        body: input.body,
        media: claimedMedia.map((media) => ({
          ...clone(media),
          status: 'attached' as const,
        })),
        createdAt: input.now.toISOString(),
        updatedAt: input.now.toISOString(),
      };
      claimedMedia.forEach((media) => {
        chatMedia.set(media.mediaId, { ...media, status: 'attached' });
      });
      participant.thread.messages.push({
        record: clone(message),
        sequence,
      });
      const recipientUserId =
        input.senderUserId === participant.thread.adopterUserId
          ? participant.thread.shelterUserId
          : participant.thread.adopterUserId;
      outbox.push({
        type: 'adoption_chat_message_created',
        payload: {
          threadId: D52_THREAD_ID,
          messageId: message.messageId,
          recipientUserId,
        },
      });
      chatIdempotency.set(scope, {
        requestHash: input.idempotency.requestHash,
        response: clone(message),
      });
      return clone(message);
    },

    async markRead(input) {
      const participant = requireParticipant(
        input.threadId,
        input.participantUserId,
      );
      const message = participant.thread.messages.find(
        (candidate) => candidate.record.messageId === input.throughMessageId,
      );
      if (!message) {
        throw new ChatPersistenceDomainError(
          'message_not_found',
          'Message is outside this thread',
        );
      }
      const current =
        participant.thread.lastReadSequence.get(input.participantUserId) ?? 0;
      participant.thread.lastReadSequence.set(
        input.participantUserId,
        Math.max(current, message.sequence),
      );
      return {
        threadId: D52_THREAD_ID,
        lastReadAt: input.now.toISOString(),
        unreadCount: unreadCount(participant.thread, input.participantUserId),
      };
    },
  };

  const tokenUsers = new Map([
    ['adopter-token', D52_ADOPTER_ID],
    ['shelter-token', D52_SHELTER_ID],
    ['outsider-token', D52_OUTSIDER_ID],
  ]);
  const verifyAccessToken = jest.fn(async (token: string) => {
    const userId = tokenUsers.get(token);
    if (!userId) throw new Error('Invalid Day 52 test token');
    return { userId, email: `${userId}@example.test` };
  });
  const app = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      authService: { verifyAccessToken } as unknown as AuthService,
      adoptionService: createAdoptionService({
        repository: adoptionRepository,
        now: () => NOW,
      }),
      adoptionChatService: createAdoptionChatService({
        repository: chatRepository,
        now: () => NOW,
      }),
    },
  );
  await app.ready();

  return {
    app,
    state: {
      decisions,
      outbox,
      get listing() {
        return listing;
      },
      get request() {
        return request;
      },
      get thread() {
        return thread;
      },
      setListingStatus(status: AdoptionListingRecord['status']) {
        listing = { ...listing, status };
      },
      closeThread() {
        if (!thread) throw new Error('Day 52 thread is not created.');
        thread.closedAt = NOW.toISOString();
      },
    },
  };
};

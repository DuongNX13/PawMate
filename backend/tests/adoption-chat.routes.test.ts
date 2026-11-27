import { buildApp } from '../src/app';
import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { type AdoptionChatService } from '../src/services/adoption/adoption-chat-service';
import { type AuthService } from '../src/services/auth/auth-service';
import { ADOPTER_USER_ID, THREAD_ID } from './helpers/adoption-fixtures';
import {
  CHAT_MESSAGE_ID,
  CHAT_MEDIA_ID,
  makeChatMessage,
} from './helpers/adoption-chat-fixtures';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const openApps: Array<ReturnType<typeof buildApp>> = [];

afterEach(async () => {
  await Promise.all(openApps.splice(0).map(async (app) => app.close()));
});

const buildHarness = async () => {
  const verifyAccessToken = jest.fn(async (token: string) => {
    if (token !== 'participant-token') {
      throw new AppError(
        AUTH_ERROR_CODES.unauthorized,
        'Access token khong hop le.',
        401,
      );
    }
    return { userId: ADOPTER_USER_ID, email: 'adopter@example.test' };
  });
  const readThread = jest.fn(async () => ({
    thread: {
      threadId: THREAD_ID,
      requestId: '51000000-0000-4000-8000-000000000005',
      participantRole: 'adopter' as const,
      lastReadAt: '2026-07-27T09:00:00.000Z',
      unreadCount: 1,
    },
    items: [makeChatMessage()],
    nextCursor: 'older-page',
    limit: 1,
  }));
  const sendMessage = jest.fn(async () => makeChatMessage());
  const markRead = jest.fn(async () => ({
    threadId: THREAD_ID,
    lastReadAt: '2026-07-27T10:00:00.000Z',
    unreadCount: 0,
  }));
  const readMedia = jest.fn(async () => ({
    bytes: Buffer.from('private-chat-fixture'),
    mimeType: 'image/jpeg',
  }));
  const app = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      authService: { verifyAccessToken } as unknown as AuthService,
      adoptionChatService: {
        readThread,
        sendMessage,
        markRead,
        readMedia,
      } as unknown as AdoptionChatService,
    },
  );
  openApps.push(app);
  await app.ready();
  return { app, readThread, sendMessage, markRead, readMedia };
};

describe('Day 51 Adoption chat routes', () => {
  it('serves private chat bytes only through an authenticated no-store endpoint', async () => {
    const { app, readMedia } = await buildHarness();
    const url = `/adoption/chat/${THREAD_ID}/media/${CHAT_MEDIA_ID}`;

    const anonymous = await app.inject({ method: 'GET', url });
    expect(anonymous.statusCode).toBe(401);
    expect(readMedia).not.toHaveBeenCalled();

    const response = await app.inject({
      method: 'GET',
      url,
      headers: { authorization: 'Bearer participant-token' },
    });
    expect(response.statusCode).toBe(200);
    expect(response.rawPayload).toEqual(Buffer.from('private-chat-fixture'));
    expect(response.headers['cache-control']).toBe('private, no-store, max-age=0');
    expect(response.headers.vary).toBe('Authorization');
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(readMedia).toHaveBeenCalledWith(ADOPTER_USER_ID, THREAD_ID, CHAT_MEDIA_ID);
  });
  it.each([
    ['GET', `/adoption/chat/${THREAD_ID}`],
    ['POST', `/adoption/chat/${THREAD_ID}/messages`],
    ['PUT', `/adoption/chat/${THREAD_ID}/read`],
  ] as const)('requires auth for %s %s', async (method, url) => {
    const { app } = await buildHarness();

    const response = await app.inject({ method, url });

    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({
      success: false,
      error: { code: AUTH_ERROR_CODES.unauthorized },
    });
  });

  it('returns participant-scoped ordered messages and page info', async () => {
    const { app, readThread } = await buildHarness();

    const response = await app.inject({
      method: 'GET',
      url: `/adoption/chat/${THREAD_ID}?limit=1`,
      headers: { authorization: 'Bearer participant-token' },
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.json()).toMatchObject({
      data: [{ messageId: CHAT_MESSAGE_ID, threadId: THREAD_ID }],
      thread: {
        threadId: THREAD_ID,
        participantRole: 'adopter',
        unreadCount: 1,
      },
      pageInfo: { nextCursor: 'older-page', hasMore: true, limit: 1 },
    });
    expect(readThread).toHaveBeenCalledWith(ADOPTER_USER_ID, THREAD_ID, {
      limit: '1',
    });
  });

  it('forwards message idempotency and returns 201', async () => {
    const { app, sendMessage } = await buildHarness();
    const payload = { body: 'Xin chao mai am', mediaIds: [] };

    const response = await app.inject({
      method: 'POST',
      url: `/adoption/chat/${THREAD_ID}/messages`,
      headers: {
        authorization: 'Bearer participant-token',
        'idempotency-key': 'message-key-01',
      },
      payload,
    });

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      data: { messageId: CHAT_MESSAGE_ID, threadId: THREAD_ID },
    });
    expect(sendMessage).toHaveBeenCalledWith(
      ADOPTER_USER_ID,
      THREAD_ID,
      payload,
      'message-key-01',
    );
  });

  it('updates the participant read cursor without mutating GET', async () => {
    const { app, markRead } = await buildHarness();
    const payload = { throughMessageId: CHAT_MESSAGE_ID };

    const response = await app.inject({
      method: 'PUT',
      url: `/adoption/chat/${THREAD_ID}/read`,
      headers: { authorization: 'Bearer participant-token' },
      payload,
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      data: { threadId: THREAD_ID, unreadCount: 0 },
    });
    expect(markRead).toHaveBeenCalledWith(ADOPTER_USER_ID, THREAD_ID, payload);
  });
});

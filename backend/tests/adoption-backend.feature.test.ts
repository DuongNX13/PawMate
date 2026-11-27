import {
  D52_ADOPTER_ID,
  D52_CHAT_MEDIA_ID,
  D52_LISTING_ID,
  D52_SHELTER_ID,
  D52_THREAD_ID,
  D52_UNKNOWN_THREAD_ID,
  buildAdoptionBackendFeatureHarness,
} from './helpers/adoption-backend-feature-harness';

const openApps: Array<
  Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>['app']
> = [];

const requestPayload = {
  livingCondition: 'Can ho rong rai',
  petExperience: 'Da cham soc cho',
  carePlan: 'Kham dinh ky va van dong moi ngay',
  commitmentAccepted: true,
  note: 'Mong muon phong van vao cuoi tuan.',
};

const headers = (
  token: 'adopter-token' | 'shelter-token' | 'outsider-token',
) => ({
  authorization: `Bearer ${token}`,
});

const buildHarness = async () => {
  const harness = await buildAdoptionBackendFeatureHarness();
  openApps.push(harness.app);
  return harness;
};

const submitRequest = async (
  harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
  options: {
    token?: 'adopter-token' | 'shelter-token';
    key?: string;
    payload?: typeof requestPayload;
  } = {},
) =>
  harness.app.inject({
    method: 'POST',
    url: `/adoption/listings/${D52_LISTING_ID}/requests`,
    headers: {
      ...headers(options.token ?? 'adopter-token'),
      'idempotency-key': options.key ?? 'd52-request-key-01',
    },
    payload: options.payload ?? requestPayload,
  });

const sendMessage = async (
  harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
  input: {
    token: 'adopter-token' | 'shelter-token';
    key: string;
    body: string;
    mediaIds?: string[];
  },
) =>
  harness.app.inject({
    method: 'POST',
    url: `/adoption/chat/${D52_THREAD_ID}/messages`,
    headers: {
      ...headers(input.token),
      'idempotency-key': input.key,
    },
    payload: {
      body: input.body,
      ...(input.mediaIds ? { mediaIds: input.mediaIds } : {}),
    },
  });

afterEach(async () => {
  await Promise.all(openApps.splice(0).map(async (app) => app.close()));
});

describe('Day 52 Adoption backend feature integration', () => {
  it('D52-XFLOW-01 executes listing -> request -> chat -> unread/read without leaking private event data', async () => {
    const harness = await buildHarness();

    const deck = await harness.app.inject({
      method: 'GET',
      url: '/adoption/listings?species=dog',
      headers: headers('adopter-token'),
    });
    expect(deck.statusCode).toBe(200);
    expect(deck.json()).toMatchObject({
      data: [
        {
          listingId: D52_LISTING_ID,
          petName: 'Golden Day 52',
          shelterId: D52_SHELTER_ID,
          status: 'available',
        },
      ],
    });
    expect(JSON.stringify(deck.json())).not.toMatch(
      /livingCondition|petExperience|carePlan|adopterUserId/,
    );

    const createdRequest = await submitRequest(harness);
    expect(createdRequest.statusCode).toBe(201);
    expect(createdRequest.json()).toMatchObject({
      data: {
        listingId: D52_LISTING_ID,
        adopterUserId: D52_ADOPTER_ID,
        shelterId: D52_SHELTER_ID,
        threadId: D52_THREAD_ID,
        status: 'submitted',
      },
    });

    const initialThread = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_THREAD_ID}`,
      headers: headers('shelter-token'),
    });
    expect(initialThread.statusCode).toBe(200);
    expect(initialThread.json()).toMatchObject({
      data: [],
      thread: {
        threadId: D52_THREAD_ID,
        participantRole: 'shelter',
        unreadCount: 0,
      },
    });

    const createdMessage = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-message-key-01',
      body: 'Toi co the hen phong van vao thu Bay khong?',
      mediaIds: [D52_CHAT_MEDIA_ID],
    });
    expect(createdMessage.statusCode).toBe(201);
    expect(createdMessage.json()).toMatchObject({
      data: {
        threadId: D52_THREAD_ID,
        senderUserId: D52_ADOPTER_ID,
        body: 'Toi co the hen phong van vao thu Bay khong?',
        media: [{ mediaId: D52_CHAT_MEDIA_ID, status: 'attached' }],
      },
    });

    const replay = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-message-key-01',
      body: 'Toi co the hen phong van vao thu Bay khong?',
      mediaIds: [D52_CHAT_MEDIA_ID],
    });
    expect(replay.statusCode).toBe(201);
    expect(replay.json()).toEqual(createdMessage.json());
    expect(harness.state.thread?.messages).toHaveLength(1);

    const unreadThread = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_THREAD_ID}`,
      headers: headers('shelter-token'),
    });
    expect(unreadThread.statusCode).toBe(200);
    expect(unreadThread.json()).toMatchObject({
      data: [{ body: 'Toi co the hen phong van vao thu Bay khong?' }],
      thread: { unreadCount: 1 },
    });

    const messageId = createdMessage.json().data.messageId as string;
    const markedRead = await harness.app.inject({
      method: 'PUT',
      url: `/adoption/chat/${D52_THREAD_ID}/read`,
      headers: headers('shelter-token'),
      payload: { throughMessageId: messageId },
    });
    expect(markedRead.statusCode).toBe(200);
    expect(markedRead.json()).toMatchObject({
      data: { threadId: D52_THREAD_ID, unreadCount: 0 },
    });

    expect(
      harness.state.outbox.filter(
        (event) => event.type === 'adoption_request_submitted',
      ),
    ).toHaveLength(1);
    expect(
      harness.state.outbox.filter(
        (event) => event.type === 'adoption_chat_message_created',
      ),
    ).toHaveLength(1);
    expect(JSON.stringify(harness.state.outbox)).not.toMatch(
      /Toi co the|livingCondition|petExperience|carePlan|note/,
    );
  });

  it('D52-REQ-07 and D52-DEC-03 replay identical commands once and reject payload conflicts', async () => {
    const harness = await buildHarness();

    const firstDecision = await harness.app.inject({
      method: 'POST',
      url: `/adoption/listings/${D52_LISTING_ID}/decisions`,
      headers: {
        ...headers('adopter-token'),
        'idempotency-key': 'd52-decision-key-01',
      },
      payload: { decision: 'like' },
    });
    const decisionReplay = await harness.app.inject({
      method: 'POST',
      url: `/adoption/listings/${D52_LISTING_ID}/decisions`,
      headers: {
        ...headers('adopter-token'),
        'idempotency-key': 'd52-decision-key-01',
      },
      payload: { decision: 'like' },
    });
    expect(firstDecision.statusCode).toBe(201);
    expect(decisionReplay.json()).toEqual(firstDecision.json());
    expect(harness.state.decisions).toHaveLength(1);

    const decisionConflict = await harness.app.inject({
      method: 'POST',
      url: `/adoption/listings/${D52_LISTING_ID}/decisions`,
      headers: {
        ...headers('adopter-token'),
        'idempotency-key': 'd52-decision-key-01',
      },
      payload: { decision: 'skip' },
    });
    expect(decisionConflict.statusCode).toBe(409);
    expect(decisionConflict.json()).toMatchObject({
      error: { code: 'IDEMPOTENCY_001' },
    });

    const firstRequest = await submitRequest(harness, {
      key: 'd52-request-key-01',
    });
    const requestReplay = await submitRequest(harness, {
      key: 'd52-request-key-01',
    });
    expect(firstRequest.statusCode).toBe(201);
    expect(requestReplay.json()).toEqual(firstRequest.json());
    expect(
      harness.state.outbox.filter(
        (event) => event.type === 'adoption_request_submitted',
      ),
    ).toHaveLength(1);

    const requestConflict = await submitRequest(harness, {
      key: 'd52-request-key-01',
      payload: { ...requestPayload, carePlan: 'Payload khac' },
    });
    expect(requestConflict.statusCode).toBe(409);
    expect(requestConflict.json()).toMatchObject({
      error: { code: 'IDEMPOTENCY_001' },
    });

    const duplicateRequest = await submitRequest(harness, {
      key: 'd52-request-key-02',
    });
    expect(duplicateRequest.statusCode).toBe(409);
    expect(duplicateRequest.json()).toMatchObject({
      error: { code: 'ADOPTION_006' },
    });
  });

  it('D52-REQ-05/06 blocks self and unavailable requests before thread/event creation', async () => {
    const selfHarness = await buildHarness();
    const selfRequest = await submitRequest(selfHarness, {
      token: 'shelter-token',
      key: 'd52-self-request-key',
    });
    expect(selfRequest.statusCode).toBe(403);
    expect(selfRequest.json()).toMatchObject({
      error: { code: 'ADOPTION_005' },
    });
    expect(selfHarness.state.thread).toBeUndefined();
    expect(selfHarness.state.outbox).toHaveLength(0);

    const closedHarness = await buildHarness();
    closedHarness.state.setListingStatus('closed');
    const unavailable = await submitRequest(closedHarness, {
      key: 'd52-closed-request-key',
    });
    expect(unavailable.statusCode).toBe(409);
    expect(unavailable.json()).toMatchObject({
      error: { code: 'ADOPTION_004' },
    });
    expect(closedHarness.state.thread).toBeUndefined();
    expect(closedHarness.state.outbox).toHaveLength(0);
  });

  it('D52-CHAT-01/02 collapses outsider and unknown-thread errors without side effects', async () => {
    const harness = await buildHarness();
    await submitRequest(harness);

    const outsiderRead = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_THREAD_ID}`,
      headers: headers('outsider-token'),
    });
    const unknownRead = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_UNKNOWN_THREAD_ID}`,
      headers: headers('adopter-token'),
    });
    expect(outsiderRead.statusCode).toBe(404);
    expect(unknownRead.statusCode).toBe(404);
    expect(outsiderRead.json().error).toEqual(unknownRead.json().error);
    expect(outsiderRead.json()).toMatchObject({
      error: { code: 'ADOPTION_007' },
    });

    const outsiderSend = await harness.app.inject({
      method: 'POST',
      url: `/adoption/chat/${D52_THREAD_ID}/messages`,
      headers: {
        ...headers('outsider-token'),
        'idempotency-key': 'd52-outsider-message',
      },
      payload: { body: 'Khong duoc gui' },
    });
    const outsiderReadUpdate = await harness.app.inject({
      method: 'PUT',
      url: `/adoption/chat/${D52_THREAD_ID}/read`,
      headers: headers('outsider-token'),
      payload: {
        throughMessageId: '55000000-0000-4000-8000-000000000001',
      },
    });
    expect(outsiderSend.statusCode).toBe(404);
    expect(outsiderReadUpdate.statusCode).toBe(404);
    expect(outsiderSend.json()).toMatchObject({
      error: { code: 'ADOPTION_007' },
    });
    expect(outsiderReadUpdate.json()).toMatchObject({
      error: { code: 'ADOPTION_007' },
    });
    expect(harness.state.thread?.messages).toHaveLength(0);
    expect(
      harness.state.outbox.filter(
        (event) => event.type === 'adoption_chat_message_created',
      ),
    ).toHaveLength(0);
  });

  it('D52-CHAT-03/09 keeps message order stable and read progress monotonic', async () => {
    const harness = await buildHarness();
    await submitRequest(harness);

    const first = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-order-message-01',
      body: 'Tin 1 tu adopter',
    });
    const second = await sendMessage(harness, {
      token: 'shelter-token',
      key: 'd52-order-message-02',
      body: 'Tin 2 tu shelter',
    });
    const third = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-order-message-03',
      body: 'Tin 3 tu adopter',
    });
    expect([first.statusCode, second.statusCode, third.statusCode]).toEqual([
      201, 201, 201,
    ]);

    const latestPage = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_THREAD_ID}?limit=2`,
      headers: headers('shelter-token'),
    });
    expect(latestPage.statusCode).toBe(200);
    expect(latestPage.json()).toMatchObject({
      data: [{ body: 'Tin 2 tu shelter' }, { body: 'Tin 3 tu adopter' }],
      thread: { unreadCount: 2 },
      pageInfo: { hasMore: true, limit: 2 },
    });

    const olderPage = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_THREAD_ID}?limit=2&cursor=${latestPage.json().pageInfo.nextCursor as string}`,
      headers: headers('shelter-token'),
    });
    expect(olderPage.statusCode).toBe(200);
    expect(olderPage.json()).toMatchObject({
      data: [{ body: 'Tin 1 tu adopter' }],
      pageInfo: { hasMore: false },
    });

    const firstMessageId = first.json().data.messageId as string;
    const thirdMessageId = third.json().data.messageId as string;
    const readFirst = await harness.app.inject({
      method: 'PUT',
      url: `/adoption/chat/${D52_THREAD_ID}/read`,
      headers: headers('shelter-token'),
      payload: { throughMessageId: firstMessageId },
    });
    expect(readFirst.json()).toMatchObject({ data: { unreadCount: 1 } });

    const readThird = await harness.app.inject({
      method: 'PUT',
      url: `/adoption/chat/${D52_THREAD_ID}/read`,
      headers: headers('shelter-token'),
      payload: { throughMessageId: thirdMessageId },
    });
    expect(readThird.json()).toMatchObject({ data: { unreadCount: 0 } });

    const regressAttempt = await harness.app.inject({
      method: 'PUT',
      url: `/adoption/chat/${D52_THREAD_ID}/read`,
      headers: headers('shelter-token'),
      payload: { throughMessageId: firstMessageId },
    });
    expect(regressAttempt.json()).toMatchObject({ data: { unreadCount: 0 } });
  });

  it('D52-CHAT-05/07/08 rejects wrong media ownership, replay conflicts and writes to a closed thread', async () => {
    const harness = await buildHarness();
    await submitRequest(harness);

    const wrongOwner = await sendMessage(harness, {
      token: 'shelter-token',
      key: 'd52-wrong-owner-media',
      body: 'Thu claim media cua adopter',
      mediaIds: [D52_CHAT_MEDIA_ID],
    });
    expect(wrongOwner.statusCode).toBe(400);
    expect(wrongOwner.json()).toMatchObject({
      error: { code: 'ADOPTION_004', field: 'mediaIds' },
    });

    const first = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-media-message-01',
      body: 'Tin co media',
      mediaIds: [D52_CHAT_MEDIA_ID],
    });
    expect(first.statusCode).toBe(201);

    const reusedMedia = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-media-message-02',
      body: 'Khong duoc claim lai media',
      mediaIds: [D52_CHAT_MEDIA_ID],
    });
    expect(reusedMedia.statusCode).toBe(400);
    expect(reusedMedia.json()).toMatchObject({
      error: { code: 'ADOPTION_004', field: 'mediaIds' },
    });

    const conflict = await sendMessage(harness, {
      token: 'adopter-token',
      key: 'd52-media-message-01',
      body: 'Payload khac cung key',
    });
    expect(conflict.statusCode).toBe(409);
    expect(conflict.json()).toMatchObject({
      error: { code: 'IDEMPOTENCY_001' },
    });

    harness.state.closeThread();
    const readable = await harness.app.inject({
      method: 'GET',
      url: `/adoption/chat/${D52_THREAD_ID}`,
      headers: headers('shelter-token'),
    });
    expect(readable.statusCode).toBe(200);
    expect(readable.json()).toMatchObject({
      thread: { closedAt: expect.any(String) },
    });

    const blockedWrite = await sendMessage(harness, {
      token: 'shelter-token',
      key: 'd52-closed-message-01',
      body: 'Khong duoc gui khi da dong',
    });
    expect(blockedWrite.statusCode).toBe(409);
    expect(blockedWrite.json()).toMatchObject({
      error: { code: 'ADOPTION_008' },
    });
  });

  it.each([
    [
      'invalid paired location',
      async (
        harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
      ) =>
        harness.app.inject({
          method: 'GET',
          url: '/adoption/listings?lat=10',
          headers: headers('adopter-token'),
        }),
      'ADOPTION_004',
      'lat',
    ],
    [
      'invalid decision',
      async (
        harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
      ) =>
        harness.app.inject({
          method: 'POST',
          url: `/adoption/listings/${D52_LISTING_ID}/decisions`,
          headers: {
            ...headers('adopter-token'),
            'idempotency-key': 'd52-invalid-decision',
          },
          payload: { decision: 'maybe' },
        }),
      'ADOPTION_004',
      'decision',
    ],
    [
      'missing request consent',
      async (
        harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
      ) =>
        submitRequest(harness, {
          payload: { ...requestPayload, commitmentAccepted: false },
        }),
      'ADOPTION_004',
      'commitmentAccepted',
    ],
    [
      'duplicate chat media IDs',
      async (
        harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
      ) => {
        await submitRequest(harness);
        return sendMessage(harness, {
          token: 'adopter-token',
          key: 'd52-duplicate-media',
          body: 'Duplicate media',
          mediaIds: [D52_CHAT_MEDIA_ID, D52_CHAT_MEDIA_ID],
        });
      },
      'ADOPTION_004',
      'mediaIds',
    ],
    [
      'malformed read message ID',
      async (
        harness: Awaited<ReturnType<typeof buildAdoptionBackendFeatureHarness>>,
      ) => {
        await submitRequest(harness);
        return harness.app.inject({
          method: 'PUT',
          url: `/adoption/chat/${D52_THREAD_ID}/read`,
          headers: headers('adopter-token'),
          payload: { throughMessageId: 'not-a-uuid' },
        });
      },
      'ADOPTION_004',
      'throughMessageId',
    ],
  ])(
    'D52-LIST-03/DEC-01/REQ-01/CHAT-04 rejects %s before unsafe persistence',
    async (_label, execute, code, field) => {
      const harness = await buildHarness();
      const response = await execute(harness);
      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        error: { code, field },
      });
    },
  );
});

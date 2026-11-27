import {
  IDEMPOTENCY_ERROR_CODES,
  RESCUE_ERROR_CODES,
} from '../src/errors/error-codes';
import {
  RescuePersistenceDomainError,
  type RescueCaseDraftRecord,
  type RescueCaseRecord,
  type RescueCommentRecord,
  type RescueMediaAssetRecord,
  type RescueRepository,
} from '../src/features/rescue/persistence/rescue-repository';
import {
  buildRescueIdempotencyInput,
  createRescueWriteService,
} from '../src/services/rescue/rescue-write-service';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const VIEWER_ID = '99999999-9999-4999-8999-999999999999';
const DRAFT_ID = '22222222-2222-4222-8222-222222222222';
const CASE_ID = '33333333-3333-4333-8333-333333333333';
const OTHER_CASE_ID = '44444444-4444-4444-8444-444444444444';
const COMMENT_ID = '55555555-5555-4555-8555-555555555555';
const NEXT_COMMENT_ID = '66666666-6666-4666-8666-666666666666';
const MEDIA_ID = '77777777-7777-4777-8777-777777777777';
const SECOND_MEDIA_ID = '88888888-8888-4888-8888-888888888888';
const NOW = new Date('2026-07-21T04:00:00.000Z');

const makeMedia = (
  overrides: Partial<RescueMediaAssetRecord> = {},
): RescueMediaAssetRecord => ({
  mediaId: MEDIA_ID,
  ownerUserId: USER_ID,
  purpose: 'rescue_comment',
  mimeType: 'image/jpeg',
  sizeBytes: 1_024,
  sha256: 'a'.repeat(64),
  status: 'attached',
  storageKey: 'rescue/comment/sanitized.jpg',
  publicUrl: 'https://cdn.example.test/rescue/comment/sanitized.jpg',
  commentId: COMMENT_ID,
  position: 0,
  verifiedAt: NOW.toISOString(),
  verificationVersion: 1,
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...overrides,
});

const makeDraft = (
  overrides: Partial<RescueCaseDraftRecord> = {},
): RescueCaseDraftRecord => ({
  draftId: DRAFT_ID,
  ownerUserId: USER_ID,
  source: 'rescue_home',
  privacyRadiusMeters: 500,
  contactPreference: 'in_app',
  version: 1,
  media: [],
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...overrides,
});

const makeCase = (
  overrides: Partial<RescueCaseRecord> = {},
): RescueCaseRecord => ({
  caseId: CASE_ID,
  sourceDraftId: DRAFT_ID,
  ownerUserId: USER_ID,
  petName: 'Mochi',
  species: 'cat',
  breedOrColor: 'Meo tam the',
  lostAt: '2026-07-20T10:00:00.000Z',
  areaLabel: 'Quan 1, Thanh pho Ho Chi Minh',
  approximateLatitude: 10.776,
  approximateLongitude: 106.7,
  privacyRadiusMeters: 500,
  identifyingFeatures: 'Deo vong co mau xanh.',
  contactPreference: 'in_app',
  status: 'missing',
  version: 1,
  commentCount: 0,
  media: [],
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...overrides,
});

const makeComment = (
  overrides: Partial<RescueCommentRecord> = {},
): RescueCommentRecord => ({
  commentId: COMMENT_ID,
  caseId: CASE_ID,
  authorUserId: USER_ID,
  author: {
    userId: USER_ID,
    displayName: 'Duong Nguyen',
  },
  body: 'Toi da thay mot be giong Mochi.',
  moderationState: 'visible',
  media: [makeMedia()],
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...overrides,
});

const buildRepository = () => {
  const createDraft = jest
    .fn<
      ReturnType<RescueRepository['createDraft']>,
      Parameters<RescueRepository['createDraft']>
    >()
    .mockResolvedValue(makeDraft());
  const updateDraft = jest
    .fn<
      ReturnType<RescueRepository['updateDraft']>,
      Parameters<RescueRepository['updateDraft']>
    >()
    .mockResolvedValue(makeDraft({ version: 2 }));
  const publishDraft = jest
    .fn<
      ReturnType<RescueRepository['publishDraft']>,
      Parameters<RescueRepository['publishDraft']>
    >()
    .mockResolvedValue(makeCase());
  const createComment = jest
    .fn<
      ReturnType<RescueRepository['createComment']>,
      Parameters<RescueRepository['createComment']>
    >()
    .mockResolvedValue(makeComment());
  const listComments = jest
    .fn<
      ReturnType<RescueRepository['listComments']>,
      Parameters<RescueRepository['listComments']>
    >()
    .mockResolvedValue({ items: [makeComment()], limit: 20 });
  const updateCaseStatus = jest
    .fn<
      ReturnType<RescueRepository['updateCaseStatus']>,
      Parameters<RescueRepository['updateCaseStatus']>
    >()
    .mockResolvedValue(
      makeCase({
        status: 'found',
        version: 2,
        foundAt: NOW.toISOString(),
      }),
    );
  const attachVerifiedMediaToDraft = jest.fn<
    ReturnType<RescueRepository['attachVerifiedMediaToDraft']>,
    Parameters<RescueRepository['attachVerifiedMediaToDraft']>
  >();

  const repository = {
    createDraft,
    updateDraft,
    publishDraft,
    createComment,
    listComments,
    updateCaseStatus,
    attachVerifiedMediaToDraft,
  } as unknown as RescueRepository;

  return {
    repository,
    createDraft,
    updateDraft,
    publishDraft,
    createComment,
    listComments,
    updateCaseStatus,
    attachVerifiedMediaToDraft,
  };
};

const makeService = (repository: RescueRepository) =>
  createRescueWriteService({ repository, now: () => NOW });

describe('Day 36 Rescue write service', () => {
  it('creates a private draft with normalized idempotency metadata', async () => {
    const { repository, createDraft } = buildRepository();
    const service = makeService(repository);

    const result = await service.createDraft(
      USER_ID,
      { source: 'rescue_home' },
      ' create-draft-key ',
    );

    expect(result).toMatchObject({
      draftId: DRAFT_ID,
      ownerUserId: USER_ID,
      version: 1,
    });
    expect(createDraft).toHaveBeenCalledWith({
      ownerUserId: USER_ID,
      source: 'rescue_home',
      idempotency: expect.objectContaining({
        userId: USER_ID,
        method: 'POST',
        normalizedPath: '/rescue/case-drafts',
        keyHash: expect.stringMatching(/^[a-f0-9]{64}$/u),
        requestHash: expect.stringMatching(/^[a-f0-9]{64}$/u),
        now: NOW,
      }),
      now: NOW,
    });
  });

  it.each([
    [{ source: 'unsupported' }, 'source'],
    [{ source: 'rescue_home', unexpected: true }, 'unexpected'],
  ])('rejects invalid create payload %p', async (payload, field) => {
    const { repository, createDraft } = buildRepository();

    await expect(
      makeService(repository).createDraft(USER_ID, payload, 'create-key'),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field,
    });
    expect(createDraft).not.toHaveBeenCalled();
  });

  it('builds stable key and request hashes for the same canonical payload', () => {
    const first = buildRescueIdempotencyInput({
      userId: USER_ID,
      method: 'POST',
      normalizedPath: '/rescue/case-drafts',
      idempotencyKey: ' stable-key ',
      payload: { source: 'rescue_home', nested: { second: 2, first: 1 } },
      now: NOW,
    });
    const second = buildRescueIdempotencyInput({
      userId: USER_ID,
      method: 'POST',
      normalizedPath: '/rescue/case-drafts',
      idempotencyKey: 'stable-key',
      payload: { nested: { first: 1, second: 2 }, source: 'rescue_home' },
      now: new Date(NOW.getTime() + 1_000),
    });
    const changed = buildRescueIdempotencyInput({
      userId: USER_ID,
      method: 'POST',
      normalizedPath: '/rescue/case-drafts',
      idempotencyKey: 'stable-key',
      payload: { source: 'deep_link', nested: { first: 1, second: 2 } },
    });

    expect(second.keyHash).toBe(first.keyHash);
    expect(second.requestHash).toBe(first.requestHash);
    expect(changed.requestHash).not.toBe(first.requestHash);
  });

  it('projects exact location privately and passes an ordered media replacement atomically', async () => {
    const { repository, updateDraft, attachVerifiedMediaToDraft } =
      buildRepository();
    const service = makeService(repository);
    const mediaIds = [SECOND_MEDIA_ID, MEDIA_ID];

    await service.updateDraft(USER_ID, DRAFT_ID, {
      expectedVersion: 1,
      exactLocation: {
        latitude: 10.7769,
        longitude: 106.7009,
        formattedAddress:
          '12 Duong Le Loi, Phuong Ben Nghe, Quan 1, Thanh pho Ho Chi Minh',
      },
      mediaIds,
    });

    expect(updateDraft).toHaveBeenCalledTimes(1);
    expect(updateDraft).toHaveBeenCalledWith({
      ownerUserId: USER_ID,
      draftId: DRAFT_ID,
      expectedVersion: 1,
      patch: {
        location: {
          latitude: 10.7769,
          longitude: 106.7009,
          formattedAddress:
            '12 Duong Le Loi, Phuong Ben Nghe, Quan 1, Thanh pho Ho Chi Minh',
          areaLabel: 'Phuong Ben Nghe, Quan 1, Thanh pho Ho Chi Minh',
          privacyRadiusMeters: 500,
        },
        mediaIds,
      },
      now: NOW,
    });
    expect(attachVerifiedMediaToDraft).not.toHaveBeenCalled();
  });

  it.each([
    [
      {
        expectedVersion: 1,
        exactLocation: { latitude: 91, longitude: 106.7 },
      },
      'exactLocation',
    ],
    [
      {
        expectedVersion: 1,
        mediaIds: [MEDIA_ID, MEDIA_ID],
      },
      'mediaIds',
    ],
    [{ expectedVersion: 1 }, 'body'],
    [{ expectedVersion: 1, unsupported: true }, 'unsupported'],
  ])('rejects invalid draft update payload %p', async (payload, field) => {
    const { repository, updateDraft } = buildRepository();

    await expect(
      makeService(repository).updateDraft(USER_ID, DRAFT_ID, payload),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field,
    });
    expect(updateDraft).not.toHaveBeenCalled();
  });

  it('validates publish input and forwards publish idempotency as one command', async () => {
    const { repository, publishDraft } = buildRepository();
    const service = makeService(repository);

    const result = await service.publishDraft(
      USER_ID,
      DRAFT_ID,
      { expectedVersion: 2 },
      'publish-key',
    );

    expect(result).toMatchObject({ caseId: CASE_ID, status: 'missing' });
    expect(publishDraft).toHaveBeenCalledWith({
      ownerUserId: USER_ID,
      draftId: DRAFT_ID,
      expectedVersion: 2,
      idempotency: expect.objectContaining({
        normalizedPath: `/rescue/case-drafts/${DRAFT_ID}/publish`,
        method: 'POST',
      }),
      now: NOW,
    });
  });

  it.each([
    [{}, 'expectedVersion'],
    [{ expectedVersion: 1, extra: true }, 'extra'],
  ])('rejects invalid publish payload %p', async (payload, field) => {
    const { repository, publishDraft } = buildRepository();

    await expect(
      makeService(repository).publishDraft(
        USER_ID,
        DRAFT_ID,
        payload,
        'publish-key',
      ),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field,
    });
    expect(publishDraft).not.toHaveBeenCalled();
  });

  it('normalizes a comment and forwards media, reply and idempotency together', async () => {
    const { repository, createComment } = buildRepository();
    const service = makeService(repository);

    const result = await service.createComment(
      USER_ID,
      CASE_ID,
      {
        body: '  Toi da thay mot be giong Mochi.  ',
        mediaIds: [MEDIA_ID],
        replyToCommentId: NEXT_COMMENT_ID,
      },
      'comment-key',
    );

    expect(result).toMatchObject({
      commentId: COMMENT_ID,
      author: { userId: USER_ID },
    });
    expect(createComment).toHaveBeenCalledWith({
      authorUserId: USER_ID,
      caseId: CASE_ID,
      body: 'Toi da thay mot be giong Mochi.',
      mediaIds: [MEDIA_ID],
      replyToCommentId: NEXT_COMMENT_ID,
      idempotency: expect.objectContaining({
        normalizedPath: `/rescue/cases/${CASE_ID}/comments`,
        method: 'POST',
      }),
      now: NOW,
    });
  });

  it.each([
    [
      { body: 'Manh moi', location: { latitude: 10, longitude: 106 } },
      'location',
    ],
    [{ body: 'Manh moi', unknown: true }, 'unknown'],
  ])('rejects forbidden comment field $field', async (payload, field) => {
    const { repository, createComment } = buildRepository();

    await expect(
      makeService(repository).createComment(
        USER_ID,
        CASE_ID,
        payload,
        'comment-key',
      ),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field,
    });
    expect(createComment).not.toHaveBeenCalled();
  });

  it('binds an opaque discussion cursor to its case and passes the decoded cursor back', async () => {
    const { repository, listComments } = buildRepository();
    listComments.mockResolvedValue({
      items: [makeComment()],
      nextCursor: {
        createdAt: NOW.toISOString(),
        commentId: NEXT_COMMENT_ID,
      },
      limit: 10,
    });
    const service = makeService(repository);

    const first = await service.listDiscussion(CASE_ID, { limit: '10' });
    expect(first.nextCursor).toEqual(expect.any(String));

    await service.listDiscussion(CASE_ID, {
      cursor: first.nextCursor,
      limit: 10,
    });
    expect(listComments).toHaveBeenLastCalledWith({
      caseId: CASE_ID,
      cursor: {
        createdAt: NOW.toISOString(),
        commentId: NEXT_COMMENT_ID,
      },
      limit: 10,
    });

    listComments.mockClear();
    await expect(
      service.listDiscussion(OTHER_CASE_ID, { cursor: first.nextCursor }),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field: 'cursor',
    });
    expect(listComments).not.toHaveBeenCalled();
  });

  it.each([0, 51, 'invalid'])(
    'rejects invalid discussion limit %p',
    async (limit) => {
      const { repository, listComments } = buildRepository();

      await expect(
        makeService(repository).listDiscussion(CASE_ID, { limit }),
      ).rejects.toMatchObject({
        code: RESCUE_ERROR_CODES.invalidInput,
        statusCode: 400,
        field: 'limit',
      });
      expect(listComments).not.toHaveBeenCalled();
    },
  );

  it('allows only confirmed missing-to-found status updates', async () => {
    const { repository, updateCaseStatus } = buildRepository();
    const service = makeService(repository);

    const result = await service.updateStatus(
      USER_ID,
      CASE_ID,
      {
        newStatus: 'found',
        expectedStatus: 'missing',
        expectedVersion: 1,
        confirmedSafe: true,
      },
      'status-key',
    );

    expect(result).toMatchObject({ caseId: CASE_ID, status: 'found' });
    expect(updateCaseStatus).toHaveBeenCalledWith({
      ownerUserId: USER_ID,
      caseId: CASE_ID,
      expectedVersion: 1,
      status: 'found',
      idempotency: expect.objectContaining({
        normalizedPath: `/rescue/cases/${CASE_ID}/status`,
        method: 'PATCH',
      }),
      now: NOW,
    });
  });

  it('D104 rejects a viewer status update through owner-scoped persistence', async () => {
    const { repository, updateCaseStatus } = buildRepository();
    updateCaseStatus.mockRejectedValueOnce(
      new RescuePersistenceDomainError(
        'forbidden',
        'Only the case owner may update status.',
      ),
    );

    await expect(
      makeService(repository).updateStatus(
        VIEWER_ID,
        CASE_ID,
        {
          newStatus: 'found',
          expectedStatus: 'missing',
          expectedVersion: 1,
          confirmedSafe: true,
        },
        'viewer-status-key',
      ),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.forbidden,
      statusCode: 403,
    });
    expect(updateCaseStatus).toHaveBeenCalledWith(
      expect.objectContaining({
        ownerUserId: VIEWER_ID,
        caseId: CASE_ID,
      }),
    );
  });

  it.each([
    {
      newStatus: 'missing',
      expectedStatus: 'missing',
      expectedVersion: 1,
      confirmedSafe: true,
    },
    {
      newStatus: 'found',
      expectedStatus: 'missing',
      expectedVersion: 1,
      confirmedSafe: false,
    },
  ])('rejects invalid status transition %p', async (payload) => {
    const { repository, updateCaseStatus } = buildRepository();

    await expect(
      makeService(repository).updateStatus(
        USER_ID,
        CASE_ID,
        payload,
        'status-key',
      ),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidStatusTransition,
      statusCode: 409,
    });
    expect(updateCaseStatus).not.toHaveBeenCalled();
  });

  it.each([
    ['forbidden', RESCUE_ERROR_CODES.forbidden, 403],
    ['not_found', RESCUE_ERROR_CODES.notFound, 404],
    ['version_conflict', RESCUE_ERROR_CODES.versionConflict, 409],
  ] as const)(
    'maps persistence failure %s to %s/%i',
    async (failure, code, statusCode) => {
      const { repository, updateDraft } = buildRepository();
      updateDraft.mockRejectedValueOnce(
        new RescuePersistenceDomainError(failure, `failure:${failure}`),
      );

      await expect(
        makeService(repository).updateDraft(USER_ID, DRAFT_ID, {
          expectedVersion: 1,
          petName: 'Mochi',
        }),
      ).rejects.toMatchObject({ code, statusCode });
    },
  );

  it('maps an idempotency payload conflict to exact IDEMPOTENCY_001/409', async () => {
    const { repository, publishDraft } = buildRepository();
    publishDraft.mockRejectedValueOnce(
      new RescuePersistenceDomainError(
        'idempotency_conflict',
        'Idempotency key reused with another payload.',
      ),
    );

    await expect(
      makeService(repository).publishDraft(
        USER_ID,
        DRAFT_ID,
        { expectedVersion: 1 },
        'reused-key',
      ),
    ).rejects.toMatchObject({
      code: IDEMPOTENCY_ERROR_CODES.payloadConflict,
      statusCode: 409,
    });
  });
});

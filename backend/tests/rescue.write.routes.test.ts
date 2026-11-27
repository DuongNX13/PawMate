import { buildApp } from '../src/app';
import { AppError } from '../src/errors/app-error';
import {
  AUTH_ERROR_CODES,
  RESCUE_ERROR_CODES,
} from '../src/errors/error-codes';
import { type AuthService } from '../src/services/auth/auth-service';
import { type RescueMediaService } from '../src/services/rescue/rescue-media-service';
import { type RescueReadService } from '../src/services/rescue/rescue-read-service';
import { type RescueWriteService } from '../src/services/rescue/rescue-write-service';
import {
  buildTestConfig,
  CASE_ID,
  DRAFT_ID,
  MEDIA_ID,
  OWNER_USER_ID,
} from './helpers/rescue-read-fixtures';

const COMMENT_ID = '55555555-5555-4555-8555-555555555555';
const VALID_ACCESS_TOKEN = 'owner-token';
const VIEWER_USER_ID = '99999999-9999-4999-8999-999999999999';

const draftDto = {
  draftId: DRAFT_ID,
  ownerUserId: OWNER_USER_ID,
  state: 'draft',
  version: 1,
};

const publishedCaseDto = {
  caseId: CASE_ID,
  ownerUserId: OWNER_USER_ID,
  status: 'missing',
  version: 1,
};

const commentDto = {
  commentId: COMMENT_ID,
  caseId: CASE_ID,
  authorUserId: OWNER_USER_ID,
  body: 'Toi vua thay be o cong vien.',
};

const foundCaseDto = {
  ...publishedCaseDto,
  status: 'found',
  version: 2,
};

const mediaTicketDto = {
  mediaId: MEDIA_ID,
  uploadUrl: 'https://storage.example.test/staging/upload',
  expiresAt: '2026-07-21T12:00:00.000Z',
};

const completedMediaDto = {
  mediaId: MEDIA_ID,
  status: 'verified',
  mimeType: 'image/jpeg',
  publicUrl: 'https://cdn.example.test/rescue/verified.jpg',
};

const openApps: Array<ReturnType<typeof buildApp>> = [];

afterEach(async () => {
  await Promise.all(openApps.splice(0).map(async (app) => app.close()));
});

const buildHarness = async () => {
  const verifyAccessToken = jest.fn(async (accessToken: string) => {
    if (accessToken !== VALID_ACCESS_TOKEN) {
      throw new AppError(
        AUTH_ERROR_CODES.unauthorized,
        'Access token khong hop le.',
        401,
      );
    }
    return { userId: OWNER_USER_ID, email: 'owner@example.test' };
  });

  const createDraft = jest.fn(async () => draftDto);
  const updateDraft = jest.fn(async () => ({ ...draftDto, version: 2 }));
  const publishDraft = jest.fn(async () => publishedCaseDto);
  const createComment = jest.fn(async () => commentDto);
  const listDiscussion = jest.fn(async () => ({
    items: [commentDto],
    nextCursor: 'discussion-next',
    limit: 2,
  }));
  const updateStatus = jest.fn(async () => foundCaseDto);
  const requestUpload = jest.fn(async () => mediaTicketDto);
  const completeUpload = jest.fn(async () => completedMediaDto);
  const listCases = jest.fn(async () => ({
    items: [{ caseId: CASE_ID, status: 'missing' }],
    limit: 20,
  }));
  const getCase = jest.fn(async () => ({
    caseId: CASE_ID,
    status: 'missing',
  }));

  const authService = { verifyAccessToken } as unknown as AuthService;
  const rescueWriteService = {
    createDraft,
    updateDraft,
    publishDraft,
    createComment,
    listDiscussion,
    updateStatus,
  } as unknown as RescueWriteService;
  const rescueMediaService = {
    requestUpload,
    completeUpload,
  } as unknown as RescueMediaService;
  const rescueReadService = {
    listCases,
    getCase,
  } as unknown as RescueReadService;

  const app = buildApp(
    { logger: false },
    {
      config: buildTestConfig(),
      authService,
      rescueReadService,
      rescueWriteService,
      rescueMediaService,
    },
  );
  openApps.push(app);
  await app.ready();

  return {
    app,
    verifyAccessToken,
    writeMocks: {
      createDraft,
      updateDraft,
      publishDraft,
      createComment,
      listDiscussion,
      updateStatus,
    },
    mediaMocks: { requestUpload, completeUpload },
    readMocks: { listCases, getCase },
  };
};

const protectedEndpoints = [
  {
    name: 'create draft',
    method: 'POST' as const,
    url: '/rescue/case-drafts',
    payload: {},
  },
  {
    name: 'update draft',
    method: 'PATCH' as const,
    url: `/rescue/case-drafts/${DRAFT_ID}`,
    payload: {},
  },
  {
    name: 'publish draft',
    method: 'POST' as const,
    url: `/rescue/case-drafts/${DRAFT_ID}/publish`,
    payload: {},
  },
  {
    name: 'create comment',
    method: 'POST' as const,
    url: `/rescue/cases/${CASE_ID}/comments`,
    payload: {},
  },
  {
    name: 'list discussion',
    method: 'GET' as const,
    url: `/rescue/cases/${CASE_ID}/discussion`,
  },
  {
    name: 'update status',
    method: 'PATCH' as const,
    url: `/rescue/cases/${CASE_ID}/status`,
    payload: {},
  },
  {
    name: 'request media upload',
    method: 'POST' as const,
    url: '/media/uploads',
    payload: {},
  },
  {
    name: 'complete media upload',
    method: 'POST' as const,
    url: `/media/uploads/${MEDIA_ID}/complete`,
    payload: {},
  },
];

describe('Day 36 Rescue write routes', () => {
  it.each(protectedEndpoints)(
    'rejects unauthenticated $name requests before invoking services',
    async ({ method, url, payload }) => {
      const { app, mediaMocks, writeMocks } = await buildHarness();

      const response = await app.inject({ method, url, payload });

      expect(response.statusCode).toBe(401);
      expect(response.json()).toEqual({
        success: false,
        error: {
          code: AUTH_ERROR_CODES.unauthorized,
          message: 'Ban can dang nhap de su dung tinh nang Rescue nay.',
        },
        requestId: expect.any(String),
      });
      Object.values({ ...writeMocks, ...mediaMocks }).forEach((mock) => {
        expect(mock).not.toHaveBeenCalled();
      });
    },
  );

  it('returns 201/200 data envelopes and forwards command inputs including Idempotency-Key', async () => {
    const { app, mediaMocks, writeMocks } = await buildHarness();
    const authorization = `Bearer ${VALID_ACCESS_TOKEN}`;
    const createBody = { source: 'rescue_home' };
    const updateBody = { expectedVersion: 1, petName: 'Golden' };
    const publishBody = { expectedVersion: 2 };
    const commentBody = { body: 'Toi vua thay be o cong vien.' };
    const statusBody = {
      newStatus: 'found',
      expectedStatus: 'missing',
      expectedVersion: 1,
      confirmedSafe: true,
    };
    const mediaBody = {
      purpose: 'rescue_case',
      mimeType: 'image/jpeg',
      sizeBytes: 4,
      sha256: 'a'.repeat(64),
    };
    const completeBody = { sha256: 'a'.repeat(64) };

    const [
      createResponse,
      updateResponse,
      publishResponse,
      commentResponse,
      discussionResponse,
      statusResponse,
      mediaResponse,
      completeResponse,
    ] = await Promise.all([
      app.inject({
        method: 'POST',
        url: '/rescue/case-drafts',
        headers: { authorization, 'idempotency-key': 'idem-create' },
        payload: createBody,
      }),
      app.inject({
        method: 'PATCH',
        url: `/rescue/case-drafts/${DRAFT_ID}`,
        headers: { authorization },
        payload: updateBody,
      }),
      app.inject({
        method: 'POST',
        url: `/rescue/case-drafts/${DRAFT_ID}/publish`,
        headers: { authorization, 'idempotency-key': 'idem-publish' },
        payload: publishBody,
      }),
      app.inject({
        method: 'POST',
        url: `/rescue/cases/${CASE_ID}/comments`,
        headers: { authorization, 'idempotency-key': 'idem-comment' },
        payload: commentBody,
      }),
      app.inject({
        method: 'GET',
        url: `/rescue/cases/${CASE_ID}/discussion?cursor=incoming&limit=2`,
        headers: { authorization },
      }),
      app.inject({
        method: 'PATCH',
        url: `/rescue/cases/${CASE_ID}/status`,
        headers: { authorization, 'idempotency-key': 'idem-status' },
        payload: statusBody,
      }),
      app.inject({
        method: 'POST',
        url: '/media/uploads',
        headers: { authorization, 'idempotency-key': 'idem-media' },
        payload: mediaBody,
      }),
      app.inject({
        method: 'POST',
        url: `/media/uploads/${MEDIA_ID}/complete`,
        headers: { authorization, 'idempotency-key': 'idem-complete' },
        payload: completeBody,
      }),
    ]);

    expect([createResponse.statusCode, updateResponse.statusCode]).toEqual([
      201, 200,
    ]);
    expect([publishResponse.statusCode, commentResponse.statusCode]).toEqual([
      201, 201,
    ]);
    expect([discussionResponse.statusCode, statusResponse.statusCode]).toEqual([
      200, 200,
    ]);
    expect([mediaResponse.statusCode, completeResponse.statusCode]).toEqual([
      201, 200,
    ]);
    expect(createResponse.json()).toEqual({ data: draftDto });
    expect(updateResponse.json()).toEqual({
      data: { ...draftDto, version: 2 },
    });
    expect(publishResponse.json()).toEqual({ data: publishedCaseDto });
    expect(commentResponse.json()).toEqual({ data: commentDto });
    expect(discussionResponse.json()).toEqual({
      data: [commentDto],
      pageInfo: { nextCursor: 'discussion-next', hasMore: true, limit: 2 },
    });
    expect(statusResponse.json()).toEqual({ data: foundCaseDto });
    expect(mediaResponse.json()).toEqual({ data: mediaTicketDto });
    expect(completeResponse.json()).toEqual({ data: completedMediaDto });
    expect(discussionResponse.headers['cache-control']).toBe('no-store');

    expect(writeMocks.createDraft).toHaveBeenCalledWith(
      OWNER_USER_ID,
      createBody,
      'idem-create',
    );
    expect(writeMocks.updateDraft).toHaveBeenCalledWith(
      OWNER_USER_ID,
      DRAFT_ID,
      updateBody,
    );
    expect(writeMocks.publishDraft).toHaveBeenCalledWith(
      OWNER_USER_ID,
      DRAFT_ID,
      publishBody,
      'idem-publish',
    );
    expect(writeMocks.createComment).toHaveBeenCalledWith(
      OWNER_USER_ID,
      CASE_ID,
      commentBody,
      'idem-comment',
    );
    expect(writeMocks.listDiscussion).toHaveBeenCalledWith(CASE_ID, {
      cursor: 'incoming',
      limit: '2',
    });
    expect(writeMocks.updateStatus).toHaveBeenCalledWith(
      OWNER_USER_ID,
      CASE_ID,
      statusBody,
      'idem-status',
    );
    expect(mediaMocks.requestUpload).toHaveBeenCalledWith(
      OWNER_USER_ID,
      mediaBody,
      'idem-media',
    );
    expect(mediaMocks.completeUpload).toHaveBeenCalledWith(
      OWNER_USER_ID,
      MEDIA_ID,
      completeBody,
      'idem-complete',
    );
  });

  it('propagates owner authorization and viewer authentication AppErrors', async () => {
    const { app, verifyAccessToken, writeMocks } = await buildHarness();
    writeMocks.updateDraft.mockRejectedValueOnce(
      new AppError(
        RESCUE_ERROR_CODES.forbidden,
        'Chi chu so huu moi duoc sua ban nhap.',
        403,
      ),
    );

    const ownerResponse = await app.inject({
      method: 'PATCH',
      url: `/rescue/case-drafts/${DRAFT_ID}`,
      headers: { authorization: `Bearer ${VALID_ACCESS_TOKEN}` },
      payload: { expectedVersion: 1 },
    });
    const viewerResponse = await app.inject({
      method: 'GET',
      url: `/rescue/cases/${CASE_ID}/discussion`,
      headers: { authorization: 'Bearer invalid-token' },
    });

    expect(ownerResponse.statusCode).toBe(403);
    expect(ownerResponse.json()).toEqual({
      success: false,
      error: {
        code: RESCUE_ERROR_CODES.forbidden,
        message: 'Chi chu so huu moi duoc sua ban nhap.',
      },
      requestId: expect.any(String),
    });
    expect(viewerResponse.statusCode).toBe(401);
    expect(viewerResponse.json()).toEqual({
      success: false,
      error: {
        code: AUTH_ERROR_CODES.unauthorized,
        message: 'Access token khong hop le.',
      },
      requestId: expect.any(String),
    });
    expect(verifyAccessToken).toHaveBeenCalledWith('invalid-token');
    expect(writeMocks.listDiscussion).not.toHaveBeenCalled();
  });

  it('D104 returns 403 and never promotes a viewer to owner on status update', async () => {
    const { app, verifyAccessToken, writeMocks } = await buildHarness();
    verifyAccessToken.mockResolvedValueOnce({
      userId: VIEWER_USER_ID,
      email: 'viewer@example.test',
    });
    writeMocks.updateStatus.mockRejectedValueOnce(
      new AppError(
        RESCUE_ERROR_CODES.forbidden,
        'Chi chu so huu moi duoc cap nhat trang thai.',
        403,
      ),
    );

    const response = await app.inject({
      method: 'PATCH',
      url: `/rescue/cases/${CASE_ID}/status`,
      headers: {
        authorization: `Bearer ${VALID_ACCESS_TOKEN}`,
        'idempotency-key': 'viewer-status-key',
      },
      payload: {
        newStatus: 'found',
        expectedStatus: 'missing',
        expectedVersion: 1,
        confirmedSafe: true,
      },
    });

    expect(response.statusCode).toBe(403);
    expect(response.json()).toMatchObject({
      success: false,
      error: { code: RESCUE_ERROR_CODES.forbidden },
    });
    expect(writeMocks.updateStatus).toHaveBeenCalledWith(
      VIEWER_USER_ID,
      CASE_ID,
      expect.objectContaining({ newStatus: 'found' }),
      'viewer-status-key',
    );
  });

  it('keeps an invalid optional bearer anonymous on public Rescue reads', async () => {
    const { app, readMocks, verifyAccessToken } = await buildHarness();

    const response = await app.inject({
      method: 'GET',
      url: '/rescue/cases',
      headers: { authorization: 'Bearer invalid-token' },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      data: [{ caseId: CASE_ID, status: 'missing' }],
      pageInfo: { nextCursor: null, hasMore: false, limit: 20 },
    });
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.headers.vary).toBe('Authorization');
    expect(verifyAccessToken).toHaveBeenCalledWith('invalid-token');
    expect(readMocks.listCases).toHaveBeenCalledWith({}, undefined);
  });
});

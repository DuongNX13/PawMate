import { buildApp } from '../src/app';
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

const buildDisabledHarness = async () => {
  const config = {
    ...buildTestConfig(),
    features: { rescueBrowse: false, rescueCreate: false },
  };
  const verifyAccessToken = jest.fn(async () => ({
    userId: OWNER_USER_ID,
    email: 'owner@example.test',
  }));
  const readMocks = {
    listCases: jest.fn(async () => ({ items: [], limit: 20 })),
    getCase: jest.fn(async () => ({ caseId: CASE_ID, status: 'missing' })),
  };
  const writeMocks = {
    createDraft: jest.fn(async () => ({ draftId: DRAFT_ID })),
    updateDraft: jest.fn(async () => ({ draftId: DRAFT_ID })),
    publishDraft: jest.fn(async () => ({ caseId: CASE_ID })),
    createComment: jest.fn(async () => ({ commentId: 'comment-id' })),
    listDiscussion: jest.fn(async () => ({ items: [], limit: 20 })),
    updateStatus: jest.fn(async () => ({ caseId: CASE_ID, status: 'found' })),
  };
  const mediaMocks = {
    requestUpload: jest.fn(async () => ({ mediaId: MEDIA_ID })),
    completeUpload: jest.fn(async () => ({ mediaId: MEDIA_ID })),
  };
  const app = buildApp(
    { logger: false },
    {
      config,
      authService: { verifyAccessToken } as unknown as AuthService,
      rescueReadService: readMocks as unknown as RescueReadService,
      rescueWriteService: writeMocks as unknown as RescueWriteService,
      rescueMediaService: mediaMocks as unknown as RescueMediaService,
    },
  );
  await app.ready();
  return { app, mediaMocks, readMocks, verifyAccessToken, writeMocks };
};

describe('Rescue backend feature flags', () => {
  it('fails closed before auth, quota, or service work when Rescue is disabled', async () => {
    const { app, mediaMocks, readMocks, verifyAccessToken, writeMocks } =
      await buildDisabledHarness();
    const auth = { authorization: 'Bearer owner-token' };
    const requests = [
      { method: 'GET' as const, url: '/rescue/cases' },
      { method: 'GET' as const, url: `/rescue/cases/${CASE_ID}` },
      {
        method: 'POST' as const,
        url: '/rescue/case-drafts',
        headers: auth,
        payload: {},
      },
      {
        method: 'PATCH' as const,
        url: `/rescue/case-drafts/${DRAFT_ID}`,
        headers: auth,
        payload: {},
      },
      {
        method: 'POST' as const,
        url: `/rescue/case-drafts/${DRAFT_ID}/publish`,
        headers: auth,
        payload: {},
      },
      {
        method: 'POST' as const,
        url: `/rescue/cases/${CASE_ID}/comments`,
        headers: auth,
        payload: {},
      },
      {
        method: 'GET' as const,
        url: `/rescue/cases/${CASE_ID}/discussion`,
        headers: auth,
      },
      {
        method: 'PATCH' as const,
        url: `/rescue/cases/${CASE_ID}/status`,
        headers: auth,
        payload: {},
      },
      {
        method: 'POST' as const,
        url: '/media/uploads',
        headers: auth,
        payload: {
          purpose: 'rescue_case',
          mimeType: 'image/jpeg',
          sizeBytes: 4,
          sha256: 'a'.repeat(64),
        },
      },
    ];

    const responses = await Promise.all(
      requests.map((request) => app.inject(request)),
    );
    responses.forEach((response) => {
      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        success: false,
        error: {
          code: 'RESCUE_012',
          message: 'Tinh nang Rescue chua duoc bat.',
        },
        requestId: expect.any(String),
      });
    });

    expect(verifyAccessToken).not.toHaveBeenCalled();
    Object.values({ ...readMocks, ...writeMocks, ...mediaMocks }).forEach(
      (mock) => expect(mock).not.toHaveBeenCalled(),
    );
    await app.close();
  });

  it('keeps non-Rescue media purposes available while Rescue create is off', async () => {
    const { app, mediaMocks } = await buildDisabledHarness();

    const response = await app.inject({
      method: 'POST',
      url: '/media/uploads',
      headers: { authorization: 'Bearer owner-token' },
      payload: {
        purpose: 'adoption_chat',
        threadId: '11111111-1111-4111-8111-111111111111',
        mimeType: 'image/jpeg',
        sizeBytes: 4,
        sha256: 'a'.repeat(64),
      },
    });

    expect(response.statusCode).toBe(201);
    expect(mediaMocks.requestUpload).toHaveBeenCalledTimes(1);
    await app.close();
  });
});

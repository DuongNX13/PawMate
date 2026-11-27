import { createHash } from 'node:crypto';

import { MEDIA_ERROR_CODES } from '../src/errors/error-codes';
import {
  type RescueMediaAssetRecord,
  type RescueMediaUploadRequestRecord,
  type RescueRepository,
} from '../src/features/rescue/persistence/rescue-repository';
import {
  RescueMediaStorageError,
  type RescueMediaStorage,
} from '../src/infrastructure/rescue-media-storage';
import { createRescueMediaService } from '../src/services/rescue/rescue-media-service';
import { buildChatRepositoryMock } from './helpers/adoption-chat-fixtures';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const MEDIA_ID = '22222222-2222-4222-8222-222222222222';
const CHAT_THREAD_ID = '33333333-3333-4333-8333-333333333333';
const NOW = new Date('2026-07-21T05:00:00.000Z');

const jpegSegment = (marker: number, payload: Buffer) => {
  const segment = Buffer.alloc(4 + payload.length);
  segment[0] = 0xff;
  segment[1] = marker;
  segment.writeUInt16BE(payload.length + 2, 2);
  payload.copy(segment, 4);
  return segment;
};

const makeJpeg = () =>
  Buffer.concat([
    Buffer.from([0xff, 0xd8]),
    jpegSegment(0xe0, Buffer.from('JFIF-safe', 'ascii')),
    jpegSegment(0xe1, Buffer.from('Exif\0\0GPS-location', 'binary')),
    jpegSegment(0xda, Buffer.from([0x01, 0x01, 0x00, 0x00, 0x3f, 0x00])),
    Buffer.from([0x11, 0x22, 0xff, 0x00, 0x33]),
    Buffer.from([0xff, 0xd9]),
  ]);

const ORIGINAL = makeJpeg();
const ORIGINAL_SHA = createHash('sha256').update(ORIGINAL).digest('hex');

const makeMedia = (
  overrides: Partial<RescueMediaAssetRecord> = {},
): RescueMediaAssetRecord => ({
  mediaId: MEDIA_ID,
  ownerUserId: USER_ID,
  purpose: 'rescue_case',
  mimeType: 'image/jpeg',
  sizeBytes: ORIGINAL.length,
  sha256: ORIGINAL_SHA,
  status: 'requested',
  storageKey: `${USER_ID}/${MEDIA_ID}/original.jpg`,
  verificationVersion: 0,
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...overrides,
});

const makeUploadRequest = (): RescueMediaUploadRequestRecord => ({
  media: makeMedia(),
  uploadUrl: 'https://storage.example.test/upload/token',
  uploadHeaders: { 'content-type': 'image/jpeg' },
  expiresAt: new Date(NOW.getTime() + 60 * 60 * 1_000).toISOString(),
});

const buildRepository = () => {
  const findIdempotencyResponse = jest.fn<
    ReturnType<RescueRepository['findIdempotencyResponse']>,
    Parameters<RescueRepository['findIdempotencyResponse']>
  >();
  const createMediaUploadRequest = jest
    .fn<
      ReturnType<RescueRepository['createMediaUploadRequest']>,
      Parameters<RescueRepository['createMediaUploadRequest']>
    >()
    .mockResolvedValue(makeUploadRequest());
  const findOwnedMediaUpload = jest
    .fn<
      ReturnType<RescueRepository['findOwnedMediaUpload']>,
      Parameters<RescueRepository['findOwnedMediaUpload']>
    >()
    .mockResolvedValue({
      media: makeMedia(),
      session: {
        mediaId: MEDIA_ID,
        stagingStorageKey: `${USER_ID}/${MEDIA_ID}/original.jpg`,
        uploadExpiresAt: new Date(
          NOW.getTime() + 60 * 60 * 1_000,
        ).toISOString(),
      },
    });
  const completeMediaUpload = jest
    .fn<
      ReturnType<RescueRepository['completeMediaUpload']>,
      Parameters<RescueRepository['completeMediaUpload']>
    >()
    .mockResolvedValue(
      makeMedia({
        status: 'verified',
        publicUrl: 'https://cdn.example.test/rescue/public.jpg',
        verifiedAt: NOW.toISOString(),
        verificationVersion: 1,
      }),
    );
  const rejectMediaUpload = jest.fn<
    ReturnType<RescueRepository['rejectMediaUpload']>,
    Parameters<RescueRepository['rejectMediaUpload']>
  >();
  const repository = {
    findIdempotencyResponse,
    createMediaUploadRequest,
    findOwnedMediaUpload,
    completeMediaUpload,
    rejectMediaUpload,
  } as unknown as RescueRepository;
  return {
    repository,
    findIdempotencyResponse,
    createMediaUploadRequest,
    findOwnedMediaUpload,
    completeMediaUpload,
    rejectMediaUpload,
  };
};

const buildStorage = () => {
  const createUploadTicket = jest
    .fn<
      ReturnType<RescueMediaStorage['createUploadTicket']>,
      Parameters<RescueMediaStorage['createUploadTicket']>
    >()
    .mockResolvedValue({
      uploadUrl: 'https://storage.example.test/upload/token',
      uploadHeaders: { 'content-type': 'image/jpeg' },
    });
  const readStagingObject = jest
    .fn<
      ReturnType<RescueMediaStorage['readStagingObject']>,
      Parameters<RescueMediaStorage['readStagingObject']>
    >()
    .mockResolvedValue(ORIGINAL);
  const writePublicObject = jest
    .fn<
      ReturnType<RescueMediaStorage['writePublicObject']>,
      Parameters<RescueMediaStorage['writePublicObject']>
    >()
    .mockResolvedValue('https://cdn.example.test/rescue/public.jpg');
  const writePrivateObject = jest
    .fn<
      ReturnType<RescueMediaStorage['writePrivateObject']>,
      Parameters<RescueMediaStorage['writePrivateObject']>
    >()
    .mockResolvedValue(undefined);
  const readPrivateObject = jest
    .fn<
      ReturnType<RescueMediaStorage['readPrivateObject']>,
      Parameters<RescueMediaStorage['readPrivateObject']>
    >()
    .mockResolvedValue(ORIGINAL);
  const deletePrivateObject = jest
    .fn<
      ReturnType<RescueMediaStorage['deletePrivateObject']>,
      Parameters<RescueMediaStorage['deletePrivateObject']>
    >()
    .mockResolvedValue(undefined);
  const deletePublicObject = jest.fn<
    ReturnType<RescueMediaStorage['deletePublicObject']>,
    Parameters<RescueMediaStorage['deletePublicObject']>
  >();
  const deleteStagingObject = jest.fn<
    ReturnType<RescueMediaStorage['deleteStagingObject']>,
    Parameters<RescueMediaStorage['deleteStagingObject']>
  >();
  const storage = {
    ensureReady: jest.fn(),
    createUploadTicket,
    readStagingObject,
    writePublicObject,
    writePrivateObject,
    readPrivateObject,
    deletePrivateObject,
    deletePublicObject,
    deleteStagingObject,
  } as RescueMediaStorage;
  return {
    storage,
    createUploadTicket,
    readStagingObject,
    writePublicObject,
    writePrivateObject,
    readPrivateObject,
    deletePrivateObject,
    deletePublicObject,
    deleteStagingObject,
  };
};

describe('rescue media service', () => {
  it('blocks Rescue media while disabled before storage or mutation work', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
      featureAvailability: { rescueBrowse: false, rescueCreate: false },
    });

    await expect(
      service.requestUpload(
        USER_ID,
        {
          purpose: 'rescue_case',
          mimeType: 'image/jpeg',
          sizeBytes: ORIGINAL.length,
          sha256: ORIGINAL_SHA,
        },
        'rescue-disabled-request',
      ),
    ).rejects.toMatchObject({ code: 'RESCUE_012', statusCode: 503 });
    expect(repo.findIdempotencyResponse).not.toHaveBeenCalled();
    expect(repo.createMediaUploadRequest).not.toHaveBeenCalled();
    expect(mediaStorage.createUploadTicket).not.toHaveBeenCalled();

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'rescue-disabled-complete',
      ),
    ).rejects.toMatchObject({ code: 'RESCUE_012', statusCode: 503 });
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
    expect(repo.completeMediaUpload).not.toHaveBeenCalled();
  });

  it('rejects an unbound chat upload before issuing a storage ticket', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(service.requestUpload(USER_ID, {
      purpose: 'adoption_chat',
      mimeType: 'image/jpeg',
      sizeBytes: ORIGINAL.length,
      sha256: ORIGINAL_SHA,
    }, 'chat-unbound')).rejects.toMatchObject({ statusCode: 400 });
    expect(mediaStorage.createUploadTicket).not.toHaveBeenCalled();
  });

  it('binds a chat upload ticket to the current participant and thread', async () => {
    const repo = buildRepository();
    const chat = buildChatRepositoryMock();
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      chatRepository: chat.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });
    const payload = {
      purpose: 'adoption_chat',
      threadId: CHAT_THREAD_ID,
      mimeType: 'image/jpeg',
      sizeBytes: ORIGINAL.length,
      sha256: ORIGINAL_SHA,
    };

    await service.requestUpload(USER_ID, payload, 'chat-bound');
    expect(chat.isCurrentParticipant).toHaveBeenCalledWith({
      participantUserId: USER_ID,
      threadId: CHAT_THREAD_ID,
    });
    expect(mediaStorage.createUploadTicket).toHaveBeenCalledWith(
      expect.stringMatching(new RegExp(
        `^adoption_chat/${CHAT_THREAD_ID}/${USER_ID}/[0-9a-f-]{36}/original\\.jpg$`,
      )),
      'image/jpeg',
    );

    chat.isCurrentParticipant.mockResolvedValue(false);
    await expect(service.requestUpload(USER_ID, payload, 'chat-denied')).rejects.toMatchObject({
      statusCode: 404,
    });
    expect(mediaStorage.createUploadTicket).toHaveBeenCalledTimes(1);
  });
  it('creates a durable upload request with a deterministic private path', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.requestUpload(
        USER_ID,
        {
          purpose: 'rescue_case',
          mimeType: 'image/jpeg',
          sizeBytes: ORIGINAL.length,
          sha256: ORIGINAL_SHA.toUpperCase(),
          fileName: ' missing-pet.jpg ',
        },
        'upload-1',
      ),
    ).resolves.toEqual({
      mediaId: MEDIA_ID,
      uploadUrl: 'https://storage.example.test/upload/token',
      uploadHeaders: { 'content-type': 'image/jpeg' },
      expiresAt: new Date(NOW.getTime() + 60 * 60 * 1_000).toISOString(),
    });

    expect(mediaStorage.createUploadTicket).toHaveBeenCalledWith(
      expect.stringMatching(
        new RegExp(`^${USER_ID}/[0-9a-f-]{36}/original\\.jpg$`),
      ),
      'image/jpeg',
    );
    expect(repo.createMediaUploadRequest).toHaveBeenCalledWith(
      expect.objectContaining({
        ownerUserId: USER_ID,
        purpose: 'rescue_case',
        mimeType: 'image/jpeg',
        sizeBytes: ORIGINAL.length,
        sha256: ORIGINAL_SHA,
      }),
    );
  });

  it('replays an upload ticket without touching storage', async () => {
    const repo = buildRepository();
    repo.findIdempotencyResponse.mockResolvedValue({
      responseStatus: 201,
      responseBody: makeUploadRequest(),
    });
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await service.requestUpload(
      USER_ID,
      {
        purpose: 'rescue_case',
        mimeType: 'image/jpeg',
        sizeBytes: ORIGINAL.length,
        sha256: ORIGINAL_SHA,
      },
      'upload-replay',
    );

    expect(mediaStorage.createUploadTicket).not.toHaveBeenCalled();
    expect(repo.createMediaUploadRequest).not.toHaveBeenCalled();
  });

  it.each([
    [
      {
        purpose: 'rescue_case',
        mimeType: 'image/gif',
        sizeBytes: 1,
        sha256: ORIGINAL_SHA,
      },
      MEDIA_ERROR_CODES.unsupportedMimeType,
    ],
    [
      {
        purpose: 'rescue_case',
        mimeType: 'image/jpeg',
        sizeBytes: 10 * 1024 * 1024 + 1,
        sha256: ORIGINAL_SHA,
      },
      MEDIA_ERROR_CODES.sizeExceeded,
    ],
    [
      {
        purpose: 'rescue_case',
        mimeType: 'video/mp4',
        sizeBytes: 50 * 1024 * 1024 + 1,
        sha256: ORIGINAL_SHA,
      },
      MEDIA_ERROR_CODES.sizeExceeded,
    ],
    [
      {
        purpose: 'rescue_case',
        mimeType: 'image/jpeg',
        sizeBytes: 1,
        sha256: 'bad',
      },
      MEDIA_ERROR_CODES.invalidRequest,
    ],
  ])(
    'rejects invalid request input before storage: %#',
    async (payload, code) => {
      const repo = buildRepository();
      const mediaStorage = buildStorage();
      const service = createRescueMediaService({
        repository: repo.repository,
        storage: mediaStorage.storage,
        now: () => NOW,
      });

      await expect(
        service.requestUpload(USER_ID, payload, 'invalid-upload'),
      ).rejects.toMatchObject({ code, statusCode: 400 });
      expect(mediaStorage.createUploadTicket).not.toHaveBeenCalled();
    },
  );

  it('sanitizes bytes, finalizes the derivative, then removes staging', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-1',
      ),
    ).resolves.toMatchObject({ status: 'verified', mediaId: MEDIA_ID });

    const [publicKey, sanitizedBytes, mimeType] =
      mediaStorage.writePublicObject.mock.calls[0];
    expect(publicKey).toMatch(
      /^rescue_case\/[0-9a-f-]{36}\/[0-9a-f]{64}\/public\.jpg$/,
    );
    expect(mimeType).toBe('image/jpeg');
    expect(sanitizedBytes.includes(Buffer.from('GPS-location'))).toBe(false);
    expect(repo.completeMediaUpload).toHaveBeenCalledWith(
      expect.objectContaining({
        ownerUserId: USER_ID,
        mediaId: MEDIA_ID,
        sanitizedStorageKey: publicKey,
        publicUrl: 'https://cdn.example.test/rescue/public.jpg',
      }),
    );
    expect(mediaStorage.deleteStagingObject).toHaveBeenCalledWith(
      `${USER_ID}/${MEDIA_ID}/original.jpg`,
    );
    expect(mediaStorage.deletePublicObject).not.toHaveBeenCalled();
  });

  it('stores adoption chat derivatives privately without persisting a public URL', async () => {
    const repo = buildRepository();
    const chat = buildChatRepositoryMock();
    repo.findOwnedMediaUpload.mockResolvedValueOnce({
      media: makeMedia({ purpose: 'adoption_chat' }),
      session: {
        mediaId: MEDIA_ID,
        stagingStorageKey: `adoption_chat/${CHAT_THREAD_ID}/${USER_ID}/${MEDIA_ID}/original.jpg`,
        uploadExpiresAt: new Date(
          NOW.getTime() + 60 * 60 * 1_000,
        ).toISOString(),
      },
    });
    repo.completeMediaUpload.mockResolvedValueOnce(
      makeMedia({
        purpose: 'adoption_chat',
        status: 'verified',
        publicUrl: undefined,
        verifiedAt: NOW.toISOString(),
        verificationVersion: 1,
      }),
    );
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      chatRepository: chat.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    const result = await service.completeUpload(
      USER_ID,
      MEDIA_ID,
      { sha256: ORIGINAL_SHA },
      'complete-private-chat-1',
    );

    expect(mediaStorage.writePrivateObject).toHaveBeenCalledWith(
      expect.stringMatching(
        new RegExp(`^adoption_chat/${CHAT_THREAD_ID}/[0-9a-f-]{36}/[0-9a-f]{64}/private\\.jpg$`),
      ),
      expect.any(Buffer),
      'image/jpeg',
    );
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
    expect(repo.completeMediaUpload).toHaveBeenCalledWith(
      expect.not.objectContaining({ publicUrl: expect.any(String) }),
    );
    expect(result).not.toHaveProperty('publicUrl');
  });

  it('rejects completion after chat access is revoked before reading staged bytes', async () => {
    const repo = buildRepository();
    repo.findOwnedMediaUpload.mockResolvedValueOnce({
      media: makeMedia({ purpose: 'adoption_chat' }),
      session: {
        mediaId: MEDIA_ID,
        stagingStorageKey: `adoption_chat/${CHAT_THREAD_ID}/${USER_ID}/${MEDIA_ID}/original.jpg`,
        uploadExpiresAt: new Date(NOW.getTime() + 60 * 60 * 1_000).toISOString(),
      },
    });
    const chat = buildChatRepositoryMock();
    chat.isCurrentParticipant.mockResolvedValue(false);
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      chatRepository: chat.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(service.completeUpload(
      USER_ID, MEDIA_ID, { sha256: ORIGINAL_SHA }, 'chat-revoked',
    )).rejects.toMatchObject({ statusCode: 404 });
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePrivateObject).not.toHaveBeenCalled();
  });

  it('rejects a completion purpose swap before reading the staged object', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA, purpose: 'rescue_case' },
        'complete-purpose-swap',
      ),
    ).rejects.toMatchObject({
      code: MEDIA_ERROR_CODES.invalidRequest,
      field: 'purpose',
      statusCode: 400,
    });
    expect(repo.findOwnedMediaUpload).not.toHaveBeenCalled();
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePrivateObject).not.toHaveBeenCalled();
  });

  it('does not read an upload owned by another user', async () => {
    const repo = buildRepository();
    repo.findOwnedMediaUpload.mockResolvedValue(undefined);
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });
    const outsiderId = '33333333-3333-4333-8333-333333333333';

    await expect(
      service.completeUpload(
        outsiderId,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-owner-swap',
      ),
    ).rejects.toMatchObject({
      code: MEDIA_ERROR_CODES.objectMissingOrExpired,
      statusCode: 404,
    });
    expect(repo.findOwnedMediaUpload).toHaveBeenCalledWith(outsiderId, MEDIA_ID);
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePrivateObject).not.toHaveBeenCalled();
  });

  it('rolls back only the private derivative if chat DB completion fails', async () => {
    const repo = buildRepository();
    const chat = buildChatRepositoryMock();
    repo.findOwnedMediaUpload.mockResolvedValueOnce({
      media: makeMedia({ purpose: 'adoption_chat' }),
      session: {
        mediaId: MEDIA_ID,
        stagingStorageKey: `adoption_chat/${CHAT_THREAD_ID}/${USER_ID}/${MEDIA_ID}/original.jpg`,
        uploadExpiresAt: new Date(NOW.getTime() + 60 * 60 * 1_000).toISOString(),
      },
    });
    repo.completeMediaUpload.mockRejectedValueOnce(new Error('database unavailable'));
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      chatRepository: chat.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-private-db-failure',
      ),
    ).rejects.toThrow('database unavailable');
    const privateKey = mediaStorage.writePrivateObject.mock.calls[0]?.[0];
    expect(privateKey).toMatch(/^adoption_chat\/.+\/private\.jpg$/);
    expect(mediaStorage.deletePrivateObject).toHaveBeenCalledWith(privateKey);
    expect(mediaStorage.deletePublicObject).not.toHaveBeenCalled();
    expect(mediaStorage.deleteStagingObject).not.toHaveBeenCalled();
  });

  it('replays private chat completion without storage or a legacy public URL', async () => {
    const repo = buildRepository();
    const chat = buildChatRepositoryMock();
    repo.findOwnedMediaUpload.mockResolvedValueOnce({
      media: makeMedia({ purpose: 'adoption_chat' }),
      session: {
        mediaId: MEDIA_ID,
        stagingStorageKey: `adoption_chat/${CHAT_THREAD_ID}/${USER_ID}/${MEDIA_ID}/original.jpg`,
        uploadExpiresAt: new Date(NOW.getTime() + 60 * 60 * 1_000).toISOString(),
      },
    });
    repo.findIdempotencyResponse.mockResolvedValue({
      responseStatus: 200,
      responseBody: makeMedia({
        purpose: 'adoption_chat',
        status: 'verified',
        publicUrl: 'https://cdn.example.test/legacy-chat.jpg',
        verifiedAt: NOW.toISOString(),
        verificationVersion: 1,
      }),
    });
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      chatRepository: chat.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    const result = await service.completeUpload(
      USER_ID,
      MEDIA_ID,
      { sha256: ORIGINAL_SHA },
      'complete-private-replay',
    );
    expect(result).not.toHaveProperty('publicUrl');
    expect(repo.findOwnedMediaUpload).toHaveBeenCalledWith(USER_ID, MEDIA_ID);
    expect(chat.isCurrentParticipant).toHaveBeenCalledWith({
      participantUserId: USER_ID,
      threadId: CHAT_THREAD_ID,
    });
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePrivateObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
  });

  it('replays a completed upload without reading or writing storage', async () => {
    const repo = buildRepository();
    repo.findIdempotencyResponse.mockResolvedValue({
      responseStatus: 200,
      responseBody: makeMedia({
        status: 'verified',
        verifiedAt: NOW.toISOString(),
        verificationVersion: 1,
      }),
    });
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await service.completeUpload(
      USER_ID,
      MEDIA_ID,
      { sha256: ORIGINAL_SHA },
      'complete-replay',
    );

    expect(repo.findOwnedMediaUpload).not.toHaveBeenCalled();
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
  });

  it('rejects an expired upload without reading storage', async () => {
    const repo = buildRepository();
    repo.findOwnedMediaUpload.mockResolvedValue({
      media: makeMedia(),
      session: {
        mediaId: MEDIA_ID,
        stagingStorageKey: `${USER_ID}/${MEDIA_ID}/original.jpg`,
        uploadExpiresAt: NOW.toISOString(),
      },
    });
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-expired',
      ),
    ).rejects.toMatchObject({
      code: MEDIA_ERROR_CODES.objectMissingOrExpired,
      statusCode: 404,
    });
    expect(repo.rejectMediaUpload).toHaveBeenCalled();
    expect(mediaStorage.readStagingObject).not.toHaveBeenCalled();
  });

  it('rejects malformed uploaded bytes and never creates a public derivative', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    mediaStorage.readStagingObject.mockResolvedValue(
      Buffer.from('not-an-image'),
    );
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-malformed',
      ),
    ).rejects.toMatchObject({
      code: MEDIA_ERROR_CODES.integrityMismatch,
      statusCode: 422,
    });
    expect(repo.rejectMediaUpload).toHaveBeenCalled();
    expect(mediaStorage.writePublicObject).not.toHaveBeenCalled();
  });

  it('maps missing staging objects and leaves the upload retryable', async () => {
    const repo = buildRepository();
    const mediaStorage = buildStorage();
    mediaStorage.readStagingObject.mockRejectedValue(
      new RescueMediaStorageError('object_missing', 'missing'),
    );
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-missing',
      ),
    ).rejects.toMatchObject({
      code: MEDIA_ERROR_CODES.objectMissingOrExpired,
      statusCode: 404,
    });
    expect(repo.completeMediaUpload).not.toHaveBeenCalled();
  });

  it('rolls back the command-specific public derivative when DB finalization fails', async () => {
    const repo = buildRepository();
    repo.completeMediaUpload.mockRejectedValue(
      new Error('database unavailable'),
    );
    const mediaStorage = buildStorage();
    const service = createRescueMediaService({
      repository: repo.repository,
      storage: mediaStorage.storage,
      now: () => NOW,
    });

    await expect(
      service.completeUpload(
        USER_ID,
        MEDIA_ID,
        { sha256: ORIGINAL_SHA },
        'complete-db-failure',
      ),
    ).rejects.toThrow('database unavailable');

    const publicKey = mediaStorage.writePublicObject.mock.calls[0][0];
    expect(mediaStorage.deletePublicObject).toHaveBeenCalledWith(publicKey);
    expect(mediaStorage.deleteStagingObject).not.toHaveBeenCalled();
  });
});

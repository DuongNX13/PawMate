import { StorageApiError, type SupabaseClient } from '@supabase/supabase-js';

import { buildApp } from '../src/app';
import * as storageModule from '../src/infrastructure/rescue-media-storage';
import {
  createSupabaseRescueMediaStorage,
  RescueMediaStorageError,
} from '../src/infrastructure/rescue-media-storage';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const STAGING_BUCKET = 'rescue-staging-test';
const PUBLIC_BUCKET = 'rescue-public-test';
const PRIVATE_CHAT_BUCKET = 'adoption-chat-private-test';

const buildClient = (options: { bucketsExist?: boolean } = {}) => {
  const getBucket = jest
    .fn()
    .mockImplementation(async () =>
      options.bucketsExist === false
        ? { data: null, error: { message: 'not found' } }
        : { data: { id: 'bucket' }, error: null },
    );
  const createBucket = jest
    .fn()
    .mockResolvedValue({ data: { name: 'bucket' }, error: null });
  const updateBucket = jest
    .fn()
    .mockResolvedValue({ data: { message: 'updated' }, error: null });
  const createSignedUploadUrl = jest.fn().mockResolvedValue({
    data: { signedUrl: 'https://storage.example.test/signed-upload' },
    error: null,
  });
  const download = jest.fn().mockResolvedValue({
    data: new Blob([Buffer.from('private-object')]),
    error: null,
  });
  const upload = jest
    .fn()
    .mockResolvedValue({ data: { path: 'public' }, error: null });
  const getPublicUrl = jest.fn().mockReturnValue({
    data: { publicUrl: 'https://cdn.example.test/public-object' },
  });
  const remove = jest.fn().mockResolvedValue({ data: [], error: null });
  const bucketApi = {
    createSignedUploadUrl,
    download,
    upload,
    getPublicUrl,
    remove,
  };
  const from = jest.fn().mockReturnValue(bucketApi);
  const client = {
    storage: {
      getBucket,
      createBucket,
      updateBucket,
      from,
    },
  } as unknown as SupabaseClient;
  return {
    client,
    getBucket,
    createBucket,
    updateBucket,
    from,
    createSignedUploadUrl,
    download,
    upload,
    getPublicUrl,
    remove,
  };
};

const buildStorage = (
  client: SupabaseClient,
  bucketSetupMode?: 'verify_existing',
) => {
  const config = buildTestConfig();
  config.supabaseBuckets.rescueMediaStaging = STAGING_BUCKET;
  config.supabaseBuckets.rescueMediaPublic = PUBLIC_BUCKET;
  config.supabaseBuckets.adoptionChatMediaPrivate = PRIVATE_CHAT_BUCKET;
  const storage = createSupabaseRescueMediaStorage(
    config,
    client,
    bucketSetupMode ? { bucketSetupMode } : undefined,
  );
  if (!storage) throw new Error('Expected supplied Supabase client storage.');
  return storage;
};

describe('Supabase rescue media storage', () => {
  it('lets the Day 132 harness inject verified storage instead of constructing bootstrap storage', async () => {
    const mock = buildClient();
    const verifiedStorage = buildStorage(mock.client, 'verify_existing');
    const defaultFactory = jest.spyOn(storageModule, 'createSupabaseRescueMediaStorage');
    const app = buildApp(
      { logger: false },
      { config: buildTestConfig(), rescueMediaStorage: verifiedStorage },
    );
    try {
      await app.ready();
      expect(defaultFactory).not.toHaveBeenCalled();
      expect(mock.createBucket).not.toHaveBeenCalled();
      expect(mock.updateBucket).not.toHaveBeenCalled();
    } finally {
      await app.close();
      defaultFactory.mockRestore();
    }
  });

  it('verifies matching live buckets without control-plane writes', async () => {
    const mock = buildClient();
    mock.getBucket.mockImplementation(async (bucket: string) => ({
      data: {
        id: bucket,
        name: bucket,
        public: bucket === PUBLIC_BUCKET,
        file_size_limit: 50 * 1024 * 1024,
        allowed_mime_types: ['video/mp4', 'image/webp', 'image/png', 'image/jpeg'],
      },
      error: null,
    }));
    const storage = buildStorage(mock.client, 'verify_existing');

    await storage.ensureReady();

    expect(mock.getBucket).toHaveBeenCalledTimes(3);
    expect(mock.createBucket).not.toHaveBeenCalled();
    expect(mock.updateBucket).not.toHaveBeenCalled();
  });

  it('fails closed on a missing bucket in verify-only mode', async () => {
    const mock = buildClient({ bucketsExist: false });
    const storage = buildStorage(mock.client, 'verify_existing');

    await expect(storage.ensureReady()).rejects.toMatchObject({
      name: 'RescueMediaStorageError',
    });
    expect(mock.createBucket).not.toHaveBeenCalled();
    expect(mock.updateBucket).not.toHaveBeenCalled();
  });

  it('fails closed on a mismatched existing bucket in verify-only mode', async () => {
    const mock = buildClient();
    mock.getBucket.mockImplementation(async (bucket: string) => ({
      data: {
        id: bucket,
        name: bucket,
        public: false,
        file_size_limit: 50 * 1024 * 1024,
        allowed_mime_types: ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'],
      },
      error: null,
    }));
    const storage = buildStorage(mock.client, 'verify_existing');

    await expect(storage.ensureReady()).rejects.toMatchObject({
      name: 'RescueMediaStorageError',
    });
    expect(mock.createBucket).not.toHaveBeenCalled();
    expect(mock.updateBucket).not.toHaveBeenCalled();
  });

  it('keeps chat derivatives private while rescue derivatives remain public', async () => {
    const mock = buildClient({ bucketsExist: true });
    const storage = buildStorage(mock.client);

    await Promise.all([storage.ensureReady(), storage.ensureReady()]);

    expect(mock.getBucket).toHaveBeenCalledTimes(3);
    expect(mock.updateBucket).toHaveBeenCalledWith(STAGING_BUCKET, {
      public: false,
      fileSizeLimit: 50 * 1024 * 1024,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'],
    });
    expect(mock.updateBucket).toHaveBeenCalledWith(PUBLIC_BUCKET, {
      public: true,
      fileSizeLimit: 50 * 1024 * 1024,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'],
    });
    expect(mock.updateBucket).toHaveBeenCalledWith(PRIVATE_CHAT_BUCKET, {
      public: false,
      fileSizeLimit: 50 * 1024 * 1024,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'],
    });
    expect(mock.createBucket).not.toHaveBeenCalled();
  });

  it('creates all three buckets with the correct visibility when missing', async () => {
    const mock = buildClient({ bucketsExist: false });
    const storage = buildStorage(mock.client);

    await storage.ensureReady();

    expect(mock.createBucket).toHaveBeenCalledTimes(3);
    expect(mock.createBucket).toHaveBeenCalledWith(
      STAGING_BUCKET,
      expect.objectContaining({ public: false }),
    );
    expect(mock.createBucket).toHaveBeenCalledWith(
      PUBLIC_BUCKET,
      expect.objectContaining({ public: true }),
    );
    expect(mock.createBucket).toHaveBeenCalledWith(
      PRIVATE_CHAT_BUCKET,
      expect.objectContaining({ public: false }),
    );
    expect(mock.updateBucket).not.toHaveBeenCalled();
  });

  it('reads, writes and rolls back private chat bytes without generating a public URL', async () => {
    const mock = buildClient({ bucketsExist: true });
    const storage = buildStorage(mock.client);
    const key = 'adoption_chat/media/hash/private.jpg';
    const bytes = Buffer.from('sanitized-private-chat');

    await storage.writePrivateObject(key, bytes, 'image/jpeg');
    await expect(storage.readPrivateObject(key)).resolves.toEqual(
      Buffer.from('private-object'),
    );
    await storage.deletePrivateObject(key);

    expect(mock.from).toHaveBeenCalledTimes(3);
    expect(mock.from.mock.calls.every(([bucket]) => bucket === PRIVATE_CHAT_BUCKET)).toBe(true);
    expect(mock.upload).toHaveBeenCalledWith(key, bytes, {
      contentType: 'image/jpeg',
      cacheControl: '0',
      upsert: false,
    });
    expect(mock.download).toHaveBeenCalledWith(key);
    expect(mock.remove).toHaveBeenCalledWith([key]);
    expect(mock.getPublicUrl).not.toHaveBeenCalled();
  });

  it('reports a missing private object without falling back to a public bucket', async () => {
    const mock = buildClient({ bucketsExist: true });
    mock.download.mockResolvedValueOnce({
      data: null,
      error: { message: 'private object missing', status: 404 },
    });
    const storage = buildStorage(mock.client);

    await expect(
      storage.readPrivateObject('adoption_chat/media/hash/private.jpg'),
    ).rejects.toMatchObject({
      name: 'RescueMediaStorageError',
      failure: 'object_missing',
    } satisfies Partial<RescueMediaStorageError>);
    expect(mock.from).toHaveBeenCalledWith(PRIVATE_CHAT_BUCKET);
    expect(mock.from).not.toHaveBeenCalledWith(PUBLIC_BUCKET);
    expect(mock.getPublicUrl).not.toHaveBeenCalled();
  });

  it.each([
    [400, '404', 'object_missing'],
    [404, '404', 'object_missing'],
    [400, '400', 'operation_failed'],
    [403, '404', 'operation_failed'],
    [429, '404', 'operation_failed'],
    [503, '404', 'operation_failed'],
  ])('classifies native SDK private errors HTTP %i / semantic %s as %s', async (
    status, statusCode, failure,
  ) => {
    const mock = buildClient({ bucketsExist: true });
    mock.download.mockResolvedValueOnce({
      data: null,
      error: new StorageApiError('Synthetic storage response', status, statusCode),
    });
    await expect(buildStorage(mock.client).readPrivateObject('adoption_chat/media/hash/private.jpg'))
      .rejects.toMatchObject({ failure });
    expect(mock.from.mock.calls.every(([bucket]) => bucket === PRIVATE_CHAT_BUCKET)).toBe(true);
    expect(mock.getPublicUrl).not.toHaveBeenCalled();
  });

  it('treats private storage outages as retryable failures, not missing objects', async () => {
    const mock = buildClient({ bucketsExist: true });
    mock.download.mockResolvedValueOnce({
      data: null,
      error: { message: 'storage unavailable', status: 503 },
    });
    const storage = buildStorage(mock.client);

    await expect(storage.readPrivateObject('adoption_chat/thread/media/hash/private.jpg'))
      .rejects.toMatchObject({ failure: 'operation_failed' });
    expect(mock.from).not.toHaveBeenCalledWith(PUBLIC_BUCKET);
  });

  it('routes signed upload, download, sanitized upload and both cleanup paths', async () => {
    const mock = buildClient({ bucketsExist: true });
    const storage = buildStorage(mock.client);
    const bytes = Buffer.from('sanitized');

    await expect(
      storage.createUploadTicket('owner/media/original.jpg', 'image/jpeg'),
    ).resolves.toEqual({
      uploadUrl: 'https://storage.example.test/signed-upload',
      uploadHeaders: { 'content-type': 'image/jpeg' },
    });
    await expect(
      storage.readStagingObject('owner/media/original.jpg'),
    ).resolves.toEqual(Buffer.from('private-object'));
    await expect(
      storage.writePublicObject('rescue/media/public.jpg', bytes, 'image/jpeg'),
    ).resolves.toBe('https://cdn.example.test/public-object');
    await storage.deleteStagingObject('owner/media/original.jpg');
    await storage.deletePublicObject('rescue/media/public.jpg');

    expect(mock.createSignedUploadUrl).toHaveBeenCalledWith(
      'owner/media/original.jpg',
      { upsert: false },
    );
    expect(mock.upload).toHaveBeenCalledWith('rescue/media/public.jpg', bytes, {
      contentType: 'image/jpeg',
      cacheControl: '31536000',
      upsert: true,
    });
    expect(mock.from).toHaveBeenCalledWith(STAGING_BUCKET);
    expect(mock.from).toHaveBeenCalledWith(PUBLIC_BUCKET);
    expect(mock.remove).toHaveBeenCalledWith(['owner/media/original.jpg']);
    expect(mock.remove).toHaveBeenCalledWith(['rescue/media/public.jpg']);
  });

  it('fails closed when a staging object is missing', async () => {
    const mock = buildClient({ bucketsExist: true });
    mock.download.mockResolvedValueOnce({
      data: null,
      error: { message: 'missing object' },
    });
    const storage = buildStorage(mock.client);

    await expect(
      storage.readStagingObject('missing.jpg'),
    ).rejects.toMatchObject({
      name: 'RescueMediaStorageError',
      failure: 'object_missing',
    } satisfies Partial<RescueMediaStorageError>);
  });

  it('surfaces public rollback failures instead of claiming cleanup', async () => {
    const mock = buildClient({ bucketsExist: true });
    mock.remove.mockResolvedValueOnce({
      data: null,
      error: { message: 'storage unavailable' },
    });
    const storage = buildStorage(mock.client);

    await expect(
      storage.deletePublicObject('rescue/media/public.jpg'),
    ).rejects.toMatchObject({
      name: 'RescueMediaStorageError',
      failure: 'operation_failed',
    } satisfies Partial<RescueMediaStorageError>);
  });
});

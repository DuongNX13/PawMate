import { type SupabaseClient } from '@supabase/supabase-js';

import { type AppConfig } from '../config/env';
import { RESCUE_BUCKET_MAX_BYTES } from '../features/rescue/rescue-media-policy';
import { createSupabaseAdminClient } from './supabase-admin-client';
import { type RescueMediaMimeType } from './rescue-media-sanitizer';

const ALLOWED_MIME_TYPES: RescueMediaMimeType[] = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
];

export type RescueMediaStorageFailure =
  | 'unavailable'
  | 'object_missing'
  | 'operation_failed';

export class RescueMediaStorageError extends Error {
  constructor(
    readonly failure: RescueMediaStorageFailure,
    message: string,
  ) {
    super(message);
    this.name = 'RescueMediaStorageError';
  }
}

export type RescueMediaUploadTicket = {
  uploadUrl: string;
  uploadHeaders: Record<string, string>;
};

export interface RescueMediaStorage {
  ensureReady(): Promise<void>;
  createUploadTicket(
    storageKey: string,
    mimeType: RescueMediaMimeType,
  ): Promise<RescueMediaUploadTicket>;
  readStagingObject(storageKey: string): Promise<Buffer>;
  writePublicObject(
    storageKey: string,
    bytes: Buffer,
    mimeType: RescueMediaMimeType,
  ): Promise<string>;
  deletePublicObject(storageKey: string): Promise<void>;
  deleteStagingObject(storageKey: string): Promise<void>;
  writePrivateObject(
    storageKey: string,
    bytes: Buffer,
    mimeType: RescueMediaMimeType,
  ): Promise<void>;
  readPrivateObject(storageKey: string): Promise<Buffer>;
  deletePrivateObject(storageKey: string): Promise<void>;
}

type BucketOptions = {
  public: boolean;
  fileSizeLimit: number;
  allowedMimeTypes: string[];
};

export type RescueMediaBucketSetupMode = 'bootstrap' | 'verify_existing';

const storageFailure = (operation: string, message: string) =>
  new RescueMediaStorageError(
    'operation_failed',
    `Rescue media storage ${operation} failed: ${message}`,
  );

const verifyExistingBucket = (
  current: Awaited<ReturnType<SupabaseClient['storage']['getBucket']>>,
  bucket: string,
  options: BucketOptions,
) => {
  if (current.error || !current.data) {
    throw new RescueMediaStorageError(
      'unavailable',
      `Required rescue media bucket ${bucket} is unavailable.`,
    );
  }
  const mimeTypes = current.data.allowed_mime_types;
  const expectedMimeTypes = options.allowedMimeTypes.slice().sort();
  const mimeTypesMatch =
    Array.isArray(mimeTypes) &&
    mimeTypes.length === expectedMimeTypes.length &&
    mimeTypes
      .slice()
      .sort()
      .every((type, index) => type === expectedMimeTypes[index]);
  if (
    current.data.name !== bucket ||
    current.data.public !== options.public ||
    current.data.file_size_limit !== options.fileSizeLimit ||
    !mimeTypesMatch
  ) {
    throw new RescueMediaStorageError(
      'unavailable',
      `Required rescue media bucket ${bucket} has unexpected configuration.`,
    );
  }
};

const ensureBucket = async (
  client: SupabaseClient,
  bucket: string,
  options: BucketOptions,
  mode: RescueMediaBucketSetupMode,
) => {
  const current = await client.storage.getBucket(bucket);
  if (mode === 'verify_existing') {
    verifyExistingBucket(current, bucket, options);
    return;
  }
  if (current.error) {
    const created = await client.storage.createBucket(bucket, options);
    if (created.error) {
      throw storageFailure('bucket bootstrap', created.error.message);
    }
    return;
  }

  const updated = await client.storage.updateBucket(bucket, options);
  if (updated.error) {
    throw storageFailure('bucket policy update', updated.error.message);
  }
};

export const createSupabaseRescueMediaStorage = (
  config: AppConfig,
  suppliedClient?: SupabaseClient,
  options: { bucketSetupMode?: RescueMediaBucketSetupMode } = {},
): RescueMediaStorage | undefined => {
  const client = suppliedClient ?? createSupabaseAdminClient(config);
  if (!client) return undefined;

  const stagingBucket =
    config.supabaseBuckets.rescueMediaStaging ?? 'rescue-media-staging';
  const publicBucket =
    config.supabaseBuckets.rescueMediaPublic ?? 'rescue-media-public';
  const chatPrivateBucket =
    config.supabaseBuckets.adoptionChatMediaPrivate ??
    'adoption-chat-media-private';
  const existingBuckets = [
    stagingBucket,
    publicBucket,
    config.supabaseBuckets.avatars,
    config.supabaseBuckets.petPhotos,
    config.supabaseBuckets.posts,
    config.supabaseBuckets.reviewPhotos,
  ];
  if (existingBuckets.includes(chatPrivateBucket)) {
    throw new RescueMediaStorageError(
      'unavailable',
      'Private chat media bucket must not share another media purpose bucket.',
    );
  }
  let ready: Promise<void> | undefined;
  const bucketSetupMode = options.bucketSetupMode ?? 'bootstrap';

  const ensureReady = () => {
    ready ??= Promise.all([
      ensureBucket(
        client,
        stagingBucket,
        {
          public: false,
          fileSizeLimit: RESCUE_BUCKET_MAX_BYTES,
          allowedMimeTypes: ALLOWED_MIME_TYPES,
        },
        bucketSetupMode,
      ),
      ensureBucket(
        client,
        publicBucket,
        {
          public: true,
          fileSizeLimit: RESCUE_BUCKET_MAX_BYTES,
          allowedMimeTypes: ALLOWED_MIME_TYPES,
        },
        bucketSetupMode,
      ),
      ensureBucket(
        client,
        chatPrivateBucket,
        {
          public: false,
          fileSizeLimit: RESCUE_BUCKET_MAX_BYTES,
          allowedMimeTypes: ALLOWED_MIME_TYPES,
        },
        bucketSetupMode,
      ),
    ]).then(() => undefined);
    return ready;
  };

  return {
    ensureReady,

    async createUploadTicket(storageKey, mimeType) {
      await ensureReady();
      const result = await client.storage
        .from(stagingBucket)
        .createSignedUploadUrl(storageKey, { upsert: false });
      if (result.error || !result.data?.signedUrl) {
        throw storageFailure(
          'signed upload',
          result.error?.message ?? 'No signed URL was returned.',
        );
      }
      return {
        uploadUrl: result.data.signedUrl,
        uploadHeaders: { 'content-type': mimeType },
      };
    },

    async readStagingObject(storageKey) {
      await ensureReady();
      const result = await client.storage
        .from(stagingBucket)
        .download(storageKey);
      if (result.error || !result.data) {
        throw new RescueMediaStorageError(
          'object_missing',
          result.error?.message ?? 'Uploaded object was not found.',
        );
      }
      return Buffer.from(await result.data.arrayBuffer());
    },

    async writePublicObject(storageKey, bytes, mimeType) {
      await ensureReady();
      const result = await client.storage
        .from(publicBucket)
        .upload(storageKey, bytes, {
          contentType: mimeType,
          cacheControl: '31536000',
          upsert: true,
        });
      if (result.error) {
        throw storageFailure('sanitized upload', result.error.message);
      }
      return client.storage.from(publicBucket).getPublicUrl(storageKey).data
        .publicUrl;
    },

    async deleteStagingObject(storageKey) {
      await ensureReady();
      const result = await client.storage
        .from(stagingBucket)
        .remove([storageKey]);
      if (result.error) {
        throw storageFailure('staging cleanup', result.error.message);
      }
    },

    async deletePublicObject(storageKey) {
      await ensureReady();
      const result = await client.storage
        .from(publicBucket)
        .remove([storageKey]);
      if (result.error) {
        throw storageFailure('public rollback', result.error.message);
      }
    },

    async writePrivateObject(storageKey, bytes, mimeType) {
      await ensureReady();
      const result = await client.storage
        .from(chatPrivateBucket)
        .upload(storageKey, bytes, {
          contentType: mimeType,
          cacheControl: '0',
          upsert: false,
        });
      if (result.error)
        throw storageFailure('private upload', result.error.message);
    },

    async readPrivateObject(storageKey) {
      await ensureReady();
      const result = await client.storage
        .from(chatPrivateBucket)
        .download(storageKey);
      if (result.error || !result.data) {
        throw new RescueMediaStorageError(
          !result.error || result.error.status === 404
            || (result.error.status === 400 && result.error.statusCode === '404')
            ? 'object_missing'
            : 'operation_failed',
          result.error?.message ?? 'Private object was not found.',
        );
      }
      return Buffer.from(await result.data.arrayBuffer());
    },

    async deletePrivateObject(storageKey) {
      await ensureReady();
      const result = await client.storage
        .from(chatPrivateBucket)
        .remove([storageKey]);
      if (result.error)
        throw storageFailure('private rollback', result.error.message);
    },
  };
};

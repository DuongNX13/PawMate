import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { type SupabaseClient } from '@supabase/supabase-js';

import { type AppConfig } from '../config/env';
import { AppError } from '../errors/app-error';
import { REVIEW_ERROR_CODES } from '../errors/error-codes';
import { createSupabaseAdminClient } from './supabase-admin-client';

export type UploadReviewPhotoInput = {
  fileName: string;
  contentType?: string;
  base64Data?: string;
};

export type UploadReviewPhotoResult = {
  url: string;
  path: string;
  contentType: string;
  sizeBytes: number;
  storage: 'supabase' | 'local';
};

export const reviewPhotoStorageRoot = path.resolve(
  process.cwd(),
  'storage',
  'review-photos',
);

const safeSegmentPattern = /[^a-zA-Z0-9._-]/g;

export const allowedReviewPhotoContentTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

const extensionByContentType: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

const contentTypeByExtension: Record<string, string> = {
  '.jpeg': 'image/jpeg',
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

const normalizeStorageSegment = (value: string) => {
  const safeValue = value.trim().replace(safeSegmentPattern, '-');
  return safeValue || 'unknown';
};

const normalizeReviewPhotoFileName = (
  fileName: string,
  contentType?: string,
) => {
  const trimmed = fileName.trim();
  const extension = path.extname(trimmed).toLowerCase();
  const baseName = path
    .basename(trimmed, extension)
    .replace(safeSegmentPattern, '-');
  const safeBaseName = baseName || 'review-photo';
  const resolvedExtension =
    extension || (contentType ? extensionByContentType[contentType] : '');

  return `${safeBaseName}${resolvedExtension}`;
};

const resolvePublicBaseUrl = (config: AppConfig) => {
  const host =
    config.host === '0.0.0.0' || config.host === '127.0.0.1'
      ? 'localhost'
      : config.host;

  return `http://${host}:${config.port}`;
};

const decodeBase64Image = (base64Data?: string) => {
  const normalized = base64Data?.replace(/^data:[^;]+;base64,/, '').trim();
  if (!normalized) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Noi dung anh review khong hop le.',
      400,
      'base64Data',
    );
  }

  return Buffer.from(normalized, 'base64');
};

const validateReviewPhotoInput = (input: UploadReviewPhotoInput) => {
  const fileName = input.fileName?.trim();
  const contentType = input.contentType?.trim().toLowerCase();

  if (!fileName) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Ten anh review khong hop le.',
      400,
      'fileName',
    );
  }

  if (!contentType || !allowedReviewPhotoContentTypes.has(contentType)) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Anh review chi ho tro JPEG, PNG, hoac WEBP.',
      400,
      'contentType',
    );
  }

  const content = decodeBase64Image(input.base64Data);
  if (content.byteLength > 5 * 1024 * 1024) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Kich thuoc anh review vuot qua 5MB.',
      400,
      'base64Data',
    );
  }

  return {
    content,
    contentType,
    fileName: normalizeReviewPhotoFileName(fileName, contentType),
  };
};

const buildObjectPath = (vetId: string, userId: string, fileName: string) =>
  [
    normalizeStorageSegment(vetId),
    normalizeStorageSegment(userId),
    `${Date.now()}-${randomUUID()}-${fileName}`,
  ].join('/');

const buildLocalReviewPhotoPath = (
  vetId: string,
  userId: string,
  fileName: string,
) =>
  path.join(
    reviewPhotoStorageRoot,
    normalizeStorageSegment(vetId),
    normalizeStorageSegment(userId),
    normalizeReviewPhotoFileName(fileName),
  );

const buildLocalReviewPhotoUrl = (
  config: AppConfig,
  vetId: string,
  userId: string,
  fileName: string,
) =>
  `${resolvePublicBaseUrl(config)}/assets/review-photos/${encodeURIComponent(
    normalizeStorageSegment(vetId),
  )}/${encodeURIComponent(normalizeStorageSegment(userId))}/${encodeURIComponent(
    normalizeReviewPhotoFileName(fileName),
  )}`;

const uploadToSupabase = async (
  client: SupabaseClient | undefined,
  bucketName: string,
  objectPath: string,
  content: Buffer,
  contentType: string,
) => {
  if (!client) {
    return undefined;
  }

  const { error } = await client.storage
    .from(bucketName)
    .upload(objectPath, content, {
      contentType,
      upsert: false,
    });

  if (error) {
    throw new AppError(
      REVIEW_ERROR_CODES.photoUploadFailed,
      `Khong upload duoc anh review: ${error.message}`,
      502,
      'photo',
    );
  }

  return client.storage.from(bucketName).getPublicUrl(objectPath).data
    .publicUrl;
};

export const uploadReviewPhoto = async (
  config: AppConfig,
  vetId: string,
  userId: string,
  input: UploadReviewPhotoInput,
): Promise<UploadReviewPhotoResult> => {
  const photo = validateReviewPhotoInput(input);
  const bucketName = config.supabaseBuckets.reviewPhotos ?? 'review-photos';
  const objectPath = buildObjectPath(vetId, userId, photo.fileName);
  const supabaseClient = createSupabaseAdminClient(config);
  const supabaseUrl = await uploadToSupabase(
    supabaseClient,
    bucketName,
    objectPath,
    photo.content,
    photo.contentType,
  );

  if (supabaseUrl) {
    return {
      url: supabaseUrl,
      path: objectPath,
      contentType: photo.contentType,
      sizeBytes: photo.content.byteLength,
      storage: 'supabase',
    };
  }

  const localFileName = path.basename(objectPath);
  const targetPath = buildLocalReviewPhotoPath(vetId, userId, localFileName);
  await mkdir(path.dirname(targetPath), { recursive: true });
  await writeFile(targetPath, photo.content);

  return {
    url: buildLocalReviewPhotoUrl(config, vetId, userId, localFileName),
    path: [
      normalizeStorageSegment(vetId),
      normalizeStorageSegment(userId),
      normalizeReviewPhotoFileName(localFileName),
    ].join('/'),
    contentType: photo.contentType,
    sizeBytes: photo.content.byteLength,
    storage: 'local',
  };
};

export const readLocalReviewPhoto = (
  vetId: string,
  userId: string,
  fileName: string,
) => readFile(buildLocalReviewPhotoPath(vetId, userId, fileName));

export const resolveReviewPhotoContentType = (fileName: string) =>
  contentTypeByExtension[path.extname(fileName).toLowerCase()] ??
  'application/octet-stream';

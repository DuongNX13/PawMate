import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { type AppConfig } from '../config/env';

const safeFileNamePattern = /[^a-zA-Z0-9._-]/g;

export const petPhotoStorageRoot = path.resolve(
  process.cwd(),
  'storage',
  'pet-photos',
);

export const allowedPetPhotoContentTypes = new Set([
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

export const normalizePetPhotoFileName = (
  fileName: string,
  contentType?: string,
) => {
  const trimmed = fileName.trim();
  const extension = path.extname(trimmed).toLowerCase();
  const baseName = path.basename(trimmed, extension).replace(safeFileNamePattern, '-');
  const safeBaseName = baseName || 'pet-photo';
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

export const buildLocalPetPhotoPath = (petId: string, fileName: string) =>
  path.join(petPhotoStorageRoot, petId, fileName);

export const buildLocalPetPhotoUrl = (
  config: AppConfig,
  petId: string,
  fileName: string,
) =>
  `${resolvePublicBaseUrl(config)}/assets/pet-photos/${petId}/${encodeURIComponent(fileName)}`;

export const saveLocalPetPhoto = async (
  petId: string,
  fileName: string,
  content: Buffer,
) => {
  const targetPath = buildLocalPetPhotoPath(petId, fileName);
  await mkdir(path.dirname(targetPath), { recursive: true });
  await writeFile(targetPath, content);
  return targetPath;
};

export const readLocalPetPhoto = (petId: string, fileName: string) =>
  readFile(buildLocalPetPhotoPath(petId, fileName));

export const resolvePetPhotoContentType = (fileName: string) =>
  contentTypeByExtension[path.extname(fileName).toLowerCase()] ??
  'application/octet-stream';

import { createHash, randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { loadEnv } from '../src/config/env';
import { sanitizeRescueMedia } from '../src/infrastructure/rescue-media-sanitizer';
import { createSupabaseAdminClient } from '../src/infrastructure/supabase-admin-client';
import { createSupabaseRescueMediaStorage } from '../src/infrastructure/rescue-media-storage';

const EXPECTED_PROJECT_REF = 'qeoowayxfqyhfcgnrfnv';

const jpegSegment = (marker: number, payload: Buffer) => {
  const segment = Buffer.alloc(4 + payload.length);
  segment[0] = 0xff;
  segment[1] = marker;
  segment.writeUInt16BE(payload.length + 2, 2);
  payload.copy(segment, 4);
  return segment;
};

const originalBytes = Buffer.concat([
  Buffer.from([0xff, 0xd8]),
  jpegSegment(0xe0, Buffer.from('JFIF-safe', 'ascii')),
  jpegSegment(0xe1, Buffer.from('Exif\0\0GPS=10.776,106.700', 'binary')),
  jpegSegment(0xda, Buffer.from([0x01, 0x01, 0x00, 0x00, 0x3f, 0x00])),
  Buffer.from([0x11, 0x22, 0xff, 0x00, 0x33]),
  Buffer.from([0xff, 0xd9]),
]);

const sha256 = (bytes: Buffer) =>
  createHash('sha256').update(bytes).digest('hex');

const main = async () => {
  const config = loadEnv();
  if (!config.supabaseUrl) throw new Error('SUPABASE_URL is required.');
  const projectRef = new URL(config.supabaseUrl).hostname.split('.')[0];
  if (projectRef !== EXPECTED_PROJECT_REF) {
    throw new Error(
      `Refusing cloud media proof for unexpected project ${projectRef}.`,
    );
  }

  const admin = createSupabaseAdminClient(config);
  const storage = createSupabaseRescueMediaStorage(config, admin);
  if (!admin || !storage) {
    throw new Error('Supabase service-role media storage is unavailable.');
  }

  const stagingBucket =
    config.supabaseBuckets.rescueMediaStaging ?? 'rescue-media-staging';
  const publicBucket =
    config.supabaseBuckets.rescueMediaPublic ?? 'rescue-media-public';
  const proofId = randomUUID();
  const stagingKey = `day36-proof/${proofId}/original.jpg`;
  const publicKey = `day36-proof/${proofId}/sanitized.jpg`;
  let stagingCreated = false;
  let publicCreated = false;
  let stagingDeleted = false;
  let publicDeleted = false;

  try {
    await storage.ensureReady();
    const [stagingDefinition, publicDefinition] = await Promise.all([
      admin.storage.getBucket(stagingBucket),
      admin.storage.getBucket(publicBucket),
    ]);
    if (stagingDefinition.error || publicDefinition.error) {
      throw new Error('Unable to read Rescue media bucket definitions.');
    }
    if (stagingDefinition.data.public || !publicDefinition.data.public) {
      throw new Error(
        'Rescue media bucket visibility does not match contract.',
      );
    }

    const staged = await admin.storage
      .from(stagingBucket)
      .upload(stagingKey, originalBytes, {
        contentType: 'image/jpeg',
        upsert: true,
      });
    if (staged.error)
      throw new Error(`Staging upload failed: ${staged.error.message}`);
    stagingCreated = true;

    const downloaded = await storage.readStagingObject(stagingKey);
    const sanitized = sanitizeRescueMedia({
      bytes: downloaded,
      declaredMimeType: 'image/jpeg',
    });
    if (
      !sanitized.metadataRemoved ||
      sanitized.bytes.includes(Buffer.from('GPS='))
    ) {
      throw new Error('Location metadata was not removed from the derivative.');
    }

    const publicUrl = await storage.writePublicObject(
      publicKey,
      sanitized.bytes,
      sanitized.detectedMimeType,
    );
    publicCreated = true;
    const publicResponse = await fetch(publicUrl, { cache: 'no-store' });
    if (!publicResponse.ok) {
      throw new Error(
        `Public derivative read failed with ${publicResponse.status}.`,
      );
    }
    const publicBytes = Buffer.from(await publicResponse.arrayBuffer());
    if (sha256(publicBytes) !== sha256(sanitized.bytes)) {
      throw new Error('Public derivative hash does not match sanitized bytes.');
    }

    await storage.deleteStagingObject(stagingKey);
    stagingDeleted = true;
    await storage.deletePublicObject(publicKey);
    publicDeleted = true;

    const proof = {
      day: 36,
      projectRef,
      checkedAt: new Date().toISOString(),
      buckets: {
        staging: {
          name: stagingBucket,
          public: stagingDefinition.data.public,
          fileSizeLimit: stagingDefinition.data.file_size_limit,
          allowedMimeTypes: stagingDefinition.data.allowed_mime_types,
        },
        sanitized: {
          name: publicBucket,
          public: publicDefinition.data.public,
          fileSizeLimit: publicDefinition.data.file_size_limit,
          allowedMimeTypes: publicDefinition.data.allowed_mime_types,
        },
      },
      media: {
        declaredMimeType: 'image/jpeg',
        detectedMimeType: sanitized.detectedMimeType,
        originalSizeBytes: originalBytes.length,
        sanitizedSizeBytes: sanitized.bytes.length,
        originalSha256: sha256(originalBytes),
        sanitizedSha256: sha256(sanitized.bytes),
        metadataRemoved: sanitized.metadataRemoved,
        removedMetadata: sanitized.removedMetadata,
        publicReadStatus: publicResponse.status,
        publicHashMatched: true,
      },
      cleanup: {
        stagingDeleted,
        publicDeleted,
      },
      result: 'PASS',
    };
    const outputPath = path.resolve(
      process.cwd(),
      '../output-evidence/day36/day36-cloud-media-storage-proof-20260721.json',
    );
    await mkdir(path.dirname(outputPath), { recursive: true });
    await writeFile(outputPath, `${JSON.stringify(proof, null, 2)}\n`, 'utf8');
    console.log(
      JSON.stringify({
        result: proof.result,
        projectRef: proof.projectRef,
        metadataRemoved: proof.media.metadataRemoved,
        publicHashMatched: proof.media.publicHashMatched,
        cleanup: proof.cleanup,
        outputPath,
      }),
    );
  } finally {
    if (stagingCreated && !stagingDeleted) {
      await storage.deleteStagingObject(stagingKey).catch(() => undefined);
    }
    if (publicCreated && !publicDeleted) {
      await storage.deletePublicObject(publicKey).catch(() => undefined);
    }
  }
};

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});

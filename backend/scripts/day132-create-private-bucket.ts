import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const PROJECT_REF = 'qeoowayxfqyhfcgnrfnv';
const BUCKET = 'adoption-chat-media-private';
const FILE_SIZE_LIMIT = 50 * 1024 * 1024;
const MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'];

const manifestPath = process.argv[2];
if (!manifestPath || process.argv.length !== 3) {
  throw new Error('DAY132_AUTHORIZATION_MANIFEST_REQUIRED');
}
const manifest = JSON.parse(readFileSync(resolve(manifestPath), 'utf8')) as {
  target?: { projectRef?: string; supabaseUrl?: string };
  authorization?: { bucketCreationApprovalRef?: string };
  scope?: {
    day?: string;
    createPrivateBucketOnly?: string;
    existingBucketMutation?: boolean;
    policyMutation?: boolean;
  };
  privateBucket?: {
    name?: string;
    public?: boolean;
    fileSizeLimit?: number;
    allowedMimeTypes?: string[];
  };
};
const sameMimes = (actual: string[] | null | undefined) =>
  JSON.stringify([...(actual ?? [])].sort()) === JSON.stringify([...MIME_TYPES].sort());
if (
  manifest.target?.projectRef !== PROJECT_REF ||
  manifest.target.supabaseUrl !== `https://${PROJECT_REF}.supabase.co/` ||
  !manifest.authorization?.bucketCreationApprovalRef ||
  manifest.scope?.day !== 'D132' ||
  manifest.scope.createPrivateBucketOnly !== BUCKET ||
  manifest.scope.existingBucketMutation !== false ||
  manifest.scope.policyMutation !== false ||
  manifest.privateBucket?.name !== BUCKET ||
  manifest.privateBucket.public !== false ||
  manifest.privateBucket.fileSizeLimit !== FILE_SIZE_LIMIT ||
  !sameMimes(manifest.privateBucket.allowedMimeTypes)
) {
  throw new Error('DAY132_AUTHORIZATION_MANIFEST_MISMATCH');
}

const envPath = [
  resolve(process.cwd(), '.env.local'),
  resolve(process.cwd(), 'backend', '.env.local'),
].find(existsSync);
if (!envPath) throw new Error('DAY132_ENV_NOT_FOUND');
dotenv.config({ path: envPath, override: false, quiet: true });
const fileEnv = dotenv.parse(readFileSync(envPath));
const first = (...values: Array<string | undefined>) =>
  values.find((value) => value && value.trim())?.trim();
const supabaseUrl = first(process.env.SUPABASE_URL, fileEnv.SUPABASE_URL);
const serviceKey = first(
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  process.env.SUPABASE_SECRET_KEY,
  fileEnv.SUPABASE_SERVICE_ROLE_KEY,
  fileEnv.SUPABASE_SECRET_KEY,
);
if (!supabaseUrl || !serviceKey) throw new Error('DAY132_CONFIG_MISSING');
if (new URL(supabaseUrl).href !== `https://${PROJECT_REF}.supabase.co/`) {
  throw new Error('DAY132_EFFECTIVE_TARGET_MISMATCH');
}

const client = createClient(supabaseUrl, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function main() {
  const before = await client.storage.getBucket(BUCKET);
  if (before.data) throw new Error('DAY132_BUCKET_ALREADY_EXISTS_STOP');
  if (
    !before.error ||
    before.error.name !== 'StorageApiError' ||
    !/bucket not found/i.test(before.error.message)
  ) {
    throw new Error('DAY132_BUCKET_READ_NOT_FOUND_NOT_CONFIRMED');
  }
  const created = await client.storage.createBucket(BUCKET, {
    public: false,
    fileSizeLimit: FILE_SIZE_LIMIT,
    allowedMimeTypes: MIME_TYPES,
  });
  if (created.error) throw new Error(`DAY132_CREATE_BUCKET_FAILED_${created.error.status ?? 'UNKNOWN'}`);
  const readback = await client.storage.getBucket(BUCKET);
  if (
    readback.error || !readback.data ||
    readback.data.name !== BUCKET ||
    readback.data.public !== false ||
    readback.data.file_size_limit !== FILE_SIZE_LIMIT ||
    !sameMimes(readback.data.allowed_mime_types)
  ) {
    throw new Error('DAY132_BUCKET_CREATED_BUT_READBACK_MISMATCH');
  }
  process.stdout.write(`${JSON.stringify({
    verdict: 'DAY132_BUCKET_CREATED_AND_VERIFIED',
    projectRef: PROJECT_REF,
    bucket: BUCKET,
    public: readback.data.public,
    fileSizeLimit: readback.data.file_size_limit,
    allowedMimeTypes: [...(readback.data.allowed_mime_types ?? [])].sort(),
    existingBucketUpdated: false,
    policyMutation: false,
    objectMutation: false,
  })}\n`);
}

main().catch((error: unknown) => {
  const code = error instanceof Error ? error.message : 'DAY132_UNKNOWN_ERROR';
  process.stderr.write(`${code}\n`);
  process.exitCode = 1;
});

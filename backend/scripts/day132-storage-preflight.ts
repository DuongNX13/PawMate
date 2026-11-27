import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { RESCUE_BUCKET_MAX_BYTES } from '../src/features/rescue/rescue-media-policy';

const EXPECTED_PROJECT_REF = 'qeoowayxfqyhfcgnrfnv';
const EXPECTED_BUCKETS = [
  {
    name: 'rescue-media-staging',
    public: false,
  },
  {
    name: 'rescue-media-public',
    public: true,
  },
  {
    name: 'adoption-chat-media-private',
    public: false,
  },
] as const;
const EXPECTED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
];

const envPath = [
  resolve(process.cwd(), '.env.local'),
  resolve(process.cwd(), 'backend', '.env.local'),
  resolve(__dirname, '..', '.env.local'),
].find(existsSync);

if (!envPath) throw new Error('DAY132_ENV_NOT_FOUND');

dotenv.config({ path: envPath, override: false, quiet: true });
const fileEnv = dotenv.parse(readFileSync(envPath));
const first = (...values: Array<string | undefined>) =>
  values.find((value) => value && value.trim().length > 0)?.trim();
const supabaseUrl = first(process.env.SUPABASE_URL, fileEnv.SUPABASE_URL);
const serviceRoleKey = first(
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  process.env.SUPABASE_SECRET_KEY,
  fileEnv.SUPABASE_SERVICE_ROLE_KEY,
  fileEnv.SUPABASE_SECRET_KEY,
);

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error('DAY132_SUPABASE_ADMIN_CONFIG_MISSING');
}

const url = new URL(supabaseUrl);
const projectRef = url.hostname.split('.')[0];
if (
  url.protocol !== 'https:' ||
  projectRef !== EXPECTED_PROJECT_REF ||
  url.hostname !== `${EXPECTED_PROJECT_REF}.supabase.co`
) {
  throw new Error('DAY132_TARGET_MISMATCH');
}

const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const normalizeMimes = (values: string[] | null | undefined) =>
  [...(values ?? [])].sort();

const main = async () => {
  const checks = [] as Array<{
    name: string;
    exists: boolean;
    configurationMatches: boolean;
    errorName?: string;
    errorStatus?: number | string;
    notFoundReported?: boolean;
    public?: boolean;
    fileSizeLimit?: number | null;
    allowedMimeTypes?: string[];
  }>;

  for (const expected of EXPECTED_BUCKETS) {
    const result = await client.storage.getBucket(expected.name);
    if (result.error || !result.data) {
      checks.push({
        name: expected.name,
        exists: false,
        configurationMatches: false,
        ...(result.error ? {
          errorName: result.error.name,
          errorStatus: result.error.status,
          notFoundReported: /bucket not found/i.test(result.error.message),
        } : {}),
      });
      continue;
    }
    const actualMimes = normalizeMimes(result.data.allowed_mime_types);
    const expectedMimes = normalizeMimes(EXPECTED_MIME_TYPES);
    checks.push({
      name: expected.name,
      exists: true,
      configurationMatches:
        result.data.public === expected.public &&
        result.data.file_size_limit === RESCUE_BUCKET_MAX_BYTES &&
        actualMimes.length === expectedMimes.length &&
        actualMimes.every((value, index) => value === expectedMimes[index]),
      public: result.data.public,
      fileSizeLimit: result.data.file_size_limit,
      allowedMimeTypes: actualMimes,
    });
  }

  const ready = checks.every(
    (check) => check.exists && check.configurationMatches,
  );
  process.stdout.write(
    `${JSON.stringify(
      {
        verdict: ready
          ? 'DAY132_STORAGE_PREFLIGHT_PASS_READ_ONLY'
          : 'DAY132_STORAGE_PREFLIGHT_BLOCKED',
        projectRef,
        readOnly: true,
        secretPrinted: false,
        checks,
      },
      null,
      2,
    )}\n`,
  );
  if (!ready) process.exitCode = 2;
};

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`DAY132_STORAGE_PREFLIGHT_FAILED: ${message}\n`);
  process.exitCode = 1;
});

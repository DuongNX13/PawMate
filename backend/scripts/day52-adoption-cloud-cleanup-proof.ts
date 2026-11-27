/* eslint-disable no-console */
import dotenv from 'dotenv';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const envPath = [
  resolve(process.cwd(), '.env.local'),
  resolve(process.cwd(), 'backend', '.env.local'),
  resolve(__dirname, '..', '.env.local'),
].find(existsSync);

if (!envPath) {
  throw new Error('PawMate backend .env.local was not found.');
}

dotenv.config({
  path: envPath,
  override: true,
  quiet: true,
});

const fileEnv = dotenv.parse(readFileSync(envPath));
const firstNonEmpty = (...values: Array<string | undefined>) =>
  values.find((value) => value && value.trim().length > 0);
const SUPABASE_URL = firstNonEmpty(
  process.env.SUPABASE_URL,
  fileEnv.SUPABASE_URL,
);
const SERVICE_KEY = firstNonEmpty(
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  process.env.SUPABASE_SECRET_KEY,
  fileEnv.SUPABASE_SERVICE_ROLE_KEY,
  fileEnv.SUPABASE_SECRET_KEY,
);

if (!SUPABASE_URL || !SERVICE_KEY) {
  throw new Error(
    `Supabase cleanup proof configuration is missing (${JSON.stringify({
      envPath,
      supabaseUrl: Boolean(SUPABASE_URL),
      serviceKey: Boolean(SERVICE_KEY),
    })}).`,
  );
}

const proofRows = [
  [
    'adoption_chat_messages',
    'thread_id=in.(51000000-0000-4000-8000-000000000009,52000000-0000-4000-8000-000000000008)',
  ],
  [
    'adoption_chat_participants',
    'thread_id=in.(51000000-0000-4000-8000-000000000009,52000000-0000-4000-8000-000000000008)',
  ],
  [
    'adoption_chat_threads',
    'id=in.(51000000-0000-4000-8000-000000000009,52000000-0000-4000-8000-000000000008,52000000-0000-4000-8000-000000000009)',
  ],
  [
    'adoption_requests',
    'listing_id=in.(51000000-0000-4000-8000-000000000007,52000000-0000-4000-8000-000000000004)',
  ],
  ['adoption_decisions', 'listing_id=eq.52000000-0000-4000-8000-000000000004'],
  [
    'adoption_listings',
    'id=in.(51000000-0000-4000-8000-000000000007,52000000-0000-4000-8000-000000000004)',
  ],
  [
    'media_assets',
    'id=in.(51000000-0000-4000-8000-000000000004,51000000-0000-4000-8000-000000000005,51000000-0000-4000-8000-000000000006,52000000-0000-4000-8000-000000000003)',
  ],
  [
    'users',
    'id=in.(51000000-0000-4000-8000-000000000001,51000000-0000-4000-8000-000000000002,51000000-0000-4000-8000-000000000003,52000000-0000-4000-8000-000000000001,52000000-0000-4000-8000-000000000002)',
  ],
] as const;

const main = async () => {
  const entries = await Promise.all(
    proofRows.map(async ([table, filter]) => {
      const select =
        table === 'adoption_chat_participants' ? 'thread_id' : 'id';
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/${table}?select=${select}&${filter}`,
        {
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
          },
        },
      );
      const body = (await response.json()) as unknown;
      if (!response.ok || !Array.isArray(body)) {
        throw new Error(
          `Cleanup read for ${table} failed with HTTP ${response.status}.`,
        );
      }
      return [table, body.length] as const;
    }),
  );
  const counts = Object.fromEntries(entries) as Record<string, number>;

  const remaining = Object.values(counts).reduce(
    (total, count) => total + count,
    0,
  );
  if (remaining !== 0) {
    throw new Error(
      `DAY52_ADOPTION_CLOUD_CLEANUP_PROOF_FAIL: ${JSON.stringify(counts)}`,
    );
  }

  console.log(
    JSON.stringify(
      {
        verdict: 'DAY52_ADOPTION_CLOUD_CLEANUP_PROOF_PASS',
        testDataOnly: true,
        remaining,
        counts,
      },
      null,
      2,
    ),
  );
};

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exitCode = 1;
});

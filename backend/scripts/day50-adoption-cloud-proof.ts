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
const ANON_KEY = firstNonEmpty(
  process.env.SUPABASE_ANON_KEY,
  process.env.SUPABASE_PUBLISHABLE_KEY,
  fileEnv.SUPABASE_ANON_KEY,
  fileEnv.SUPABASE_PUBLISHABLE_KEY,
);

if (!SUPABASE_URL || !SERVICE_KEY || !ANON_KEY) {
  throw new Error(
    `Supabase proof configuration is missing (${JSON.stringify({
      envPath,
      supabaseUrl: Boolean(SUPABASE_URL),
      serviceKey: Boolean(SERVICE_KEY),
      anonKey: Boolean(ANON_KEY),
    })}).`,
  );
}

const SHELTER_ID = '52000000-0000-4000-8000-000000000001';
const ADOPTER_ID = '52000000-0000-4000-8000-000000000002';
const MEDIA_ID = '52000000-0000-4000-8000-000000000003';
const LISTING_ID = '52000000-0000-4000-8000-000000000004';
const REQUEST_ID = '52000000-0000-4000-8000-000000000005';
const DUPLICATE_REQUEST_ID = '52000000-0000-4000-8000-000000000006';
const SELF_REQUEST_ID = '52000000-0000-4000-8000-000000000007';
const THREAD_ID = '52000000-0000-4000-8000-000000000008';
const INVALID_THREAD_ID = '52000000-0000-4000-8000-000000000009';
const PROOF_TIME = '2026-07-27T08:00:00.000Z';

type RestResult = {
  status: number;
  body: unknown;
};

const callRest = async (
  path: string,
  init: RequestInit,
  key = SERVICE_KEY,
): Promise<RestResult> => {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
      ...init.headers,
    },
  });
  let body: unknown;
  const text = await response.text();
  try {
    body = text ? JSON.parse(text) : undefined;
  } catch {
    body = text;
  }
  return { status: response.status, body };
};

const expectStatus = (
  label: string,
  result: RestResult,
  expected: number | readonly number[],
) => {
  const allowed = Array.isArray(expected) ? expected : [expected];
  if (!allowed.includes(result.status)) {
    const detail =
      result.body && typeof result.body === 'object'
        ? JSON.stringify(result.body)
        : String(result.body ?? '');
    throw new Error(
      `${label} expected HTTP ${allowed.join('/')} but got ${result.status}: ${detail.slice(0, 500)}`,
    );
  }
};

const create = async (table: string, row: Record<string, unknown>) =>
  callRest(table, {
    method: 'POST',
    headers: {
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify(row),
  });

const cleanup = async () => {
  const paths = [
    `adoption_chat_threads?request_id=eq.${REQUEST_ID}`,
    `adoption_requests?listing_id=eq.${LISTING_ID}`,
    `adoption_decisions?listing_id=eq.${LISTING_ID}`,
    `adoption_listings?id=eq.${LISTING_ID}`,
    `media_assets?id=eq.${MEDIA_ID}`,
    `users?id=eq.${ADOPTER_ID}`,
    `users?id=eq.${SHELTER_ID}`,
  ];
  await paths.reduce(async (previous, path) => {
    await previous;
    const result = await callRest(path, {
      method: 'DELETE',
      headers: { Prefer: 'return=minimal' },
    });
    expectStatus(`cleanup ${path}`, result, [200, 204]);
  }, Promise.resolve());
};

const main = async () => {
  await cleanup();
  const statuses: Record<string, number> = {};
  try {
    const shelter = await create('users?on_conflict=id', {
      id: SHELTER_ID,
      email: 'day50-cloud-shelter@pawmate.local',
      display_name: 'Day 50 Cloud Shelter',
      email_verified: true,
      created_at: PROOF_TIME,
      updated_at: PROOF_TIME,
    });
    expectStatus('create shelter', shelter, 201);
    statuses.createShelter = shelter.status;

    const adopter = await create('users?on_conflict=id', {
      id: ADOPTER_ID,
      email: 'day50-cloud-adopter@pawmate.local',
      display_name: 'Day 50 Cloud Adopter',
      email_verified: true,
      created_at: PROOF_TIME,
      updated_at: PROOF_TIME,
    });
    expectStatus('create adopter', adopter, 201);
    statuses.createAdopter = adopter.status;

    const media = await create('media_assets?on_conflict=id', {
      id: MEDIA_ID,
      owner_user_id: SHELTER_ID,
      purpose: 'adoption_listing',
      mime_type: 'image/webp',
      size_bytes: 4096,
      sha256: '5'.repeat(64),
      status: 'verified',
      storage_key: 'day50/cloud-proof/golden.webp',
      public_url: 'https://example.invalid/day50/cloud-proof/golden.webp',
      width: 1200,
      height: 900,
      verification_version: 1,
      verified_at: PROOF_TIME,
      created_at: PROOF_TIME,
      updated_at: PROOF_TIME,
    });
    expectStatus('create media', media, 201);
    statuses.createMedia = media.status;

    const listing = await create('adoption_listings?on_conflict=id', {
      id: LISTING_ID,
      shelter_id: SHELTER_ID,
      hero_media_id: MEDIA_ID,
      pet_name: 'Golden Cloud Proof',
      species: 'dog',
      breed: 'Golden Retriever',
      age_label: '2 thang tuoi',
      traits: ['hien lanh'],
      health_badges: ['da tiem phong'],
      verification_badges: ['mai am da xac minh'],
      latitude: 10.776889,
      longitude: 106.700806,
      status: 'available',
    });
    expectStatus('create listing', listing, 201);
    statuses.createListing = listing.status;

    const anonymousRead = await callRest(
      `adoption_listings?id=eq.${LISTING_ID}&select=id`,
      { method: 'GET' },
      ANON_KEY,
    );
    expectStatus('anonymous RLS read', anonymousRead, 200);
    if (!Array.isArray(anonymousRead.body) || anonymousRead.body.length !== 0) {
      throw new Error('RLS proof failed: anon key can read Adoption rows.');
    }
    statuses.anonRlsRead = anonymousRead.status;

    const serviceRead = await callRest(
      `adoption_listings?id=eq.${LISTING_ID}&select=id`,
      { method: 'GET' },
    );
    expectStatus('service listing read', serviceRead, 200);
    if (!Array.isArray(serviceRead.body) || serviceRead.body.length !== 1) {
      throw new Error('Service-role proof failed: listing is not persisted.');
    }
    statuses.serviceListingRead = serviceRead.status;

    const request = await create('adoption_requests', {
      id: REQUEST_ID,
      listing_id: LISTING_ID,
      adopter_user_id: ADOPTER_ID,
      shelter_id: SHELTER_ID,
      living_condition: 'Can ho rong rai',
      pet_experience: 'Da cham soc cho',
      care_plan: 'Kham dinh ky',
      commitment_accepted: true,
      status: 'submitted',
    });
    expectStatus('create request', request, 201);
    statuses.createRequest = request.status;

    const duplicate = await create('adoption_requests', {
      id: DUPLICATE_REQUEST_ID,
      listing_id: LISTING_ID,
      adopter_user_id: ADOPTER_ID,
      shelter_id: SHELTER_ID,
      living_condition: 'Nha rieng',
      pet_experience: 'Da cham soc meo',
      care_plan: 'Kham dinh ky',
      commitment_accepted: true,
      status: 'reviewing',
    });
    expectStatus('duplicate active request guard', duplicate, 409);
    statuses.duplicateGuard = duplicate.status;

    const selfRequest = await create('adoption_requests', {
      id: SELF_REQUEST_ID,
      listing_id: LISTING_ID,
      adopter_user_id: SHELTER_ID,
      shelter_id: SHELTER_ID,
      living_condition: 'Mai am',
      pet_experience: 'Chu tin',
      care_plan: 'Tu cham soc',
      commitment_accepted: true,
      status: 'submitted',
    });
    expectStatus('self request guard', selfRequest, 400);
    statuses.selfRequestGuard = selfRequest.status;

    const thread = await create('adoption_chat_threads', {
      id: THREAD_ID,
      request_id: REQUEST_ID,
      adopter_user_id: ADOPTER_ID,
      shelter_id: SHELTER_ID,
    });
    expectStatus('create participant thread', thread, 201);
    statuses.createThread = thread.status;

    const invalidThread = await create('adoption_chat_threads', {
      id: INVALID_THREAD_ID,
      request_id: REQUEST_ID,
      adopter_user_id: SHELTER_ID,
      shelter_id: ADOPTER_ID,
    });
    expectStatus('thread participant guard', invalidThread, 409);
    statuses.threadParticipantGuard = invalidThread.status;

    process.stdout.write(
      `${JSON.stringify(
        {
          verdict: 'DAY50_ADOPTION_CLOUD_PROOF_PASS',
          testDataOnly: true,
          statuses,
        },
        null,
        2,
      )}\n`,
    );
  } finally {
    await cleanup();
  }
};

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`DAY50_ADOPTION_CLOUD_PROOF_FAIL: ${message}\n`);
  process.exitCode = 1;
});

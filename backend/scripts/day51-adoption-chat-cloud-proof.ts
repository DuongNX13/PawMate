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

const SHELTER_ID = '51000000-0000-4000-8000-000000000001';
const ADOPTER_ID = '51000000-0000-4000-8000-000000000002';
const NON_PARTICIPANT_ID = '51000000-0000-4000-8000-000000000003';
const LISTING_MEDIA_ID = '51000000-0000-4000-8000-000000000004';
const CHAT_MEDIA_ID = '51000000-0000-4000-8000-000000000005';
const DUPLICATE_MEDIA_ID = '51000000-0000-4000-8000-000000000006';
const LISTING_ID = '51000000-0000-4000-8000-000000000007';
const REQUEST_ID = '51000000-0000-4000-8000-000000000008';
const THREAD_ID = '51000000-0000-4000-8000-000000000009';
const MESSAGE_ID = '51000000-0000-4000-8000-000000000010';
const INVALID_MESSAGE_ID = '51000000-0000-4000-8000-000000000011';
const PROOF_TIME = '2026-07-27T11:00:00.000Z';

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
  const text = await response.text();
  let body: unknown;
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

const patch = async (
  path: string,
  row: Record<string, unknown>,
  returnRepresentation = false,
) =>
  callRest(path, {
    method: 'PATCH',
    headers: {
      Prefer: returnRepresentation ? 'return=representation' : 'return=minimal',
    },
    body: JSON.stringify(row),
  });

const cleanup = async () => {
  const paths = [
    `media_assets?id=in.(${CHAT_MEDIA_ID},${DUPLICATE_MEDIA_ID})`,
    `adoption_chat_messages?thread_id=eq.${THREAD_ID}`,
    `adoption_chat_participants?thread_id=eq.${THREAD_ID}`,
    `adoption_chat_threads?id=eq.${THREAD_ID}`,
    `adoption_requests?id=eq.${REQUEST_ID}`,
    `adoption_listings?id=eq.${LISTING_ID}`,
    `media_assets?id=eq.${LISTING_MEDIA_ID}`,
    `users?id=in.(${ADOPTER_ID},${SHELTER_ID},${NON_PARTICIPANT_ID})`,
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

const createUser = (id: string, role: string) =>
  create('users?on_conflict=id', {
    id,
    email: `day51-cloud-${role}@pawmate.local`,
    display_name: `Day 51 Cloud ${role}`,
    email_verified: true,
    created_at: PROOF_TIME,
    updated_at: PROOF_TIME,
  });

const createMedia = (
  id: string,
  ownerUserId: string,
  purpose: 'adoption_listing' | 'adoption_chat',
  storageName: string,
) =>
  create('media_assets?on_conflict=id', {
    id,
    owner_user_id: ownerUserId,
    purpose,
    mime_type: 'image/webp',
    size_bytes: 4096,
    sha256: id.replaceAll('-', '').padEnd(64, '0').slice(0, 64),
    status: 'verified',
    storage_key: `day51/cloud-proof/${storageName}.webp`,
    public_url: `https://example.invalid/day51/cloud-proof/${storageName}.webp`,
    width: 1200,
    height: 900,
    verification_version: 1,
    verified_at: PROOF_TIME,
    created_at: PROOF_TIME,
    updated_at: PROOF_TIME,
  });

const runSequentially = async <T>(
  items: readonly T[],
  work: (item: T) => Promise<void>,
) =>
  items.reduce(async (previous, item) => {
    await previous;
    await work(item);
  }, Promise.resolve());

const main = async () => {
  await cleanup();
  const statuses: Record<string, number> = {};
  try {
    await runSequentially(
      [
        ['shelter', SHELTER_ID],
        ['adopter', ADOPTER_ID],
        ['non-participant', NON_PARTICIPANT_ID],
      ] as const,
      async ([label, id]) => {
        const user = await createUser(id, label);
        expectStatus(`create ${label}`, user, 201);
        statuses[`create-${label}`] = user.status;
      },
    );

    const listingMedia = await createMedia(
      LISTING_MEDIA_ID,
      SHELTER_ID,
      'adoption_listing',
      'listing',
    );
    expectStatus('create listing media', listingMedia, 201);
    statuses.createListingMedia = listingMedia.status;

    const listing = await create('adoption_listings?on_conflict=id', {
      id: LISTING_ID,
      shelter_id: SHELTER_ID,
      hero_media_id: LISTING_MEDIA_ID,
      pet_name: 'Mint Cloud Proof',
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

    const request = await create('adoption_requests?on_conflict=id', {
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

    const thread = await create('adoption_chat_threads?on_conflict=id', {
      id: THREAD_ID,
      request_id: REQUEST_ID,
      adopter_user_id: ADOPTER_ID,
      shelter_id: SHELTER_ID,
    });
    expectStatus('create thread', thread, 201);
    statuses.createThread = thread.status;

    await runSequentially(
      [
        { user_id: ADOPTER_ID, role: 'adopter' },
        { user_id: SHELTER_ID, role: 'shelter' },
      ],
      async (participant) => {
        const result = await create('adoption_chat_participants', {
          thread_id: THREAD_ID,
          ...participant,
        });
        expectStatus(`create ${participant.role} participant`, result, 201);
        statuses[`participant-${participant.role}`] = result.status;
      },
    );

    const invalidRole = await create('adoption_chat_participants', {
      thread_id: THREAD_ID,
      user_id: NON_PARTICIPANT_ID,
      role: 'adopter',
    });
    expectStatus('participant role trigger', invalidRole, 400);
    statuses.participantRoleGuard = invalidRole.status;

    const invalidMessage = await create('adoption_chat_messages', {
      id: INVALID_MESSAGE_ID,
      thread_id: THREAD_ID,
      sender_user_id: NON_PARTICIPANT_ID,
      body: 'must be rejected',
    });
    expectStatus('message participant foreign key', invalidMessage, 409);
    statuses.messageParticipantGuard = invalidMessage.status;

    const message = await create('adoption_chat_messages', {
      id: MESSAGE_ID,
      thread_id: THREAD_ID,
      sender_user_id: ADOPTER_ID,
      body: 'Xin chao tu Day 51 cloud proof',
    });
    expectStatus('create message', message, 201);
    statuses.createMessage = message.status;
    const messageRows = message.body;
    if (
      !Array.isArray(messageRows) ||
      messageRows.length !== 1 ||
      typeof messageRows[0]?.sequence_no !== 'number'
    ) {
      throw new Error('message sequence_no was not returned as a number');
    }
    const sequence = messageRows[0].sequence_no as number;

    await runSequentially(
      [
        [CHAT_MEDIA_ID, ADOPTER_ID, 'chat'],
        [DUPLICATE_MEDIA_ID, SHELTER_ID, 'duplicate-position'],
      ] as const,
      async ([id, owner, name]) => {
        const media = await createMedia(id, owner, 'adoption_chat', name);
        expectStatus(`create ${name} media`, media, 201);
      },
    );

    const attach = await patch(`media_assets?id=eq.${CHAT_MEDIA_ID}`, {
      adoption_chat_message_id: MESSAGE_ID,
      position: 0,
      status: 'attached',
    });
    expectStatus('attach verified chat media', attach, 204);
    statuses.attachMedia = attach.status;

    const duplicatePosition = await patch(
      `media_assets?id=eq.${DUPLICATE_MEDIA_ID}`,
      {
        adoption_chat_message_id: MESSAGE_ID,
        position: 0,
        status: 'attached',
      },
    );
    expectStatus('duplicate chat media position', duplicatePosition, 409);
    statuses.duplicateMediaPositionGuard = duplicatePosition.status;

    const markRead = await patch(
      `adoption_chat_participants?thread_id=eq.${THREAD_ID}&user_id=eq.${SHELTER_ID}`,
      {
        last_read_sequence: sequence,
        last_read_at: PROOF_TIME,
      },
      true,
    );
    expectStatus('advance read cursor', markRead, 200);
    statuses.advanceReadCursor = markRead.status;

    const regressRead = await patch(
      `adoption_chat_participants?thread_id=eq.${THREAD_ID}&user_id=eq.${SHELTER_ID}`,
      { last_read_sequence: 0 },
    );
    expectStatus('reject read cursor regression', regressRead, 400);
    statuses.readCursorRegressionGuard = regressRead.status;

    await runSequentially(
      ['adoption_chat_participants', 'adoption_chat_messages'],
      async (table) => {
        const anonymousRead = await callRest(
          `${table}?select=*&limit=5`,
          { method: 'GET' },
          ANON_KEY,
        );
        expectStatus(`anonymous ${table} read`, anonymousRead, 200);
        if (
          !Array.isArray(anonymousRead.body) ||
          anonymousRead.body.length !== 0
        ) {
          throw new Error(`deny-by-default RLS leaked ${table} rows`);
        }
        statuses[`anon-${table}`] = anonymousRead.status;
      },
    );

    const serviceRead = await callRest(
      `adoption_chat_messages?thread_id=eq.${THREAD_ID}&select=id,sequence_no,body`,
      { method: 'GET' },
    );
    expectStatus('service message read', serviceRead, 200);
    if (!Array.isArray(serviceRead.body) || serviceRead.body.length !== 1) {
      throw new Error('service role did not observe exactly one chat message');
    }
    statuses.serviceMessageRead = serviceRead.status;

    process.stdout.write(
      `${JSON.stringify(
        {
          verdict: 'DAY51_ADOPTION_CHAT_CLOUD_PROOF_PASS',
          testDataOnly: true,
          cleanupRequired: true,
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
  process.stderr.write(`DAY51_ADOPTION_CHAT_CLOUD_PROOF_FAIL: ${message}\n`);
  process.exitCode = 1;
});

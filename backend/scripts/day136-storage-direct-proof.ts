import { createHash, randomBytes } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { join, resolve } from 'node:path';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

const PROJECT_REF = 'qeoowayxfqyhfcgnrfnv';
const PRIVATE_BUCKET = 'adoption-chat-media-private';
const PUBLIC_BUCKET = 'rescue-media-public';
const runId = process.env.DAY136_RUN_ID ?? '';
const evidenceRoot = process.env.DAY136_EVIDENCE_ROOT ?? '';
const authorizationManifest = process.env.DAY136_AUTH_MANIFEST ?? '';

type Check = {
  id: string;
  expected: string;
  actual: string;
  verdict: 'PASS' | 'FAIL';
};

type OwnedObject = { bucket: string; key: string };

const fail = (message: string): never => {
  throw new Error(message);
};
const assert: (
  condition: unknown,
  message: string,
) => asserts condition = (condition, message) => {
  if (!condition) fail(message);
};
const sha256 = (value: Uint8Array) =>
  createHash('sha256').update(value).digest('hex');
const now = () => new Date().toISOString();
const writeJson = (path: string, value: unknown) =>
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, 'utf8');

assert(/^d136-[a-z0-9-]{8,60}$/.test(runId), 'DAY136_RUN_ID_INVALID');
assert(evidenceRoot.length > 0, 'DAY136_EVIDENCE_ROOT_MISSING');
assert(
  authorizationManifest.length > 0 && existsSync(authorizationManifest),
  'DAY136_AUTH_MANIFEST_MISSING',
);

const manifest = JSON.parse(
  readFileSync(authorizationManifest, 'utf8'),
) as {
  target: { projectRef: string };
  scope: {
    day: string;
    syntheticOnly: boolean;
    deleteOnlyRunOwned: boolean;
    createSyntheticAuthUser: boolean;
    createRunOwnedStorageObjects: boolean;
    policyMutation: boolean;
    bucketConfigurationMutation: boolean;
    existingObjectMutation: boolean;
    applicationRowMutation: boolean;
  };
};

assert(manifest.target.projectRef === PROJECT_REF, 'DAY136_AUTH_TARGET_MISMATCH');
assert(manifest.scope.day === 'D136', 'DAY136_AUTH_DAY_MISMATCH');
assert(manifest.scope.syntheticOnly, 'DAY136_AUTH_SYNTHETIC_ONLY_REQUIRED');
assert(manifest.scope.deleteOnlyRunOwned, 'DAY136_AUTH_OWNED_CLEANUP_REQUIRED');
assert(
  manifest.scope.createSyntheticAuthUser &&
    manifest.scope.createRunOwnedStorageObjects,
  'DAY136_AUTH_FIXTURE_SCOPE_MISSING',
);
assert(
  !manifest.scope.policyMutation &&
    !manifest.scope.bucketConfigurationMutation &&
    !manifest.scope.existingObjectMutation &&
    !manifest.scope.applicationRowMutation,
  'DAY136_AUTH_MUTATION_SCOPE_TOO_BROAD',
);

const envPath = [
  resolve(process.cwd(), '.env.local'),
  resolve(process.cwd(), 'backend', '.env.local'),
  resolve(__dirname, '..', '.env.local'),
].find(existsSync);
assert(envPath, 'DAY136_ENV_NOT_FOUND');
dotenv.config({ path: envPath, override: false, quiet: true });
const fileEnv = dotenv.parse(readFileSync(envPath));
const first = (...values: Array<string | undefined>) =>
  values.find((value) => value && value.trim().length > 0)?.trim();
const supabaseUrl = first(process.env.SUPABASE_URL, fileEnv.SUPABASE_URL);
const anonKey = first(
  process.env.SUPABASE_PUBLISHABLE_KEY,
  process.env.SUPABASE_ANON_KEY,
  fileEnv.SUPABASE_PUBLISHABLE_KEY,
  fileEnv.SUPABASE_ANON_KEY,
);
const serviceRoleKey = first(
  process.env.SUPABASE_SECRET_KEY,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  fileEnv.SUPABASE_SECRET_KEY,
  fileEnv.SUPABASE_SERVICE_ROLE_KEY,
);
assert(supabaseUrl && anonKey && serviceRoleKey, 'DAY136_SUPABASE_CONFIG_MISSING');

const url = new URL(supabaseUrl);
assert(
  url.protocol === 'https:' &&
    url.hostname === `${PROJECT_REF}.supabase.co`,
  'DAY136_SUPABASE_TARGET_MISMATCH',
);

mkdirSync(evidenceRoot, { recursive: true });
const summaryPath = join(evidenceRoot, 'storage-acceptance-summary.json');
const cleanupPath = join(evidenceRoot, 'storage-cleanup.json');
const statePath = join(evidenceRoot, 'storage-owned-state.json');
const checks: Check[] = [];
const ownedObjects: OwnedObject[] = [];
const ownedAuthUserIds: string[] = [];

const saveOwnedState = () =>
  writeJson(statePath, {
    runId,
    projectRef: PROJECT_REF,
    ownedObjects,
    ownedAuthUserIds,
    secretPrinted: false,
    updatedAt: now(),
  });
const record = (
  id: string,
  expected: string,
  condition: boolean,
  actual: string,
) => {
  checks.push({
    id,
    expected,
    actual,
    verdict: condition ? 'PASS' : 'FAIL',
  });
  if (!condition) fail(`${id}:${actual}`);
};

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const anonymous = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Public 1x1 PNG fixture; it contains no user data.
const fixture = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z7dQAAAAASUVORK5CYII=',
  'base64',
);
const fixtureHash = sha256(fixture);
const privateKey = `day136/${runId}/private.png`;
const publicKey = `day136/${runId}/public.png`;

const downloadBytes = async (
  client: SupabaseClient<any, any, any, any, any>,
  bucket: string,
  key: string,
) => {
  const response = await client.storage.from(bucket).download(key);
  if (response.error || !response.data) return undefined;
  return Buffer.from(await response.data.arrayBuffer());
};

const cleanup = async () => {
  const objectResults: Array<{
    bucket: string;
    key: string;
    removed: boolean;
    readbackDenied: boolean;
    error?: string;
  }> = [];
  for (const owned of [...ownedObjects].reverse()) {
    const removed = await admin.storage.from(owned.bucket).remove([owned.key]);
    const readback = await downloadBytes(admin, owned.bucket, owned.key);
    objectResults.push({
      ...owned,
      removed: !removed.error,
      readbackDenied: readback === undefined,
      ...(removed.error ? { error: removed.error.name } : {}),
    });
  }

  const authResults: Array<{
        id: string;
        removed: boolean;
        readbackDenied: boolean;
        error?: string;
      }> = [];
  for (const ownedAuthUserId of [...ownedAuthUserIds].reverse()) {
    const removed = await admin.auth.admin.deleteUser(ownedAuthUserId);
    const readback = await admin.auth.admin.getUserById(ownedAuthUserId);
    authResults.push({
      id: ownedAuthUserId,
      removed: !removed.error,
      readbackDenied: Boolean(readback.error) || !readback.data.user,
      ...(removed.error ? { error: removed.error.name } : {}),
    });
  }

  const passed =
    objectResults.every((item) => item.removed && item.readbackDenied) &&
    authResults.every((item) => item.removed && item.readbackDenied);
  writeJson(cleanupPath, {
    runId,
    projectRef: PROJECT_REF,
    completedAt: now(),
    objects: objectResults,
    authUsers: authResults,
    verdict: passed ? 'PASS' : 'FAIL',
  });
  return passed;
};

const main = async () => {
  let firstFailure: string | undefined;
  let cleanupPassed = false;
  try {
    saveOwnedState();
    for (const expected of [
      { name: PRIVATE_BUCKET, isPublic: false },
      { name: PUBLIC_BUCKET, isPublic: true },
    ]) {
      const bucket = await admin.storage.getBucket(expected.name);
      record(
        `bucket_${expected.name}_contract`,
        `exists and public=${expected.isPublic}`,
        !bucket.error && Boolean(bucket.data) &&
          bucket.data?.public === expected.isPublic,
        bucket.error
          ? `error=${bucket.error.name}`
          : `public=${bucket.data?.public}`,
      );
    }

    const authenticatedClients: Array<{
      role: 'A' | 'B';
      client: SupabaseClient<any, any, any, any, any>;
    }> = [];
    for (const role of ['A', 'B'] as const) {
      const email = `${runId}-storage-${role.toLowerCase()}@example.invalid`;
      const password = `D136-${randomBytes(24).toString('hex')}Z8`;
      const created = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });
      assert(
        created.data.user && !created.error,
        `DAY136_AUTH_USER_${role}_CREATE_FAILED`,
      );
      ownedAuthUserIds.push(created.data.user.id);
      saveOwnedState();

      const signedIn = await anonymous.auth.signInWithPassword({
        email,
        password,
      });
      assert(
        signedIn.data.session && !signedIn.error,
        `DAY136_AUTH_USER_${role}_SIGNIN_FAILED`,
      );
      authenticatedClients.push({
        role,
        client: createClient(supabaseUrl, anonKey, {
          auth: { persistSession: false, autoRefreshToken: false },
          global: {
            headers: {
              Authorization: `Bearer ${signedIn.data.session.access_token}`,
            },
          },
        }),
      });
    }

    for (const owned of [
      { bucket: PRIVATE_BUCKET, key: privateKey },
      { bucket: PUBLIC_BUCKET, key: publicKey },
    ]) {
      const upload = await admin.storage.from(owned.bucket).upload(
        owned.key,
        fixture,
        { contentType: 'image/png', upsert: false },
      );
      assert(!upload.error, `DAY136_STORAGE_UPLOAD_FAILED:${owned.bucket}`);
      ownedObjects.push(owned);
      saveOwnedState();
    }

    const adminPrivate = await downloadBytes(admin, PRIVATE_BUCKET, privateKey);
    record(
      'service_role_private_positive_control',
      'exact fixture bytes',
      Boolean(adminPrivate) && sha256(adminPrivate!) === fixtureHash,
      adminPrivate ? `sha256=${sha256(adminPrivate)}` : 'missing',
    );

    const anonPrivate = await downloadBytes(
      anonymous,
      PRIVATE_BUCKET,
      privateKey,
    );
    const anonList = await anonymous.storage
      .from(PRIVATE_BUCKET)
      .list(`day136/${runId}`, { limit: 10 });
    record(
      'anon_private_get_and_list_denied',
      'no bytes and no listed object',
      !anonPrivate && (!anonList.data || anonList.data.length === 0),
      `get=${Boolean(anonPrivate)}; list=${anonList.data?.length ?? 0}`,
    );
    for (const authenticated of authenticatedClients) {
      const privateBytes = await downloadBytes(
        authenticated.client,
        PRIVATE_BUCKET,
        privateKey,
      );
      const privateList = await authenticated.client.storage
        .from(PRIVATE_BUCKET)
        .list(`day136/${runId}`, { limit: 10 });
      record(
        `authenticated_${authenticated.role.toLowerCase()}_private_get_and_list_denied`,
        'no bytes and no listed object',
        !privateBytes &&
          (!privateList.data || privateList.data.length === 0),
        `get=${Boolean(privateBytes)}; list=${privateList.data?.length ?? 0}`,
      );
    }

    const anonPublic = await downloadBytes(anonymous, PUBLIC_BUCKET, publicKey);
    record(
      'public_rescue_media_anon_readable',
      'exact fixture bytes',
      Boolean(anonPublic) && sha256(anonPublic!) === fixtureHash,
      anonPublic ? `sha256=${sha256(anonPublic)}` : 'missing',
    );
    for (const authenticated of authenticatedClients) {
      const publicBytes = await downloadBytes(
        authenticated.client,
        PUBLIC_BUCKET,
        publicKey,
      );
      record(
        `public_rescue_media_authenticated_${authenticated.role.toLowerCase()}_readable`,
        'exact fixture bytes',
        Boolean(publicBytes) && sha256(publicBytes!) === fixtureHash,
        publicBytes ? `sha256=${sha256(publicBytes)}` : 'missing',
      );
    }
  } catch (error) {
    firstFailure = error instanceof Error ? error.message : String(error);
  }

  try {
    cleanupPassed = await cleanup();
  } catch (error) {
    firstFailure = `${firstFailure ?? ''}; CLEANUP:${
      error instanceof Error ? error.message : String(error)
    }`;
  }

  const passed =
    !firstFailure &&
    cleanupPassed &&
    checks.length === 9 &&
    checks.every((check) => check.verdict === 'PASS');
  const summary = {
    schemaVersion: 1,
    runId,
    projectRef: PROJECT_REF,
    completedAt: now(),
    verdict: passed ? 'PASS' : 'BLOCKED',
    syntheticOnly: true,
    applicationRowsMutated: 0,
    existingObjectsMutated: 0,
    policyOrBucketConfigurationMutated: false,
    secretPrinted: false,
    fixtureSha256: fixtureHash,
    checks,
    cleanup: cleanupPassed ? 'PASS' : 'FAIL',
    ...(firstFailure ? { firstFailure } : {}),
  };
  writeJson(summaryPath, summary);
  process.stdout.write(`${JSON.stringify(summary)}\n`);
  if (!passed) process.exitCode = 1;
};

void main();

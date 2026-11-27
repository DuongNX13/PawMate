// R26 test-only cleanup traversal. No client construction, provider discovery,
// retries, credentials, or authority grants are performed by this helper.
import assert from 'node:assert/strict';

const CLEANUP_CALL_CAP = 13;
class FatalCleanupBoundary extends Error {
  constructor(error) { super(String(error)); this.cause = error; }
}
class OwnedReadbackFailure extends Error {}

function recoverableProviderError(error) {
  if (error instanceof FatalCleanupBoundary) return false;
  if (error instanceof OwnedReadbackFailure) return true;
  // SDK failures are local to the owned request, except lost authority.
  // Unknown errors (including assertions/guard/budget failures) fail closed.
  const sdk = error?.__isAuthError === true || error?.__isStorageError === true;
  return sdk && ![401, 403].includes(Number(error.status ?? error.statusCode));
}

function validateOwnership(guard, buckets) {
  assert(guard?.authIds instanceof Set && guard?.attemptedEmails instanceof Set, 'OWNED_AUTH_LEDGER_REQUIRED');
  assert(guard.objects instanceof Map, 'OWNED_OBJECT_LEDGER_REQUIRED');
  assert(guard.authIds.size <= 5 && guard.attemptedEmails.size <= 5, 'OWNED_AUTH_LIMIT');
  assert(guard.authIds.size <= guard.attemptedEmails.size, 'OWNED_AUTH_CREATION_BINDING');
  assert(Array.isArray(buckets) && buckets.length >= 2 && buckets[0] !== buckets[1], 'OWNED_BUCKET_BINDING');
  assert(guard.objects.size <= 2, 'OWNED_OBJECT_LIMIT');
  for (const id of guard.authIds) assert(/^[a-f0-9-]{36}$/.test(id), 'OWNED_AUTH_ID');
  const seen = new Set();
  for (const [key, bucket] of guard.objects) {
    assert(buckets.slice(0, 2).includes(bucket) && !seen.has(bucket), 'OWNED_OBJECT_BUCKET');
    assert(typeof key === 'string' && key.includes('/') && !key.split('/').some(p => !p || p === '..' || p === '.'), 'OWNED_OBJECT_KEY');
    seen.add(bucket);
  }
}

/**
 * Consume exact owned ledgers only. The caller must retain its authoritative
 * transport budget/guard and provide fatalCheck(), which rethrows any latched
 * pre-dispatch error even when the SDK converted it into a provider error.
 * write() must persist through the caller's secret-safe serializer.
 * Return BLOCKED on any failed delete/readback; the caller sets exitCode=1.
 */
export async function cleanupOwnedProviderFixtures({ runId, guard, cloud, buckets, journal, write, safeError, fatalCheck }) {
  const cleanup = { runId, auth: [], objects: [], verdict: 'NOT_RUN', errors: [], attempts: [], cleanupCalls: 0, halted: false };
  const persist = () => write('provider-cleanup.json', cleanup);
  const recordError = (operation, resource, error, fatal) => {
    cleanup.errors.push({ operation, resource, error: safeError(error), fatal });
    cleanup.halted ||= fatal;
    cleanup.verdict = 'BLOCKED';
  };
  const boundary = () => {
    try { fatalCheck(); } catch (error) { throw new FatalCleanupBoundary(error); }
  };
  // Setup and all boundary decisions are fatal; no SDK classification applies.
  try {
    assert.equal(typeof write, 'function', 'CLEANUP_WRITER_REQUIRED');
    assert.equal(typeof safeError, 'function', 'CLEANUP_SAFE_ERROR_REQUIRED');
    assert.equal(typeof fatalCheck, 'function', 'CLEANUP_FATAL_LATCH_REQUIRED');
    assert(Array.isArray(journal), 'CLEANUP_JOURNAL_REQUIRED');
    boundary(); validateOwnership(guard, buckets);
  } catch (error) {
    cleanup.verdict = 'BLOCKED'; cleanup.halted = true;
    cleanup.errors.push({ operation: 'cleanup_preflight', resource: null, error: typeof safeError === 'function' ? safeError(error) : String(error), fatal: true });
    if (typeof write === 'function') persist();
    return cleanup;
  }
  const authIds = [...guard.authIds], objectEntries = [...guard.objects];
  const ownership = () => {
    assert.deepEqual([...guard.authIds], authIds, 'OWNED_AUTH_LEDGER_CHANGED');
    assert.deepEqual([...guard.objects], objectEntries, 'OWNED_OBJECT_LEDGER_CHANGED');
  };
  // Exactly one SDK invocation per attempt. No retry is hidden in this helper.
  const attempt = async (operation, resource, slot, invoke, validate) => {
    try {
      boundary(); ownership();
      assert(cleanup.cleanupCalls < CLEANUP_CALL_CAP, 'CLEANUP_CALL_CAP');
      cleanup.cleanupCalls += 1; slot.status = 'ATTEMPTED';
      const event = { ordinal: cleanup.cleanupCalls, operation, resource, status: 'ATTEMPTED' };
      cleanup.attempts.push(event); persist();
      let result;
      try { result = await invoke(); } catch (error) { boundary(); throw error; }
      boundary(); ownership(); validate(result);
      slot.status = 'PASS'; event.status = 'PASS'; persist();
      return true;
    } catch (error) {
      const fatal = !recoverableProviderError(error);
      slot.status = 'ERROR'; slot.error = safeError(error); slot.fatal = fatal;
      const event = cleanup.attempts.at(-1);
      if (event?.operation === operation && event.resource === resource) Object.assign(event, { status: 'ERROR', error: slot.error, fatal });
      recordError(operation, resource, error, fatal); persist();
      return false;
    }
  };
  const validateDelete = result => { assert(result && typeof result === 'object', 'PROVIDER_DELETE_RESPONSE'); if (result.error !== null) throw result.error ?? new Error('PROVIDER_DELETE_ERROR_FIELD'); };
  persist();
  for (const id of authIds) {
    const row = { id, remaining: null, delete: { status: 'NOT_RUN' }, readback: { status: 'NOT_RUN' } };
    cleanup.auth.push(row);
    await attempt('auth_owned_delete', id, row.delete, () => cloud.auth.admin.deleteUser(id), validateDelete);
    if (cleanup.halted) break;
    await attempt('auth_owned_readback', id, row.readback, () => cloud.auth.admin.getUserById(id), result => {
      assert(result?.data && Object.hasOwn(result.data, 'user'), 'PROVIDER_AUTH_READBACK_RESPONSE');
      if (result.data.user === null && Number(result.error?.status) === 404) { row.remaining = 0; return; }
      if (result.error) throw result.error;
      row.remaining = result.data.user ? 1 : null;
      throw new OwnedReadbackFailure('OWNED_AUTH_READBACK_ABSENCE_NOT_PROVEN');
    });
    if (cleanup.halted) break;
  }
  if (!cleanup.halted) {
    const nativeStagingDelete = journal.some(j => j.operation === 'owned_object_delete' && j.path === '/storage/v1/object/' + buckets[0] && j.status === 200 && j.cleanup === false);
    for (const [key, bucket] of objectEntries) {
      const row = { bucket, key, remaining: null, delete: { status: 'NOT_RUN' }, readback: { status: 'NOT_RUN' } };
      cleanup.objects.push(row);
      if (bucket === buckets[0] && nativeStagingDelete) {
        row.delete.status = 'SKIPPED_PROVEN_NATIVE_STAGING_DELETE'; persist();
      } else await attempt('owned_object_delete', key, row.delete, () => cloud.storage.from(bucket).remove([key]), validateDelete);
      if (cleanup.halted) break;
    }
  }
  if (!cleanup.halted) for (const row of cleanup.objects) {
    const prefix = row.key.slice(0, row.key.lastIndexOf('/'));
    await attempt('owned_objects_readback', row.key, row.readback, () => cloud.storage.from(row.bucket).list(prefix, { limit: 10 }), result => {
      assert(result && typeof result === 'object', 'PROVIDER_OBJECT_READBACK_RESPONSE');
      if (result.error !== null) throw result.error ?? new Error('PROVIDER_OBJECT_READBACK_ERROR_FIELD');
      assert(Array.isArray(result.data), 'PROVIDER_OBJECT_READBACK_DATA'); row.remaining = result.data.length;
      if (result.data.length !== 0) throw new OwnedReadbackFailure('OWNED_OBJECT_READBACK_ABSENCE_NOT_PROVEN');
    });
    if (cleanup.halted) break;
  }
  if (authIds.length !== guard.attemptedEmails.size) recordError('owned_auth_creation_readback', null, new Error('UNCERTAIN_AUTH_CREATION_REQUIRES_OWNED_READBACK'), false);
  cleanup.cloudCalls = journal.length;
  cleanup.verdict = cleanup.errors.length || cleanup.halted ? 'BLOCKED' : 'PASS_EXACT_OWNED_CLEANUP';
  persist(); return cleanup;
}

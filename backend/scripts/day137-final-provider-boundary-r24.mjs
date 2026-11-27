import assert from 'node:assert/strict';
import { createProviderGuard } from './day137-provider-guard.mjs';

// Never broad-list Auth or overwrite an existing key. Two newly bound objects only.
export function createFinalProviderGuard(options) {
  const old = createProviderGuard(options);
  const uploads = new Set();
  let cleanup = false;
  return {
    ...old,
    setCleanup() { cleanup = true; old.setCleanup(); },
    check(url, method, body, headers = new Headers()) {
      assert.equal(url.origin, 'https://qeoowayxfqyhfcgnrfnv.supabase.co');
      assert(!url.pathname.includes('%2f') && !url.pathname.includes('%2F'), 'ENCODED_SLASH');
      assert.notEqual(url.pathname, '/auth/v1/admin/users', 'NO_BROAD_AUTH_DISCOVERY');
      const signedPut = method === 'PUT' && url.pathname.startsWith('/storage/v1/object/upload/sign/');
      assert(signedPut ? url.searchParams.size === 1 && url.searchParams.has('token') : !url.search, 'QUERY_ALLOWLIST');
      const operation = old.check(url, method, body);
      if (cleanup) assert(['auth_owned_readback', 'auth_owned_delete', 'owned_object_delete', 'owned_objects_readback'].includes(operation), 'CLEANUP_OPERATION_ONLY');
      // The installed SDK omits this header for upsert:false; only true
      // enables replacement. Accept omission or explicit false, never true.
      if (operation === 'owned_signed_ticket') assert([null, 'false'].includes(headers.get('x-upsert')), 'NO_STAGING_OVERWRITE');
      if (operation === 'owned_derivative_upload' || operation === 'owned_original_upload') {
        assert(!cleanup);
        assert(!uploads.has(url.pathname), 'NO_UPLOAD_REPLAY');
        if (operation === 'owned_derivative_upload') {
          assert.equal(headers.get('x-upsert'), 'true');
          assert(url.pathname.includes('/' + options.buckets[1] + '/pet_profile/'), 'UNIQUE_DERIVATIVE_ONLY');
        }
        uploads.add(url.pathname);
      }
      return operation;
    },
  };
}

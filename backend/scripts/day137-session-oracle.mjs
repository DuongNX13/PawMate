// Test-only oracle. Redis indexes include revoked tombstones until their TTL.
// Never persist raw sessions, token hashes, IP addresses, or device metadata.
import assert from 'node:assert/strict';

export function evaluateRevocation(indexedCount, metadata) {
  assert(Number.isSafeInteger(indexedCount) && indexedCount > 0, 'REVOCATION_NOT_OBSERVED');
  assert(Array.isArray(metadata) && metadata.length === indexedCount, 'SESSION_INDEX_MISMATCH');
  for (const item of metadata) {
    assert.deepEqual(Object.keys(item).sort(), ['exists', 'revoked', 'ttlSeconds'], 'UNSAFE_SESSION_METADATA');
    assert.equal(typeof item.exists, 'boolean');
    assert.equal(typeof item.revoked, 'boolean');
    assert(Number.isSafeInteger(item.ttlSeconds), 'INVALID_TTL');
    if (!item.exists) assert.equal(item.ttlSeconds, -2, 'ABSENT_SESSION_TTL');
    else assert(item.revoked && item.ttlSeconds > 0, 'ACTIVE_OR_UNBOUNDED_SESSION');
  }
  const activeCount = metadata.filter(item => item.exists && !item.revoked).length;
  const revokedCount = metadata.filter(item => item.exists && item.revoked).length;
  assert.equal(activeCount, 0, 'ACTIVE_SESSION_AFTER_LOGOUT');
  assert(revokedCount > 0, 'REVOCATION_NOT_OBSERVED');
  return { indexedCount, activeCount, revokedCount, metadata };
}

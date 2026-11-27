import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateRevocation } from './day137-session-oracle.mjs';

const revoked = () => ({ exists: true, revoked: true, ttlSeconds: 120 });
test('accepts a revoked, TTL-bounded tombstone in a nonempty index', () => {
  assert.deepEqual(evaluateRevocation(1, [revoked()]), {
    indexedCount: 1, activeCount: 0, revokedCount: 1, metadata: [revoked()],
  });
});
test('allows an expired missing entry alongside an observed tombstone', () => {
  assert.equal(evaluateRevocation(2, [revoked(), { exists: false, revoked: false, ttlSeconds: -2 }]).activeCount, 0);
});
test('rejects vacuous empty-index proof', () => assert.throws(() => evaluateRevocation(0, []), /REVOCATION_NOT_OBSERVED/));
test('rejects mismatched index and readback', () => assert.throws(() => evaluateRevocation(2, [revoked()]), /SESSION_INDEX_MISMATCH/));
test('rejects a still-active session', () => assert.throws(() => evaluateRevocation(1, [{ ...revoked(), revoked: false }]), /ACTIVE_OR_UNBOUNDED_SESSION/));
for (const ttlSeconds of [-2, -1, 0, 1.5, NaN]) {
  test(`rejects invalid live-tombstone TTL ${ttlSeconds}`, () => assert.throws(() => evaluateRevocation(1, [{ ...revoked(), ttlSeconds }])));
}
test('rejects a false absent-session TTL', () => assert.throws(() => evaluateRevocation(2, [revoked(), { exists: false, revoked: false, ttlSeconds: 5 }]), /ABSENT_SESSION_TTL/));
test('rejects raw secret-bearing session metadata', () => assert.throws(() => evaluateRevocation(1, [{ ...revoked(), refreshTokenHash: 'synthetic-sensitive-field' }]), /UNSAFE_SESSION_METADATA/));

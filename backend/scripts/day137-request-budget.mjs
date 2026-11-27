import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

export function initializeBudget(envelopePath, now = Date.now()) {
  const envelope = JSON.parse(fs.readFileSync(envelopePath, 'utf8'));
  assert.equal(envelope.approval, 'USER_CONTINUE_WITHIN_PREVIOUSLY_DESCRIBED_ENVELOPE');
  assert.equal(envelope.maxRequests, 800);
  assert.equal(envelope.cleanupReserve, 40);
  assert.equal(envelope.maxRuntimeMinutes, 40);
  const file = path.join(path.dirname(envelopePath), 'request-budget.json');
  const state = { envelopeId: envelope.id, startedAt: new Date(now).toISOString(),
    deadlineMs: now + envelope.maxRuntimeMinutes * 60000, total: 0, runtime: 0, cloud: 0, cleanup: 0 };
  fs.writeFileSync(file, JSON.stringify(state, null, 2) + '\n', { flag: 'wx' });
  return file;
}

export function claimRequest(envelopePath, kind, cleanup = false, now = Date.now()) {
  assert(['runtime', 'cloud'].includes(kind), 'REQUEST_KIND');
  const envelope = JSON.parse(fs.readFileSync(envelopePath, 'utf8'));
  const file = path.join(path.dirname(envelopePath), 'request-budget.json');
  const lock = `${file}.lock`;
  const fd = fs.openSync(lock, 'wx'); // Concurrent processes cannot reset/overspend.
  try {
    const state = JSON.parse(fs.readFileSync(file, 'utf8'));
    assert.equal(state.envelopeId, envelope.id, 'BUDGET_IDENTITY');
    assert(Number.isSafeInteger(state.total) && state.total >= 0, 'BUDGET_COUNT');
    assert(state.total === state.runtime + state.cloud, 'BUDGET_RECONCILIATION');
    assert(cleanup || now < state.deadlineMs, 'RUNTIME_DEADLINE');
    assert(state.total < envelope.maxRequests - (cleanup ? 0 : envelope.cleanupReserve), 'REQUEST_BUDGET');
    state.total++; state[kind]++; if (cleanup) state.cleanup++;
    state.updatedAt = new Date(now).toISOString();
    fs.writeFileSync(file, JSON.stringify(state, null, 2) + '\n');
    return state;
  } finally { fs.closeSync(fd); fs.unlinkSync(lock); }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  assert.equal(process.argv[2], 'start');
  console.log(initializeBudget(process.argv[3]));
}

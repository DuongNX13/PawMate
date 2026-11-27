import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
export function initializeBudget(envelopePath, now = Date.now()) {
  const contract = JSON.parse(fs.readFileSync(envelopePath, 'utf8'));
  assert.equal(contract.day, 137);
  assert.equal(contract.cloudCallsMax, 0);
  assert.equal(contract.modelEvaluationCallsMax, 0);
  assert.equal(contract.runtimeCallsMax, 450);
  assert.equal(contract.runtimeMinutesMax, 30);
  const file = path.join(path.dirname(envelopePath), 'request-budget.json');
  fs.writeFileSync(file, JSON.stringify({ envelopeId: 'd137-authlocal-r14-local-only', startedAt: new Date(now).toISOString(), deadlineMs: now + 30 * 60000, total: 0, runtime: 0, cloud: 0, cleanup: 0 }, null, 2), { flag: 'wx' });
  return file;
}
export function claimRequest(envelopePath, now = Date.now()) {
  const file = path.join(path.dirname(envelopePath), 'request-budget.json');
  const state = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.equal(state.envelopeId, 'd137-authlocal-r14-local-only');
  assert(!state.closedAt, 'ENVELOPE_CLOSED');
  assert.equal(state.cloud, 0);
  assert(now < state.deadlineMs - 300000, 'CLEANUP_RESERVE');
  assert(state.total < 450, 'REQUEST_BUDGET');
  state.total++; state.runtime++; state.updatedAt = new Date(now).toISOString();
  fs.writeFileSync(file, JSON.stringify(state, null, 2));
  return state;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  assert.equal(process.argv[2], 'start');
  console.log(initializeBudget(process.argv[3]));
}

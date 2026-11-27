import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { artifact, verifyReference, ORIGIN } from '../../scripts/qa/day137/day137-provider-budget-r26.mjs';

export const CONTRACT_ID = 'd137-review-photo-r27';
export const LIMITS = Object.freeze({ cloud: 10, ordinary: 8, cleanup: 2, runtime: 40, minutes: 30, auth: 0, objects: 4 });
const ROOT = path.resolve(import.meta.dirname, '../..');
const sha = b => createHash('sha256').update(b).digest('hex');
const statePath = p => path.join(path.dirname(p), 'request-budget.json');
const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const write = (p, v, flag = 'w') => fs.writeFileSync(p, JSON.stringify(v, null, 2) + '\n', { flag });

export function validateEnvelope(c, approval, parent) {
  assert.equal(c.schemaVersion, 1); assert.equal(c.day, 137); assert.equal(c.contractId, CONTRACT_ID);
  assert(/^d137-review-photo-[a-z0-9-]{6,28}$/.test(c.runId), 'FRESH_RUN_ID_REQUIRED');
  assert.equal(c.origin, ORIGIN); assert.equal(c.allowlistedProject, 'qeoowayxfqyhfcgnrfnv');
  assert.deepEqual(c.requiredCaseIds, ['anonymous', 'owner_adopter', 'outsider', 'shelter_A', 'shelter_B'].map(r => 'D137-R27-photo-' + r));
  assert.deepEqual([c.cloudCallsMax, c.cloudOrdinaryMax, c.cloudCleanupReserve, c.runtimeCallsMax,
    c.runtimeMinutesMax, c.maximumOwnedAuthAccounts, c.maximumOwnedStorageObjects, c.modelEvaluationCallsMax], [10, 8, 2, 40, 30, 0, 4, 0], 'SCOPE_CAP_DRIFT');
  assert.equal(c.fullDay137Acceptance, false); assert.equal(c.authorityStatus, 'APPROVED_EXACT_SCOPE', 'FRESH_AUTHORITY_REQUIRED');
  assert(approval && parent, 'APPROVAL_AND_PARENT_REQUIRED');
  assert.equal(approval.kind, 'direct-human-exact-scope'); assert.equal(approval.runId, c.runId);
  assert.equal(approval.contractId, c.contractId); assert.equal(approval.origin, c.origin);
  assert.deepEqual(approval.limits, LIMITS); assert(typeof approval.humanReply === 'string' && approval.humanReply.trim());
  assert(typeof approval.question === 'string' && approval.question.trim());
  assert(Number.isFinite(Date.parse(approval.recordedAt)));
  assert.equal(parent.fullDay137Acceptance, false);
  assert(Number.isFinite(Date.parse(parent.startedAt)) && Number.isFinite(Date.parse(parent.absoluteDeadline)));
  assert(Date.parse(parent.absoluteDeadline) > Date.parse(parent.startedAt));
  return true;
}
export function loadEnvelope(p, root = ROOT, authorityPath) {
  const relative = path.relative(root, p).replaceAll('\\', '/');
  assert(relative.startsWith('output-evidence/security/day137/') && !relative.split('/').includes('..'), 'UNSAFE_ENVELOPE');
  const c = read(p);
  // Pending authority fails before dereferencing credentials or initializing a clock.
  assert.equal(c.authorityStatus, 'APPROVED_EXACT_SCOPE', 'FRESH_AUTHORITY_REQUIRED');
  verifyReference(root, c.authorityApproval); verifyReference(root, c.parentContract); verifyReference(root, c.sourceManifest);
  if (authorityPath) assert.equal(path.resolve(authorityPath), path.resolve(root, c.authorityApproval.path), 'AUTHORITY_PATH_MISMATCH');
  const approval = read(path.join(root, c.authorityApproval.path)), parent = read(path.join(root, c.parentContract.path));
  validateEnvelope(c, approval, parent);
  assert(Array.isArray(c.refs) && c.refs.length && new Set(c.refs.map(r => r.path)).size === c.refs.length);
  c.refs.forEach(r => verifyReference(root, r));
  const source = read(path.join(root, c.sourceManifest.path));
  assert.equal(source.sourceFingerprint, c.sourceFingerprint); source.files.forEach(r => verifyReference(root, r));
  return { contract: c, approval, parent, source, envelopeRef: artifact(root, relative) };
}
export function validateBudget(s, c, envelopeHash, parent) {
  assert.equal(s.runId, c.runId); assert.equal(s.envelopeId, c.contractId); assert.equal(s.envelopeSha256, envelopeHash, 'ENVELOPE_CHANGED');
  assert(!s.closedAt && s.newRequestsAllowed !== false, 'CLOSED_ENVELOPE');
  const start = Date.parse(s.startedAt), parentStart = Date.parse(parent.startedAt);
  assert(start >= parentStart && start < Date.parse(parent.absoluteDeadline), 'PARENT_CLOCK');
  assert.equal(s.parentDeadlineMs, Date.parse(parent.absoluteDeadline));
  assert.equal(s.deadlineMs, Math.min(start + LIMITS.minutes * 60000, s.parentDeadlineMs), 'CLOCK_RESET_FORBIDDEN');
  for (const k of ['cloud', 'runtime', 'cleanup', 'total']) assert(Number.isSafeInteger(s[k]) && s[k] >= 0);
  assert.equal(s.total, s.cloud + s.runtime); assert(s.cloud <= 10 && s.runtime <= 40 && s.cleanup <= 2 && s.cleanup <= s.cloud);
  assert(['ordinary', 'cleanup'].includes(s.phase));
  return true;
}
export function initializeBudget(p, authorityPath, now = Date.now(), root = ROOT) {
  const { contract: c, parent, envelopeRef } = loadEnvelope(p, root, authorityPath);
  const deadlineMs = Math.min(now + 1800000, Date.parse(parent.absoluteDeadline));
  assert(now >= Date.parse(parent.startedAt) && deadlineMs - now > 300000, 'INSUFFICIENT_CLEANUP_RESERVE');
  write(statePath(p), { runId: c.runId, envelopeId: c.contractId, envelopeSha256: envelopeRef.sha256,
    startedAt: new Date(now).toISOString(), deadlineMs, parentDeadlineMs: Date.parse(parent.absoluteDeadline),
    cloud: 0, runtime: 0, cleanup: 0, total: 0, phase: 'ordinary', newRequestsAllowed: true }, 'wx');
  return statePath(p);
}
function context(p, root = ROOT) {
  const bytes = fs.readFileSync(p), c = JSON.parse(bytes), s = read(statePath(p));
  verifyReference(root, c.parentContract);
  const parent = read(path.join(root, c.parentContract.path));
  validateBudget(s, c, sha(bytes), parent);
  return { c, s };
}
export function assertBudgetActive(p, now = Date.now()) {
  const { s } = context(p);
  assert.equal(s.phase, 'ordinary', 'CLEANUP_IS_TERMINAL');
  assert(now >= Date.parse(s.startedAt) && now < s.deadlineMs - 300000, 'CLEANUP_RESERVE');
  return s;
}
export function stopOrdinary(p, reason) {
  const { s } = context(p); s.phase = 'cleanup'; s.firstFailure ??= { reason, at: new Date().toISOString() };
  write(statePath(p), s);
}
export function claimRequest(p, kind = 'runtime', cleanup = false, now = Date.now(), root = ROOT) {
  const { s } = context(p, root);
  try {
    assert(['runtime', 'cloud'].includes(kind)); assert(!cleanup || kind === 'cloud');
    assert(cleanup || s.phase === 'ordinary', 'CLEANUP_IS_TERMINAL');
    assert(now >= Date.parse(s.startedAt) && now < s.deadlineMs - (cleanup ? 0 : 300000), 'CLEANUP_RESERVE');
    const cap = kind === 'cloud' ? (cleanup ? 10 : 8) : 40;
    assert(s[kind] < cap && (!cleanup || s.cleanup < 2), 'REQUEST_BUDGET');
    s[kind]++; s.total++; if (cleanup) { s.cleanup++; s.phase = 'cleanup'; }
    s.updatedAt = new Date(now).toISOString(); write(statePath(p), s); return s;
  } catch (e) { s.phase = 'cleanup'; s.firstFailure ??= { reason: String(e), at: new Date(now).toISOString() }; write(statePath(p), s); throw e; }
}
export function closeBudget(p, reason, now = Date.now()) {
  const s = read(statePath(p)); assert(!s.closedAt, 'CLOSED_ENVELOPE');
  s.closedAt = new Date(now).toISOString(); s.closure = reason; s.newRequestsAllowed = false; write(statePath(p), s);
  return s;
}
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  const [command, p, extra] = process.argv.slice(2);
  if (command === 'preflight') console.log(JSON.stringify({ verdict: 'PASS_CONTRACT_ONLY', runId: loadEnvelope(p, ROOT, extra).contract.runId }));
  else if (command === 'start') console.log(initializeBudget(p, extra));
  else if (command === 'close') console.log(JSON.stringify(closeBudget(p, extra)));
  else throw new Error('UNKNOWN_COMMAND');
}

import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

export function initializeBudget(envelopePath, now = Date.now()) {
  const c = JSON.parse(fs.readFileSync(envelopePath, 'utf8'));
  assert.equal(c.day, 137);
  assert.equal(c.authorityStatus, 'APPROVED_EXACT_SCOPE', 'AUTHORITY_PENDING');
  assert.equal(c.cloudCallsMax, 45);
  assert.equal(c.runtimeCallsMax, 80);
  assert.equal(c.runtimeMinutesMax, 60);
  assert.equal(c.modelEvaluationCallsMax, 0);
  const p = path.join(path.dirname(envelopePath), 'request-budget.json');
  fs.writeFileSync(p, JSON.stringify({ envelopeId: 'd137-final-provider-r24',
    startedAt: new Date(now).toISOString(), deadlineMs: now + 3600000,
    total: 0, runtime: 0, cloud: 0, cleanup: 0 }, null, 2) + '\n', { flag: 'wx' });
  return p;
}

export function claimRequest(envelopePath, kind = 'runtime', cleanup = false, now = Date.now()) {
  const p = path.join(path.dirname(envelopePath), 'request-budget.json');
  const s = JSON.parse(fs.readFileSync(p, 'utf8'));
  assert.equal(s.envelopeId, 'd137-final-provider-r24');
  assert(!s.closedAt, 'CLOSED_ENVELOPE');
  assert(['runtime', 'cloud'].includes(kind));
  assert(now < s.deadlineMs - (cleanup ? 0 : 600000), 'CLEANUP_RESERVE');
  const max = kind === 'cloud' ? (cleanup ? 45 : 32) : 80;
  assert(s[kind] < max, 'REQUEST_BUDGET');
  s[kind] += 1; s.total += 1;
  if (cleanup) s.cleanup += 1;
  s.updatedAt = new Date(now).toISOString();
  fs.writeFileSync(p, JSON.stringify(s, null, 2) + '\n');
  return s;
}

if (process.argv[2] === 'start') console.log(initializeBudget(process.argv[3]));

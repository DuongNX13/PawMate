// One bounded metadata read after owned-object cleanup. No object/auth mutation.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { loadEnv } from '../src/config/env';
import { claimRequest } from './day137-private-media-budget-r20.mjs';

const root = path.resolve(__dirname, '../..');
const control = path.join(root, 'output-evidence/security/day137/d137-private-media-20261005-r20');
const out = path.join(root, 'output-evidence/security/day137/d137-local-private-20261005-r20');
const target = path.join(control, 'metadata-readback.json');
assert(!fs.existsSync(target), 'IMMUTABLE_READBACK');
const read = (p: string) => JSON.parse(fs.readFileSync(p, 'utf8'));
const operations = read(path.join(out, 'cloud-requests.json'));
const before = operations.find((c: any) => c.operation === 'read_bucket_metadata' &&
  c.path === '/storage/v1/bucket/adoption-chat-media-private');
assert(before?.metadata && before.status === 200);
assert.equal(read(path.join(out, 'provider-cleanup.json')).remainingOwnedObjects, 0);
const config = loadEnv();
const url = new URL('/storage/v1/bucket/adoption-chat-media-private', config.supabaseUrl);
assert.equal(url.origin, 'https://qeoowayxfqyhfcgnrfnv.supabase.co');
claimRequest(path.join(control, 'envelope.json'), 'cloud', true);
const startedAt = new Date().toISOString();
async function run() {
  const response = await fetch(url, { method: 'GET', redirect: 'error',
    signal: AbortSignal.timeout(15000),
    headers: { apikey: config.supabaseServiceRoleKey!,
      authorization: `Bearer ${config.supabaseServiceRoleKey!}` } });
  assert.equal(response.status, 200);
  const after = await response.json() as any;
  assert.deepEqual(after, before.metadata);
  assert.equal(after.public, false);
  const sha = (x: any) => createHash('sha256').update(JSON.stringify(x)).digest('hex');
  fs.writeFileSync(target, JSON.stringify({ verdict: 'PASS_METADATA_UNCHANGED',
    runId: 'd137-local-private-20261005-r20', startedAt, endedAt: new Date().toISOString(),
    method: 'GET', path: url.pathname, status: response.status,
    beforeSha256: sha(before.metadata), afterSha256: sha(after), public: after.public,
    cloudCalls: 1, noOwnedObjectRemaining: true, fullDay137Acceptance: false }, null, 2) + '\n',
    { flag: 'wx' });
  console.log('PASS_METADATA_UNCHANGED');
}
run().catch(error => { console.error(error.code ?? error.message); process.exitCode = 1; });

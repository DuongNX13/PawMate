import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeBudget, claimRequest } from './day137-request-budget-r2.mjs';

function fixture(run) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'day137-budget-'));
  const envelope = path.join(directory, 'envelope.json');
  fs.writeFileSync(envelope, JSON.stringify({ id: 'own-fixture', approval: 'USER_CONTINUE_WITHIN_PREVIOUSLY_DESCRIBED_ENVELOPE', maxRequests: 800, cleanupReserve: 40, maxRuntimeMinutes: 40 }));
  try { const state = initializeBudget(envelope, 1000); run(envelope, state); }
  finally { assert(fs.realpathSync(directory).startsWith(fs.realpathSync(os.tmpdir()) + path.sep + 'day137-budget-')); fs.rmSync(directory, { recursive: true }); }
}
test('one persisted counter includes cloud, runtime, and failed dispatches', () => fixture((e, s) => {
  claimRequest(e, 'runtime', false, 2000); claimRequest(e, 'cloud', false, 3000);
  assert.equal(JSON.parse(fs.readFileSync(s)).total, 2);
  assert.throws(() => initializeBudget(e), /EEXIST/);
}));
test('execution cap reserves cleanup without resetting the total', () => fixture((e, s) => {
  const value = JSON.parse(fs.readFileSync(s)); Object.assign(value, { total: 760, runtime: 760 }); fs.writeFileSync(s, JSON.stringify(value));
  assert.throws(() => claimRequest(e, 'runtime', false, 2000), /REQUEST_BUDGET/);
  assert.equal(claimRequest(e, 'cloud', true, 2000).total, 761);
}));
test('deadline rejects execution but allows reserved cleanup', () => fixture(e => {
  assert.throws(() => claimRequest(e, 'runtime', false, 2401000), /RUNTIME_DEADLINE/);
  assert.equal(claimRequest(e, 'cloud', true, 2401000).total, 1);
}));
test('corrupt reconciliation is rejected before dispatch', () => fixture((e, s) => {
  const value = JSON.parse(fs.readFileSync(s)); value.total = 10; fs.writeFileSync(s, JSON.stringify(value));
  assert.throws(() => claimRequest(e, 'runtime', false, 2000), /BUDGET_RECONCILIATION/);
}));
test('a concurrent owner lock fails closed and is not deleted', () => fixture((e, s) => {
  fs.writeFileSync(`${s}.lock`, 'owned elsewhere'); assert.throws(() => claimRequest(e, 'runtime', false, 2000), /EEXIST/);
  assert.equal(fs.readFileSync(`${s}.lock`, 'utf8'), 'owned elsewhere');
}));
test('hard cap includes cleanup', () => fixture((e, s) => {
  const value = JSON.parse(fs.readFileSync(s)); Object.assign(value, { total: 800, runtime: 800 }); fs.writeFileSync(s, JSON.stringify(value));
  assert.throws(() => claimRequest(e, 'cloud', true, 2000), /REQUEST_BUDGET/);
}));
test('local-only envelope initializes and rejects cloud including cleanup before counting',()=>{
 const d=fs.mkdtempSync(path.join(os.tmpdir(),'day137-budget-'));const e=path.join(d,'envelope.json');
 try{fs.writeFileSync(e,JSON.stringify({id:'local',approval:'LOCAL_ONLY_IN_SCOPE',cloudAllowed:false,maxOwnedStorageObjects:0,newAuthProviderFixtureAllowed:false,maxRequests:200,cleanupReserve:20,maxRuntimeMinutes:40}));const s=initializeBudget(e,1000);assert.equal(claimRequest(e,'runtime',false,2000).total,1);assert.throws(()=>claimRequest(e,'cloud',false,2000),/LOCAL_ONLY_CLOUD_FORBIDDEN/);assert.throws(()=>claimRequest(e,'cloud',true,2000),/LOCAL_ONLY_CLOUD_FORBIDDEN/);assert.equal(JSON.parse(fs.readFileSync(s)).total,1);}finally{fs.rmSync(d,{recursive:true});}
});

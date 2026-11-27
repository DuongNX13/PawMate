import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
export function initializeBudget(p,now=Date.now()) {
  const c=JSON.parse(fs.readFileSync(p,'utf8'));
  assert.equal(c.day,137); assert.equal(c.cloudCallsMax,0); assert.equal(c.runtimeCallsMax,220);
  assert.equal(c.runtimeMinutesMax,30); assert.equal(c.modelEvaluationCallsMax,0);
  const out=path.join(path.dirname(p),'request-budget.json');
  fs.writeFileSync(out,JSON.stringify({envelopeId:'d137-local-states-r22',startedAt:new Date(now).toISOString(),deadlineMs:now+1800000,total:0,runtime:0,cloud:0,cleanup:0},null,2)+'\n',{flag:'wx'}); return out;
}
export function claimRequest(p,kind='runtime',cleanup=false,now=Date.now()) {
  assert.equal(kind,'runtime','ZERO_CLOUD_ENVELOPE');
  const out=path.join(path.dirname(p),'request-budget.json'),s=JSON.parse(fs.readFileSync(out,'utf8'));
  assert.equal(s.envelopeId,'d137-local-states-r22'); assert(!s.closedAt);
  assert(now<s.deadlineMs-300000,'CLEANUP_RESERVE'); assert(s.runtime<220,'REQUEST_BUDGET');
  s.runtime++;s.total++;s.updatedAt=new Date(now).toISOString();fs.writeFileSync(out,JSON.stringify(s,null,2)+'\n');return s;
}
if(process.argv[2]==='start')console.log(initializeBudget(process.argv[3]));

import assert from 'node:assert/strict';import test from 'node:test';
import {classifyPhotoRequest,preparePhotoDispatch,completePhotoCleanup,executePhotoDispatch,type PhotoScope} from './day137-review-photo-boundary-r27';
const id='12345678-1234-1234-1234-123456789012',runId='d137-review-photo-20261005-r27',key=`${id}/${id}/123-${id}-${runId}.png`;
const scope=():PhotoScope=>({origin:'https://qeoowayxfqyhfcgnrfnv.supabase.co',bucket:'review-photos',vetId:id,userIds:[id],runId,ownedKeys:new Set(),cleanup:false});
test('native upload shape is allowed once with upsert=false, then exact authenticated byte read',()=>{
  const s=scope(),url=s.origin+'/storage/v1/object/'+s.bucket+'/'+key;
  assert.equal(classifyPhotoRequest(s,url,'POST',Buffer.from('fixture'),new Headers({'x-upsert':'false'})).kind,'upload');
  s.ownedKeys.add(key);assert.equal(classifyPhotoRequest(s,s.origin+'/storage/v1/object/'+s.bucket+'/'+key,'GET',undefined,new Headers({'authorization':'synthetic fixture'})).kind,'download');
  assert.throws(()=>classifyPhotoRequest(s,url,'POST',Buffer.from('fixture'),new Headers({'x-upsert':'false'})));
});
test('control-plane, wrong project, existing/foreign objects and upsert are refused',()=>{
  const s=scope(),url=s.origin+'/storage/v1/object/'+s.bucket+'/'+key;
  assert.throws(()=>classifyPhotoRequest(s,url,'POST',Buffer.from('fixture'),new Headers({'x-upsert':'true'})));
  assert.throws(()=>classifyPhotoRequest(s,url.replace(s.origin,'https://other.invalid'),'POST',Buffer.from('fixture'),new Headers({'x-upsert':'false'})));
  assert.throws(()=>classifyPhotoRequest(s,s.origin+'/storage/v1/bucket/'+s.bucket,'PUT','{}',new Headers()));
  assert.throws(()=>classifyPhotoRequest(s,s.origin+'/storage/v1/object/authenticated/'+s.bucket+'/existing.png','GET',undefined,new Headers()));
});
test('cleanup accepts exact registered keys and zero-count bounded readback only',()=>{
  const s=scope();s.cleanup=true;s.ownedKeys.add(key);
  assert.equal(classifyPhotoRequest(s,s.origin+'/storage/v1/object/'+s.bucket,'DELETE',JSON.stringify({prefixes:[key]}),new Headers()).kind,'delete');
  assert.throws(()=>classifyPhotoRequest(s,s.origin+'/storage/v1/object/'+s.bucket,'DELETE',JSON.stringify({prefixes:[key,'other']}),new Headers()));
  assert.equal(classifyPhotoRequest(s,s.origin+'/storage/v1/object/list/'+s.bucket,'POST',JSON.stringify({prefix:id,limit:10,offset:0}),new Headers()).kind,'list');
});

// Controlled counterfactual restores the pre-fix boundary (no stop latch,
// ownership only after response). It is a local test fixture, never a runner.
const dispatch = process.env.DAY137_PHOTO_GUARD_COUNTERFACTUAL === '1'
  ? ((s: PhotoScope, url: string, method: string, body: unknown, headers: Headers, _bytes: Buffer,
      hooks: { claim: (cleanup: boolean) => void; stop: (reason: string) => void }) => {
      const request = classifyPhotoRequest(s, url, method, body, headers);
      hooks.claim(request.cleanup);
      return request;
    })
  : preparePhotoDispatch;

test('ownership failure latches later ordinary dispatch before any transport', () => {
  const s = scope(), bytes = Buffer.from('fixture'); let stopped = false, transports = 0;
  const hooks = { claim: () => assert(!stopped, 'ORDINARY_STOPPED'), stop: () => { stopped = true; } };
  assert.throws(() => dispatch(s, 'https://other.invalid/storage/v1/object/review-photos/'+key, 'POST', bytes, new Headers({'x-upsert':'false'}), bytes, hooks), /WRONG_PROJECT/);
  assert.throws(() => {
    dispatch(s, s.origin+'/storage/v1/object/'+s.bucket+'/'+key, 'POST', bytes, new Headers({'x-upsert':'false'}), bytes, hooks);
    transports++;
  }, /ORDINARY_STOPPED/);
  assert.equal(transports, 0);
});

test('attempted upload belongs to exact cleanup even when transport will fail', () => {
  const s = scope(), bytes = Buffer.from('fixture');
  dispatch(s, s.origin+'/storage/v1/object/'+s.bucket+'/'+key, 'POST', bytes, new Headers({'x-upsert':'false'}), bytes, {claim: () => {}, stop: () => {}});
  assert(s.ownedKeys.has(key), 'OWNERSHIP_BEFORE_DISPATCH');
});

const cleanup = process.env.DAY137_PHOTO_CLEANUP_COUNTERFACTUAL === '1'
  ? async (keys: Set<string>, operations: Parameters<typeof completePhotoCleanup>[1]) => {
    const removed = await operations.remove([...keys]); assert.equal(removed.error, null);
    const listed = await operations.list(); assert.equal(listed.error, null);
    return { errors: [], remainingOwnedPrefixEntries: listed.data!.length };
  } : completePhotoCleanup;

test('failed delete still spends only the reserved readback, never produces PASS', async () => {
  let reads=0; const keys=new Set([key]);
  const result=await cleanup(keys,{
    remove:async actual=>{assert.deepEqual(actual,[key]);return{error:'synthetic delete failure'};},
    list:async()=>{reads++;return{error:null,data:[]};},
  });
  assert.equal(reads,1);assert.equal(result.errors.length,1);assert.equal(result.remainingOwnedPrefixEntries,0);
});
test('readback failure or remaining object is retained; no implicit empty list',async()=>{
  for(const reply of [{error:'offline',data:null},{error:null,data:[{name:'remaining'}]},{error:null,data:null}]){
    const result=await completePhotoCleanup(new Set([key]),{remove:async()=>({error:null}),list:async()=>reply});
    assert.equal(result.errors.length,1);
  }
});
test('throwing deletion still performs readback; empty ownership makes no requests',async()=>{
  let reads=0;
  const result=await completePhotoCleanup(new Set([key]),{remove:async()=>{throw Error('transport');},list:async()=>{reads++;return{error:null,data:[]};}});
  assert.equal(reads,1);assert.equal(result.errors.length,1);
  await completePhotoCleanup(new Set(),{remove:async()=>{throw Error('unexpected');},list:async()=>{throw Error('unexpected');}});
});
test('journal failure latches ordinary requests before transport',async()=>{
  let stopped=false,transports=0;
  await assert.rejects(executePhotoDispatch(scope(),{
    prepare:()=>{throw Error('journal write failed');},transport:async()=>{transports++;},complete:async()=>{},
    stop:()=>{stopped=true;},failed:()=>{assert(stopped);},
  }),/journal write failed/);
  assert(stopped);assert.equal(transports,0);
});
test('HTTP failure latches ordinary traffic; cleanup failure does not stop reserved readback',async()=>{
  for(const isCleanup of [false,true]){
    const s=scope();s.cleanup=isCleanup;let stopped=false;
    await assert.rejects(executePhotoDispatch(s,{
      prepare:()=>{},transport:async()=>({ok:false}),complete:async()=>{throw Error('PHOTO_PROVIDER_HTTP_500');},
      stop:()=>{stopped=true;},failed:()=>{},
    }),/HTTP_500/);
    assert.equal(stopped,!isCleanup);
  }
});

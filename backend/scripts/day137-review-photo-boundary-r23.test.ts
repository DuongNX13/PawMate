import assert from 'node:assert/strict';import test from 'node:test';
import {classifyPhotoRequest,type PhotoScope} from './day137-review-photo-boundary-r23';
const id='12345678-1234-1234-1234-123456789012',runId='d137-review-photo-20261005-r23',key=`${id}/${id}/123-${id}-${runId}.png`;
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

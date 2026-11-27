import assert from 'node:assert/strict';import test from 'node:test';import fs from 'node:fs';import path from 'node:path';
import type {AppConfig} from '../src/config/env';import {createSupabaseAdminClient} from '../src/infrastructure/supabase-admin-client';
import {uploadReviewPhoto} from '../src/infrastructure/review-photo-storage';import {classifyPhotoRequest,type PhotoScope}from'./day137-review-photo-boundary-r27';
test('real installed production SDK emits allowlisted upload/download/delete/list shapes without network',async()=>{
  const config={supabaseUrl:'https://qeoowayxfqyhfcgnrfnv.supabase.co',supabaseServiceRoleKey:'synthetic-test-not-a-credential',supabaseBuckets:{reviewPhotos:'review-photos'}} as AppConfig,id='12345678-1234-1234-1234-123456789012',runId='d137-review-photo-preflight-r27';
  const bytes=fs.readFileSync(path.resolve(__dirname,'../../output-evidence/security/day137/d137-local-private-20261005-r20/fixture.png'));
  const scope:PhotoScope={origin:new URL(config.supabaseUrl!).origin,bucket:config.supabaseBuckets.reviewPhotos??'review-photos',vetId:id,userIds:[id],runId,ownedKeys:new Set(),cleanup:false};
  const original=globalThis.fetch,seen:string[]=[];
  globalThis.fetch=async(input:any,init:any={})=>{
    const url=typeof input==='string'?input:input.url,method=init.method??input.method??'GET';
    const c=classifyPhotoRequest(scope,url,method,init.body,new Headers(init.headers??input.headers));seen.push(c.kind);
    if(c.kind==='upload'){assert.deepEqual(Buffer.from(init.body),bytes);scope.ownedKeys.add(c.key!);return new Response(JSON.stringify({Id:id,Key:scope.bucket+'/'+c.key}),{status:200});}
    if(c.kind==='download')return new Response(bytes,{status:200,headers:{'content-type':'image/png'}});
    return new Response('[]',{status:200,headers:{'content-type':'application/json'}});
  };
  try{const photo=await uploadReviewPhoto(config,id,id,{fileName:runId+'.png',contentType:'image/png',base64Data:bytes.toString('base64')});
    assert.equal(photo.storage,'supabase');const client=createSupabaseAdminClient(config)!;
    const file=await client.storage.from(scope.bucket).download(photo.path);assert.equal(file.error,null);
    assert.deepEqual(Buffer.from(await file.data!.arrayBuffer()),bytes);scope.cleanup=true;
    assert.equal((await client.storage.from(scope.bucket).remove([...scope.ownedKeys])).error,null);
    assert.deepEqual((await client.storage.from(scope.bucket).list(id,{limit:10,offset:0})).data,[]);
    assert.deepEqual(seen,['upload','download','delete','list']);
  }finally{globalThis.fetch=original;}
});

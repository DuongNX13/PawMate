import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs';import os from 'node:os';import path from 'node:path';
import {createProviderGuard} from './day137-provider-guard.mjs';
import {initializeBudget,claimRequest} from './day137-request-budget-r3.mjs';
const emails=Array.from({length:5},(_,i)=>`fixture-${i}@pawmate.test`),buckets=['rescue-media-staging','rescue-media-public','adoption-chat-media-private'];
const url=p=>new URL('https://qeoowayxfqyhfcgnrfnv.supabase.co'+p);
test('positive full allowlist with owned auth, ticket, original and derivative',()=>{
 const g=createProviderGuard({emails,buckets});const id='11111111-1111-4111-8111-111111111111';
 assert.equal(g.check(url('/auth/v1/admin/generate_link'),'POST',{type:'signup',email:emails[0]}),'auth_generate_owned_no_email');
 g.ownAuth(id);g.ownToken('fixture-owned-token');g.check(url('/auth/v1/verify'),'POST',{type:'signup',token_hash:'fixture-owned-token'});
 g.ticket(buckets[0],'a/b/original.png');g.check(url('/storage/v1/object/upload/sign/'+buckets[0]+'/a/b/original.png'),'POST',{});
 g.object(buckets[0],'a/b/original.png');g.check(url('/storage/v1/object/upload/sign/'+buckets[0]+'/a/b/original.png?token=redacted'),'PUT');
 g.object(buckets[1],'rescue_case/b/hash/public.png');g.check(url('/storage/v1/object/'+buckets[1]+'/rescue_case/b/hash/public.png'),'POST');
 g.setCleanup();g.check(url('/auth/v1/admin/users/'+id),'DELETE');g.check(url('/storage/v1/object/'+buckets[1]),'DELETE',{prefixes:['rescue_case/b/hash/public.png']});
 g.check(url('/storage/v1/object/list/'+buckets[1]),'POST',{prefix:'rescue_case/b/hash',limit:10});
});
for(const [name,p,m,b] of [
 ['email dispatch','/auth/v1/signup','POST',{}],['unknown user','/auth/v1/admin/users/22222222-2222-4222-8222-222222222222','DELETE',{}],
 ['wrong email','/auth/v1/admin/generate_link','POST',{type:'signup',email:'user@example.com'}],
 ['wrong OTP','/auth/v1/verify','POST',{type:'signup',token_hash:'foreign'}],['bucket update','/storage/v1/bucket/rescue-media-public','PUT',{}],
 ['bucket creation','/storage/v1/bucket','POST',{}],['foreign object','/storage/v1/object/rescue-media-public/foreign','POST',{}],
 ['whole bucket deletion','/storage/v1/object/rescue-media-public','DELETE',{prefixes:['']}],['unbounded list','/storage/v1/object/list/rescue-media-public','POST',{prefix:'',limit:1000}],
 ['database REST','/rest/v1/users','POST',{}]
])test('deny '+name,()=>assert.throws(()=>createProviderGuard({emails,buckets}).check(url(p),m,b)));
test('two-object ceiling and duplicate account generation',()=>{const g=createProviderGuard({emails,buckets});g.object(buckets[0],'a');g.object(buckets[1],'b');assert.throws(()=>g.object(buckets[0],'c'));g.check(url('/auth/v1/admin/generate_link'),'POST',{type:'signup',email:emails[0]});assert.throws(()=>g.check(url('/auth/v1/admin/generate_link'),'POST',{type:'signup',email:emails[0]}));});
test('budget request/deadline/reserve/closed and no reset',()=>{
 const d=fs.mkdtempSync(path.join(os.tmpdir(),'d137-budget-test-'));try{
 const env=JSON.parse(fs.readFileSync(new URL('../../output-evidence/security/day137/d137-provider-20261002-r1/envelope.json',import.meta.url),'utf8'));
 const p=path.join(d,'envelope.json');fs.writeFileSync(p,JSON.stringify(env));const f=initializeBudget(p,1000);assert.throws(()=>initializeBudget(p,1000));
 let s=claimRequest(p,'cloud',false,1001);assert.equal(s.total,1);s.total=760;s.runtime=759;fs.writeFileSync(f,JSON.stringify(s));assert.throws(()=>claimRequest(p,'runtime',false,1002));claimRequest(p,'cloud',true,3000000);
 s=JSON.parse(fs.readFileSync(f));s.closedAt='closed';fs.writeFileSync(f,JSON.stringify(s));assert.throws(()=>claimRequest(p,'cloud',true,1004));
 }finally{fs.rmSync(d,{recursive:true});}
});

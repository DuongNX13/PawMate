// Test-only native review-photo SDK proof; exact owned images, no product edits.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash, createHmac, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';
import { buildApp } from '../src/app';
import { createDay137PhotoVetService } from './day137-review-photo-vet-factory-r27';
import { loadEnv, resolveAuthJwtConfig } from '../src/config/env';
import { getRedisClient } from '../src/infrastructure/redis';
import { createAuthService } from '../src/services/auth/auth-service';
import { PrismaAuthUserStore } from '../src/repositories/prisma-auth-user-store';
import { RedisAuthSessionStore } from '../src/repositories/redis-auth-session-store';
import { createActionQuotaGuard, ACTION_QUOTA_POLICIES } from '../src/security/distributed-action-quota';
import { RedisActionQuotaStore } from '../src/security/redis-action-quota-store';
import { buildDay137ProductionConfig, validateDay137EffectiveConfigs } from './day137-bootstrap-r20';
import { claimRequest, assertBudgetActive, stopOrdinary } from './day137-review-photo-budget-r27.mjs';
import { preparePhotoDispatch, completePhotoCleanup, executePhotoDispatch, type PhotoScope } from './day137-review-photo-boundary-r27';
import { createSupabaseAdminClient } from '../src/infrastructure/supabase-admin-client';
import { snapshotContract } from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';

const root=path.resolve(__dirname,'../..'),out=process.env.DAY137_EVIDENCE_ROOT!,runId=process.env.DAY137_RUN_ID!,envelope=process.env.DAY137_ENVELOPE_PATH!,db=process.env.DATABASE_URL!,redisUrl=process.env.REDIS_URL!;
assertBudgetActive(envelope);
assert(/^d137-review-photo-[a-z0-9-]{6,28}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root,'output-evidence/security/day137')+path.sep));
assert.equal(new URL(db).hostname,'127.0.0.1'); assert.equal(new URL(redisUrl).hostname,'127.0.0.1');
const sha=(b:Buffer|string)=>createHash('sha256').update(b).digest('hex');
function safeError(error:unknown){
  let text=String(error);
  for(const secret of [config.supabaseServiceRoleKey,config.supabaseAnonKey,config.auth.accessTokenSecret,config.auth.refreshTokenSecret])if(secret)text=text.replaceAll(secret,'[REDACTED]');
  return text.replace(/eyJ[\w-]+\.[\w-]+\.[\w-]+/g,'[REDACTED]').replace(/([?&]token=)[^\s"&]+/g,'$1[REDACTED]');
}
const write=(n:string,v:any)=>fs.writeFileSync(path.join(out,n),JSON.stringify(v,(_key,value)=>typeof value==='string'?safeError(value):value,2)+'\n');
const ref=(n:string)=>{const b=fs.readFileSync(path.join(out,n));return{path:path.relative(root,path.join(out,n)).replaceAll('\\','/'),bytes:b.length,sha256:sha(b)};};
const envelopeContract=JSON.parse(fs.readFileSync(envelope,'utf8'));
const source=JSON.parse(fs.readFileSync(path.join(root,envelopeContract.sourceManifest.path),'utf8'));
assert.equal(source.sourceFingerprint,envelopeContract.sourceFingerprint);
const sourceFingerprint=source.sourceFingerprint,producerHash=sha(fs.readFileSync(__filename));
function checkSource(){for(const f of source.files){const b=fs.readFileSync(path.join(root,f.path));assert.equal(b.length,f.bytes);assert.equal(sha(b),f.sha256);}}
checkSource();
const config=buildDay137ProductionConfig(loadEnv(),db,redisUrl);
const schema=fs.readFileSync(path.join(root,'backend/prisma/schema.prisma'),'utf8'),contract=snapshotContract(schema);
const psql=path.join(root,'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const pgArgs=['-h','127.0.0.1','-p',new URL(db).port,'-U','pawmate','-d',new URL(db).pathname.slice(1),'-At','-v','ON_ERROR_STOP=1'];
const sql=(q:string)=>JSON.parse(execFileSync(psql,[...pgArgs,'-c',q],{encoding:'utf8',timeout:10000}).trim());
const snapshot=()=>sql(contract.query);
const redisCli=path.join(root,'output-evidence/day67/portable-redis/redis-3.0.504/redis-cli.exe');
const redisArgs=['-h','127.0.0.1','-p',new URL(redisUrl).port,'--raw'];
const rc=(...args:string[])=>execFileSync(redisCli,[...redisArgs,...args],{encoding:'utf8',timeout:10000}).trim();
const prisma=new PrismaClient({datasources:{db:{url:db}}});
const redis=new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0});
const ownedClients:Redis[]=[redis],apps:any[]=[],cases:any[]=[],sessions:Record<string,any>={};
const roles=['owner_adopter','outsider','shelter_A','shelter_B'];
const f:any={users:Object.fromEntries(roles.map(r=>[r,randomUUID()])),authUser:randomUUID(),thread:randomUUID(),request:randomUUID(),listing:randomUUID(),hero:randomUUID(),media:randomUUID(),message:randomUUID(),vet:randomUUID(),reviews:roles.map(()=>randomUUID())};
const photoRoles=['anonymous',...roles];
const ids=photoRoles.map(role=>'D137-R27-photo-'+role);
let app:any,current:any,failure:any,runtimeCalls=0,cloudAttempts=0;
const originalFetch=globalThis.fetch;
const fixtureBytes=fs.readFileSync(path.join(root,'output-evidence/security/day137/d137-local-private-20261005-r20/fixture.png'));
assert.equal(sha(fixtureBytes),'502710ef2d0517db28cbe203db1d31d78e503fce0b02f1147ee7e658b11f4fe0');
const bucket=config.supabaseBuckets.reviewPhotos ?? 'review-photos';
assert.match(bucket,/^[a-z0-9-]+$/);assert.equal(new URL(config.supabaseUrl!).origin,'https://qeoowayxfqyhfcgnrfnv.supabase.co');
const scope:PhotoScope={origin:new URL(config.supabaseUrl!).origin,bucket,vetId:f.vet,userIds:Object.values(f.users),runId,ownedKeys:new Set(),cleanup:false};
const cloudJournal:any[]=[];
globalThis.fetch=async(input:any,init:any={})=>{
  const url=typeof input==='string'?input:input instanceof URL?input.href:input.url;
  const method=(init.method??input.method??'GET').toUpperCase(),headers=new Headers(init.headers??input.headers);
  let entry:any;
  return executePhotoDispatch(scope,{
    prepare:()=>{
      const native=preparePhotoDispatch(scope,url,method,init.body,headers,fixtureBytes,{
        claim:cleanup=>{claimRequest(envelope,'cloud',cleanup);},
        stop:reason=>stopOrdinary(envelope,reason),
      });cloudAttempts++;
      write('owned-object-attempts.json',{runId,registeredOwnedKeys:[...scope.ownedKeys],registeredBeforeDispatch:true});
      entry={ordinal:cloudAttempts,...native,method,path:new URL(url).pathname,startedAt:new Date().toISOString(),headersRedacted:true};
      if(native.kind==='upload'){entry.uploadByteSha256=sha(fixtureBytes);entry.upsert=false;}
      cloudJournal.push(entry);write('provider-journal.json',{runId,sourceFingerprint,producerHash,cloudJournal});
    },
    transport:()=>originalFetch(input,{...init,signal:AbortSignal.timeout(30000),redirect:'error'}),
    complete:async response=>{
      entry.status=response.status;entry.endedAt=new Date().toISOString();entry.responseByteSha256=sha(Buffer.from(await response.clone().arrayBuffer()));
      write('provider-journal.json',{runId,sourceFingerprint,producerHash,cloudJournal});
      assert(response.ok,'PHOTO_PROVIDER_HTTP_'+response.status);
    },
    stop:reason=>stopOrdinary(envelope,reason),
    failed:error=>{if(entry){entry.error=safeError(error);entry.endedAt=new Date().toISOString();write('provider-journal.json',{runId,sourceFingerprint,producerHash,cloudJournal});}},
  });
};
function save(){write('state-results.json',{schemaVersion:1,runId,sourceFingerprint,producerHash,requiredStates:ids,cases,runtimeCalls,cloudAttempts,fullDay137Acceptance:false});}
async function call(method:string,url:string,role:string,payload?:any,headers:any={},target=app){
  claimRequest(envelope);runtimeCalls++;
  const action:any={id:current?`${current.id}#${current.actions.length+1}`:`setup#${runtimeCalls}`,method,url,role,startedAt:new Date().toISOString()};
  current?.actions.push(action);
  const response=await target.inject({method,url,payload,headers:{...(role==='anonymous'?{}:{authorization:`Bearer ${sessions[role].accessToken}`}),...headers}});
  action.endedAt=new Date().toISOString();action.status=response.statusCode;action.headers={cacheControl:response.headers['cache-control'],retryAfter:response.headers['retry-after'],contentType:response.headers['content-type']};
  const body=response.json();
  if(body.accessToken||body.refreshToken){
    const jwtConfig=resolveAuthJwtConfig(config);
    action.body={...body,accessToken:'[MEMORY_ONLY]',refreshToken:'[MEMORY_ONLY]'};
    for(const type of ['access','refresh']){
      const verified=jwt.verify(body[type+'Token'],type==='access'?config.auth.accessTokenSecret:config.auth.refreshTokenSecret,{algorithms:['HS256'],issuer:jwtConfig.issuer,audience:jwtConfig.audience});
      action[type+'Claims']=verified;action[type+'CryptoVerified']=true;
    }
  }else action.body=body;
  save();return response;
}
const success=(r:any,status:number)=>{assert.equal(r.statusCode,status);return r.json();};
const denied=(r:any,status:number,code:string)=>{assert.equal(r.statusCode,status);const b=r.json();assert.equal(b.success,false);assert.equal(b.error.code,code);assert.equal(typeof b.error.message,'string');assert.equal(typeof b.requestId,'string');assert(!JSON.stringify(b).includes('supabase'));return b;};
async function journey(id:string,fn:()=>Promise<void>){
  current={id,runId,sourceFingerprint,producerHash,startedAt:new Date().toISOString(),actions:[],verdict:'NOT_RUN',sqlBefore:snapshot(),native:{}};
  cases.push(current);save();
  try{await fn();current.sqlAfter=snapshot();current.verdict='PASS';}
  catch(e){current.sqlAfter=snapshot();current.verdict='FAIL';current.failure=safeError(e);throw e;}
  finally{current.endedAt=new Date().toISOString();write(id.replaceAll(':','-')+'-checkpoint.json',current);current.checkpointRef=ref(id.replaceAll(':','-')+'-checkpoint.json');save();current=undefined;}
}
const equalSql=()=>assert.deepEqual(snapshot(),current.sqlBefore);
function counter(action:string,dimension:string,value:string,window:number){
  const hmacKey=createHmac('sha256',config.auth.accessTokenSecret).update('pawmate-abuse-key-v1').digest();
  const identity=createHmac('sha256',hmacKey).update(dimension+'\u0000'+value.trim()).digest('hex');
  const seconds=Number(rc('time').split(/\r?\n/)[0]),bucket=Math.floor(seconds/window);
  const key=`pawmate:q:v1:${action}:${dimension}:${window}:${identity}:${bucket}`;
  return{key,value:Number(rc('get',key)||0),ttlSeconds:Number(rc('ttl',key)),redisSeconds:seconds,bucket,command:[redisCli,...redisArgs,'get',key]};
}
function authRows(userId:string){
  const indexKey='auth:user-sessions:'+userId;
  const list=rc('zrange',indexKey,'0','-1');const sids=list?list.split(/\r?\n/):[];
  return{indexKey,indexTtlMs:Number(rc('pttl',indexKey)),sessions:sids.map(sid=>({key:'auth:session:'+sid,fields:JSON.parse(rc('get','auth:session:'+sid)),ttlMs:Number(rc('pttl','auth:session:'+sid))})),oracle:'independent redis-cli GET/ZRANGE/PTTL'};
}
async function seed(){
  const stamp=new Date('2026-09-01T00:00:00Z'),password='Day137Synthetic!2026';
  await prisma.user.createMany({data:[...roles.map(role=>({id:f.users[role],email:`${runId}-${role.toLowerCase()}@pawmate.test`,passwordHash:bcrypt.hashSync(password,4),displayName:role,emailVerified:true})),{id:f.authUser,email:`${runId}-refresh@pawmate.test`,passwordHash:bcrypt.hashSync(password,4),displayName:'Synthetic refresh',emailVerified:true}]});
  for(const role of roles){const r=await call('POST','/auth/login','anonymous',{email:`${runId}-${role.toLowerCase()}@pawmate.test`,password});sessions[role]=success(r,200);}
  await prisma.mediaAsset.create({data:{id:f.hero,ownerUserId:f.users.shelter_A,purpose:'adoption_listing',mimeType:'image/png',sizeBytes:114,sha256:'0'.repeat(64),status:'attached',storageKey:runId+'/hero.png',publicUrl:'https://fixtures.invalid/hero.png'}});
  await prisma.adoptionListing.create({data:{id:f.listing,shelterId:f.users.shelter_A,heroMediaId:f.hero,petName:'Synthetic',species:'dog',ageLabel:'2 years',status:'available',traits:[],healthBadges:[],verificationBadges:[],createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionRequest.create({data:{id:f.request,listingId:f.listing,adopterUserId:f.users.owner_adopter,shelterId:f.users.shelter_A,livingCondition:'Synthetic',petExperience:'Synthetic',carePlan:'Synthetic',commitmentAccepted:true,status:'submitted',createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionChatThread.create({data:{id:f.thread,requestId:f.request,adopterUserId:f.users.owner_adopter,shelterId:f.users.shelter_A,createdAt:stamp,updatedAt:stamp}});
  await prisma.adoptionChatParticipant.createMany({data:['owner_adopter','shelter_A'].map(r=>({threadId:f.thread,userId:f.users[r],role:r==='owner_adopter'?'adopter':'shelter',lastReadAt:stamp,lastReadSequence:0n,createdAt:stamp,updatedAt:stamp}))});
  await prisma.adoptionChatMessage.create({data:{id:f.message,threadId:f.thread,senderUserId:f.users.owner_adopter,body:'Synthetic private photo',createdAt:stamp,updatedAt:stamp}});
  await prisma.mediaAsset.create({data:{id:f.media,ownerUserId:f.users.owner_adopter,purpose:'adoption_chat',mimeType:'image/png',sizeBytes:114,sha256:'0'.repeat(64),status:'attached',storageKey:`adoption_chat/${f.thread}/${f.media}/fixture/private.png`,publicUrl:null,adoptionChatMessageId:f.message,position:0}});
  await prisma.$executeRawUnsafe("INSERT INTO vets(id,external_id,name,address,city,district,location,opening_hours,is_24h,average_rating,review_count,source_rank,ready_for_map,created_at,updated_at) VALUES($1::uuid,$2,'Synthetic Vet','Synthetic address','Test city','Test district',ST_SetSRID(ST_MakePoint(106.7009,10.7769),4326)::geography,'[]'::jsonb,false,5,4,1,true,$3,$3)",f.vet,f.vet,stamp);
  await prisma.review.createMany({data:roles.map((role,i)=>({id:f.reviews[i],vetId:f.vet,userId:f.users[role],rating:5,body:'Owned quota fixture',photoUrls:[],createdAt:stamp,updatedAt:stamp}))});
  write('fixture.json',{runId,sourceFingerprint,values:f,privateObjectUploaded:false,privateStateScope:'membership denial only; object bytes are not claimed'});
}
async function run(){
  process.chdir(out);write('producer-ownership.json',{runId,pid:process.pid,startedAt:new Date().toISOString(),argv:process.argv,producerHash});write('effective-config-validation.json',validateDay137EffectiveConfigs({reviewPhoto:config}));
  app=buildApp({logger:false},{config,vetService:createDay137PhotoVetService(root,prisma)});apps.push(app);await app.ready();await redis.connect();
  assert.equal(await redis.dbsize(),0);assert(Object.values(snapshot()).every((t:any)=>t.count===0));
  write('plan.json',{runId,sourceFingerprint,producerHash,cases:photoRoles.map((role,i)=>({id:ids[i],canonicalRequirementId:'D137-C060-'+role+'-baseline',role,method:'POST',url:'/vets/'+f.vet+'/reviews/photos',expectedStatus:role==='anonymous'?401:201})),cloudCallsMax:10,sqlQuery:contract.query,fixtureByteSha256:sha(fixtureBytes),realBoundaries:['native auth','native quota','native Vet repository','native review-photo SDK','owned SQL/Redis','real Supabase object upload/download'],prohibited:['bucket/policy/auth/control-plane mutation','existing-object access'],rollback:'batch delete exactly registered upload attempts, including ambiguous failures; independently list only owned fixture Vet prefix; no metadata mutation claim'});
  await seed();
  const provider=createSupabaseAdminClient(config)!;assert(provider);
  for(const [i,role]of photoRoles.entries()){
    await journey(ids[i],async()=>{
      const beforeCloud=cloudAttempts;
      const r=await call('POST','/vets/'+f.vet+'/reviews/photos',role,{fileName:runId+'.png',contentType:'image/png',base64Data:fixtureBytes.toString('base64')});
      if(role==='anonymous'){denied(r,401,'REVIEW_005');assert.equal(cloudAttempts,beforeCloud);equalSql();current.native={providerCallsDelta:0};return;}
      const b=success(r,201);assert.deepEqual(Object.keys(b),['data']);assert.deepEqual(Object.keys(b.data).sort(),['contentType','path','sizeBytes','storage','url']);
      const d=b.data;assert.equal(d.storage,'supabase');assert.equal(d.contentType,'image/png');assert.equal(d.sizeBytes,fixtureBytes.length);
      const parts=d.path.split('/');assert.equal(parts[0],f.vet);assert.equal(parts[1],f.users[role]);assert(scope.ownedKeys.has(d.path));assert.equal(parts.length,3);assert(parts[2].endsWith(runId+'.png'));
      const expectedUrl=new URL('/storage/v1/object/public/'+bucket+'/'+d.path,scope.origin).href;assert.equal(d.url,expectedUrl);
      const object=await provider.storage.from(bucket).download(d.path);assert.equal(object.error,null);assert(object.data);
      const remoteBytes=Buffer.from(await object.data.arrayBuffer());assert.equal(remoteBytes.length,fixtureBytes.length);assert.equal(sha(remoteBytes),sha(fixtureBytes));assert.deepEqual(remoteBytes,fixtureBytes);
      assert.equal(cloudAttempts-beforeCloud,2);equalSql();
      const auth=authRows(f.users[role]);assert(auth.sessions.length>0&&auth.sessions.every((x:any)=>!x.fields.revokedAt));
      current.native={callerUserId:f.users[role],bucket,objectPath:d.path,returnedDto:d,providerCallsDelta:2,remoteByteSha256:sha(remoteBytes),remoteByteCount:remoteBytes.length,auth,sqlEffect:'all28 table snapshots unchanged; native API stores only object',bucketMetadataDiff:'NOT_MEASURED; allowlist prohibits bucket/policy operations'};
    });
  }
  assert.equal(cases.length,5);assert(cases.every(c=>c.verdict==='PASS'));assert.equal(cloudAttempts,8);checkSource();
  write('native-state-summary.json',{runId,sourceFingerprint,producerHash,casesPassed:5,runtimeCalls,cloudCalls:cloudAttempts,fullDay137Acceptance:false,baselineBindingsAdded:5,verdict:'PASS_FIVE_NATIVE_REVIEW_PHOTO_CASES'});
}
run().catch(e=>{failure=e;console.error(safeError(e));process.exitCode=1;}).finally(async()=>{
  save();
  try{
    scope.cleanup=true;const provider=createSupabaseAdminClient(config)!;
    const result=await completePhotoCleanup(scope.ownedKeys,{
      remove:keys=>provider.storage.from(bucket).remove(keys),
      list:()=>provider.storage.from(bucket).list(f.vet,{limit:10,offset:0}),
    });
    write('provider-cleanup.json',{runId,sourceFingerprint,registeredOwnedKeys:[...scope.ownedKeys],...result,cloudCalls:cloudAttempts,verdict:result.errors.length?'BLOCKED':'PASS_EXACT_OWNED_OBJECT_DELETE_AND_PREFIX_READBACK',bucketPolicyMutations:0,metadataDiffVerified:false});
    if(result.errors.length){console.error('PROVIDER_CLEANUP:'+result.errors.map(safeError).join('; '));process.exitCode=1;}
  }catch(e){console.error('PROVIDER_CLEANUP:'+safeError(e));process.exitCode=1;write('provider-cleanup.json',{runId,verdict:'BLOCKED',error:safeError(e),registeredOwnedKeys:[...scope.ownedKeys],cloudCalls:cloudAttempts});}
  try{const before=snapshot();await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.map(t=>'"'+t+'"').join(',')} CASCADE`);const after=snapshot();const keys=await redis.keys('*');if(keys.length)await redis.del(...keys);assert(Object.values(after).every((t:any)=>t.count===0));assert.equal(await redis.dbsize(),0);checkSource();write('fixture-cleanup.json',{runId,sourceFingerprint,sqlBefore:before,sqlAfter:after,remainingRows:0,redisRemaining:0,cloudCalls:cloudAttempts,verdict:'PASS'});}catch(e){console.error('CLEANUP:'+safeError(e));process.exitCode=1;}
  for(const a of [...apps].reverse()){try{await a.close();}catch(e){console.error('APP_CLOSE:'+safeError(e));process.exitCode=1;}}
  await prisma.$disconnect();for(const client of ownedClients)client.disconnect();globalThis.fetch=originalFetch;
  if(failure)write('first-failure.json',{at:new Date().toISOString(),error:safeError(failure)});
  write('producer-terminal.json',{runId,pid:process.pid,endedAt:new Date().toISOString(),exitCode:process.exitCode??0,producerHash});
});

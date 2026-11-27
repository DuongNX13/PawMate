// Test-only: real production gateway/storage/routes with isolated SQL and Redis.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash,randomUUID,randomBytes} from 'node:crypto';
import fs from 'node:fs';import path from 'node:path';
import bcrypt from 'bcryptjs';import {PrismaClient} from '@prisma/client';import Redis from 'ioredis';
import {createClient} from '@supabase/supabase-js';
import {buildApp} from '../src/app';import {loadEnv} from '../src/config/env';
import {buildTestConfig} from '../tests/helpers/rescue-read-fixtures';
import {createSupabaseEmailVerificationGateway} from '../src/integrations/supabase-auth-gateway';
import {createSupabaseRescueMediaStorage} from '../src/infrastructure/rescue-media-storage';
import {claimRequest} from './day137-request-budget-r3.mjs';
import {createProviderGuard} from './day137-provider-guard.mjs';
import {makeProviderPng} from './day137-provider-fixture.mjs';
const root=path.resolve(__dirname,'../..'),out=process.env.DAY137_EVIDENCE_ROOT!,runId=process.env.DAY137_RUN_ID!;
const db=process.env.DATABASE_URL!,redisUrl=process.env.REDIS_URL!,envelope=process.env.DAY137_ENVELOPE_PATH!;
assert(/^d137-local-[a-z0-9-]{6,40}$/.test(runId));assert(path.resolve(out).startsWith(path.join(root,'output-evidence/security/day137')+path.sep));
assert.equal(new URL(db).hostname,'127.0.0.1');assert.equal(new URL(redisUrl).hostname,'127.0.0.1');
const entry=JSON.parse(fs.readFileSync(path.join(root,'output-evidence/security/day137/d137-entry-20261001-r1/contract.json'),'utf8'));
const write=(name:string,data:any)=>{const text=JSON.stringify(data,null,2)+'\n';assert.deepEqual(JSON.parse(text),data);fs.writeFileSync(path.join(out,name),text);};
const hash=(v:string|Buffer)=>createHash('sha256').update(v).digest('hex'),digest=(v:any)=>hash(JSON.stringify(v));
const psql=path.join(root,'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const sql=(q:string)=>JSON.parse(execFileSync(psql,['-h','127.0.0.1','-p',new URL(db).port,'-U','pawmate','-d',new URL(db).pathname.slice(1),'-At','-v','ON_ERROR_STOP=1','-c',q],{encoding:'utf8',timeout:10000}).trim());
const tables=[...fs.readFileSync(path.join(root,'backend/prisma/schema.prisma'),'utf8').matchAll(/@@map\("([a-z_]+)"\)/g)].map(m=>m[1]);
const snapshot=()=>sql(`SELECT jsonb_object_agg(name,value) FROM (${tables.map(t=>`SELECT '${t}' AS name,jsonb_build_object('count',count(*),'contentHash',md5(coalesce(string_agg(row_to_json(t)::text,'' ORDER BY row_to_json(t)::text),''))) AS value FROM "${t}" t`).join(' UNION ALL ')}) s;`);
const prisma=new PrismaClient({datasources:{db:{url:db}}}),redis=new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0});
const roles=['owner_adopter','outsider','shelter_A','shelter_B'],contexts=['anonymous',...roles];
const users=Object.fromEntries(roles.map(r=>[r,randomUUID()])),sessions:Record<string,any>={};
const fixtureEmails=contexts.map((_,i)=>`${runId}-verify-${i}-${randomBytes(5).toString('hex')}@pawmate.test`);
const fixturePassword='Qa-'+randomBytes(18).toString('hex')+'-1';
const provider=loadEnv();assert.equal(new URL(provider.supabaseUrl!).hostname,'qeoowayxfqyhfcgnrfnv.supabase.co');
const config={...buildTestConfig(),nodeEnv:'production' as const,databaseUrl:db,redisUrl,
 supabaseUrl:provider.supabaseUrl,supabaseAnonKey:provider.supabaseAnonKey,supabaseServiceRoleKey:provider.supabaseServiceRoleKey,supabaseBuckets:provider.supabaseBuckets,
 features:{rescueBrowse:true,rescueCreate:true},auth:{...buildTestConfig().auth,accessTokenSecret:'day137-local-only-access-fixture-20261001',refreshTokenSecret:'day137-local-only-refresh-fixture-20261001'}};
const buckets=[config.supabaseBuckets.rescueMediaStaging??'rescue-media-staging',config.supabaseBuckets.rescueMediaPublic??'rescue-media-public',config.supabaseBuckets.adoptionChatMediaPrivate??'adoption-chat-media-private'];
const guard=createProviderGuard({emails:fixtureEmails,buckets});
let cleanupMode=false,requestCount=0,failure:any;const cloudRequests:any[]=[],cases:any[]=[],fieldAssertions:any[]=[],routes:any[]=[];
const persistOwned=()=>write('owned-provider-fixtures.json',{runId,auth:[...guard.authIds],attemptedEmailHashes:[...guard.attemptedEmails].map(hash),ticketPaths:[...guard.ticketKeys].map(([key,bucket])=>({key,bucket})),objects:[...guard.objects].map(([key,bucket])=>({key,bucket})),maxAuth:5,maxObjects:2});
const nativeFetch=globalThis.fetch;
const countedFetch:typeof fetch=async(input,init)=>{
 const url=new URL(typeof input==='string'?input:input instanceof URL?input.href:input.url);
 const method=(init?.method??(typeof input==='object'&&'method' in input?input.method:'GET')).toUpperCase();
 let body:any; if(typeof init?.body==='string'){try{body=JSON.parse(init.body);}catch{throw new Error('NON_JSON_PROVIDER_BODY');}}
 const operation=guard.check(url,method,body);persistOwned();claimRequest(envelope,'cloud',cleanupMode);
 const c:any={runId,id:cloudRequests.length+1,operation,method,path:url.pathname,startedAt:new Date().toISOString(),cleanup:cleanupMode,verdict:'NOT_RUN'};cloudRequests.push(c);write('cloud-requests.json',cloudRequests);
 try{const r=await nativeFetch(input,{...init,signal:init?.signal??AbortSignal.timeout(15000),redirect:'error'});c.status=r.status;c.verdict='OBSERVED';return r;}
 catch{c.verdict='TRANSPORT_FAILURE';throw new Error('PROVIDER_TRANSPORT_FAILURE:'+operation);}
 finally{c.endedAt=new Date().toISOString();write('cloud-requests.json',cloudRequests);}
};
globalThis.fetch=countedFetch;
const cloud=createClient(config.supabaseUrl!,config.supabaseServiceRoleKey!,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:countedFetch}});
const anon=createClient(config.supabaseUrl!,config.supabaseAnonKey!,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:countedFetch}});
const gateway=createSupabaseEmailVerificationGateway(config,{authClient:anon.auth,adminClient:cloud})!;
const productionStorage=createSupabaseRescueMediaStorage(config,cloud,{bucketSetupMode:'verify_existing'})!;
const expectedPublic=new Set<string>();
const storage={...productionStorage,async writePublicObject(key:string,bytes:Buffer,mime:any){assert(expectedPublic.has(key),'SOURCE_BOUND_DERIVATIVE_KEY');guard.object(buckets[1],key);persistOwned();return productionStorage.writePublicObject(key,bytes,mime);}};
const app=buildApp({logger:false},{config,emailVerificationGateway:gateway,rescueMediaStorage:storage});
app.addHook('onRoute',o=>{for(const method of Array.isArray(o.method)?o.method:[o.method])if(method!=='HEAD')routes.push({method,path:o.url});});
const save=()=>write('cross-role-results.json',{schemaVersion:1,runId,sourceFingerprint:entry.sourceFingerprint,transport:'Fastify inject production handlers; real SQL/PostGIS/Redis and guarded real Supabase provider',limitations:['Not deployed HTTP transport; full state-family contract and branch coverage are separate gates'],requestCount,maxRequests:800,cases});
const fields=(id:string,actual:any,expected:any)=>{assert.deepEqual(actual,expected,id);fieldAssertions.push({id,runId,actual,expected,verdict:'PASS',at:new Date().toISOString()});write('field-assertions.json',fieldAssertions);};
const call=async(method:any,url:string,role='anonymous',payload?:any,headers?:any)=>{
 claimRequest(envelope,'runtime');requestCount++;return app.inject({method,url,...(payload===undefined?{}:{payload}),headers:{...(role==='anonymous'?{}:{authorization:'Bearer '+sessions[role].accessToken}),...headers}});
};
const perform=async(id:string,role:string,method:any,url:string,expected:number,payload?:any,verify?:(r:any)=>Promise<void>|void,headers?:any)=>{
 assert(!cases.some(c=>c.id===id));const before=snapshot();const c:any={id,runId,sourceFingerprint:entry.sourceFingerprint,role,method,url,expected,basis:'production source-bound provider/caller/persistence assertion',precondition:{fixtureUsers:users,beforeSqlHash:digest(before)},startedAt:new Date().toISOString(),verdict:'NOT_RUN',reviewer:'agent-runtime-assertions'};cases.push(c);save();
 try{const r=await call(method,url,role,payload,headers);const after=snapshot();c.sqlOracle=id+'-sql.json';write(c.sqlOracle,{runId,id,before,after});c.actual={status:r.statusCode,error:r.headers['content-type']?.includes('json')?r.json().error?.code??null:null};assert.equal(r.statusCode,expected,id+':HTTP'+r.statusCode);if(expected>=400)assert.deepEqual(after,before,id+':denial_sql');await verify?.(r);c.verdict='PASS';return r;}
 catch(e){c.verdict='FAIL';c.failure=e instanceof Error?e.message:'UNKNOWN_FAILURE';throw e;}finally{c.endedAt=new Date().toISOString();save();}
};
const readConfiguration=async()=>{const result=[];for(const b of buckets){const r=await cloud.storage.getBucket(b);assert(!r.error&&r.data,'BUCKET_READ');result.push(r.data);}return result;};
const uuid=(scope:string)=>{const b=createHash('sha256').update(scope).digest().subarray(0,16);b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;const h=b.toString('hex');return [h.slice(0,8),h.slice(8,12),h.slice(12,16),h.slice(16,20),h.slice(20)].join('-');};
let configBefore:any;
async function run(){
 await redis.connect();assert.equal(await redis.dbsize(),0);assert(Object.values(snapshot()).every((t:any)=>t.count===0));
 configBefore=await readConfiguration();write('bucket-baseline.json',{runId,configuration:configBefore,sha256:digest(configBefore)});await storage.ensureReady();
 await prisma.user.createMany({data:roles.map(role=>({id:users[role],email:`${runId}-${role.toLowerCase()}@pawmate.test`,passwordHash:bcrypt.hashSync(fixturePassword,4),displayName:role,emailVerified:true}))});
 await app.ready();write('runtime-routes.json',{runId,routes});
 for(const role of roles){const r=await call('POST','/auth/login','anonymous',{email:`${runId}-${role.toLowerCase()}@pawmate.test`,password:fixturePassword});assert.equal(r.statusCode,200);sessions[role]=r.json();}
 for(const [i,role] of contexts.entries()){
  const localId=randomUUID();const email=fixtureEmails[i];
  await prisma.user.create({data:{id:localId,email,passwordHash:bcrypt.hashSync(fixturePassword,4),displayName:'Synthetic provider verification',emailVerified:false}});
  const generated=await cloud.auth.admin.generateLink({type:'signup',email,password:fixturePassword,options:{data:{day137RunId:runId}}});
  if(generated.data.user?.id){guard.ownAuth(generated.data.user.id);persistOwned();}
  assert(!generated.error&&generated.data.user?.id&&generated.data.properties?.hashed_token,'GENERATE_OWNED_LINK');
  const remoteId=generated.data.user.id,token=generated.data.properties.hashed_token;guard.ownToken(token);
  const pre=await cloud.auth.admin.getUserById(remoteId);assert(!pre.error&&pre.data.user?.email===email);assert(!pre.data.user?.email_confirmed_at,'FRESH_UNCONFIRMED_PROVIDER');
  await perform('D137-PROVIDER-VERIFY-'+role,role,'POST','/auth/verify-email',200,{tokenHash:token},async r=>{
   const actual=r.json();fields('VERIFY-'+role+'-subject',{userId:actual.userId,subject:actual.user.id,verified:actual.user.emailVerified},{userId:localId,subject:localId,verified:true});
   const local=sql(`SELECT jsonb_build_object('id',id,'verified',email_verified) FROM users WHERE id='${localId}'::uuid;`);fields('VERIFY-'+role+'-sql',local,{id:localId,verified:true});
   const claims=JSON.parse(Buffer.from(actual.accessToken.split('.')[1],'base64url').toString());fields('VERIFY-'+role+'-session-sub',claims.sub,localId);assert(await redis.dbsize()>0);
   const post=await cloud.auth.admin.getUserById(remoteId);assert(!post.error&&post.data.user?.email===email&&post.data.user?.email_confirmed_at);fields('VERIFY-'+role+'-provider-confirmed',!!post.data.user?.email_confirmed_at,true);
  });
  await perform('D137-PROVIDER-REPLAY-'+role,role,'POST','/auth/verify-email',400,{tokenHash:token},r=>fields('VERIFY-'+role+'-replay-denied',['AUTH_015','AUTH_017'].includes(r.json().error.code),true));
 }
 const bytes=makeProviderPng();const sha=hash(bytes);
 const ticketBody={purpose:'rescue_case',mimeType:'image/png',sizeBytes:bytes.length,sha256:sha,fileName:'synthetic.png'};
 const tickets:Record<string,any>={};
 for(const role of roles){
  const key=runId+'-ticket-'+role,mediaId=uuid(users[role]+':/media/uploads:'+hash(key)),objectKey=users[role]+'/'+mediaId+'/original.png';guard.ticket(buckets[0],objectKey);persistOwned();
  await perform('D137-PROVIDER-TICKET-'+role,role,'POST','/media/uploads',201,ticketBody,async r=>{
   const t=r.json();tickets[role]=t;fields('TICKET-'+role+'-media-id',t.mediaId,mediaId);const url=new URL(t.uploadUrl);assert.equal(url.hostname,'qeoowayxfqyhfcgnrfnv.supabase.co');assert.equal(decodeURIComponent(url.pathname),'/storage/v1/object/upload/sign/'+buckets[0]+'/'+objectKey);assert(url.searchParams.get('token'));
   const persisted=sql(`SELECT jsonb_build_object('owner',owner_user_id,'key',storage_key,'status',status,'sha256',sha256) FROM media_assets WHERE id='${mediaId}'::uuid;`);fields('TICKET-'+role+'-sql',persisted,{owner:users[role],key:objectKey,status:'requested',sha256:sha});
   const listed=await cloud.storage.from(buckets[0]).list(objectKey.substring(0,objectKey.lastIndexOf('/')),{limit:10});assert(!listed.error&&listed.data);fields('TICKET-'+role+'-no-object-yet',listed.data.length,0);
  },{'idempotency-key':key});
 }
 const owner=tickets.owner_adopter,originalKey=users.owner_adopter+'/'+owner.mediaId+'/original.png';guard.object(buckets[0],originalKey);persistOwned();
 const upload=await countedFetch(owner.uploadUrl,{method:'PUT',headers:owner.uploadHeaders,body:bytes});assert(upload.ok,'SIGNED_UPLOAD');write('original-upload.json',{runId,mediaId:owner.mediaId,key:originalKey,sha256:sha,bytes:bytes.length,status:upload.status,at:new Date().toISOString()});
 const completeKey=runId+'-complete-owner',publicKey='rescue_case/'+owner.mediaId+'/'+hash(completeKey)+'/public.png';expectedPublic.add(publicKey);
 for(const role of ['outsider','shelter_A','shelter_B'])await perform('D137-PROVIDER-COMPLETE-DENY-'+role,role,'POST',`/media/uploads/${owner.mediaId}/complete`,404,{sha256:sha},undefined,{'idempotency-key':runId+'-deny-'+role});
 await perform('D137-PROVIDER-COMPLETE-OWNER','owner_adopter','POST',`/media/uploads/${owner.mediaId}/complete`,200,{sha256:sha},async r=>{
  const dto=r.json();fields('COMPLETE-owner-fields',{owner:dto.ownerUserId,mediaId:dto.mediaId,status:dto.status,mime:dto.mimeType},{owner:users.owner_adopter,mediaId:owner.mediaId,status:'verified',mime:'image/png'});
  const asset=await prisma.mediaAsset.findUniqueOrThrow({where:{id:owner.mediaId}});fields('COMPLETE-sql-fields',{key:asset.storageKey,status:asset.status,owner:asset.ownerUserId,width:asset.width,height:asset.height},{key:publicKey,status:'verified',owner:users.owner_adopter,width:null,height:null});
  const uploadSession=await prisma.mediaUploadSession.findUniqueOrThrow({where:{mediaId:owner.mediaId}});
  const downloaded=await cloud.storage.from(buckets[1]).download(publicKey);assert(!downloaded.error&&downloaded.data);const finalBytes=Buffer.from(await downloaded.data.arrayBuffer());fields('COMPLETE-sanitized-byte-hash',hash(finalBytes),uploadSession.sanitizedSha256);fields('COMPLETE-metadata-removed',finalBytes.includes(Buffer.from('Day137 synthetic metadata')),false);fields('COMPLETE-png-IHDR',{width:finalBytes.readUInt32BE(16),height:finalBytes.readUInt32BE(20)},{width:1,height:1});write('sanitized-byte-proof.json',{runId,mediaId:owner.mediaId,originalSha256:sha,sanitizedSha256:hash(finalBytes),bytes:finalBytes.length,width:1,height:1,dimensionsOracle:'actual PNG IHDR; current source does not populate SQL dimensions',verificationVersion:asset.verificationVersion,metadataRemoved:true});
  const listed=await cloud.storage.from(buckets[0]).list(originalKey.substring(0,originalKey.lastIndexOf('/')),{limit:10});assert(!listed.error&&listed.data);fields('COMPLETE-original-deleted',listed.data.length,0);
 },{'idempotency-key':completeKey});
 // Remaining two contexts, source-bound revoked requirements; provider never dispatched here.
 const contract=JSON.parse(fs.readFileSync(path.join(root,'output-evidence/security/day137/d137-preflight-20261002-r6/state-contract.json'),'utf8'));
 for(const role of ['shelter_A','shelter_B']){
  await perform('D137-STATE-REVOKE-'+role,role,'POST','/auth/logout',204,{refreshToken:sessions[role].refreshToken});
  for(const target of contract.requirements.filter((r:any)=>r.role===role&&r.state==='revoked_bearer')){
   const url=target.path.replace(/:[A-Za-z]+/g,randomUUID());await perform(target.id,role,target.method,url,401,['POST','PUT','PATCH'].includes(target.method)?{}:undefined);
   const c=cases.at(-1),o=JSON.parse(fs.readFileSync(path.join(out,c.sqlOracle),'utf8'));c.requirementId=target.id;c.state='revoked_bearer';c.fieldChecks=[{id:'http_status',expected:401,actual:c.actual.status},{id:'fresh_independent_sql',expected:digest(o.before),actual:digest(o.before)},{id:'rejected_no_db_outbox_effect',expected:digest(o.before),actual:digest(o.after)}];save();
  }
 }
}
async function cleanupCloud(){
 cleanupMode=true;guard.setCleanup();let failures=0;const report:any={runId,objects:[],auth:[],configUnchanged:false,verdict:'NOT_RUN'};
 for(const [key,bucket] of guard.objects){try{const removed=await cloud.storage.from(bucket).remove([key]);assert(!removed.error);const r=await cloud.storage.from(bucket).list(key.substring(0,key.lastIndexOf('/')),{limit:10});assert(!r.error&&r.data);assert.equal(r.data.length,0);report.objects.push({bucket,key,remaining:0});}catch{failures++;report.objects.push({bucket,key,verdict:'CLEANUP_FAILED'});}}
 // Also verify signed-ticket folders without uploaded bytes stayed empty.
 for(const [key,bucket] of guard.ticketKeys){try{const r=await cloud.storage.from(bucket).list(key.substring(0,key.lastIndexOf('/')),{limit:10});assert(!r.error&&r.data?.length===0);}catch{failures++;}}
 for(const id of guard.authIds){try{const r=await cloud.auth.admin.deleteUser(id);assert(!r.error);const read=await cloud.auth.admin.getUserById(id);assert(read.error&&read.error.status===404&&!read.data.user);report.auth.push({id,remaining:0,readbackStatus:404});}catch{failures++;report.auth.push({id,verdict:'CLEANUP_FAILED'});}}
 try{const listed=await cloud.auth.admin.listUsers({page:1,perPage:1000});assert(!listed.error);const listedUsers=listed.data.users as Array<{email?:string}>;const owned=listedUsers.filter(u=>guard.attemptedEmails.has(u.email??''));assert.equal(owned.length,0);assert(listedUsers.length<1000,'CLEANUP_DISCOVERY_PAGINATION_REQUIRED');report.remainingAttemptedAccounts=0;}catch{failures++;}
 try{if(configBefore){const after=await readConfiguration();assert.deepEqual(after,configBefore);report.configUnchanged=true;report.beforeSha256=digest(configBefore);report.afterSha256=digest(after);}}catch{failures++;}
 report.verdict=failures===0?'PASS':'FAIL';write('provider-cleanup.json',report);assert.equal(failures,0,'PROVIDER_CLEANUP');
}
run().catch(e=>{failure=e;process.exitCode=1;console.error(e instanceof Error?e.message:'UNKNOWN_FAILURE');}).finally(async()=>{
 save();try{await cleanupCloud();}catch{process.exitCode=1;}
 try{const before=snapshot();await prisma.$executeRawUnsafe(`TRUNCATE ${tables.map(t=>'"'+t+'"').join(',')} CASCADE`);const after=snapshot();const keys=await redis.keys('*');if(keys.length)await redis.del(...keys);const remainingRows=Object.values(after).reduce((n:number,t:any)=>n+t.count,0),redisRemaining=await redis.dbsize();assert.equal(remainingRows,0);assert.equal(redisRemaining,0);write('fixture-cleanup.json',{runId,fixtureOnlyDisposable:true,sqlBefore:before,sqlAfter:after,remainingRows,redisRemaining});}catch{process.exitCode=1;}
 await app.close();await prisma.$disconnect();redis.disconnect();globalThis.fetch=nativeFetch;
 if(failure)write('first-failure.json',{at:new Date().toISOString(),error:failure instanceof Error?failure.message:'UNKNOWN_FAILURE'});
});

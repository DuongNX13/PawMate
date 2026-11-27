// Test-only final-source native SQL/Redis journeys. No cloud or product changes.
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
import { loadEnv, resolveAuthJwtConfig } from '../src/config/env';
import { getRedisClient } from '../src/infrastructure/redis';
import { createNativeAuthForDay137 } from './day137-native-auth-factory-r22b';
import { PrismaAuthUserStore } from '../src/repositories/prisma-auth-user-store';
import { RedisAuthSessionStore } from '../src/repositories/redis-auth-session-store';
import { createActionQuotaGuard, ACTION_QUOTA_POLICIES } from '../src/security/distributed-action-quota';
import { RedisActionQuotaStore } from '../src/security/redis-action-quota-store';
import { buildDay137ProductionConfig, validateDay137EffectiveConfigs } from './day137-bootstrap-r20';
import { claimRequest } from './day137-local-states-budget-r22.mjs';
import { snapshotContract } from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';

const root=path.resolve(__dirname,'../..'),out=process.env.DAY137_EVIDENCE_ROOT!,runId=process.env.DAY137_RUN_ID!,envelope=process.env.DAY137_ENVELOPE_PATH!,db=process.env.DATABASE_URL!,redisUrl=process.env.REDIS_URL!;
assert(/^d137-local-states-[a-z0-9-]{6,28}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root,'output-evidence/security/day137')+path.sep));
assert.equal(new URL(db).hostname,'127.0.0.1'); assert.equal(new URL(redisUrl).hostname,'127.0.0.1');
const sha=(b:Buffer|string)=>createHash('sha256').update(b).digest('hex');
const write=(n:string,v:any)=>fs.writeFileSync(path.join(out,n),JSON.stringify(v,null,2)+'\n');
const ref=(n:string)=>{const b=fs.readFileSync(path.join(out,n));return{path:path.relative(root,path.join(out,n)).replaceAll('\\','/'),bytes:b.length,sha256:sha(b)};};
const sourcePath=process.env.DAY137_SOURCE_MANIFEST??'output-evidence/security/day137/d137-completion-20261005-r13/source-manifest.json';
assert(!path.isAbsolute(sourcePath)&&!sourcePath.split(/[\\/]/).includes('..'),'UNSAFE_SOURCE_PATH');
const source=JSON.parse(fs.readFileSync(path.join(root,sourcePath),'utf8'));
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
const ids=['QUOTA:below_threshold','QUOTA:threshold_plus_one','QUOTA:account_isolation','QUOTA:spoofed_forwarded_ip','QUOTA:idempotent_no_double_charge','QUOTA:store_unavailable','ADOPTION_CHAT:membership_revoked','AUTH:refresh_reuse','NOTIFICATION_VET_WEB:readiness_unavailable'];
let app:any,current:any,failure:any,runtimeCalls=0,cloudAttempts=0;
const originalFetch=globalThis.fetch;
globalThis.fetch=async()=>{cloudAttempts++;throw Error('DAY137_ZERO_CLOUD_ALLOWLIST');};
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
  catch(e){current.sqlAfter=snapshot();current.verdict='FAIL';current.failure=String(e);throw e;}
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
  await prisma.$executeRawUnsafe("INSERT INTO vets(id,external_id,name,address,city,district,location,opening_hours,is_24h,average_rating,review_count,source_rank,ready_for_map,created_at,updated_at) VALUES($1::uuid,$2,'Synthetic Vet','Synthetic address','Test city','Test district',ST_SetSRID(ST_MakePoint(106.7009,10.7769),4326)::geography,'[]'::jsonb,false,5,4,1,true,$3,$3)",f.vet,runId+'-vet',stamp);
  await prisma.review.createMany({data:roles.map((role,i)=>({id:f.reviews[i],vetId:f.vet,userId:f.users[role],rating:5,body:'Owned quota fixture',photoUrls:[],createdAt:stamp,updatedAt:stamp}))});
  write('fixture.json',{runId,sourceFingerprint,values:f,privateObjectUploaded:false,privateStateScope:'membership denial only; object bytes are not claimed'});
}
async function run(){
  process.chdir(out);write('effective-config-validation.json',validateDay137EffectiveConfigs({localStates:config}));
  app=buildApp({logger:false},{config});apps.push(app);await app.ready();await redis.connect();
  assert.equal(await redis.dbsize(),0);assert(Object.values(snapshot()).every((t:any)=>t.count===0));
  write('plan.json',{runId,sourceFingerprint,producerHash,states:ids,cloudCallsMax:0,sqlQuery:contract.query,fixture:'fresh owned disposable PostgreSQL and Redis',productionSourceUnchanged:true});
  await seed();
  await journey(ids[0],async()=>{
    assert.deepEqual(ACTION_QUOTA_POLICIES['review.helpful'].map(p=>p.limit),[120,60,20]);
    const before=counter('review.helpful','account',f.users.outsider,3600);assert.equal(before.value,0);
    for(let n=0;n<60;n++){const reviewId=f.reviews[Math.floor(n/20)],r=await call('PUT',`/reviews/${reviewId}/helpful`,'outsider');const b=success(r,200);assert.deepEqual(b,{data:{reviewId,helpfulCount:n%2===0?1:0,hasVoted:n%2===0}});}
    const account=counter('review.helpful','account',f.users.outsider,3600),resources=f.reviews.map((id:string)=>counter('review.helpful','resource',id,3600));
    assert.equal(account.bucket,before.bucket);assert.equal(account.value,60);assert(account.ttlSeconds>0);assert.deepEqual(resources.map((r:any)=>r.value),[20,20,20,0]);
    const votes=sql("SELECT coalesce(jsonb_agg(row_to_json(v)), '[]'::jsonb) FROM review_helpful_votes v;");assert.equal(votes.length,0);
    current.native={before,account,resources,votes,semantics:'actual native toggle: even requests return vote count zero, not 60 rows'};
  });
  await journey(ids[1],async()=>{const r=await call('PUT',`/reviews/${f.reviews[3]}/helpful`,'outsider');denied(r,429,'SEC_001');assert(Number(r.headers['retry-after'])>0);equalSql();const account=counter('review.helpful','account',f.users.outsider,3600),resource=counter('review.helpful','resource',f.reviews[3],3600);assert.equal(account.value,60);assert.equal(resource.value,0);current.native={account,resource};});
  await journey(ids[2],async()=>{const before=counter('review.helpful','account',f.users.owner_adopter,3600);assert.equal(before.value,0);const r=await call('PUT',`/reviews/${f.reviews[3]}/helpful`,'owner_adopter');assert.deepEqual(success(r,200),{data:{reviewId:f.reviews[3],helpfulCount:1,hasVoted:true}});const account=counter('review.helpful','account',f.users.owner_adopter,3600),other=counter('review.helpful','account',f.users.outsider,3600);assert.equal(account.value,1);assert.equal(other.value,60);assert.notEqual(account.key,other.key);const rows=sql(`SELECT coalesce(jsonb_agg(row_to_json(v)),'[]'::jsonb) FROM review_helpful_votes v WHERE review_id='${f.reviews[3]}'::uuid AND user_id='${f.users.owner_adopter}'::uuid;`);assert.equal(rows.length,1);current.native={before,account,other,rows};});
  await journey(ids[3],async()=>{const r=await call('PUT',`/reviews/${f.reviews[3]}/helpful`,'outsider',undefined,{'x-forwarded-for':'198.51.100.19'});denied(r,429,'SEC_001');equalSql();const account=counter('review.helpful','account',f.users.outsider,3600);assert.equal(account.value,60);current.native={account,trustProxy:false,scope:'account quota cannot be bypassed; not exhausted-IP proof'};});
  await journey(ids[4],async()=>{const before=counter('chat.message','account',f.users.owner_adopter,300);const payload={body:'Owned r22 replay',mediaIds:[]},headers={'idempotency-key':runId+'-replay'};
    const first=success(await call('POST',`/adoption/chat/${f.thread}/messages`,'owner_adopter',payload,headers),201),afterFirst=snapshot();
    const second=success(await call('POST',`/adoption/chat/${f.thread}/messages`,'owner_adopter',payload,headers),201);assert.deepEqual(second,first);assert.deepEqual(snapshot(),afterFirst);
    const account=counter('chat.message','account',f.users.owner_adopter,300);assert.equal(account.bucket,before.bucket);assert.equal(account.value-before.value,1);
    const messageId=first.data.messageId;assert.equal(typeof messageId,'string');const rows=sql(`SELECT jsonb_build_object('messages',(SELECT count(*) FROM adoption_chat_messages WHERE id='${messageId}'::uuid),'outbox',(SELECT count(*) FROM outbox_events WHERE aggregate_id='${messageId}' AND event_type='adoption.chat_message_created.v1'));`);assert.equal(rows.messages,1);assert.equal(rows.outbox,1);current.native={before,account,rows,afterFirst,createdMessageId:messageId};
  });
  await journey(ids[5],async()=>{const quotaClient=new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0,enableOfflineQueue:false});ownedClients.push(quotaClient);await quotaClient.connect();const guard=createActionQuotaGuard({store:new RedisActionQuotaStore(quotaClient),secret:config.auth.accessTokenSecret});const downApp=buildApp({logger:false},{config,actionQuotaGuard:guard});apps.push(downApp);await downApp.ready();quotaClient.disconnect();
    const r=await call('PUT',`/reviews/${f.reviews[0]}/helpful`,'owner_adopter',undefined,{},downApp);denied(r,503,'SEC_002');assert(Number(r.headers['retry-after'])>0);equalSql();const auth=authRows(f.users.owner_adopter);assert(auth.sessions.every((s:any)=>!s.fields.revokedAt));assert.equal(rc('ping'),'PONG');current.native={auth,quotaClientStatus:quotaClient.status,independentRedisAlive:true};
  });
  await journey(ids[6],async()=>{const saved=await prisma.adoptionChatParticipant.findUniqueOrThrow({where:{threadId_userId:{threadId:f.thread,userId:f.users.shelter_A}}});const beforeRestore=snapshot();await prisma.adoptionChatParticipant.delete({where:{threadId_userId:{threadId:f.thread,userId:f.users.shelter_A}}});
    const revoked=snapshot(),participantCount=sql(`SELECT to_json(count(*)) FROM adoption_chat_participants WHERE thread_id='${f.thread}'::uuid AND user_id='${f.users.shelter_A}'::uuid;`);assert.equal(participantCount,0);
    try{const probes=[['GET',`/adoption/chat/${f.thread}`,undefined],['POST',`/adoption/chat/${f.thread}/messages`,{body:'Owned revoked membership probe',mediaIds:[]}],['PUT',`/adoption/chat/${f.thread}/read`,{throughMessageId:f.message}],['GET',`/adoption/chat/${f.thread}/media/${f.media}`,undefined]];
      for(const [method,url,payload]of probes){denied(await call(method as string,url as string,'shelter_A',payload,{'idempotency-key':runId+'-revoked'}),404,'ADOPTION_007');assert.deepEqual(snapshot(),revoked);}
    }finally{await prisma.adoptionChatParticipant.create({data:saved});}
    assert.deepEqual(snapshot(),beforeRestore);const auth=authRows(f.users.shelter_A);assert(auth.sessions.every((s:any)=>!s.fields.revokedAt));current.native={saved:{...saved,lastReadSequence:saved.lastReadSequence.toString()},participantCount,revoked,restored:snapshot(),auth,providerReadAttempts:cloudAttempts};assert.equal(cloudAttempts,0);
  });
  let clock=Date.now();const now=()=>new Date(clock);
  const authClients=[new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0}),new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0})];ownedClients.push(...authClients);await Promise.all(authClients.map(c=>c.connect()));
  const authServices=authClients.map(client=>createNativeAuthForDay137(config,new PrismaAuthUserStore(prisma),new RedisAuthSessionStore(client),now));
  const authApps=authServices.map(authService=>buildApp({logger:false},{config,authService}));apps.push(...authApps);await Promise.all(authApps.map(a=>a.ready()));
  sessions.refresh=success(await call('POST','/auth/login','anonymous',{email:`${runId}-refresh@pawmate.test`,password:'Day137Synthetic!2026'}, {},authApps[0]),200);
  await journey(ids[7],async()=>{const t0=sessions.refresh.refreshToken,before=authRows(f.authUser);clock+=1000;
    const responses=await Promise.all(authApps.map(a=>call('POST','/auth/refresh','anonymous',{refreshToken:t0},{},a)));assert.deepEqual(responses.map(r=>r.statusCode).sort(),[200,401]);const winner=responses.find(r=>r.statusCode===200)!.json();denied(responses.find(r=>r.statusCode===401),401,'AUTH_007');
    sessions.winner=winner;const rotated=authRows(f.authUser);assert(rotated.sessions.every((s:any)=>!s.fields.revokedAt));assert.equal(rotated.sessions[0].fields.previousRefreshTokenHash,sha(t0));assert.equal(rotated.sessions[0].fields.refreshTokenHash,sha(winner.refreshToken));
    denied(await call('POST','/auth/refresh','anonymous',{refreshToken:t0},{},authApps[1]),401,'AUTH_007');assert.equal((await authServices[1].verifyAccessToken(winner.accessToken)).userId,f.authUser);
    clock+=6000;denied(await call('POST','/auth/refresh','anonymous',{refreshToken:t0},{},authApps[0]),401,'AUTH_009');denied(await call('GET',`/adoption/chat/${f.thread}`,'winner',undefined,{},authApps[1]),401,'AUTH_013');
    const revoked=authRows(f.authUser);assert(revoked.sessions.length>0);assert(revoked.sessions.every((s:any)=>s.fields.revokedAt&&s.ttlMs>0));assert.equal((await new RedisAuthSessionStore(authClients[1]).listActiveSessionsByUser(f.authUser)).length,0);equalSql();current.native={before,rotated,revoked,activeSessionCount:0,injectedClockMs:clock,scope:'native Redis and production service with QA clock; all API routes real'};
  });
  await journey(ids[8],async()=>{assert.deepEqual(success(await call('GET','/ready','anonymous'),200),{status:'ready'});const defaultRedis=getRedisClient(redisUrl);defaultRedis.disconnect();
    assert.deepEqual(success(await call('GET','/health','anonymous'),200),{status:'ok'});assert.deepEqual(success(await call('GET','/ready','anonymous'),503),{status:'not_ready'});assert.equal(rc('ping'),'PONG');const redisStatus=defaultRedis.status;await defaultRedis.connect();assert.deepEqual(success(await call('GET','/ready','anonymous'),200),{status:'ready'});
    const closedPort=Number(process.env.DAY137_UNAVAILABLE_DB_PORT);assert.equal(closedPort,55448);const cmd="if(Get-NetTCPConnection -State Listen -LocalPort 55448 -ErrorAction SilentlyContinue){exit 1}else{exit 0}";execFileSync('powershell.exe',['-NoProfile','-Command',cmd],{timeout:10000});
    const url=new URL(db);url.port=String(closedPort);url.searchParams.set('connect_timeout','1');const unavailableConfig=buildDay137ProductionConfig(config,url.href,redisUrl);validateDay137EffectiveConfigs({dbUnavailable:unavailableConfig});const dbApp=buildApp({logger:false},{config:unavailableConfig});apps.push(dbApp);await dbApp.ready();
    assert.deepEqual(success(await call('GET','/health','anonymous',undefined,{},dbApp),200),{status:'ok'});assert.deepEqual(success(await call('GET','/ready','anonymous',undefined,{},dbApp),503),{status:'not_ready'});assert.deepEqual(success(await call('GET','/ready','anonymous'),200),{status:'ready'});equalSql();current.native={defaultChecks:true,redisDownClientStatus:redisStatus,redisServerPing:'PONG',dbUnavailableTarget:url.href,dbPortOwnership:'verified no listener; no server/process mutated',healthyDbQuery:sql('SELECT to_json(1);'),recovery:true};
  });
  assert.equal(cases.length,ids.length);assert(cases.every(c=>c.verdict==='PASS'));assert.equal(cloudAttempts,0);checkSource();write('native-state-summary.json',{runId,sourceFingerprint,producerHash,states:ids,nativeCasesPassed:9,runtimeCalls,cloudCalls:0,fullDay137Acceptance:false,baselineBindingsAdded:0,verdict:'PASS_SCOPED_NATIVE_STATE_JOURNEYS'});
}
run().catch(e=>{failure=e;console.error(String(e));process.exitCode=1;}).finally(async()=>{
  save();try{const before=snapshot();await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.map(t=>'"'+t+'"').join(',')} CASCADE`);const after=snapshot();const keys=await redis.keys('*');if(keys.length)await redis.del(...keys);assert(Object.values(after).every((t:any)=>t.count===0));assert.equal(await redis.dbsize(),0);checkSource();write('fixture-cleanup.json',{runId,sourceFingerprint,sqlBefore:before,sqlAfter:after,remainingRows:0,redisRemaining:0,cloudCalls:cloudAttempts,verdict:'PASS'});}catch(e){console.error('CLEANUP:'+String(e));process.exitCode=1;}
  for(const a of [...apps].reverse()){try{await a.close();}catch(e){console.error('APP_CLOSE:'+String(e));process.exitCode=1;}}
  await prisma.$disconnect();for(const client of ownedClients)client.disconnect();globalThis.fetch=originalFetch;
  if(failure)write('first-failure.json',{at:new Date().toISOString(),error:String(failure)});
});

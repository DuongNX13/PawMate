// Test-only lane: production notifications handlers; real disposable PostgreSQL/Redis.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
import fs from 'node:fs';import path from 'node:path';import bcrypt from 'bcryptjs';
import {PrismaClient} from '@prisma/client';import Redis from 'ioredis';
import {buildApp} from '../src/app';import {loadEnv} from '../src/config/env';
import {buildTestConfig} from '../tests/helpers/rescue-read-fixtures';
import {claimRequest} from './day137-notifications-budget-r9.mjs';
import {buildNotificationsPlan} from '../../scripts/qa/day137/day137-notifications-plan-r9.mjs';
import {validateNotificationsCase} from '../../scripts/qa/day137/day137-notifications-oracle-r9.mjs';
const root=path.resolve(__dirname,'../..'),out=process.env.DAY137_EVIDENCE_ROOT!,runId=process.env.DAY137_RUN_ID!,envelope=process.env.DAY137_ENVELOPE_PATH!;
const db=process.env.DATABASE_URL!,redisUrl=process.env.REDIS_URL!;
assert(/^d137-local-notifications-[a-z0-9-]{6,28}$/.test(runId));
assert(path.resolve(out).startsWith(path.join(root,'output-evidence/security/day137')+path.sep));
assert.equal(new URL(db).hostname,'127.0.0.1');assert.equal(new URL(redisUrl).hostname,'127.0.0.1');
const hash=(v:Buffer|string)=>createHash('sha256').update(v).digest('hex');
const write=(name:string,v:unknown)=>fs.writeFileSync(path.join(out,name),JSON.stringify(v,null,2)+'\n');
const ref=(name:string)=>{const b=fs.readFileSync(path.join(out,name));return {path:path.relative(root,path.join(out,name)).replaceAll('\\','/'),bytes:b.length,sha256:hash(b)};};
const protectedManifest=JSON.parse(fs.readFileSync(path.join(root,'output-evidence/security/day137/d137-entry-20261001-r1/source-manifest.json'),'utf8'));
const checkSource=()=>{for(const f of protectedManifest.files){const b=fs.readFileSync(path.join(root,f.path));assert.equal(b.length,f.bytes);assert.equal(hash(b),f.sha256,`SOURCE:${f.path}`);}};
checkSource();const sourceFingerprint=protectedManifest.sourceFingerprint,producerHash=hash(fs.readFileSync(__filename));
const psql=path.join(root,'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe');
const pgArgs=['-h','127.0.0.1','-p',new URL(db).port,'-U','pawmate','-d',new URL(db).pathname.slice(1),'-At','-v','ON_ERROR_STOP=1'];
const sql=(q:string)=>JSON.parse(execFileSync(psql,[...pgArgs,'-c',q],{encoding:'utf8',timeout:10000}).trim());
const tables=[...fs.readFileSync(path.join(root,'backend/prisma/schema.prisma'),'utf8').matchAll(/@@map\("([a-z_]+)"\)/g)].map(m=>m[1]);
const snapshotQuery=`SELECT jsonb_object_agg(name,value) FROM (${tables.map(t=>`SELECT '${t}' name,jsonb_build_object('count',count(*),'contentHash',md5(coalesce(string_agg(row_to_json(t)::text,'' ORDER BY row_to_json(t)::text),''))) value FROM "${t}" t`).join(' UNION ALL ')}) s;`;
const snapshot=()=>sql(snapshotQuery),prisma=new PrismaClient({datasources:{db:{url:db}}}),redis=new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0});
const rowQuery=`SELECT jsonb_build_object('notifications',(SELECT coalesce(jsonb_agg(row_to_json(n) ORDER BY id),'[]') FROM notifications n),'reminders',(SELECT coalesce(jsonb_agg(row_to_json(m) ORDER BY id),'[]') FROM reminders m));`;
const rows=()=>sql(rowQuery);
const roleNames=['owner_adopter','outsider','shelter_A','shelter_B'];
const f:any={users:Object.fromEntries(roleNames.map(r=>[r,randomUUID()])),pets:Object.fromEntries(roleNames.map(r=>[r,randomUUID()])),notifications:Object.fromEntries(roleNames.map(r=>[r,[randomUUID(),randomUUID(),randomUUID()]])),reminders:Object.fromEntries(roleNames.map(r=>[r,[randomUUID(),randomUUID(),randomUUID(),randomUUID()]])),missingNotification:randomUUID()},plan=buildNotificationsPlan(f);
write('expected-fixture.json',{kind:'DAY137_EXPECTED_FIXTURE',runId,sourceFingerprint,values:f});
write('plan.json',{schemaVersion:1,runId,sourceFingerprint,producerHash,fixtureRef:ref('expected-fixture.json'),cases:plan});
write('preflight-references.json',{plan:ref('plan.json'),fixture:ref('expected-fixture.json'),sourceFingerprint,producerHash});
const provider=loadEnv(),base=buildTestConfig();
const config={...base,nodeEnv:'production' as const,databaseUrl:db,redisUrl,supabaseUrl:provider.supabaseUrl,supabaseAnonKey:provider.supabaseAnonKey,supabaseServiceRoleKey:provider.supabaseServiceRoleKey,supabaseProjectRef:provider.supabaseProjectRef,supabaseBuckets:provider.supabaseBuckets,auth:{...base.auth,accessTokenSecret:'day137-preferences-access-local-only',refreshTokenSecret:'day137-preferences-refresh-local-only'}};
let cloudCalls=0;const oldFetch=globalThis.fetch;
globalThis.fetch=(async()=>{cloudCalls++;throw new Error('NETWORK_NOT_AUTHORIZED_IN_LOCAL_LANE');}) as typeof fetch;
const app=buildApp({logger:false},{config}),sessions:Record<string,string>={},cases:any[]=[];
let requestCount=0,failure:unknown,cleaned=false;
const save=()=>write('cross-role-results.json',{schemaVersion:1,runId,sourceFingerprint,cases,requestCount,cloudCalls,verdict:failure?'FAIL':cases.length===plan.length&&cases.every(c=>c.verdict==='PASS')?'PASS_NOTIFICATIONS_SLICE':'PARTIAL',limitations:['Notifications90 recipes/25canonical baseline only, not Day137','Fastify in-process transport, PostgreSQL/Redis real','Sequential due idempotency, not concurrent worker atomicity','No live provider operations']});
const call=async(method:any,url:string,role:string,payload?:any)=>{claimRequest(envelope);requestCount++;return app.inject({method,url,...(payload===undefined?{}:{payload}),headers:role==='anonymous'?{}:{authorization:`Bearer ${sessions[role]}`}});};
async function resetFixture(p:any){
  await prisma.notification.deleteMany();await prisma.reminder.deleteMany();await prisma.pet.deleteMany();
  const stamp=new Date('2026-09-01T00:00:00.000Z'),future=new Date('2099-01-01T00:00:00.000Z');
  for(const role of roleNames){
    await prisma.pet.create({data:{id:f.pets[role],userId:f.users[role],name:'Fixture '+role,species:'dog',createdAt:stamp,updatedAt:stamp}});
    await prisma.reminder.createMany({data:f.reminders[role].map((id:string,i:number)=>({id,petId:f.pets[role],createdByUserId:f.users[role],title:`Due fixture ${role} ${i}`,note:`Body fixture ${role} ${i}`,reminderAt:i===1?future:stamp,nextTriggerAt:i===1?future:i===0&&p.state==='already_processed'?null:stamp,status:i===3?'done':i===0&&p.state==='already_processed'?'sent':'scheduled',deletedAt:i===2?stamp:null,repeatRule:'none',timezone:'Asia/Bangkok',createdAt:stamp,updatedAt:stamp,lastTriggeredAt:i===0&&p.state==='already_processed'?stamp:null}))});
    if(p.kind==='list'&&p.state==='empty'&&role===(p.role==='anonymous'?'owner_adopter':p.role))continue;
    await prisma.notification.createMany({data:f.notifications[role].map((id:string,i:number)=>({id,userId:f.users[role],petId:f.pets[role],type:'reminder_due',title:`Title fixture ${role} ${i}`,body:`Body fixture ${role} ${i}`,createdAt:new Date(stamp.getTime()+(3-i)*1000),deliveredAt:stamp,readAt:i===1||p.state==='already_read_all'?stamp:null,dismissedAt:i===2?stamp:null}))});
  }
}
async function run(){
  await redis.connect();assert.equal(await redis.dbsize(),0);assert(Object.values(snapshot()).every((t:any)=>t.count===0));
  const password='Day137PreferencesSynthetic!2026';
  await prisma.user.createMany({data:roleNames.map(role=>({id:f.users[role],email:`${runId}-${role.toLowerCase()}@pawmate.test`,passwordHash:bcrypt.hashSync(password,4),displayName:role,emailVerified:true}))});
  await app.ready();
  for(const role of roleNames){const r=await call('POST','/auth/login','anonymous',{email:`${runId}-${role.toLowerCase()}@pawmate.test`,password});assert.equal(r.statusCode,200);sessions[role]=r.json().accessToken;}
  for(const p of plan){
    await resetFixture(p);const before=snapshot(),rowsBefore=rows(),startedDb=sql('SELECT to_json(clock_timestamp());');
    const c:any={id:p.id,runId,sourceFingerprint,producerHash,method:p.method,url:p.url,role:p.role,state:p.state,precondition:{fixtureRef:ref('expected-fixture.json'),databaseAndRedis:'real-local'},startedAt:new Date().toISOString(),command:['Fastify.inject',p.method,p.url],verdict:'NOT_RUN',reviewer:'runtime-independent-SQL-assertions'};
    cases.push(c);save();
    try {
      const response=await call(p.method,p.url,p.role);
      const responses=[{status:response.statusCode,body:response.json()}];const afterFirst=snapshot(),rowsAfterFirst=rows();
      if(p.repeat){const second=await call(p.method,p.url,p.role);responses.push({status:second.statusCode,body:second.json()});}
      const endedDb=sql('SELECT to_json(clock_timestamp());'),after=snapshot(),rowsAfter=rows();
      const responseName=`${p.id}-response.json`,sqlName=`${p.id}-sql.json`;
      const identity={runId,id:p.id,sourceFingerprint,producerHash,method:p.method,url:p.url,role:p.role,state:p.state};
      write(responseName,{...identity,responses});
      write(sqlName,{...identity,startedDb,endedDb,before,after,afterFirst,rowsBefore,rowsAfter,rowsAfterFirst,query:snapshotQuery,command:[psql,...pgArgs,'-c',snapshotQuery],rowQuery,rowCommand:[psql,...pgArgs,'-c',rowQuery]});
      c.responseRef=ref(responseName);c.sqlRef=ref(sqlName);c.actual={status:response.statusCode};
      const read=(reference:any)=>{const b=fs.readFileSync(path.join(root,reference.path));assert.equal(b.length,reference.bytes);assert.equal(hash(b),reference.sha256);return JSON.parse(b.toString('utf8'));};
      const proof=validateNotificationsCase({planned:p,actual:c,raw:read(c.responseRef),sql:read(c.sqlRef),fixture:f,runId,sourceFingerprint,producerHash,schema:fs.readFileSync(path.join(root,'backend/prisma/schema.prisma'),'utf8')});
      c.assertions=proof.assertions;assert.equal(proof.verdict,'PASS',JSON.stringify(proof.errors));c.verdict='PASS';
    }catch(e){c.verdict='FAIL';c.failure=String(e);throw e;}finally{c.endedAt=new Date().toISOString();save();}
  }
  assert.equal(cloudCalls,0);checkSource();
}
run().catch(e=>{failure=e;console.error(String(e));process.exitCode=1;}).finally(async()=>{
  save();try{
    const before=snapshot();await prisma.$executeRawUnsafe(`TRUNCATE ${tables.map(t=>`"${t}"`).join(',')} CASCADE`);
    const after=snapshot(),keys=await redis.keys('*');if(keys.length)await redis.del(...keys);
    const remainingRows=Object.values(after).reduce((n:number,t:any)=>n+t.count,0),redisRemaining=await redis.dbsize();
    assert.equal(remainingRows,0);assert.equal(redisRemaining,0);checkSource();cleaned=true;
    write('fixture-cleanup.json',{runId,fixtureOnlyDisposable:true,sqlBefore:before,sqlAfter:after,remainingRows,redisRemaining,sourceFingerprint,protectedFiles:protectedManifest.files.length,cloudCalls});
  }catch(e){console.error(`CLEANUP:${e}`);process.exitCode=1;}
  await app.close();await prisma.$disconnect();redis.disconnect();globalThis.fetch=oldFetch;
  if(failure)write('first-failure.json',{at:new Date().toISOString(),error:String(failure),cleanupVerified:cleaned});
});

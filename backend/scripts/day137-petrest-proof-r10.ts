// Test-only lane: production public handlers; real disposable PostgreSQL/Redis.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
import fs from 'node:fs';import path from 'node:path';import bcrypt from 'bcryptjs';
import {PrismaClient} from '@prisma/client';import Redis from 'ioredis';
import {loadEnv} from '../src/config/env';
import {buildTestConfig} from '../tests/helpers/rescue-read-fixtures';
import {claimRequest} from './day137-petrest-budget-r10.mjs';
import {buildPetRestPlan} from '../../scripts/qa/day137/day137-petrest-plan-r10.mjs';
import {photoBase64} from '../../scripts/qa/day137/day137-petrest-plan-r10.mjs';
import {validatePetRestCase} from '../../scripts/qa/day137/day137-petrest-oracle-r10.mjs';
const root=path.resolve(__dirname,'../..'),out=process.env.DAY137_EVIDENCE_ROOT!,runId=process.env.DAY137_RUN_ID!,envelope=process.env.DAY137_ENVELOPE_PATH!;
const db=process.env.DATABASE_URL!,redisUrl=process.env.REDIS_URL!;
assert(/^d137-local-public-[a-z0-9-]{6,28}$/.test(runId));
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
const rowQuery="SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY id),'[]') FROM pets p;",rows=()=>sql(rowQuery);
const storage=path.join(out,'storage/pet-photos');assert(path.resolve(storage).startsWith(path.resolve(out)+path.sep));
const inventory=()=>{const files:any[]=[];const walk=(dir:string)=>{if(!fs.existsSync(dir))return;for(const e of fs.readdirSync(dir,{withFileTypes:true})){const target=path.join(dir,e.name);if(e.isDirectory())walk(target);else{const b=fs.readFileSync(target);files.push({path:path.relative(out,target).replaceAll('\\','/'),bytes:b.length,sha256:hash(b)});}}};walk(storage);return files.sort((a,b)=>a.path.localeCompare(b.path));};
const roleNames=['owner_adopter','outsider','shelter_A','shelter_B'];
const f:any={users:Object.fromEntries(roleNames.map(r=>[r,randomUUID()])),pets:Object.fromEntries(roleNames.map(r=>[r,randomUUID()])),deletedPet:randomUUID(),missingPet:randomUUID(),baseUrl:'http://localhost:3000'},plan=buildPetRestPlan(f);
write('expected-fixture.json',{kind:'DAY137_EXPECTED_FIXTURE',runId,sourceFingerprint,values:f});
write('plan.json',{schemaVersion:1,runId,sourceFingerprint,producerHash,fixtureRef:ref('expected-fixture.json'),cases:plan});
write('preflight-references.json',{plan:ref('plan.json'),fixture:ref('expected-fixture.json'),sourceFingerprint,producerHash});
const provider=loadEnv(),base=buildTestConfig();
const config={...base,nodeEnv:'production' as const,databaseUrl:db,redisUrl,supabaseUrl:provider.supabaseUrl,supabaseAnonKey:provider.supabaseAnonKey,supabaseServiceRoleKey:provider.supabaseServiceRoleKey,supabaseProjectRef:provider.supabaseProjectRef,supabaseBuckets:provider.supabaseBuckets,auth:{...base.auth,accessTokenSecret:'day137-preferences-access-local-only',refreshTokenSecret:'day137-preferences-refresh-local-only'}};
let cloudCalls=0;const oldFetch=globalThis.fetch;
globalThis.fetch=(async()=>{cloudCalls++;throw new Error('NETWORK_NOT_AUTHORIZED_IN_LOCAL_LANE');}) as typeof fetch;
let app:any;const sessions:Record<string,string>={},cases:any[]=[];
let requestCount=0,failure:unknown,cleaned=false;
const save=()=>write('cross-role-results.json',{schemaVersion:1,runId,sourceFingerprint,cases,requestCount,cloudCalls,verdict:failure?'FAIL':cases.length===plan.length&&cases.every(c=>c.verdict==='PASS')?'PASS_PETREST_SLICE':'PARTIAL',limitations:['Pet remaining65recipes/20canonical baseline only, not Day137','Fastify in-process HTTP, real SQL/Redis and local-storage bytes','Not D138 sanitizer/media privacy hardening','No live provider operations']});
const call=async(method:any,url:string,role:string,payload?:any)=>{claimRequest(envelope);requestCount++;return app.inject({method,url,...(payload===undefined?{}:{payload}),headers:role==='anonymous'?{}:{authorization:`Bearer ${sessions[role]}`}});};
async function run(){
  process.chdir(out);const {buildApp}=await import('../src/app');app=buildApp({logger:false},{config});
  await redis.connect();assert.equal(await redis.dbsize(),0);assert(Object.values(snapshot()).every((t:any)=>t.count===0));
  const password='Day137PreferencesSynthetic!2026';
  await prisma.user.createMany({data:roleNames.map(role=>({id:f.users[role],email:`${runId}-${role.toLowerCase()}@pawmate.test`,passwordHash:bcrypt.hashSync(password,4),displayName:role,emailVerified:true}))});
  await app.ready();
  for(const role of roleNames){const r=await call('POST','/auth/login','anonymous',{email:`${runId}-${role.toLowerCase()}@pawmate.test`,password});assert.equal(r.statusCode,200);sessions[role]=r.json().accessToken;}
  for(const p of plan){
    await prisma.pet.deleteMany();if(fs.existsSync(storage))fs.rmSync(storage,{recursive:true});
    const stamp=new Date('2026-09-01T00:00:00Z');
    for(const role of roleNames){if(p.kind==='list'&&p.state==='empty'&&role===(p.role==='anonymous'?'owner_adopter':p.role))continue;await prisma.pet.create({data:{id:f.pets[role],userId:f.users[role],name:'Fixture '+role,species:'dog',breed:'Golden',color:'cream',microchipNumber:role==='owner_adopter'?'MC-owner-adopter':null,createdAt:stamp,updatedAt:stamp}});}
    if(!(p.kind==='list'&&p.state==='empty'&&p.role==='owner_adopter'))await prisma.pet.create({data:{id:f.deletedPet,userId:f.users.owner_adopter,name:'Deleted fixture',species:'cat',deletedAt:stamp,createdAt:stamp,updatedAt:stamp}});
    fs.mkdirSync(path.join(storage,f.pets.owner_adopter),{recursive:true});fs.writeFileSync(path.join(storage,f.pets.owner_adopter,'fixture.png'),Buffer.from(photoBase64,'base64'));
    const before=snapshot(),rowsBefore=rows(),filesBefore=inventory(),startedDb=sql('SELECT to_json(clock_timestamp());');
    const c:any={id:p.id,runId,sourceFingerprint,producerHash,method:p.method,url:p.url,role:p.role,state:p.state,precondition:{fixtureRef:ref('expected-fixture.json'),databaseAndRedis:'real-local',storageSandbox:out},startedAt:new Date().toISOString(),command:['Fastify.inject',p.method,p.url],verdict:'NOT_RUN',reviewer:'runtime-independent-SQL-and-file-assertions'};
    cases.push(c);save();
    try {
      const response=await call(p.method,p.url,p.role,p.payload);
      const endedDb=sql('SELECT to_json(clock_timestamp());'),after=snapshot(),rowsAfter=rows(),filesAfter=inventory();
      const responseName=`${p.id}-response.json`,sqlName=`${p.id}-sql.json`;
      const identity={runId,id:p.id,sourceFingerprint,producerHash,method:p.method,url:p.url,role:p.role,state:p.state};
      write(responseName,{...identity,status:response.statusCode,contentType:response.headers['content-type'],...(p.kind==='asset'&&response.statusCode===200?{binaryBase64:response.rawPayload.toString('base64'),binaryBytes:response.rawPayload.length,binarySha256:hash(response.rawPayload)}:{body:response.json()}),filesBefore,filesAfter});
      write(sqlName,{...identity,startedDb,endedDb,before,after,rowsBefore,rowsAfter,query:snapshotQuery,command:[psql,...pgArgs,'-c',snapshotQuery],rowQuery,rowCommand:[psql,...pgArgs,'-c',rowQuery]});
      c.responseRef=ref(responseName);c.sqlRef=ref(sqlName);c.actual={status:response.statusCode};
      const read=(reference:any)=>{const b=fs.readFileSync(path.join(root,reference.path));assert.equal(b.length,reference.bytes);assert.equal(hash(b),reference.sha256);return JSON.parse(b.toString('utf8'));};
      const proof=validatePetRestCase({planned:p,actual:c,raw:read(c.responseRef),sql:read(c.sqlRef),fixture:f,runId,sourceFingerprint,producerHash,schema:fs.readFileSync(path.join(root,'backend/prisma/schema.prisma'),'utf8')});
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
    assert.equal(remainingRows,0);assert.equal(redisRemaining,0);if(fs.existsSync(storage))fs.rmSync(storage,{recursive:true});assert(!fs.existsSync(storage));checkSource();cleaned=true;
    write('fixture-cleanup.json',{runId,fixtureOnlyDisposable:true,sqlBefore:before,sqlAfter:after,remainingRows,redisRemaining,storageRemoved:true,sourceFingerprint,protectedFiles:protectedManifest.files.length,cloudCalls});
  }catch(e){console.error(`CLEANUP:${e}`);process.exitCode=1;}
  await app?.close();await prisma.$disconnect();redis.disconnect();globalThis.fetch=oldFetch;
  if(failure)write('first-failure.json',{at:new Date().toISOString(),error:String(failure),cleanupVerified:cleaned});
});

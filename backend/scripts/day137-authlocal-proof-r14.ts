// Test-only; production handlers with SQL/Redis; no provider network.
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
import fs from 'node:fs';import path from 'node:path';import bcrypt from 'bcryptjs';import jwt from 'jsonwebtoken';
import {PrismaClient} from '@prisma/client';import Redis from 'ioredis';
import {loadEnv,resolveAuthJwtConfig} from '../src/config/env';
import {buildTestConfig} from '../tests/helpers/rescue-read-fixtures';
import {claimRequest} from './day137-authlocal-budget-r14.mjs';
import {buildAuthLocalPlan} from '../../scripts/qa/day137/day137-authlocal-plan-r14.mjs';
import {validateAuthLocalCase,authRowsQuery} from '../../scripts/qa/day137/day137-authlocal-oracle-r14.mjs';
import {snapshotContract} from '../../scripts/qa/day137/day137-public-sql-r8b.mjs';
const root=path.resolve(__dirname,'../..'),out=process.env.DAY137_EVIDENCE_ROOT!,runId=process.env.DAY137_RUN_ID!,envelope=process.env.DAY137_ENVELOPE_PATH!,db=process.env.DATABASE_URL!,redisUrl=process.env.REDIS_URL!;
assert(/^d137-local-authlocal-[a-z0-9-]{6,28}$/.test(runId));assert(path.resolve(out).startsWith(path.join(root,'output-evidence/security/day137')+path.sep));assert.equal(new URL(db).hostname,'127.0.0.1');assert.equal(new URL(redisUrl).hostname,'127.0.0.1');
const hash=(v:Buffer|string)=>createHash('sha256').update(v).digest('hex'),write=(n:string,v:unknown)=>fs.writeFileSync(path.join(out,n),JSON.stringify(v,null,2)+'\n');
const ref=(n:string)=>{const b=fs.readFileSync(path.join(out,n));return {path:path.relative(root,path.join(out,n)).replaceAll('\\','/'),bytes:b.length,sha256:hash(b)};};
const sourcePath=process.env.DAY137_SOURCE_MANIFEST??'output-evidence/security/day137/d137-completion-20261005-r13/source-manifest.json';
assert(!path.isAbsolute(sourcePath)&&!sourcePath.split(/[\\/]/).includes('..'),'UNSAFE_SOURCE_MANIFEST');
const source=JSON.parse(fs.readFileSync(path.join(root,sourcePath),'utf8'));
const checkSource=()=>{for(const f of source.files){const b=fs.readFileSync(path.join(root,f.path));assert.equal(b.length,f.bytes);assert.equal(hash(b),f.sha256,f.path);}};checkSource();
const sourceFingerprint=source.sourceFingerprint,producerHash=hash(fs.readFileSync(__filename));
const psql=path.join(root,'output-evidence/day66/portable-postgres/pgsql/bin/psql.exe'),redisCli=path.join(root,'output-evidence/day67/portable-redis/redis-3.0.504/redis-cli.exe');
const pgArgs=['-h','127.0.0.1','-p',new URL(db).port,'-U','pawmate','-d',new URL(db).pathname.slice(1),'-At','-v','ON_ERROR_STOP=1'];
const sql=(q:string)=>JSON.parse(execFileSync(psql,[...pgArgs,'-c',q],{encoding:'utf8',timeout:10000}).trim());
const schema=fs.readFileSync(path.join(root,'backend/prisma/schema.prisma'),'utf8'),contract=snapshotContract(schema),snapshot=()=>sql(contract.query),rows=()=>sql(authRowsQuery);
const cliArgs=['-h','127.0.0.1','-p',new URL(redisUrl).port,'--raw'];
const redisSnapshot=()=>execFileSync(redisCli,[...cliArgs,'keys','auth:session:*'],{encoding:'utf8',timeout:10000}).trim().split(/\r?\n/).filter(Boolean).sort().map(key=>{const raw=JSON.parse(execFileSync(redisCli,[...cliArgs,'get',key],{encoding:'utf8',timeout:10000}).trim());const ttlMs=Number(execFileSync(redisCli,[...cliArgs,'pttl',key],{encoding:'utf8',timeout:10000}).trim());return {...raw,ttlMs};});
const prisma=new PrismaClient({datasources:{db:{url:db}}}),redis=new Redis(redisUrl,{lazyConnect:true,maxRetriesPerRequest:0}),roleNames=['owner_adopter','outsider','shelter_A','shelter_B'];
const provider=loadEnv(),base=buildTestConfig(),config={...base,nodeEnv:'production' as const,databaseUrl:db,redisUrl,supabaseUrl:provider.supabaseUrl,supabaseAnonKey:provider.supabaseAnonKey,supabaseServiceRoleKey:provider.supabaseServiceRoleKey,supabaseProjectRef:provider.supabaseProjectRef,supabaseBuckets:provider.supabaseBuckets,auth:{...base.auth,accessTokenSecret:'day137-authlocal-access-local-only',refreshTokenSecret:'day137-authlocal-refresh-local-only'}};
const jwtConfig=resolveAuthJwtConfig(config);
const f:any={users:Object.fromEntries(roleNames.map(r=>[r,randomUUID()])),emails:Object.fromEntries(roleNames.map(r=>[r,`${runId}-${r.toLowerCase()}@pawmate.test`])),jwt:{issuer:jwtConfig.issuer,audience:jwtConfig.audience,accessKeyId:jwtConfig.accessKeyId,refreshKeyId:jwtConfig.refreshKeyId}},plan=buildAuthLocalPlan(f);
write('expected-fixture.json',{runId,sourceFingerprint,values:f});write('plan.json',{runId,sourceFingerprint,producerHash,cases:plan});write('preflight-references.json',{plan:ref('plan.json'),fixture:ref('expected-fixture.json'),sourceFingerprint,producerHash});
let cloudCalls=0;const oldFetch=globalThis.fetch;globalThis.fetch=(async()=>{cloudCalls++;throw new Error('LOCAL_AUTH_PROVIDER_NETWORK_FORBIDDEN');}) as typeof fetch;
let app:any,requestCount=0,failure:unknown,cleaned=false;const cases:any[]=[],sessions:Record<string,any>={};
const save=()=>write('cross-role-results.json',{schemaVersion:1,runId,sourceFingerprint,producerHash,cases,requestCount,cloudCalls,verdict:failure?'FAIL':cases.length===plan.length&&cases.every(c=>c.verdict==='PASS')?'PASS_AUTHLOCAL_SLICE':'PARTIAL',limitations:['30 baseline only; real provider verify-email excluded','production handlers, real SQL/Redis; Fastify in-process HTTP not deployed TCP','tokens memory-only; persisted evidence contains hashes and independently verified claims']});
const call=async(url:string,role:string,payload:any)=>{claimRequest(envelope);requestCount++;return app.inject({method:'POST',url,payload,headers:role==='anonymous'?{}:{authorization:`Bearer ${sessions[role].accessToken}`}});};
const tokenProof=(token:string,type:'access'|'refresh')=>{const key=type==='access'?config.auth.accessTokenSecret:config.auth.refreshTokenSecret;const claims=jwt.verify(token,key,{algorithms:[jwtConfig.algorithm],issuer:jwtConfig.issuer,audience:jwtConfig.audience}) as jwt.JwtPayload;const decoded=jwt.decode(token,{complete:true})!;return {sha256:hash(token),verified:true,keyId:decoded.header.kid,claims};};
const project=(body:any)=>{if(typeof body.accessToken!=='string')return body;const {accessToken,refreshToken,...rest}=body;return {...rest,accessTokenProof:tokenProof(accessToken,'access'),refreshTokenProof:tokenProof(refreshToken,'refresh')};};
async function run(){
  const {buildApp}=await import('../src/app');app=buildApp({logger:false},{config});await app.ready();await redis.connect();assert.equal(await redis.dbsize(),0);assert(Object.values(snapshot()).every((t:any)=>t.count===0));
  const password='Day137AuthSynthetic!2026',stamp=new Date('2026-09-01T00:00:00Z');
  await prisma.user.createMany({data:roleNames.map(role=>({id:f.users[role],email:f.emails[role],passwordHash:bcrypt.hashSync(password,4),displayName:role,emailVerified:true,createdAt:stamp,updatedAt:stamp}))});
  for(const p of plan){
    const keys=await redis.keys('*');if(keys.length)await redis.del(...keys);await prisma.user.updateMany({data:{emailVerified:true,failedLoginAttempts:0,lockedUntil:null,updatedAt:stamp}});
    for(const role of roleNames){const r=await call('/auth/login','anonymous',{email:f.emails[role],password});assert.equal(r.statusCode,200);sessions[role]=r.json();}
    let payload:any;
    if(p.kind==='register')payload={email:p.state==='invalid'?'invalid-email':f.emails[p.account],password};
    if(p.kind==='resend')payload={email:p.state==='invalid'?'invalid-email':f.emails[p.account]};
    if(p.kind==='login')payload={email:f.emails[p.account],password:p.state==='invalid'?'WrongPassword1':password};
    if(p.state==='unverified')await prisma.user.update({where:{id:p.targetUserId},data:{emailVerified:false,updatedAt:stamp}});
    if(['refresh','logout'].includes(p.kind))payload={refreshToken:p.state==='invalid'?'malformed':sessions[p.account].refreshToken};
    if(p.state==='revoked'){const r=await call('/auth/logout','anonymous',{refreshToken:sessions[p.account].refreshToken});assert.equal(r.statusCode,204);}
    if(p.state==='expired'){const old=jwt.decode(sessions[p.account].refreshToken) as jwt.JwtPayload;payload.refreshToken=jwt.sign({typ:'refresh',sub:old.sub,sid:old.sid,jti:randomUUID(),iat:Math.floor(Date.now()/1000)-300,exp:Math.floor(Date.now()/1000)-120},config.auth.refreshTokenSecret,{algorithm:jwtConfig.algorithm,keyid:jwtConfig.refreshKeyId,issuer:jwtConfig.issuer,audience:jwtConfig.audience});}
    if(p.kind==='oauth')payload={provider:p.state==='invalid'?'email':'google',credential:'synthetic-no-external-provider-token'};
    const before=snapshot(),rowsBefore=rows(),cacheBefore=redisSnapshot(),startedDb=sql('SELECT to_json(clock_timestamp());');
    const identity={runId,id:p.id,sourceFingerprint,producerHash,method:p.method,url:p.url,role:p.role,state:p.state};
    const c:any={...identity,startedAt:new Date().toISOString(),precondition:{fixtureRef:ref('expected-fixture.json'),reset:'four real verified local users and independent real sessions; no provider call',payloadAccount:p.account},command:['Fastify.inject','POST',p.url],reviewer:'independent psql/redis-cli exact field/effect oracle',verdict:'NOT_RUN'};cases.push(c);save();
    try{
      const response=await call(p.url,p.role,payload),endedDb=sql('SELECT to_json(clock_timestamp());'),after=snapshot(),rowsAfter=rows(),cacheAfter=redisSnapshot();
      const body=response.statusCode===204?null:project(response.json());
      const presentedRefreshTokenProof=p.state==='expired'?{sha256:hash(payload.refreshToken),signatureVerified:true,keyId:jwt.decode(payload.refreshToken,{complete:true})!.header.kid,claims:jwt.verify(payload.refreshToken,config.auth.refreshTokenSecret,{algorithms:[jwtConfig.algorithm],issuer:jwtConfig.issuer,audience:jwtConfig.audience,ignoreExpiration:true}),observedAt:startedDb}:null;
      write(`${p.id}-response.json`,{...identity,status:response.statusCode,body,presentedRefreshTokenProof,effectiveSocialLoginEnabled:config.auth.socialLoginEnabled,redaction:'raw JWT removed; crypto verification and SHA retained'});
      write(`${p.id}-sql.json`,{...identity,query:contract.query,command:[psql,...pgArgs,'-c',contract.query],rowQuery:authRowsQuery,rowCommand:[psql,...pgArgs,'-c',authRowsQuery],before,after,rowsBefore,rowsAfter,startedDb,endedDb});
      write(`${p.id}-cache.json`,{...identity,before:cacheBefore,after:cacheAfter,boundary:'independent redis-cli readback, not app sessionStore',command:[redisCli,...cliArgs,'keys/get/pttl','auth:session:*']});
      c.responseRef=ref(`${p.id}-response.json`);c.sqlRef=ref(`${p.id}-sql.json`);c.cacheRef=ref(`${p.id}-cache.json`);c.actual={status:response.statusCode};
      const load=(r:any)=>JSON.parse(fs.readFileSync(path.join(root,r.path),'utf8'));
      const proof=validateAuthLocalCase({planned:p,actual:c,raw:load(c.responseRef),sql:load(c.sqlRef),cache:load(c.cacheRef),fixture:f,runId,sourceFingerprint,producerHash,schema});c.assertions=proof.assertions;assert.equal(proof.verdict,'PASS',JSON.stringify(proof.errors));c.verdict='PASS';
    }catch(e){c.verdict='FAIL';c.failure=String(e);throw e;}finally{c.endedAt=new Date().toISOString();save();}
  }
  assert.equal(cloudCalls,0);checkSource();
}
run().catch(e=>{failure=e;console.error(String(e));process.exitCode=1;}).finally(async()=>{
  save();try{const before=snapshot();await prisma.$executeRawUnsafe(`TRUNCATE ${contract.tables.map(t=>`"${t}"`).join(',')} CASCADE`);const after=snapshot(),keys=await redis.keys('*');if(keys.length)await redis.del(...keys);const remainingRows=Object.values(after).reduce((n:number,t:any)=>n+t.count,0),redisRemaining=await redis.dbsize();assert.equal(remainingRows,0);assert.equal(redisRemaining,0);checkSource();cleaned=true;write('fixture-cleanup.json',{runId,sourceFingerprint,fixtureOnlyDisposable:true,sqlBefore:before,sqlAfter:after,remainingRows,redisRemaining,cloudCalls});}catch(e){console.error(`CLEANUP:${e}`);process.exitCode=1;}
  await app?.close();await prisma.$disconnect();redis.disconnect();globalThis.fetch=oldFetch;if(failure)write('first-failure.json',{at:new Date().toISOString(),error:String(failure),cleanupVerified:cleaned});
});

import test from 'node:test';import assert from 'node:assert/strict';
import { loadEnv } from '../src/config/env';import { buildDay137ProductionConfig } from './day137-bootstrap-r20';
import { createNativeAuthForDay137 } from './day137-native-auth-factory-r22b';
test('actual production Auth constructor has native required gateways without making network calls',()=>{
  const config=buildDay137ProductionConfig(loadEnv(),'postgresql://pawmate@127.0.0.1:55447/pawmate?schema=public','redis://127.0.0.1:56387');
  const original=globalThis.fetch;let calls=0;globalThis.fetch=async()=>{calls++;throw Error('UNEXPECTED_CONSTRUCTOR_NETWORK');};
  try{const service=createNativeAuthForDay137(config,{} as any,{} as any,()=>new Date());assert.equal(typeof service.refresh,'function');assert.equal(calls,0);}finally{globalThis.fetch=original;}
});

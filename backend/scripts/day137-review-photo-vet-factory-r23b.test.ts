import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';import test from 'node:test';import type{PrismaClient}from'@prisma/client';
import{createDay137PhotoVetService}from'./day137-review-photo-vet-factory-r23b';
test('native Vet source assets remain readable from isolated evidence cwd',async()=>{
  const root=path.resolve(__dirname,'../..'),old=process.cwd(),fixture=JSON.parse(fs.readFileSync(path.join(root,'backend/prisma/data/day2_vet_seed_candidates.json'),'utf8'));
  const id=fixture.clinics[0].id;assert.equal(typeof id,'string');
  process.chdir(path.join(root,'output-evidence/security/day137/d137-review-photo-20261005-r23'));
  try{const service=createDay137PhotoVetService(root,{}as PrismaClient);const dto=await service.get(id);assert.equal(dto.vetId,id);}
  finally{process.chdir(old);}
});

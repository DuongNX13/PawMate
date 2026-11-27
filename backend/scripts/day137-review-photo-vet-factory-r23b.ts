import path from 'node:path';
import type {PrismaClient} from '@prisma/client';
import {createVetService} from '../src/services/vets/vet-service';
import {PrismaVetNearbyStore} from '../src/repositories/prisma-vet-nearby-store';
export function createDay137PhotoVetService(root:string,prisma:PrismaClient){
  if(process.env.DAY137_PHOTO_VET_COUNTERFACTUAL==='1')return createVetService({nearbyStore:new PrismaVetNearbyStore(prisma)});
  return createVetService({nearbyStore:new PrismaVetNearbyStore(prisma),
    seedPath:path.join(root,'backend/prisma/data/day2_vet_seed_candidates.json'),
    pilotSeedPath:path.join(root,'backend/prisma/data/day3_vet_geo_pilot.json')});
}

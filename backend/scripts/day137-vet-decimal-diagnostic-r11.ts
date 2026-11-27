import assert from 'node:assert/strict';
import fs from 'node:fs';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaVetNearbyStore } from '../src/repositories/prisma-vet-nearby-store';

// Boundary reproduction only: runtime HTTP/SQL failure is retained separately.
// This does not replace real SQL evidence or count as product acceptance.
async function main() {
  const output = process.argv[2];
  assert(output?.includes('d137-vetlocal-20261005-r11/'));
  const cases = [];
  for (const value of [new Prisma.Decimal('5.00'), 5, '5.00', null]) {
    const row = {
      id: 'd137-fixture-near', name: 'Fixture nearby', city: 'Fixture city',
      district: 'Fixture district', address: 'Fixture address', phone: null,
      latitude: 10.7769, longitude: 106.7009, services: [], sourceRank: 1,
      averageRating: value, reviewCount: 0, is24h: true, openHours: [],
      readyForMap: true, distanceMeters: 0,
    };
    const prismaBoundary = {
      $queryRawUnsafe: async () => [row],
    } as unknown as PrismaClient;
    const store = new PrismaVetNearbyStore(prismaBoundary);
    const nearby = await store.listNearby({ latitude: 10.7769, longitude: 106.7009, radiusMeters: 1000 });
    const detail = await store.getDetailById(row.id);
    cases.push({
      inputType: typeof value,
      constructor: value?.constructor.name ?? null,
      inputValue: value?.toString() ?? null,
      nearbyRating: nearby[0].averageRating,
      detailRating: detail?.averageRating,
    });
  }
  assert.equal(cases[0].constructor, 'Decimal');
  assert.equal(cases[0].nearbyRating, null);
  assert.equal(cases[0].detailRating, null);
  for (const i of [1, 2]) {
    assert.equal(cases[i].nearbyRating, 5);
    assert.equal(cases[i].detailRating, 5);
  }
  assert.equal(cases[3].nearbyRating, null);
  fs.writeFileSync(output, JSON.stringify({
    classification: 'PRODUCT_DEFECT', diagnosticVerdict: 'REPRODUCED_DECIMAL_DROPPED',
    productionChanged: false, databaseCalls: 0, cloudCalls: 0,
    acceptance: false, cases,
    limit: 'Controlled production adapter boundary with installed Prisma Decimal; real API/SQL first failure is separate evidence.',
  }, null, 2) + '\n', { flag: 'wx' });
  console.log('REPRODUCED_DECIMAL_DROPPED_NOT_ACCEPTANCE');
}
main().catch((error: unknown) => { console.error(error); process.exitCode = 1; });

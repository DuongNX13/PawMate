import assert from 'node:assert/strict';
import fs from 'node:fs';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaReviewStore } from '../src/repositories/prisma-review-store';

// Controlled adapter boundary reproduction. This is not real DB/HTTP acceptance.
async function main() {
  const output = process.argv[2];
  assert(output?.includes('d137-vet-decimal-20261005-r12/'));
  const cases = [];
  for (const value of [new Prisma.Decimal('4.00'), 4, '4.00', null]) {
    const queries: Array<{ query: string; parameters: unknown[] }> = [];
    const responses = [
      [{ id: '11111111-1111-1111-1111-111111111111', externalId: 'hn-001' }],
      [],
      [{ count: 2n }],
      [{ averageRating: value, reviewCount: 2n }],
      [{ rating: 3, count: 1n }, { rating: 5, count: 1n }],
    ];
    const boundary = {
      $queryRawUnsafe: async (query: string, ...parameters: unknown[]) => {
        queries.push({ query, parameters });
        return responses[queries.length - 1];
      },
    } as unknown as PrismaClient;
    const result = await new PrismaReviewStore(boundary).listReviews('hn-001', {
      limit: 20, sort: 'newest',
    });
    assert.equal(queries.length, 5);
    assert(queries[3].query.includes('ROUND(AVG(rating)::numeric, 2)'));
    assert(queries[3].query.includes("status = 'visible'"));
    assert.equal(result.summary.reviewCount, 2);
    assert.deepEqual(result.summary.distribution, { 1: 0, 2: 0, 3: 1, 4: 0, 5: 1 });
    cases.push({
      isPrismaDecimal: Prisma.Decimal.isDecimal(value),
      inputType: typeof value,
      inputValue: value?.toString() ?? null,
      actualAverage: result.summary.averageRating,
      queries: queries.length,
    });
  }
  assert.equal(cases[0].isPrismaDecimal, true);
  assert.equal(cases[0].actualAverage, null);
  assert.equal(cases[1].actualAverage, 4);
  assert.equal(cases[2].actualAverage, 4);
  assert.equal(cases[3].actualAverage, null);
  fs.writeFileSync(output, JSON.stringify({
    classification: 'PRODUCT_DEFECT', diagnosticVerdict: 'REPRODUCED_REVIEW_DECIMAL_DROPPED',
    productionChangedByDiagnostic: false, databaseCalls: 0, cloudCalls: 0,
    acceptance: false, cases,
    limit: 'Installed actual Prisma Decimal passed into production adapter; saved real HTTP/SQL R12 first failure is separate evidence.',
  }, null, 2) + '\n', { flag: 'wx' });
  console.log('REPRODUCED_REVIEW_DECIMAL_DROPPED_NOT_ACCEPTANCE');
}
main().catch((error: unknown) => { console.error(error); process.exitCode = 1; });

import { filterKnownDrift } from '../scripts/schema-drift-check';

const GENERATED = [{ table: 'rescue_cases', column: 'public_location' }];

const diff = (...statements: string[]) =>
  statements.map((statement) => `-- AlterTable\n${statement}\n`).join('\n');

describe('Day 128 D127-P3-001 schema drift check', () => {
  it('ignores DROP DEFAULT on a database generated column', () => {
    const sql = diff(
      'ALTER TABLE "rescue_cases" ALTER COLUMN "public_location" DROP DEFAULT;',
    );

    expect(filterKnownDrift(sql, GENERATED)).toEqual([]);
  });

  it('reports DROP DEFAULT on an ordinary column', () => {
    const sql = diff(
      'ALTER TABLE "rescue_cases" ALTER COLUMN "status" DROP DEFAULT;',
    );

    expect(filterKnownDrift(sql, GENERATED)).toEqual([
      'ALTER TABLE "rescue_cases" ALTER COLUMN "status" DROP DEFAULT',
    ]);
  });

  it('reports every other statement next to an ignored one', () => {
    const sql = diff(
      'ALTER TABLE "adoption_listings" ADD COLUMN     "age_months" SMALLINT;',
      'ALTER TABLE "rescue_cases" ALTER COLUMN "public_location" DROP DEFAULT;',
    );

    expect(filterKnownDrift(sql, GENERATED)).toEqual([
      'ALTER TABLE "adoption_listings" ADD COLUMN     "age_months" SMALLINT',
    ]);
  });

  it('treats an empty diff as no drift', () => {
    expect(filterKnownDrift('-- This is an empty migration.\n', GENERATED)).toEqual(
      [],
    );
  });
});

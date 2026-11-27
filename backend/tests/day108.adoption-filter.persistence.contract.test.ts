import fs from 'node:fs';
import path from 'node:path';

const read = (relativePath: string) =>
  fs.readFileSync(path.join(process.cwd(), relativePath), 'utf8');

describe('Day 108 Adoption age-filter persistence contract', () => {
  const preflight = read('prisma/sql/day108_adoption_age_filter_preflight.sql');
  const patch = read('prisma/sql/day108_adoption_age_filter_patch.sql');
  const postflight = read(
    'prisma/sql/day108_adoption_age_filter_postflight.sql',
  );
  const rollback = read('prisma/sql/day108_adoption_age_filter_rollback.sql');

  it('adds a nullable normalized age with a validated range and index', () => {
    expect(preflight).toContain('DAY108_ADOPTION_AGE_FILTER_PREFLIGHT_PASS');
    // D127-P3-002: the patch must be safe to re-run on a DB that already has it.
    expect(patch).toContain('ADD COLUMN IF NOT EXISTS age_months smallint');
    expect(patch).toContain('CREATE INDEX IF NOT EXISTS');
    expect(patch).toMatch(/IF NOT EXISTS \(\s*SELECT 1 FROM pg_constraint/);
    expect(patch).not.toMatch(/ADD COLUMN age_months/);
    expect(patch).toContain('adoption_listings_age_months_check');
    expect(patch).toContain('VALIDATE CONSTRAINT');
    expect(patch).toContain('adoption_listings_age_months_status_created_idx');
    expect(postflight).toContain('DAY108_ADOPTION_AGE_FILTER_POSTFLIGHT_PASS');
    expect(postflight).toContain('unresolved_listing_count');
  });

  it('keeps rollback explicit and fail closed', () => {
    expect(rollback).toContain('allow_destructive_rollback');
    expect(rollback).toContain('rollback refused');
    expect(rollback).toContain('DROP COLUMN IF EXISTS age_months');
  });
});

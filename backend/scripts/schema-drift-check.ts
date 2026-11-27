// Day 128 (D127-P3-001): compare the live DB with prisma/schema.prisma.
// Prisma cannot model `GENERATED ALWAYS AS (...) STORED` columns, so it reads
// their expression as a default and proposes `DROP DEFAULT`. Running that would
// be wrong, so the check skips it for columns the DB reports as generated and
// fails on anything else.
import { spawnSync } from 'node:child_process';

import { PrismaClient } from '@prisma/client';

export type GeneratedColumn = { table: string; column: string };

const DROP_DEFAULT =
  /^ALTER TABLE "([^"]+)" ALTER COLUMN "([^"]+)" DROP DEFAULT$/;

const toStatements = (sql: string): string[] =>
  sql
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.trim())
    .filter((statement) => statement.length > 0);

const isGeneratedDropDefault = (
  statement: string,
  generated: readonly GeneratedColumn[],
): boolean => {
  const match = DROP_DEFAULT.exec(statement);
  if (!match) return false;
  const [, table, column] = match;
  return generated.some(
    (entry) => entry.table === table && entry.column === column,
  );
};

export const filterKnownDrift = (
  sql: string,
  generated: readonly GeneratedColumn[],
): string[] =>
  toStatements(sql).filter(
    (statement) => !isGeneratedDropDefault(statement, generated),
  );

const readGeneratedColumns = async (): Promise<GeneratedColumn[]> => {
  const prisma = new PrismaClient();
  try {
    return await prisma.$queryRaw<GeneratedColumn[]>`
      SELECT table_name AS "table", column_name AS "column"
      FROM information_schema.columns
      WHERE table_schema = 'public' AND is_generated = 'ALWAYS'`;
  } finally {
    await prisma.$disconnect();
  }
};

const readPrismaDiff = (): string => {
  const result = spawnSync(
    'npx',
    [
      'prisma',
      'migrate',
      'diff',
      '--from-schema-datasource',
      'prisma/schema.prisma',
      '--to-schema-datamodel',
      'prisma/schema.prisma',
      '--script',
    ],
    { encoding: 'utf8', shell: process.platform === 'win32' },
  );
  if (result.status !== 0) {
    throw new Error(`prisma migrate diff failed: ${result.stderr}`);
  }
  return result.stdout;
};

const main = async (): Promise<number> => {
  const generated = await readGeneratedColumns();
  const drift = filterKnownDrift(readPrismaDiff(), generated);
  const ignored = generated.map((entry) => `${entry.table}.${entry.column}`);
  console.log(`generated columns ignored for DROP DEFAULT: ${ignored.join(', ') || 'none'}`);
  if (drift.length === 0) {
    console.log('SCHEMA_DRIFT_CHECK_PASS drift=0');
    return 0;
  }
  console.log(`SCHEMA_DRIFT_CHECK_FAIL drift=${drift.length}`);
  drift.forEach((statement) => console.log(`${statement};`));
  return 1;
};

if (require.main === module) {
  main()
    .then((code) => process.exit(code))
    .catch((error: unknown) => {
      console.error(error instanceof Error ? error.message : error);
      process.exit(1);
    });
}

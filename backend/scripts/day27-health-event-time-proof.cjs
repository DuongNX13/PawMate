const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const dotenv = require('dotenv');

const backendRoot = path.resolve(__dirname, '..');
const workspaceRoot = path.resolve(backendRoot, '..', '..');
const patchFile = path.join(
  backendRoot,
  'prisma',
  'sql',
  'day27_health_event_time_patch.sql',
);

const explicitEnvironment = { ...process.env };
dotenv.config({
  path: path.join(backendRoot, '.env'),
  override: false,
  quiet: true,
});
dotenv.config({
  path: path.join(backendRoot, '.env.local'),
  override: false,
  quiet: true,
});

for (const [key, value] of Object.entries(explicitEnvironment)) {
  process.env[key] = value;
}

const verifyOnly = process.argv.includes('--verify-only');
const evidenceArg = process.argv.find((arg) => arg.startsWith('--evidence-file='));
const evidenceFile = evidenceArg ? path.resolve(backendRoot, evidenceArg.slice('--evidence-file='.length)) : null;

const databaseUrl =
  process.env.PAWMATE_DB_MIGRATION_URL ||
  process.env.PAWMATE_REMINDER_DATABASE_URL ||
  process.env.DATABASE_DIRECT_URL ||
  process.env.SUPABASE_DATABASE_URL ||
  process.env.SUPABASE_DB_URL ||
  process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error('No PostgreSQL migration URL is configured.');
}

const url = new URL(databaseUrl);
if (!['postgres:', 'postgresql:'].includes(url.protocol)) {
  throw new Error(`Unsupported database protocol: ${url.protocol}`);
}

const isLocal = ['localhost', '127.0.0.1', '::1'].includes(
  url.hostname.toLowerCase(),
);
if (!isLocal && process.env.PAWMATE_ALLOW_REMOTE_MIGRATION !== '1') {
  throw new Error(
    'Remote migration is disabled. Set PAWMATE_ALLOW_REMOTE_MIGRATION=1 only for an approved environment.',
  );
}

if (!fs.existsSync(patchFile)) {
  throw new Error(`Day 27 SQL patch not found: ${patchFile}`);
}

const resolvePsql = () => {
  const portable = path.join(workspaceRoot, 'tools', 'pgsql', 'bin', 'psql.exe');
  if (fs.existsSync(portable)) return portable;

  const finder = process.platform === 'win32' ? 'where.exe' : 'which';
  const found = spawnSync(finder, ['psql'], { encoding: 'utf8', windowsHide: true });
  if (found.status === 0 && found.stdout.trim()) return found.stdout.trim().split(/\r?\n/)[0];
  throw new Error(`psql not found. Expected portable psql at ${portable} or psql on PATH.`);
};

const psql = resolvePsql();
const databaseName = decodeURIComponent(url.pathname.slice(1)) || 'postgres';

const connection = [
  `host=${url.hostname}`,
  `port=${url.port || '5432'}`,
  `user=${decodeURIComponent(url.username)}`,
  `dbname=${databaseName}`,
].join(' ');
const env = { ...process.env };
if (url.password) {
  env.PGPASSWORD = decodeURIComponent(url.password);
}

const runPsql = (args) => {
  const result = spawnSync(psql, args, {
    cwd: backendRoot,
    env,
    encoding: 'utf8',
    shell: false,
  });
  if (result.status !== 0) {
    const failure = [result.stdout?.trim(), result.stderr?.trim()].filter(Boolean).join('\n');
    if (/could not translate host name|name or service not known|could not resolve/i.test(failure)) {
      throw new Error(
        `Migration target ${url.hostname} is not resolvable. Restore the approved Supabase project or configure a new direct/session-pooler URL before applying Day 27 SQL.`,
      );
    }
    throw new Error(failure);
  }
  return result.stdout.trim();
};

if (!verifyOnly) runPsql(['-v', 'ON_ERROR_STOP=1', connection, '-f', patchFile]);

const proof = runPsql([
  '-v',
  'ON_ERROR_STOP=1',
  connection,
  '-At',
  '-F',
  '|',
  '-c',
  [
    'select c.column_name, c.data_type, c.character_maximum_length, c.is_nullable,',
    "       coalesce(pc.conname, ''), coalesce(pc.convalidated::text, '')",
    'from information_schema.columns c',
    "left join pg_constraint pc on pc.conname = 'health_records_event_time_format_check'",
    "  and pc.conrelid = 'public.health_records'::regclass",
    "where c.table_schema = 'public'",
    "  and c.table_name = 'health_records'",
    "  and c.column_name = 'event_time';",
  ].join(' '),
]);

const expected =
  'event_time|character varying|5|YES|health_records_event_time_format_check|true';
if (proof !== expected) {
  throw new Error(`Day 27 schema proof failed: ${proof || '<empty>'}`);
}

const result = {
  database: `${url.hostname}:${url.port || '5432'}/${databaseName}`,
  local: isLocal,
  mode: verifyOnly ? 'verify-only' : 'apply-and-verify',
  eventTimeColumn: 'varchar(5) nullable',
  formatConstraint: 'validated',
};
if (evidenceFile) {
  fs.mkdirSync(path.dirname(evidenceFile), { recursive: true });
  fs.writeFileSync(evidenceFile, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
}
console.log(JSON.stringify(result));

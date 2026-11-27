const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const dotenv = require('dotenv');

const backendRoot = path.resolve(__dirname, '..');
const workspaceRoot = path.resolve(backendRoot, '..', '..');
const patchFile = path.join(
  backendRoot,
  'prisma',
  'sql',
  'day34_rescue_foundation_patch.sql',
);
const seedFile = path.join(
  backendRoot,
  'prisma',
  'sql',
  'day34_rescue_seed.sql',
);
const preflightFile = path.join(
  backendRoot,
  'prisma',
  'sql',
  'day34_rescue_cloud_preflight.sql',
);
const postflightFile = path.join(
  backendRoot,
  'prisma',
  'sql',
  'day34_rescue_cloud_postflight.sql',
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

const apply = process.argv.includes('--apply');
const withSeed = process.argv.includes('--with-seed');
const evidenceArg = process.argv.find((arg) =>
  arg.startsWith('--evidence-file='),
);
const evidenceFile = evidenceArg
  ? path.resolve(backendRoot, evidenceArg.slice('--evidence-file='.length))
  : null;

const databaseUrl =
  process.env.PAWMATE_RESCUE_DATABASE_URL ||
  process.env.PAWMATE_DB_MIGRATION_URL ||
  process.env.DATABASE_DIRECT_URL ||
  process.env.SUPABASE_DATABASE_URL ||
  process.env.SUPABASE_DB_URL ||
  process.env.DATABASE_URL ||
  'postgresql://pawmate:pawmate@localhost:5432/pawmate';
const url = new URL(databaseUrl);
if (!['postgres:', 'postgresql:'].includes(url.protocol)) {
  throw new Error(`Unsupported database protocol: ${url.protocol}`);
}

const isLocal = ['localhost', '127.0.0.1', '::1'].includes(
  url.hostname.toLowerCase(),
);
if (!isLocal && apply && process.env.PAWMATE_ALLOW_REMOTE_MIGRATION !== '1') {
  throw new Error(
    'Remote migration is disabled. Set PAWMATE_ALLOW_REMOTE_MIGRATION=1 only for the approved Supabase project.',
  );
}
if (!isLocal && withSeed) {
  throw new Error('The Day 34 development seed is forbidden on remote databases.');
}
if (
  !fs.existsSync(patchFile) ||
  !fs.existsSync(seedFile) ||
  !fs.existsSync(preflightFile) ||
  !fs.existsSync(postflightFile)
) {
  throw new Error('Day 34 migration, seed, preflight, or postflight SQL is missing.');
}

const resolvePsql = () => {
  const portable = path.join(workspaceRoot, 'tools', 'pgsql', 'bin', 'psql.exe');
  if (fs.existsSync(portable)) return portable;
  const finder = process.platform === 'win32' ? 'where.exe' : 'which';
  const found = spawnSync(finder, ['psql'], {
    encoding: 'utf8',
    windowsHide: true,
  });
  if (found.status === 0 && found.stdout.trim()) {
    return found.stdout.trim().split(/\r?\n/)[0];
  }
  throw new Error(`psql not found. Expected ${portable} or a PATH entry.`);
};

const psql = resolvePsql();
const databaseName = decodeURIComponent(url.pathname.slice(1)) || 'postgres';
const connection = [
  `host=${url.hostname}`,
  `port=${url.port || '5432'}`,
  `user=${decodeURIComponent(url.username)}`,
  `dbname=${databaseName}`,
  url.searchParams.get('sslmode')
    ? `sslmode=${url.searchParams.get('sslmode')}`
    : null,
]
  .filter(Boolean)
  .join(' ');
const env = { ...process.env };
if (url.password) env.PGPASSWORD = decodeURIComponent(url.password);

const runPsql = (args) => {
  const result = spawnSync(psql, args, {
    cwd: backendRoot,
    env,
    encoding: 'utf8',
    shell: false,
    windowsHide: true,
  });
  if (result.status !== 0) {
    const failure = [result.stdout?.trim(), result.stderr?.trim()]
      .filter(Boolean)
      .join('\n');
    throw new Error(failure || `psql exited with ${result.status}`);
  }
  return result.stdout.trim();
};

const runQuery = (sql) =>
  runPsql([
    '-v',
    'ON_ERROR_STOP=1',
    connection,
    '-At',
    '-F',
    '|',
    '-c',
    sql,
  ]);

const parseMetrics = (output) =>
  Object.fromEntries(
    output
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => {
        const separator = line.indexOf('|');
        return [line.slice(0, separator), line.slice(separator + 1)];
      }),
  );

const preflightSql = fs.readFileSync(preflightFile, 'utf8');
const verificationSql = fs.readFileSync(postflightFile, 'utf8');

const expectedPreflightMetrics = {
  postgis_extension_count: '1',
  phase1_users_table_count: '1',
  users_id_uuid_count: '1',
  pet_species_enum_count: '1',
  pet_species_required_label_count: '5',
  can_create_public: 'true',
};

const targetPreflightMetricNames = [
  'existing_target_table_count',
  'existing_target_enum_count',
  'existing_target_index_count',
  'existing_target_policy_count',
  'existing_request_user_function_count',
];

const expectedMetrics = {
  table_count: '6',
  enum_count: '5',
  rls_count: '6',
  policy_count: '6',
  invalid_constraint_count: '0',
  required_index_count: '7',
  public_location_generated: 'ALWAYS:geography',
  public_sensitive_column_count: '0',
  private_location_column_count: '3',
  comment_location_column_count: '0',
  request_user_function_count: '1',
  postgrest_base_table_privilege_count: '0',
};

const cleanupSeed = () =>
  runQuery(`
    DELETE FROM public.rescue_status_events
      WHERE changed_by_user_id = '34000000-0000-4000-8000-000000000001';
    DELETE FROM public.media_assets
      WHERE owner_user_id = '34000000-0000-4000-8000-000000000001';
    DELETE FROM public.rescue_comments
      WHERE author_user_id = '34000000-0000-4000-8000-000000000001';
    DELETE FROM public.rescue_case_private_locations
      WHERE owner_user_id = '34000000-0000-4000-8000-000000000001';
    DELETE FROM public.rescue_cases
      WHERE owner_user_id = '34000000-0000-4000-8000-000000000001';
    DELETE FROM public.rescue_case_drafts
      WHERE owner_user_id = '34000000-0000-4000-8000-000000000001';
    DELETE FROM public.users
      WHERE id = '34000000-0000-4000-8000-000000000001';
  `);

let seedMetrics = null;
try {
  const preflightMetrics = parseMetrics(runQuery(preflightSql));
  for (const [name, expected] of Object.entries(expectedPreflightMetrics)) {
    if (preflightMetrics[name] !== expected) {
      throw new Error(
        `Day 34 preflight failed for ${name}: expected ${expected}, received ${preflightMetrics[name] ?? '<missing>'}.`,
      );
    }
  }
  const targetObjectsExist = targetPreflightMetricNames.some(
    (name) => preflightMetrics[name] !== '0',
  );
  if (targetObjectsExist) {
    const currentMetrics = parseMetrics(runQuery(verificationSql));
    for (const [name, expected] of Object.entries(expectedMetrics)) {
      if (currentMetrics[name] !== expected) {
        throw new Error(
          `Day 34 preflight found a partial target schema: ${name} expected ${expected}, received ${currentMetrics[name] ?? '<missing>'}.`,
        );
      }
    }
  }

  if (apply) {
    runPsql(['-v', 'ON_ERROR_STOP=1', connection, '-f', patchFile]);
  }
  const metrics = parseMetrics(runQuery(verificationSql));
  for (const [name, expected] of Object.entries(expectedMetrics)) {
    if (metrics[name] !== expected) {
      throw new Error(
        `Day 34 schema proof failed for ${name}: expected ${expected}, received ${metrics[name] ?? '<missing>'}.`,
      );
    }
  }

  if (withSeed) {
    cleanupSeed();
    runPsql(['-v', 'ON_ERROR_STOP=1', connection, '-f', seedFile]);
    seedMetrics = parseMetrics(
      runQuery(`
        SELECT 'seed_case_count', count(*)::text
          FROM public.rescue_cases
          WHERE id = '34000000-0000-4000-8000-000000000003';
        SELECT 'seed_private_location_count', count(*)::text
          FROM public.rescue_case_private_locations
          WHERE case_id = '34000000-0000-4000-8000-000000000003';
        SELECT 'seed_media_count', count(*)::text
          FROM public.media_assets
          WHERE case_id = '34000000-0000-4000-8000-000000000003'
            AND status = 'attached';
        SELECT 'seed_comment_count', count(*)::text
          FROM public.rescue_comments
          WHERE case_id = '34000000-0000-4000-8000-000000000003';
        SELECT 'seed_status_event_count', count(*)::text
          FROM public.rescue_status_events
          WHERE case_id = '34000000-0000-4000-8000-000000000003';
        SELECT 'seed_exact_vs_public_separated',
          (p.latitude <> c.approximate_latitude
           AND p.longitude <> c.approximate_longitude)::text
          FROM public.rescue_cases c
          JOIN public.rescue_case_private_locations p ON p.case_id = c.id
          WHERE c.id = '34000000-0000-4000-8000-000000000003';
      `),
    );
    const expectedSeed = {
      seed_case_count: '1',
      seed_private_location_count: '1',
      seed_media_count: '1',
      seed_comment_count: '1',
      seed_status_event_count: '1',
      seed_exact_vs_public_separated: 'true',
    };
    for (const [name, expected] of Object.entries(expectedSeed)) {
      if (seedMetrics[name] !== expected) {
        throw new Error(
          `Day 34 seed proof failed for ${name}: expected ${expected}, received ${seedMetrics[name] ?? '<missing>'}.`,
        );
      }
    }
  }

  const result = {
    database: `${url.hostname}:${url.port || '5432'}/${databaseName}`,
    local: isLocal,
    mode: apply ? 'apply-and-verify' : 'verify-only',
    seed: withSeed ? 'verified-and-cleaned' : 'not-run',
    preflightMetrics,
    metrics,
    seedMetrics,
  };
  if (evidenceFile) {
    fs.mkdirSync(path.dirname(evidenceFile), { recursive: true });
    fs.writeFileSync(evidenceFile, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
  }
  console.log(JSON.stringify(result));
} finally {
  if (withSeed && isLocal) cleanupSeed();
}

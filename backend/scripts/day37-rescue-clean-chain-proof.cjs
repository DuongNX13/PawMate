const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const workspaceRoot = path.resolve(repoRoot, '..');
const sqlRoot = path.join(backendRoot, 'prisma', 'sql');
const portablePgRoot = path.join(workspaceRoot, 'tools', 'pgsql', 'bin');
const psql = path.join(portablePgRoot, process.platform === 'win32' ? 'psql.exe' : 'psql');
const pgDump = path.join(
  portablePgRoot,
  process.platform === 'win32' ? 'pg_dump.exe' : 'pg_dump',
);

const sourceUrl = new URL(
  process.env.PAWMATE_DAY37_SOURCE_DATABASE_URL ||
    'postgresql://pawmate:pawmate@127.0.0.1:5432/pawmate',
);
const localHosts = new Set(['localhost', '127.0.0.1', '::1']);
const sourceDatabase = decodeURIComponent(sourceUrl.pathname.slice(1));
const sourceHost = sourceUrl.hostname.toLowerCase();
const sourcePort = sourceUrl.port || '5432';
const sourceUser = decodeURIComponent(sourceUrl.username);
const maintenanceDatabase = 'postgres';

if (!['postgres:', 'postgresql:'].includes(sourceUrl.protocol)) {
  throw new Error(`Unsupported database protocol: ${sourceUrl.protocol}`);
}
if (!localHosts.has(sourceHost)) {
  throw new Error('Day 37 clean-chain proof is local-only; remote hosts are forbidden.');
}
if (sourceDatabase !== 'pawmate') {
  throw new Error(
    `Day 37 source database must be the read-only schema source named pawmate; received ${sourceDatabase}.`,
  );
}
if (!sourceUser) {
  throw new Error('Day 37 source database URL must include a local PostgreSQL user.');
}
if (!fs.existsSync(psql) || !fs.existsSync(pgDump)) {
  throw new Error(`Portable PostgreSQL tools are missing under ${portablePgRoot}.`);
}

const now = new Date();
const timestamp = now
  .toISOString()
  .replace(/[-:]/g, '')
  .replace(/\.\d{3}Z$/, 'Z');
const targetDatabase = `pawmate_day37_${timestamp.toLowerCase()}_${process.pid}`;
if (!/^pawmate_day37_[a-z0-9_]+$/.test(targetDatabase)) {
  throw new Error(`Unsafe disposable database name: ${targetDatabase}`);
}

const evidenceArg = process.argv.find((argument) =>
  argument.startsWith('--evidence-dir='),
);
const evidenceRoot = path.join(repoRoot, 'output-evidence', 'day37');
const evidenceDir = evidenceArg
  ? path.resolve(repoRoot, evidenceArg.slice('--evidence-dir='.length))
  : path.join(evidenceRoot, timestamp.toLowerCase());
const evidenceRelative = path.relative(evidenceRoot, evidenceDir);
if (
  evidenceRelative.startsWith('..') ||
  path.isAbsolute(evidenceRelative) ||
  evidenceRelative.length === 0
) {
  throw new Error(
    `Evidence directory must be a child of ${evidenceRoot}; received ${evidenceDir}.`,
  );
}
const logsDir = path.join(evidenceDir, 'logs');
const coverageDir = path.join(evidenceDir, 'coverage');
const dumpFile = path.join(evidenceDir, 'source-schema-only.sql');
const resultFile = path.join(evidenceDir, 'day37-clean-chain-result.json');
const manifestFile = path.join(evidenceDir, 'manifest.json');

fs.mkdirSync(logsDir, { recursive: true });

const passwordEnvironment = {
  ...process.env,
  PGPASSWORD: decodeURIComponent(sourceUrl.password),
};
const sourceReadOnlyEnvironment = {
  ...passwordEnvironment,
  PGOPTIONS: [
    passwordEnvironment.PGOPTIONS,
    '-c default_transaction_read_only=on',
  ]
    .filter(Boolean)
    .join(' '),
};
const steps = [];
const defects = [];
let targetCreated = false;
let terminalError = null;
let sourceFingerprintBefore = null;
let sourceFingerprintAfter = null;
let sourceReadOnlySetting = null;

const sha256 = (filePath) =>
  crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');

const relativeToRepo = (filePath) =>
  path.relative(repoRoot, filePath).replaceAll('\\', '/');

const redact = (value) =>
  String(value)
    .replace(/(postgres(?:ql)?:\/\/[^:\s/]+:)[^@\s/]+@/gi, '$1[REDACTED]@')
    .replace(/(PGPASSWORD=)[^\s]+/gi, '$1[REDACTED]');

const run = (id, command, args, options = {}) => {
  const startedAt = new Date().toISOString();
  const logFile = path.join(logsDir, `${String(steps.length + 1).padStart(2, '0')}-${id}.log`);
  const result = spawnSync(command, args, {
    cwd: options.cwd || repoRoot,
    env: options.env || passwordEnvironment,
    encoding: 'utf8',
    windowsHide: true,
    maxBuffer: 64 * 1024 * 1024,
  });
  const finishedAt = new Date().toISOString();
  const exitCode = result.status ?? 1;
  const commandPreview = [command, ...args].map(redact).join(' ');
  fs.writeFileSync(
    logFile,
    [
      `started_at=${startedAt}`,
      `finished_at=${finishedAt}`,
      `exit_code=${exitCode}`,
      `command=${commandPreview}`,
      '',
      '[stdout]',
      result.stdout || '',
      '',
      '[stderr]',
      result.stderr || '',
      '',
      '[spawn_error]',
      result.error ? result.error.stack || result.error.message : '',
    ].join('\n'),
    'utf8',
  );
  const step = {
    id,
    startedAt,
    finishedAt,
    exitCode,
    log: relativeToRepo(logFile),
  };
  steps.push(step);
  if (exitCode !== 0 && !options.allowFailure) {
    throw new Error(`${id} failed with exit code ${exitCode}; see ${step.log}.`);
  }
  return { ...result, exitCode, step };
};

const connectionArgs = (database) => [
  '-h',
  sourceHost,
  '-p',
  sourcePort,
  '-U',
  sourceUser,
  '-d',
  database,
  '-X',
  '-v',
  'ON_ERROR_STOP=1',
];

const runSql = (id, database, sql, options = {}) =>
  run(
    id,
    psql,
    [...connectionArgs(database), '-At', '-F', '|', '-c', sql],
    options,
  );

const runSqlFile = (id, database, fileName, options = {}) => {
  const filePath = path.join(sqlRoot, fileName);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Required SQL file is missing: ${filePath}`);
  }
  return run(id, psql, [...connectionArgs(database), '-At', '-F', '|', '-f', filePath], options);
};

const parseMetrics = (output) =>
  Object.fromEntries(
    String(output)
      .split(/\r?\n/)
      .filter((line) => line.includes('|'))
      .map((line) => {
        const separator = line.indexOf('|');
        return [line.slice(0, separator), line.slice(separator + 1)];
      }),
  );

const assertMetrics = (label, actual, expected) => {
  const mismatches = Object.entries(expected)
    .filter(([key, value]) => actual[key] !== String(value))
    .map(([key, value]) => `${key}: expected ${value}, got ${actual[key] ?? '[missing]'}`);
  if (mismatches.length > 0) {
    throw new Error(`${label} metric mismatch: ${mismatches.join('; ')}`);
  }
};

const metricFile = (id, database, fileName, expected, options = {}) => {
  const result = runSqlFile(id, database, fileName, options);
  const metrics = parseMetrics(result.stdout);
  assertMetrics(id, metrics, expected);
  return metrics;
};

const sourceFingerprintSql = `
SELECT 'postgis_extension_count', count(*)::text
FROM pg_extension WHERE extname = 'postgis';
SELECT 'users_table_count', count(*)::text
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'users';
SELECT 'pet_species_required_label_count', count(*)::text
FROM pg_enum e
JOIN pg_type t ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public' AND t.typname = 'PetSpecies'
  AND e.enumlabel IN ('dog', 'cat', 'bird', 'rabbit', 'other');
SELECT 'rescue_table_count', count(*)::text
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'rescue_case_drafts', 'rescue_cases', 'rescue_case_private_locations',
    'rescue_comments', 'media_assets', 'rescue_status_events',
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  );
SELECT 'rescue_enum_count', count(*)::text
FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname IN (
    'RescueCaseStatus', 'RescueContactPreference',
    'RescueCommentModerationState', 'MediaPurpose', 'MediaLifecycleStatus'
  );
SELECT 'rescue_data_row_count', (
  (SELECT count(*) FROM public.rescue_case_drafts) +
  (SELECT count(*) FROM public.rescue_cases) +
  (SELECT count(*) FROM public.rescue_case_private_locations) +
  (SELECT count(*) FROM public.rescue_comments) +
  (SELECT count(*) FROM public.media_assets) +
  (SELECT count(*) FROM public.rescue_status_events) +
  (SELECT count(*) FROM public.idempotency_records) +
  (SELECT count(*) FROM public.outbox_events) +
  (SELECT count(*) FROM public.media_upload_sessions)
)::text;
`;

const baselineZeroSql = `
SELECT 'target_table_count', count(*)::text
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'rescue_case_drafts', 'rescue_cases', 'rescue_case_private_locations',
    'rescue_comments', 'media_assets', 'rescue_status_events',
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  );
SELECT 'target_enum_count', count(*)::text
FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname IN (
    'RescueCaseStatus', 'RescueContactPreference',
    'RescueCommentModerationState', 'MediaPurpose', 'MediaLifecycleStatus'
  );
SELECT 'target_index_count', count(*)::text
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'rescue_%';
SELECT 'day36_index_count', count(*)::text
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idempotency_records_scope_key', 'idempotency_records_expires_idx',
    'idempotency_records_user_created_idx', 'outbox_events_dedupe_key_key',
    'outbox_events_claim_idx', 'outbox_events_aggregate_created_idx',
    'media_upload_sessions_staging_storage_key_key',
    'media_upload_sessions_sanitized_storage_key_key',
    'media_upload_sessions_expiry_idx'
  );
SELECT 'request_user_function_count', count(*)::text
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'pawmate_request_user_id';
SELECT 'verification_version_count', count(*)::text
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'media_assets'
  AND column_name = 'verification_version';
`;

const day34PreflightExpected = {
  postgis_extension_count: '1',
  phase1_users_table_count: '1',
  users_id_uuid_count: '1',
  pet_species_enum_count: '1',
  pet_species_required_label_count: '5',
  can_create_public: 'true',
  existing_target_table_count: '0',
  existing_target_enum_count: '0',
  existing_target_index_count: '0',
  existing_target_policy_count: '0',
  existing_request_user_function_count: '0',
};
const day34PostflightExpected = {
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
const day35PreflightExpected = {
  rescue_cases_table_count: '1',
  required_enum_count: '2',
  existing_day35_index_count: '0',
};
const day35PostflightExpected = {
  day35_index_count: '4',
  day35_index_valid_count: '4',
  day35_partial_index_count: '4',
};
const day36PreflightExpected = {
  source_table_count: '2',
  source_uuid_key_count: '2',
  source_media_position_unique_index_count: '3',
  can_create_public: 'true',
  existing_target_table_count: '0',
  existing_verification_version_count: '0',
  existing_target_index_count: '0',
  existing_target_policy_count: '0',
};
const day36PostflightExpected = {
  table_count: '3',
  verification_version_contract: 'NO:integer:0',
  idempotency_hash_column_count: '2',
  plaintext_idempotency_key_count: '0',
  idempotency_response_jsonb_count: '1',
  upload_audit_column_count: '12',
  outbox_delivery_column_count: '7',
  rls_count: '3',
  policy_count: '0',
  foreign_key_count: '3',
  critical_check_constraint_count: '14',
  media_size_50mb_constraint_count: '2',
  legacy_100mb_constraint_count: '0',
  invalid_constraint_count: '0',
  required_index_count: '12',
  valid_required_index_count: '12',
  partial_index_count: '5',
  postgrest_base_table_privilege_count: '0',
};

const verifyCurrentChain = (prefix, database, options = {}) => ({
  day34: metricFile(
    `${prefix}-day34-postflight`,
    database,
    'day34_rescue_cloud_postflight.sql',
    day34PostflightExpected,
    options,
  ),
  day35: metricFile(
    `${prefix}-day35-postflight`,
    database,
    'day35_rescue_read_indexes_postflight.sql',
    day35PostflightExpected,
    options,
  ),
  day36: metricFile(
    `${prefix}-day36-postflight`,
    database,
    'day36_rescue_write_postflight.sql',
    day36PostflightExpected,
    options,
  ),
});

const applyChain = (prefix, database, proveIdempotency) => {
  const proof = {};
  proof.day34Preflight = metricFile(
    `${prefix}-day34-preflight`,
    database,
    'day34_rescue_cloud_preflight.sql',
    day34PreflightExpected,
  );
  runSqlFile(
    `${prefix}-day34-apply`,
    database,
    'day34_rescue_foundation_patch.sql',
  );
  proof.day34Postflight = metricFile(
    `${prefix}-day34-postflight`,
    database,
    'day34_rescue_cloud_postflight.sql',
    day34PostflightExpected,
  );
  if (proveIdempotency) {
    runSqlFile(
      `${prefix}-day34-idempotent-apply`,
      database,
      'day34_rescue_foundation_patch.sql',
    );
    metricFile(
      `${prefix}-day34-idempotent-postflight`,
      database,
      'day34_rescue_cloud_postflight.sql',
      day34PostflightExpected,
    );
  }

  proof.day35Preflight = metricFile(
    `${prefix}-day35-preflight`,
    database,
    'day35_rescue_read_indexes_preflight.sql',
    day35PreflightExpected,
  );
  runSqlFile(
    `${prefix}-day35-apply`,
    database,
    'day35_rescue_read_indexes_patch.sql',
  );
  proof.day35Postflight = metricFile(
    `${prefix}-day35-postflight`,
    database,
    'day35_rescue_read_indexes_postflight.sql',
    day35PostflightExpected,
  );
  if (proveIdempotency) {
    runSqlFile(
      `${prefix}-day35-idempotent-apply`,
      database,
      'day35_rescue_read_indexes_patch.sql',
    );
    metricFile(
      `${prefix}-day35-idempotent-postflight`,
      database,
      'day35_rescue_read_indexes_postflight.sql',
      day35PostflightExpected,
    );
  }

  proof.day36Preflight = metricFile(
    `${prefix}-day36-preflight`,
    database,
    'day36_rescue_write_preflight.sql',
    day36PreflightExpected,
  );
  runSqlFile(
    `${prefix}-day36-apply`,
    database,
    'day36_rescue_write_patch.sql',
  );
  proof.day36Postflight = metricFile(
    `${prefix}-day36-postflight`,
    database,
    'day36_rescue_write_postflight.sql',
    day36PostflightExpected,
  );
  if (proveIdempotency) {
    runSqlFile(
      `${prefix}-day36-idempotent-apply`,
      database,
      'day36_rescue_write_patch.sql',
    );
    metricFile(
      `${prefix}-day36-idempotent-postflight`,
      database,
      'day36_rescue_write_postflight.sql',
      day36PostflightExpected,
    );
  }
  return proof;
};

const rollbackChain = (prefix, database) => {
  runSqlFile(
    `${prefix}-day36-rollback`,
    database,
    'day36_rescue_write_rollback.sql',
  );
  runSqlFile(
    `${prefix}-day35-rollback`,
    database,
    'day35_rescue_read_indexes_rollback.sql',
  );
  runSqlFile(
    `${prefix}-day34-rollback`,
    database,
    'day34_rescue_foundation_rollback.sql',
  );
  const zeroResult = runSql(`${prefix}-zero-audit`, database, baselineZeroSql);
  const metrics = parseMetrics(zeroResult.stdout);
  assertMetrics(`${prefix}-zero-audit`, metrics, {
    target_table_count: '0',
    target_enum_count: '0',
    target_index_count: '0',
    day36_index_count: '0',
    request_user_function_count: '0',
    verification_version_count: '0',
  });
  return metrics;
};

const jestEnvironment = (databaseUrl) => ({
  ...process.env,
  DATABASE_URL: databaseUrl,
  PAWMATE_RESCUE_TEST_DATABASE_URL: databaseUrl,
  PAWMATE_RESCUE_DB_INTEGRATION: '1',
  PAWMATE_ALLOW_REMOTE_RESCUE_TEST: '0',
  NODE_ENV: 'test',
});

const runJest = (id, targetUrl, args) =>
  run(
    id,
    process.execPath,
    [path.join(backendRoot, 'node_modules', 'jest', 'bin', 'jest.js'), ...args],
    {
      cwd: backendRoot,
      env: jestEnvironment(targetUrl),
      allowFailure: true,
    },
  );

const runNpmGate = (id, targetUrl, args) =>
  run(
    id,
    process.execPath,
    [
      path.join(
        path.dirname(process.execPath),
        'node_modules',
        'npm',
        'bin',
        'npm-cli.js',
      ),
      ...args,
    ],
    {
      cwd: backendRoot,
      env: jestEnvironment(targetUrl),
      allowFailure: true,
    },
  );

const walkFiles = (directory) => {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    return entry.isDirectory() ? walkFiles(absolute) : [absolute];
  });
};

const writeManifest = (status, details = {}) => {
  const artifactFiles = walkFiles(evidenceDir).filter(
    (filePath) => filePath !== manifestFile,
  );
  const manifest = {
    schemaVersion: 1,
    day: 37,
    scope: 'Rescue backend TEST-only clean migration-chain proof',
    status,
    startedAt: now.toISOString(),
    finishedAt: new Date().toISOString(),
    executor: 'Codex Day 37 backend test lane',
    repository: {
      root: repoRoot,
      commit: details.commit || null,
      dirtyTrackedCount: details.dirtyTrackedCount ?? null,
    },
    safety: {
      sourceDatabase: `${sourceHost}:${sourcePort}/${sourceDatabase}`,
      sourceAccess: 'pg_dump schema-only and read-only fingerprints/postflights',
      sourceReadOnlySetting,
      disposableDatabase: targetDatabase,
      disposablePrefixVerified: targetDatabase.startsWith('pawmate_day37_'),
      remoteDatabaseWrites: false,
      sourceDatabaseWrites: false,
      disposableDatabaseDropped: !targetCreated,
      containsTestDataOnly: true,
      redactionStatus: details.redactionStatus || 'PENDING',
    },
    sourceFingerprintBefore,
    sourceFingerprintAfter,
    sourceFingerprintUnchanged:
      sourceFingerprintBefore !== null &&
      JSON.stringify(sourceFingerprintBefore) === JSON.stringify(sourceFingerprintAfter),
    sourceFiles: details.sourceFiles || {},
    coverage: details.coverage || null,
    defects,
    steps,
    artifacts: artifactFiles.map((filePath) => ({
      path: relativeToRepo(filePath),
      bytes: fs.statSync(filePath).size,
      sha256: sha256(filePath),
    })),
    terminalError: terminalError ? redact(terminalError.stack || terminalError.message) : null,
  };
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
};

const scanEvidenceForSecrets = () => {
  const textExtensions = new Set([
    '.csv',
    '.html',
    '.info',
    '.js',
    '.json',
    '.log',
    '.md',
    '.sql',
    '.txt',
  ]);
  const findings = [];
  for (const filePath of walkFiles(evidenceDir)) {
    if (!textExtensions.has(path.extname(filePath).toLowerCase())) continue;
    const text = fs.readFileSync(filePath, 'utf8');
    if (/postgres(?:ql)?:\/\/[^:\s/]+:[^@\s/]+@/i.test(text)) {
      findings.push(`${relativeToRepo(filePath)}:database-url-with-password`);
    }
    if (/\b(?:SUPABASE_SERVICE_ROLE_KEY|JWT_SECRET|PGPASSWORD)\s*=\s*[^\s\[]+/i.test(text)) {
      findings.push(`${relativeToRepo(filePath)}:secret-assignment`);
    }
  }
  if (findings.length > 0) {
    throw new Error(`Evidence secret scan failed: ${findings.join(', ')}`);
  }
  return 'PASS';
};

const sourceFiles = [
  'day34_rescue_cloud_preflight.sql',
  'day34_rescue_foundation_patch.sql',
  'day34_rescue_cloud_postflight.sql',
  'day34_rescue_foundation_rollback.sql',
  'day35_rescue_read_indexes_preflight.sql',
  'day35_rescue_read_indexes_patch.sql',
  'day35_rescue_read_indexes_postflight.sql',
  'day35_rescue_read_indexes_rollback.sql',
  'day36_rescue_write_preflight.sql',
  'day36_rescue_write_patch.sql',
  'day36_rescue_write_postflight.sql',
  'day36_rescue_write_rollback.sql',
];

const runtimeDetails = {
  sourceFiles: Object.fromEntries(
    sourceFiles.map((fileName) => [fileName, sha256(path.join(sqlRoot, fileName))]),
  ),
  coverage: null,
  redactionStatus: 'PENDING',
  commit: null,
  dirtyTrackedCount: null,
};

try {
  runtimeDetails.commit = run(
    'git-head',
    'git',
    ['rev-parse', 'HEAD'],
    { cwd: repoRoot },
  ).stdout.trim();
  runtimeDetails.dirtyTrackedCount = Number(
    run(
      'git-dirty-tracked-count',
      'git',
      ['status', '--porcelain', '--untracked-files=no'],
      { cwd: repoRoot },
    ).stdout
      .split(/\r?\n/)
      .filter(Boolean).length,
  );

  sourceReadOnlySetting = parseMetrics(
    runSql(
      'source-read-only-enforcement',
      sourceDatabase,
      "SELECT 'default_transaction_read_only', current_setting('default_transaction_read_only');",
      { env: sourceReadOnlyEnvironment },
    ).stdout,
  ).default_transaction_read_only;
  if (sourceReadOnlySetting !== 'on') {
    throw new Error(
      `Source read-only enforcement failed; current setting is ${sourceReadOnlySetting}.`,
    );
  }

  sourceFingerprintBefore = parseMetrics(
    runSql(
      'source-fingerprint-before',
      sourceDatabase,
      sourceFingerprintSql,
      { env: sourceReadOnlyEnvironment },
    ).stdout,
  );
  assertMetrics('source-fingerprint-before', sourceFingerprintBefore, {
    postgis_extension_count: '1',
    users_table_count: '1',
    pet_species_required_label_count: '5',
    rescue_table_count: '9',
    rescue_enum_count: '5',
  });
  verifyCurrentChain('source-current', sourceDatabase, {
    env: sourceReadOnlyEnvironment,
  });

  run(
    'source-schema-dump',
    pgDump,
    [
      '-h',
      sourceHost,
      '-p',
      sourcePort,
      '-U',
      sourceUser,
      '-d',
      sourceDatabase,
      '--schema-only',
      '--no-owner',
      '--no-privileges',
      '--file',
      dumpFile,
    ],
    { env: sourceReadOnlyEnvironment },
  );

  const targetExists = parseMetrics(
    runSql(
      'target-absence-check',
      maintenanceDatabase,
      `SELECT 'target_database_count', count(*)::text FROM pg_database WHERE datname = '${targetDatabase}';`,
    ).stdout,
  );
  assertMetrics('target-absence-check', targetExists, { target_database_count: '0' });
  runSql(
    'target-create',
    maintenanceDatabase,
    `CREATE DATABASE "${targetDatabase}" TEMPLATE template0 ENCODING 'UTF8';`,
  );
  targetCreated = true;
  run(
    'target-schema-restore',
    psql,
    [...connectionArgs(targetDatabase), '-f', dumpFile],
  );
  verifyCurrentChain('target-clone-current', targetDatabase);

  const baselineAfterInitialRollback = rollbackChain(
    'cycle1',
    targetDatabase,
  );
  const cycle1 = applyChain('cycle1', targetDatabase, true);
  const targetUrl = new URL(sourceUrl.href);
  targetUrl.pathname = `/${targetDatabase}`;

  const focused = runJest('cycle1-focused-db-tests', targetUrl.href, [
    '--runInBand',
    '--config',
    'jest.config.cjs',
    'tests/rescue.persistence.integration.test.ts',
    'tests/rescue.read.persistence.integration.test.ts',
    'tests/rescue.day36.persistence.integration.test.ts',
  ]);
  if (focused.exitCode !== 0) {
    defects.push({
      id: 'D37-DB-FOCUSED-01',
      severity: 'P0',
      summary: 'Focused Rescue PostgreSQL integration suite failed on cycle 1.',
      evidence: focused.step.log,
      owner: 'Day 38',
    });
  }

  const baselineAfterTestRollback = rollbackChain('cycle2', targetDatabase);
  const cycle2 = applyChain('cycle2', targetDatabase, false);

  const fullCoverage = runJest('cycle2-full-backend-coverage', targetUrl.href, [
    '--runInBand',
    '--config',
    'jest.config.cjs',
    '--coverage',
    '--coverageReporters=json-summary',
    '--coverageReporters=lcov',
    '--coverageReporters=text-summary',
    `--coverageDirectory=${coverageDir}`,
  ]);
  if (fullCoverage.exitCode !== 0) {
    defects.push({
      id: 'D37-FULL-REGRESSION-01',
      severity: 'P0',
      summary: 'Full backend coverage suite failed on cycle 2.',
      evidence: fullCoverage.step.log,
      owner: 'Day 38',
    });
  }

  const coverageSummaryFile = path.join(coverageDir, 'coverage-summary.json');
  if (fs.existsSync(coverageSummaryFile)) {
    const coverageSummary = JSON.parse(fs.readFileSync(coverageSummaryFile, 'utf8'));
    runtimeDetails.coverage = coverageSummary.total;
    if ((coverageSummary.total?.lines?.pct ?? 0) < 80) {
      defects.push({
        id: 'D37-COVERAGE-01',
        severity: 'P1',
        summary: `Backend global line coverage is ${coverageSummary.total?.lines?.pct ?? 0}%, below the proposed 80% gate.`,
        evidence: relativeToRepo(coverageSummaryFile),
        owner: 'Day 38',
      });
    }
  } else {
    defects.push({
      id: 'D37-COVERAGE-ARTIFACT-01',
      severity: 'P1',
      summary: 'Coverage summary artifact was not produced.',
      evidence: fullCoverage.step.log,
      owner: 'Day 38',
    });
  }

  const staticGates = [
    runNpmGate('static-lint', targetUrl.href, ['run', 'lint']),
    runNpmGate('static-build', targetUrl.href, ['run', 'build']),
    runNpmGate('static-prisma-validate', targetUrl.href, [
      'run',
      'prisma:validate',
    ]),
    runNpmGate('dependency-audit-high', targetUrl.href, [
      'audit',
      '--omit=dev',
      '--audit-level=high',
    ]),
  ];
  for (const gate of staticGates) {
    if (gate.exitCode !== 0) {
      defects.push({
        id: `D37-${gate.step.id.toUpperCase().replaceAll('-', '_')}-01`,
        severity: 'P1',
        summary: `${gate.step.id} failed with exit code ${gate.exitCode}.`,
        evidence: gate.step.log,
        owner: 'Day 38 or baseline owner',
      });
    }
  }

  const finalMetrics = verifyCurrentChain('target-final', targetDatabase);
  const result = {
    schemaVersion: 1,
    runId: timestamp.toLowerCase(),
    verdict: defects.length === 0 ? 'PASS_TEST_EXECUTION' : 'COMPLETE_WITH_DEFECTS',
    databaseSafety: {
      source: `${sourceHost}:${sourcePort}/${sourceDatabase}`,
      sourceReadOnly: true,
      disposable: targetDatabase,
      remoteWrites: false,
    },
    baselineAfterInitialRollback,
    baselineAfterTestRollback,
    cycle1,
    cycle2,
    finalMetrics,
    focusedTestExitCode: focused.exitCode,
    fullCoverageExitCode: fullCoverage.exitCode,
    staticGateExitCodes: Object.fromEntries(
      staticGates.map((gate) => [gate.step.id, gate.exitCode]),
    ),
    coverage: runtimeDetails.coverage,
    defects,
  };
  fs.writeFileSync(resultFile, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
} catch (error) {
  terminalError = error;
} finally {
  if (targetCreated) {
    try {
      runSql(
        'target-drop-finally',
        maintenanceDatabase,
        `DROP DATABASE IF EXISTS "${targetDatabase}" WITH (FORCE);`,
      );
      targetCreated = false;
    } catch (cleanupError) {
      terminalError ||= cleanupError;
    }
  }

  try {
    sourceFingerprintAfter = parseMetrics(
      runSql(
        'source-fingerprint-after',
        sourceDatabase,
        sourceFingerprintSql,
        { env: sourceReadOnlyEnvironment },
      ).stdout,
    );
    if (
      sourceFingerprintBefore &&
      JSON.stringify(sourceFingerprintBefore) !== JSON.stringify(sourceFingerprintAfter)
    ) {
      terminalError ||= new Error('Source database fingerprint changed during Day 37 proof.');
    }
  } catch (fingerprintError) {
    terminalError ||= fingerprintError;
  }

  try {
    runtimeDetails.redactionStatus = scanEvidenceForSecrets();
  } catch (scanError) {
    runtimeDetails.redactionStatus = 'FAIL';
    terminalError ||= scanError;
  }

  const finalStatus = terminalError
    ? 'FAILED_INFRA_OR_MIGRATION'
    : defects.length === 0
      ? 'PASS_TEST_EXECUTION'
      : 'COMPLETE_WITH_DEFECTS';
  writeManifest(finalStatus, runtimeDetails);

  const summary = {
    status: finalStatus,
    evidenceDir: relativeToRepo(evidenceDir),
    manifest: relativeToRepo(manifestFile),
    disposableDatabaseDropped: !targetCreated,
    sourceFingerprintUnchanged:
      sourceFingerprintBefore !== null &&
      JSON.stringify(sourceFingerprintBefore) === JSON.stringify(sourceFingerprintAfter),
    defectCount: defects.length,
  };
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  if (terminalError) {
    process.stderr.write(`${redact(terminalError.message)}\n`);
    process.exitCode = 1;
  } else if (defects.length > 0) {
    process.exitCode = 2;
  }
}

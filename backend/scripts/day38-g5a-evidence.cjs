const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const day38EvidenceRoot = path.join(repoRoot, 'output-evidence', 'day38');

const readArg = (name, fallback) => {
  const prefix = `--${name}=`;
  const argument = process.argv.find((value) => value.startsWith(prefix));
  return argument ? argument.slice(prefix.length) : fallback;
};

const evidenceDir = path.resolve(
  repoRoot,
  readArg('evidence-dir', 'output-evidence/day38/final-20260722-1533'),
);
const cleanChainDir = path.resolve(
  repoRoot,
  readArg('clean-chain-dir', 'output-evidence/day37/20260722t085001z'),
);
const evidenceRelative = path.relative(day38EvidenceRoot, evidenceDir);
if (
  !evidenceRelative ||
  evidenceRelative.startsWith('..') ||
  path.isAbsolute(evidenceRelative)
) {
  throw new Error(`Evidence directory must be below ${day38EvidenceRoot}.`);
}

const logsDir = path.join(evidenceDir, 'logs');
const resultFile = path.join(evidenceDir, 'day38-g5a-result.json');
const manifestFile = path.join(evidenceDir, 'manifest.json');
const changedCoverageFile = path.join(
  evidenceDir,
  'changed-source-coverage.json',
);
const cloudParityFile = path.join(evidenceDir, 'day38-cloud-parity-chain.json');
const cleanChainManifestFile = path.join(cleanChainDir, 'manifest.json');
fs.mkdirSync(logsDir, { recursive: true });

const sha256 = (filePath) =>
  crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
const relativeToRepo = (filePath) =>
  path.relative(repoRoot, filePath).replaceAll('\\', '/');
const redact = (value) =>
  String(value)
    .replace(/(postgres(?:ql)?:\/\/[^:\s/]+:)[^@\s/]+@/giu, '$1[REDACTED]@')
    .replace(/(PGPASSWORD=)[^\s]+/giu, '$1[REDACTED]');

const steps = [];
const run = (id, command, args, options = {}) => {
  const startedAt = new Date().toISOString();
  const result = spawnSync(command, args, {
    cwd: options.cwd || repoRoot,
    env: options.env || process.env,
    encoding: 'utf8',
    windowsHide: true,
    maxBuffer: 64 * 1024 * 1024,
  });
  const finishedAt = new Date().toISOString();
  const exitCode = result.status ?? 1;
  const logFile = path.join(
    logsDir,
    `${String(steps.length + 1).padStart(2, '0')}-${id}.log`,
  );
  fs.writeFileSync(
    logFile,
    [
      `started_at=${startedAt}`,
      `finished_at=${finishedAt}`,
      `exit_code=${exitCode}`,
      `command=${[command, ...args].map(redact).join(' ')}`,
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

const npmCli = path.join(
  path.dirname(process.execPath),
  'node_modules',
  'npm',
  'bin',
  'npm-cli.js',
);
const runNpm = (id, args) =>
  run(id, process.execPath, [npmCli, ...args], { cwd: backendRoot });

const walkFiles = (directory) => {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    return entry.isDirectory() ? walkFiles(absolute) : [absolute];
  });
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
    '.ts',
    '.txt',
  ]);
  const findings = [];
  walkFiles(evidenceDir).forEach((filePath) => {
    if (!textExtensions.has(path.extname(filePath).toLowerCase())) return;
    const text = fs.readFileSync(filePath, 'utf8');
    if (/postgres(?:ql)?:\/\/[^:\s/]+:[^@\s/]+@/iu.test(text)) {
      findings.push(`${relativeToRepo(filePath)}:database-url-with-password`);
    }
    if (
      /\b(?:SUPABASE_SERVICE_ROLE_KEY|JWT_SECRET|PGPASSWORD)\s*=\s*[^\s\[]+/iu.test(
        text,
      )
    ) {
      findings.push(`${relativeToRepo(filePath)}:secret-assignment`);
    }
  });
  if (findings.length) {
    throw new Error(`Evidence secret scan failed: ${findings.join(', ')}`);
  }
  return 'PASS';
};

const changedFiles = [
  'backend/package.json',
  'backend/package-lock.json',
  'backend/src/services/rescue/rescue-location-privacy.ts',
  'backend/src/features/rescue/persistence/prisma-rescue-repository.ts',
  'backend/tests/rescue.location-privacy.test.ts',
  'backend/tests/rescue.repository.test.ts',
  'backend/tests/rescue.persistence.integration.test.ts',
  'backend/tests/day38.rescue.contract.test.ts',
  'backend/scripts/day38-changed-source-coverage.cjs',
  'backend/scripts/day38-g5a-evidence.cjs',
  'docs/architecture/day38_g5a_decision_record.md',
  'docs/architecture/pawmate_api_contract_v1.json',
  'docs/architecture/pawmate_api_contract_v1.md',
  'docs/architecture/pawmate_api_contract_change_report_v1.md',
  'docs/engineering/day38_rescue_backend_fix_verify_g5a_status.md',
  'docs/management/pawmate_execution_ledger_v1_1_2026-07-13.md',
  'docs/management/pawmate_v1_roadmap_v1_2_addendum_2026-07-22.md',
  'docs/product/srs_v031_day37_38_update_2026-07-22/SRS_UPDATE_CONTRACT.md',
  'docs/qa/phase2/day36_rescue_write_api_test_matrix.md',
  'docs/qa/rescue-backend/day38_defect_ledger.csv',
  'docs/qa/rescue-backend/day38_api_contract_impact_report.md',
  'docs/qa/rescue-backend/day38_g5a_gate_matrix.md',
];

const productDecisionIds = [
  'G5A-DEC-AUTH-01',
  'G5A-DEC-PRIVACY-01',
  'G5A-DEC-CONTACT-01',
  'G5A-DEC-OUTBOX-01',
];

const startedAt = new Date().toISOString();
let terminalError = null;
let redactionStatus = 'PENDING';
let cleanChainManifest = null;
let changedCoverage = null;
let dependencyAudit = null;
let fastUri = null;
let cloudParity = null;

try {
  [cleanChainManifestFile, changedCoverageFile, cloudParityFile].forEach((filePath) => {
    if (!fs.existsSync(filePath)) throw new Error(`Required artifact missing: ${filePath}`);
  });
  changedFiles.forEach((relativePath) => {
    if (!fs.existsSync(path.join(repoRoot, relativePath))) {
      throw new Error(`Changed-file allowlist member missing: ${relativePath}`);
    }
  });

  cleanChainManifest = JSON.parse(
    fs.readFileSync(cleanChainManifestFile, 'utf8'),
  );
  changedCoverage = JSON.parse(fs.readFileSync(changedCoverageFile, 'utf8'));
  cloudParity = JSON.parse(fs.readFileSync(cloudParityFile, 'utf8'));
  const nonZeroCleanSteps = cleanChainManifest.steps.filter(
    (step) => step.exitCode !== 0,
  );
  if (
    cleanChainManifest.status !== 'PASS_TEST_EXECUTION' ||
    cleanChainManifest.defects.length !== 0 ||
    !cleanChainManifest.sourceFingerprintUnchanged ||
    !cleanChainManifest.safety.disposableDatabaseDropped ||
    cleanChainManifest.safety.redactionStatus !== 'PASS' ||
    nonZeroCleanSteps.length !== 0
  ) {
    throw new Error('Referenced clean-chain manifest is not an all-green proof.');
  }
  if (!changedCoverage.gate.pass || changedCoverage.totals.lineCoveragePct < 90) {
    throw new Error('Day 38 changed-source coverage gate did not pass.');
  }
  if (
    cloudParity.verdict !== 'PASS_BY_UNCHANGED_ARTIFACT_CHAIN' ||
    cloudParity.cloudWrites !== false ||
    cloudParity.unchangedArtifacts.some((artifact) => artifact.match !== true)
  ) {
    throw new Error('Day 38 cloud parity artifact chain did not pass.');
  }
  changedCoverage.files.forEach((file) => {
    const currentPath = path.join(repoRoot, file.sourceFile);
    if (sha256(currentPath) !== file.currentSha256) {
      throw new Error(`Changed-source coverage hash drifted: ${file.sourceFile}`);
    }
  });

  run('runner-syntax', process.execPath, [
    '--check',
    path.join(backendRoot, 'scripts', 'day38-g5a-evidence.cjs'),
  ]);
  run('changed-coverage-script-syntax', process.execPath, [
    '--check',
    path.join(backendRoot, 'scripts', 'day38-changed-source-coverage.cjs'),
  ]);
  run(
    'day38-focused-tests',
    process.execPath,
    [
      path.join(backendRoot, 'node_modules', 'jest', 'bin', 'jest.js'),
      '--runInBand',
      '--config',
      'jest.config.cjs',
      'tests/rescue.location-privacy.test.ts',
      'tests/rescue.repository.test.ts',
      'tests/day38.rescue.contract.test.ts',
    ],
    { cwd: backendRoot },
  );

  const auditResult = runNpm('dependency-audit-high-json', [
    'audit',
    '--omit=dev',
    '--audit-level=high',
    '--json',
  ]);
  dependencyAudit = JSON.parse(auditResult.stdout);
  const vulnerabilities = dependencyAudit.metadata?.vulnerabilities || {};
  if ((vulnerabilities.high || 0) > 0 || (vulnerabilities.critical || 0) > 0) {
    throw new Error('Production dependency audit still has high/critical findings.');
  }

  const fastUriResult = runNpm('dependency-fast-uri-tree', [
    'ls',
    'fast-uri',
    '--all',
    '--depth=10',
    '--json',
  ]);
  fastUri = JSON.parse(fastUriResult.stdout);
  const fastUriText = JSON.stringify(fastUri);
  if (!fastUriText.includes('"version":"3.1.4"')) {
    throw new Error('Resolved dependency tree does not prove fast-uri 3.1.4.');
  }

  redactionStatus = scanEvidenceForSecrets();
} catch (error) {
  terminalError = error;
  try {
    redactionStatus = scanEvidenceForSecrets();
  } catch {
    redactionStatus = 'FAIL';
  }
}

const technicalPass = terminalError === null;
const result = {
  schemaVersion: 1,
  day: 38,
  verdict: technicalPass
    ? 'TECHNICAL_PASS_PRODUCT_APPROVAL_PENDING'
    : 'TECHNICAL_FAIL',
  g5a: technicalPass ? 'PENDING_PRODUCT_BA_APPROVAL' : 'FAIL',
  productDecisionIds: productDecisionIds.map((id) => ({
    id,
    status: 'PENDING_PRODUCT_BA_APPROVAL',
  })),
  technical: {
    cleanChainStatus: cleanChainManifest?.status || null,
    cleanChainDefectCount: cleanChainManifest?.defects?.length ?? null,
    globalCoverage: cleanChainManifest?.coverage || null,
    changedSourceLineCoverage: changedCoverage?.totals || null,
    focusedStep: steps.find((step) => step.id === 'day38-focused-tests') || null,
    dependencyAudit: dependencyAudit?.metadata?.vulnerabilities || null,
    fastUriResolvedVersion: fastUri ? '3.1.4' : null,
    cloudParity: cloudParity?.verdict || null,
  },
  safety: {
    remoteDatabaseWrites: false,
    sourceDatabaseWrites: false,
    cloudParityClaimed: false,
    notificationDeliveryClaimed: false,
    redactionStatus,
  },
  terminalError: terminalError
    ? redact(terminalError.stack || terminalError.message)
    : null,
};
fs.writeFileSync(resultFile, `${JSON.stringify(result, null, 2)}\n`, 'utf8');

const artifacts = walkFiles(evidenceDir).filter(
  (filePath) => filePath !== manifestFile,
);
const manifest = {
  schemaVersion: 1,
  day: 38,
  scope: 'Rescue backend privacy/dependency remediation and G5A technical proof',
  status: result.verdict,
  g5a: result.g5a,
  startedAt,
  finishedAt: new Date().toISOString(),
  executor: 'Codex Day 38 technical lane',
  safety: result.safety,
  referencedCleanChain: {
    manifest: relativeToRepo(cleanChainManifestFile),
    sha256: sha256(cleanChainManifestFile),
    status: cleanChainManifest?.status || null,
  },
  changedSourceCoverage: {
    artifact: relativeToRepo(changedCoverageFile),
    sha256: sha256(changedCoverageFile),
    lineCoveragePct: changedCoverage?.totals?.lineCoveragePct ?? null,
    gatePass: changedCoverage?.gate?.pass ?? false,
  },
  cloudParity: {
    artifact: relativeToRepo(cloudParityFile),
    sha256: sha256(cloudParityFile),
    verdict: cloudParity?.verdict || null,
    freshCloudQueryExecuted: cloudParity?.freshCloudQueryExecuted ?? null,
    cloudWrites: cloudParity?.cloudWrites ?? null,
  },
  productDecisions: result.productDecisionIds,
  changedFileAllowlist: changedFiles.map((relativePath) => ({
    path: relativePath,
    sha256: sha256(path.join(repoRoot, relativePath)),
  })),
  steps,
  artifacts: artifacts.map((filePath) => ({
    path: relativeToRepo(filePath),
    bytes: fs.statSync(filePath).size,
    sha256: sha256(filePath),
  })),
  terminalError: result.terminalError,
};
fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

process.stdout.write(
  `${JSON.stringify(
    {
      status: manifest.status,
      g5a: manifest.g5a,
      evidenceDir: relativeToRepo(evidenceDir),
      manifest: relativeToRepo(manifestFile),
      cleanChain: manifest.referencedCleanChain,
      changedSourceCoverage: manifest.changedSourceCoverage,
      redactionStatus,
    },
    null,
    2,
  )}\n`,
);
if (!technicalPass) process.exitCode = 1;

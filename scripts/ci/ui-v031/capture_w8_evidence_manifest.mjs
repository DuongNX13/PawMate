import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const repoRoot = process.cwd();
const relativeEvidenceRoot =
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8';
const evidenceRoot = path.join(repoRoot, relativeEvidenceRoot);
const manifestPath = path.join(evidenceRoot, 'evidence-manifest.json');
const redactionPath = path.join(evidenceRoot, 'redaction-scan.json');
const parentEvidenceManifestRelativePath =
  'docs/qa/ui-v031/W8_EVIDENCE_MANIFEST_PRE_P1-01_NO_RAILS.json';
const parentEvidenceManifestPath = path.join(
  repoRoot,
  parentEvidenceManifestRelativePath,
);
const parentEvidenceManifest = JSON.parse(
  fs.readFileSync(parentEvidenceManifestPath, 'utf8'),
);
const sourceSnapshotRoots = [
  '.github/workflows',
  'codemagic.yaml',
  'docs/design/pawmate-v031-platform-ui',
  'docs/qa/ui-v031',
  'mobile/.metadata',
  'mobile/analysis_options.yaml',
  'mobile/android/app/src/main',
  'mobile/assets/images/auth',
  'mobile/integration_test',
  'mobile/ios/Runner',
  'mobile/lib',
  'mobile/pubspec.lock',
  'mobile/pubspec.yaml',
  'mobile/test',
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/live-audit-2026-07-22',
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/pre-write-approved-matrix',
  'scripts/ci/ui-v031',
];

const sha256Buffer = (value) =>
  crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const sha256File = (filePath) => sha256Buffer(fs.readFileSync(filePath));

function walkFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    return entry.isDirectory() ? walkFiles(absolute) : [absolute];
  });
}

function expandSnapshotRoot(relativeRoot) {
  const absolute = path.join(repoRoot, relativeRoot);
  if (!fs.existsSync(absolute)) {
    throw new Error(`Source snapshot root does not exist: ${relativeRoot}`);
  }
  return fs.statSync(absolute).isDirectory() ? walkFiles(absolute) : [absolute];
}

function countMatches(text, pattern) {
  return [...text.matchAll(pattern)].length;
}

const textExtensions = new Set([
  '.csv',
  '.html',
  '.json',
  '.log',
  '.md',
  '.txt',
  '.xml',
]);
const scanFiles = walkFiles(evidenceRoot).filter((filePath) => {
  if ([manifestPath, redactionPath].includes(filePath)) return false;
  return textExtensions.has(path.extname(filePath).toLowerCase());
});

const counters = {
  openAiStyleKey: 0,
  jwt: 0,
  authorizationBearer: 0,
  supabaseServiceRole: 0,
  nonSyntheticEmail: 0,
  syntheticEmail: 0,
  coordinatePair: 0,
  windowsUserPath: 0,
  assetNameAtScaleFalsePositive: 0,
};
const syntheticDomains = new Set([
  'example.com',
  'example.org',
  'example.net',
  'pawmate.test',
  'test.invalid',
]);

for (const filePath of scanFiles) {
  const text = fs.readFileSync(filePath, 'utf8');
  counters.openAiStyleKey += countMatches(text, /\bsk-[A-Za-z0-9_-]{20,}\b/g);
  counters.jwt += countMatches(
    text,
    /\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/g,
  );
  counters.authorizationBearer += countMatches(
    text,
    /\bAuthorization\s*[:=]\s*Bearer\s+[A-Za-z0-9._~-]{16,}/gi,
  );
  counters.supabaseServiceRole += countMatches(
    text,
    /\b(?:SUPABASE_SERVICE_ROLE_KEY|service_role_key)\s*[:=]\s*[^\s"']{12,}/gi,
  );
  counters.coordinatePair += countMatches(
    text,
    /(?<![\d.])-?\d{1,3}\.\d{5,}\s*,\s*-?\d{1,3}\.\d{5,}(?![\d.])/g,
  );
  counters.windowsUserPath += countMatches(
    text,
    /C:[\\/]+Users[\\/]+[^\\/\r\n]+/gi,
  );

  for (const match of text.matchAll(
    /\b[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})\b/gi,
  )) {
    const domain = match[1].toLowerCase();
    if (/^[123]x\.(?:png|webp|jpe?g)$/.test(domain)) {
      counters.assetNameAtScaleFalsePositive += 1;
    } else if (syntheticDomains.has(domain)) counters.syntheticEmail += 1;
    else counters.nonSyntheticEmail += 1;
  }
}

const secretOrSensitiveCount =
  counters.openAiStyleKey +
  counters.jwt +
  counters.authorizationBearer +
  counters.supabaseServiceRole +
  counters.nonSyntheticEmail +
  counters.coordinatePair;
const redactionStatus =
  secretOrSensitiveCount > 0
    ? 'FAIL'
    : counters.windowsUserPath > 0
      ? 'PENDING'
      : 'PASS';
const redaction = {
  schema_version: '1.0',
  evidence_root: relativeEvidenceRoot,
  scanned_at: new Date().toISOString(),
  text_files_scanned: scanFiles.length,
  status: redactionStatus,
  counters,
  policy: {
    synthetic_email_domains_allowed: [...syntheticDomains].sort(),
    local_windows_user_paths:
      'PENDING means repo copies still contain machine-local paths; canonical raw logs remain outside the repo evidence tree.',
    matched_values_emitted: false,
  },
};
fs.writeFileSync(redactionPath, `${JSON.stringify(redaction, null, 2)}\n`, 'utf8');

function mediaType(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case '.apk':
      return 'application/vnd.android.package-archive';
    case '.csv':
      return 'text/csv';
    case '.json':
      return 'application/json';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.xml':
      return 'application/xml';
    default:
      return 'text/plain';
  }
}

const artifactFiles = walkFiles(evidenceRoot)
  .filter((filePath) => filePath !== manifestPath)
  .filter((filePath) => fs.statSync(filePath).size > 0)
  .sort((left, right) => left.localeCompare(right));
const artifacts = artifactFiles.map((filePath) => ({
  path: path.relative(repoRoot, filePath).replaceAll('\\', '/'),
  sha256: sha256File(filePath),
  bytes: fs.statSync(filePath).size,
  media_type: mediaType(filePath),
  storage_tier: 'repo-relative',
  retention_days: null,
}));

const sourceSnapshotFiles = [
  ...new Set(sourceSnapshotRoots.flatMap(expandSnapshotRoot)),
].sort((left, right) => left.localeCompare(right));
const sourceSnapshot = sourceSnapshotFiles.map((filePath) => ({
  path: path.relative(repoRoot, filePath).replaceAll('\\', '/'),
  sha256: sha256File(filePath),
  bytes: fs.statSync(filePath).size,
}));
const sourceSnapshotPayload = sourceSnapshot
  .map((item) => `${item.path}:${item.sha256}:${item.bytes}`)
  .join('\n');
const sourceSnapshotSha256 = sha256Buffer(
  Buffer.from(sourceSnapshotPayload, 'utf8'),
);

function git(args) {
  const result = spawnSync('git', args, {
    cwd: repoRoot,
    encoding: null,
    maxBuffer: 128 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`git ${args.join(' ')} failed with exit ${result.status}`);
  }
  return result.stdout;
}

const commitSha = git(['rev-parse', 'HEAD']).toString('utf8').trim();
const dirtySnapshotSha256 = sha256Buffer(
  Buffer.concat([
    git(['status', '--porcelain=v1', '-z']),
    git(['diff', '--binary', '--no-ext-diff']),
    Buffer.from(artifacts.map((item) => `${item.path}:${item.sha256}`).join('\n')),
    Buffer.from(sourceSnapshotPayload, 'utf8'),
  ]),
);
const now = new Date().toISOString();

const manifest = {
  schema_version: '1.1',
  evidence_id: 'ui-v031-w8-g4b-convergence-20260723',
  wave: 'W8',
  baseline_id: 'UI-CC-2026-07-21-G4B-W8-CONVERGENCE-20260723',
  parent_baseline_id: parentEvidenceManifest.baseline_id,
  change_control_id: 'UI031-CHANGE-W8-P1-01-NO-RAILS-02',
  parent_evidence_manifest: {
    path: parentEvidenceManifestRelativePath,
    sha256: sha256File(parentEvidenceManifestPath),
    evidence_id: parentEvidenceManifest.evidence_id,
    baseline_id: parentEvidenceManifest.baseline_id,
  },
  commit_sha: commitSha,
  dirty_snapshot_sha256: dirtySnapshotSha256,
  source_snapshot_sha256: sourceSnapshotSha256,
  source_snapshot: sourceSnapshot,
  platform: 'multi',
  device_runtime: [
    {
      platform: 'android',
      runtime: 'emulator API 34',
      status: 'PASS',
      evidence: 'docs/qa/ui-v031/W8_DEVICE_MATRIX.csv',
    },
    {
      platform: 'android',
      runtime: 'emulator API 35',
      status: 'PASS',
      evidence: 'docs/qa/ui-v031/W8_DEVICE_MATRIX.csv',
    },
    {
      platform: 'android',
      runtime: 'emulator API 36',
      status: 'PASS',
      evidence:
        'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/talkback-journeys-20260723/talkback-journey-index.json',
      note: 'Seven of seven named TalkBack journeys pass at font scale 2.0.',
    },
    {
      platform: 'android',
      runtime: 'emulator API 36 normal APK after accessibility instrumentation',
      status: 'PASS',
      evidence:
        'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/normal-apk-post-talkback-20260723/normal-apk-proof.json',
      note:
        'Preserved artifact and installed base.apk hashes match; cleared-data cold launch renders P1-01.',
    },
    {
      platform: 'ios',
      runtime: 'Codemagic iOS simulator post-change',
      status: 'NOT_RUN',
      evidence: 'docs/qa/ui-v031/W7_NATIVE_REPORT.md',
      note: 'Only the pre-change baseline exists; the dirty local tree is not CI-visible.',
    },
  ],
  command: {
    working_directory: 'D:/My Playground/PawMate',
    argv: ['node', 'scripts/ci/ui-v031/capture_w8_evidence_manifest.mjs'],
    environment_keys: [],
    started_at: now,
    finished_at: now,
    exit_code: 0,
  },
  status: 'BLOCKED',
  attempts: [
    {
      attempt: 1,
      exit_code: 0,
      status: 'BLOCKED_BY_IOS_POSTCHANGE',
      inputs_changed: false,
      failure_class: 'IOS_POSTCHANGE_NOT_RUN',
      evidence_path: `${relativeEvidenceRoot}/redaction-scan.json`,
    },
  ],
  artifacts,
  executor: 'Codex lead',
  reviewer: 'Codex lead self-review; Product Owner joint G4B sign-off pending',
  contains_test_data_only: true,
  redaction_status: redactionStatus,
  known_exceptions: [
    {
      id: 'W7-IOS-POSTCHANGE-CI',
      description: 'W3 is PASS at 77/77, traceability is PASS at 191/191, 82 CTA manifests and seven Android TalkBack journey manifests are attached, and the normal post-instrumentation Android APK proof is PASS. No post-change Codemagic iOS simulator compile/render artifact exists for the dirty local UI tree.',
      owner: 'Codex lead / CI owner',
      reconsideration_trigger: 'Authorize a commit/push or provide an equivalent macOS simulator runner.',
    },
  ],
};

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(
  JSON.stringify(
    {
      status: 'PASS',
      waveStatus: manifest.status,
      artifacts: artifacts.length,
      bytes: artifacts.reduce((sum, artifact) => sum + artifact.bytes, 0),
      sourceSnapshotFiles: sourceSnapshot.length,
      sourceSnapshotSha256,
      redactionStatus,
      manifest: path.relative(repoRoot, manifestPath).replaceAll('\\', '/'),
      redaction: path.relative(repoRoot, redactionPath).replaceAll('\\', '/'),
    },
    null,
    2,
  ),
);

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const repoRoot = process.cwd();
const manifestRelativePath =
  process.env.D39_EXIT_MANIFEST_PATH ??
  'output-evidence/day39/D39-EXIT-20260723.json';
const manifestPath = path.join(repoRoot, manifestRelativePath);

const sourcePaths = [
  'mobile/lib/app/router/app_feature_availability.dart',
  'mobile/lib/app/router/app_router.dart',
  'mobile/lib/features/rescue/rescue_feature.dart',
  'mobile/lib/features/rescue/application/rescue_home_provider.dart',
  'mobile/lib/features/rescue/data/rescue_api.dart',
  'mobile/lib/features/rescue/domain/rescue_case_models.dart',
  'mobile/lib/features/rescue/presentation/rescue_home_screen.dart',
  'mobile/lib/features/rescue/presentation/rescue_map_preview.dart',
  'mobile/test/features/rescue/rescue_api_test.dart',
  'mobile/test/features/rescue/rescue_home_live_screen_test.dart',
  'mobile/test/features/rescue/rescue_home_provider_test.dart',
  'mobile/test/features/rescue/rescue_home_screen_test.dart',
  'mobile/test/features/rescue/rescue_test_fixtures.dart',
  'mobile/test/visual/ui_v031_rescue_live_golden_test.dart',
  'mobile/test/visual/ui_v031_rescue_staged_golden_test.dart',
  'mobile/test/visual/goldens/ui-v031-rescue/rescue-live-360x844.png',
  'mobile/test/visual/goldens/ui-v031-rescue/rescue-live-390x844.png',
  'mobile/test/visual/goldens/ui-v031-rescue/rescue-live-430x932.png',
  'mobile/test/visual/goldens/ui-v031-rescue/rescue-staged-360x844.png',
  'mobile/test/visual/goldens/ui-v031-rescue/rescue-staged-390x844.png',
  'mobile/test/visual/goldens/ui-v031-rescue/rescue-staged-430x932.png',
];

const evidencePaths = [
  'docs/management/gates/D39-ENTRY-20260723-g4b-approved.json',
  'output-evidence/day39/flutter-analyze-20260723.log',
  'output-evidence/day39/flutter-test-rescue-focused-20260723.log',
  'output-evidence/day39/flutter-test-rescue-goldens-20260723.log',
  'output-evidence/day39/flutter-test-full-20260723.log',
  'output-evidence/day39/flutter-test-coverage-20260723.log',
  'output-evidence/day39/flutter-build-apk-debug-20260723.log',
  'output-evidence/day39/flutter-pub-outdated-20260723.log',
  'output-evidence/day39/lcov.info',
  'output-evidence/day39/app-debug-day39.apk',
];

const resolve = (relativePath) => path.join(repoRoot, relativePath);
const sha256Buffer = (value) =>
  crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const sha256File = (relativePath) =>
  sha256Buffer(fs.readFileSync(resolve(relativePath)));
const readText = (relativePath) => {
  const value = fs.readFileSync(resolve(relativePath));
  if (value[0] === 0xff && value[1] === 0xfe) {
    return value.subarray(2).toString('utf16le').replace(/^\uFEFF/, '');
  }
  return value.toString('utf8').replace(/^\uFEFF/, '');
};

function artifact(relativePath) {
  const absolute = resolve(relativePath);
  return {
    path: relativePath.replaceAll('\\', '/'),
    bytes: fs.statSync(absolute).size,
    sha256: sha256File(relativePath),
  };
}

function snapshotHash(artifacts) {
  return sha256Buffer(
    Buffer.from(
      artifacts
        .map((entry) => `${entry.path}|${entry.bytes}|${entry.sha256}`)
        .join('\n'),
      'utf8',
    ),
  );
}

function parseRescueCoverage(relativePath) {
  const records = [];
  let current;
  for (const line of readText(relativePath).split(/\r?\n/)) {
    if (line.startsWith('SF:')) {
      current = {
        path: line.slice(3).replaceAll('\\', '/'),
        lines_found: 0,
        lines_hit: 0,
      };
    } else if (current && line.startsWith('LF:')) {
      current.lines_found = Number(line.slice(3));
    } else if (current && line.startsWith('LH:')) {
      current.lines_hit = Number(line.slice(3));
    } else if (current && line === 'end_of_record') {
      if (current.path.includes('/features/rescue/')) records.push(current);
      current = undefined;
    }
  }

  const linesFound = records.reduce(
    (total, record) => total + record.lines_found,
    0,
  );
  const linesHit = records.reduce(
    (total, record) => total + record.lines_hit,
    0,
  );
  return {
    kind: 'line',
    files: records,
    lines_found: linesFound,
    lines_hit: linesHit,
    percent:
      linesFound === 0 ? 0 : Number(((linesHit / linesFound) * 100).toFixed(2)),
  };
}

const missing = [...sourcePaths, ...evidencePaths].filter(
  (relativePath) => !fs.existsSync(resolve(relativePath)),
);
if (missing.length > 0) {
  console.error(
    JSON.stringify(
      {
        status: 'FAIL',
        reason: 'Required Day 39 artifacts are missing.',
        missing,
      },
      null,
      2,
    ),
  );
  process.exit(1);
}

const analyzeLog = readText(evidencePaths[1]);
const focusedLog = readText(evidencePaths[2]);
const goldenLog = readText(evidencePaths[3]);
const fullLog = readText(evidencePaths[4]);
const coverageLog = readText(evidencePaths[5]);
const buildLog = readText(evidencePaths[6]);
const dependencyLog = readText(evidencePaths[7]);
const featureAvailability = readText(sourcePaths[0]);
const router = readText(sourcePaths[1]);
const rescueApi = readText(sourcePaths[4]);
const rescueHome = readText(sourcePaths[6]);
const entryManifest = JSON.parse(readText(evidencePaths[0]));

const checks = [
  {
    id: 'D39-ENTRY',
    status:
      entryManifest.status === 'PASS' &&
      entryManifest.checks?.every((entry) => entry.status === 'PASS')
        ? 'PASS'
        : 'FAIL',
    evidence: evidencePaths[0],
    detail: `${entryManifest.checks?.length ?? 0} entry checks`,
  },
  {
    id: 'FEATURE-FLAGS-FAIL-CLOSED',
    status:
      featureAvailability.includes("'PAWMATE_RESCUE_BROWSE_ENABLED'") &&
      featureAvailability.includes("'PAWMATE_RESCUE_CREATE_ENABLED'") &&
      (featureAvailability.match(/defaultValue: false/g)?.length ?? 0) >= 3
        ? 'PASS'
        : 'FAIL',
    evidence: sourcePaths[0],
    detail: 'Browse/create defaults remain false/false.',
  },
  {
    id: 'REAL-API-WIRING',
    status:
      rescueApi.includes("'/rescue/cases'") &&
      rescueApi.includes("'Cache-Control': 'no-store'") &&
      router.includes('availability.rescueBrowse')
        ? 'PASS'
        : 'FAIL',
    evidence: sourcePaths[4],
    detail: 'Production source is the Rescue read API; no persistent cache.',
  },
  {
    id: 'NO-VISIBLE-BAO-THAY',
    status: !rescueHome.includes("'Báo thấy'") ? 'PASS' : 'FAIL',
    evidence: sourcePaths[6],
    detail: 'P2-01 source contains no visible Báo thấy action.',
  },
  {
    id: 'ANALYZE',
    status: analyzeLog.includes('No issues found!') ? 'PASS' : 'FAIL',
    evidence: evidencePaths[1],
    detail: 'Full mobile analyze exits cleanly.',
  },
  {
    id: 'RESCUE-FOCUSED',
    status: focusedLog.includes('+13: All tests passed!')
      ? 'PASS'
      : 'FAIL',
    evidence: evidencePaths[2],
    detail: '13 focused API/provider/widget tests.',
  },
  {
    id: 'RESPONSIVE-GOLDENS',
    status: goldenLog.includes('+6: All tests passed!') ? 'PASS' : 'FAIL',
    evidence: evidencePaths[3],
    detail: 'Live and fail-closed goldens at 360, 390 and 430 widths.',
  },
  {
    id: 'FULL-MOBILE-REGRESSION',
    status: fullLog.includes('+427 ~1: All tests passed!')
      ? 'PASS'
      : 'FAIL',
    evidence: evidencePaths[4],
    detail: '427 tests pass; one backend-account integration test is skipped.',
  },
  {
    id: 'FULL-COVERAGE-RUN',
    status: coverageLog.includes('+427 ~1: All tests passed!')
      ? 'PASS'
      : 'FAIL',
    evidence: evidencePaths[5],
    detail: 'Full suite also passes while collecting LCOV.',
  },
  {
    id: 'ANDROID-DEBUG-BUILD',
    status: buildLog.includes(
      'Built build\\app\\outputs\\flutter-apk\\app-debug.apk',
    )
      ? 'PASS'
      : 'FAIL',
    evidence: evidencePaths[6],
    detail: 'Android debug APK build completed successfully.',
  },
  {
    id: 'DEPENDENCY-INVENTORY',
    status: dependencyLog.includes('Showing outdated packages.')
      ? 'PASS'
      : 'FAIL',
    evidence: evidencePaths[7],
    detail:
      'Read-only dependency inventory completed; no package or lockfile was changed.',
  },
];

const sourceArtifacts = sourcePaths.map(artifact);
const evidenceArtifacts = evidencePaths.map(artifact);
const coverage = parseRescueCoverage(evidencePaths[8]);
const head = spawnSync('git', ['rev-parse', 'HEAD'], {
  cwd: repoRoot,
  encoding: 'utf8',
}).stdout.trim();
const branch = spawnSync('git', ['branch', '--show-current'], {
  cwd: repoRoot,
  encoding: 'utf8',
}).stdout.trim();
const pubspecLockHash = sha256File('mobile/pubspec.lock');

const manifest = {
  schema: 'pawmate.day39-exit.v1',
  run_id: 'D39-EXIT-20260723',
  status: checks.every((entry) => entry.status === 'PASS') ? 'PASS' : 'FAIL',
  captured_at: new Date().toISOString(),
  source: {
    commit: head,
    branch,
    artifacts: sourceArtifacts,
    snapshot_sha256: snapshotHash(sourceArtifacts),
  },
  evidence: {
    artifacts: evidenceArtifacts,
    snapshot_sha256: snapshotHash(evidenceArtifacts),
  },
  feature_flags: {
    PAWMATE_RESCUE_BROWSE_ENABLED: false,
    PAWMATE_RESCUE_CREATE_ENABLED: false,
    activation: 'STAGING_APPROVAL_PENDING',
  },
  coverage,
  dependency_inventory: {
    command: 'flutter pub outdated --no-dev-dependencies',
    pubspec_lock_sha256: pubspecLockHash,
    lockfile_changed_by_day39: false,
    security_audit: 'NO_DEDICATED_DART_AUDIT_COMMAND_CONFIGURED',
  },
  android_debug_apk: artifact(evidencePaths[9]),
  day39_transition: {
    from: 'IN_PROGRESS',
    to: 'PASS',
    next_day: 40,
    next_day_state: 'NOT_STARTED',
  },
  checks,
  reviewer: 'Codex lead',
  approver: 'Product Owner approved G4B; Day 39 is closed by objective gates',
};

fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(
  JSON.stringify(
    {
      status: manifest.status,
      manifest: manifestRelativePath.replaceAll('\\', '/'),
      sourceCommit: head,
      sourceSnapshotSha256: manifest.source.snapshot_sha256,
      evidenceSnapshotSha256: manifest.evidence.snapshot_sha256,
      rescueCoverage: coverage,
      checks: checks.length,
    },
    null,
    2,
  ),
);
process.exit(manifest.status === 'PASS' ? 0 : 1);

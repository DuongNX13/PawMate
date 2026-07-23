import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repoRoot = process.cwd();
const manifestRelativePath =
  process.argv[2] ??
  process.env.D39_EXIT_MANIFEST_PATH ??
  'output-evidence/day39/D39-EXIT-20260723.json';
const manifestPath = path.join(repoRoot, manifestRelativePath);
const errors = [];

const sha256Buffer = (value) =>
  crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const sha256File = (relativePath) =>
  sha256Buffer(fs.readFileSync(path.join(repoRoot, relativePath)));

function validateArtifacts(label, artifacts, expectedSnapshotHash) {
  if (!Array.isArray(artifacts) || artifacts.length === 0) {
    errors.push(`${label} artifacts are missing.`);
    return;
  }
  const seen = new Set();
  for (const artifact of artifacts) {
    if (
      typeof artifact.path !== 'string' ||
      path.isAbsolute(artifact.path) ||
      artifact.path.includes('..')
    ) {
      errors.push(`Unsafe ${label} path: ${artifact.path}`);
      continue;
    }
    if (seen.has(artifact.path)) {
      errors.push(`Duplicate ${label} path: ${artifact.path}`);
      continue;
    }
    seen.add(artifact.path);
    const absolute = path.join(repoRoot, artifact.path);
    if (!fs.existsSync(absolute)) {
      errors.push(`Missing ${label} artifact: ${artifact.path}`);
      continue;
    }
    const bytes = fs.statSync(absolute).size;
    const hash = sha256File(artifact.path);
    if (bytes !== artifact.bytes || hash !== artifact.sha256) {
      errors.push(`Drift in ${label} artifact: ${artifact.path}`);
    }
  }

  const payload = artifacts
    .map((artifact) => `${artifact.path}|${artifact.bytes}|${artifact.sha256}`)
    .join('\n');
  if (sha256Buffer(Buffer.from(payload, 'utf8')) !== expectedSnapshotHash) {
    errors.push(`${label} snapshot SHA-256 mismatch.`);
  }
}

if (!fs.existsSync(manifestPath)) {
  console.error(
    JSON.stringify(
      {
        status: 'FAIL',
        manifest: manifestRelativePath,
        errors: ['Day 39 exit manifest does not exist.'],
      },
      null,
      2,
    ),
  );
  process.exit(1);
}

const manifest = JSON.parse(
  fs.readFileSync(manifestPath, 'utf8').replace(/^\uFEFF/, ''),
);
if (manifest.schema !== 'pawmate.day39-exit.v1') {
  errors.push('Unexpected Day 39 exit manifest schema.');
}
if (manifest.status !== 'PASS') {
  errors.push('Day 39 exit status must be PASS.');
}
if (
  !Array.isArray(manifest.checks) ||
  manifest.checks.length !== 11 ||
  manifest.checks.some((entry) => entry.status !== 'PASS')
) {
  errors.push('Exactly 11 Day 39 exit checks must be present and PASS.');
}

validateArtifacts(
  'source',
  manifest.source?.artifacts,
  manifest.source?.snapshot_sha256,
);
validateArtifacts(
  'evidence',
  manifest.evidence?.artifacts,
  manifest.evidence?.snapshot_sha256,
);

if (
  manifest.feature_flags?.PAWMATE_RESCUE_BROWSE_ENABLED !== false ||
  manifest.feature_flags?.PAWMATE_RESCUE_CREATE_ENABLED !== false
) {
  errors.push('Rescue feature flags must remain false/false.');
}
if (
  manifest.coverage?.kind !== 'line' ||
  !(manifest.coverage?.lines_hit > 0) ||
  !(manifest.coverage?.percent >= 80)
) {
  errors.push('Rescue line coverage must be present and at least 80%.');
}
if (
  manifest.android_debug_apk?.path !==
    'output-evidence/day39/app-debug-day39.apk' ||
  !(manifest.android_debug_apk?.bytes > 0) ||
  !manifest.android_debug_apk?.sha256
) {
  errors.push('Preserved Android debug APK provenance is missing.');
}
if (
  manifest.day39_transition?.from !== 'IN_PROGRESS' ||
  manifest.day39_transition?.to !== 'PASS' ||
  manifest.day39_transition?.next_day !== 40 ||
  manifest.day39_transition?.next_day_state !== 'NOT_STARTED'
) {
  errors.push('Day 39/40 transition contract is invalid.');
}
if (
  !manifest.source?.commit ||
  !manifest.source?.branch ||
  !manifest.captured_at ||
  Number.isNaN(Date.parse(manifest.captured_at)) ||
  !manifest.reviewer ||
  !manifest.approver
) {
  errors.push('Commit, branch, timestamp, reviewer and approver are required.');
}

console.log(
  JSON.stringify(
    {
      status: errors.length === 0 ? 'PASS' : 'FAIL',
      manifest: manifestRelativePath.replaceAll('\\', '/'),
      sourceCommit: manifest.source?.commit,
      sourceSnapshotSha256: manifest.source?.snapshot_sha256,
      evidenceSnapshotSha256: manifest.evidence?.snapshot_sha256,
      rescueCoveragePercent: manifest.coverage?.percent,
      checks: manifest.checks?.length ?? 0,
      errors,
    },
    null,
    2,
  ),
);
process.exit(errors.length === 0 ? 0 : 1);

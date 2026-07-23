import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repoRoot = process.cwd();
const runId = process.env.D39_RUN_ID ?? '20260723-g4b-approved';
const manifestRelativePath =
  process.argv[2] ??
  process.env.D39_MANIFEST_PATH ??
  `docs/management/gates/D39-ENTRY-${runId}.json`;
const manifestPath = path.join(repoRoot, manifestRelativePath);
const errors = [];

const sha256Buffer = (value) =>
  crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const sha256File = (relativePath) =>
  sha256Buffer(fs.readFileSync(path.join(repoRoot, relativePath)));

if (!fs.existsSync(manifestPath)) {
  console.error(
    JSON.stringify(
      {
        status: 'FAIL',
        manifest: manifestRelativePath,
        errors: ['D39 entry manifest does not exist.'],
      },
      null,
      2,
    ),
  );
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (manifest.schema !== 'pawmate.d39-entry.v1') {
  errors.push('Unexpected D39 entry manifest schema.');
}
if (manifest.status !== 'PASS') {
  errors.push('D39 entry manifest status must be PASS.');
}
if (
  !Array.isArray(manifest.checks) ||
  manifest.checks.length < 20 ||
  manifest.checks.some((entry) => entry.status !== 'PASS')
) {
  errors.push('Every D39 entry check must be present and PASS.');
}

const snapshot = manifest.source?.snapshot;
if (!Array.isArray(snapshot) || snapshot.length === 0) {
  errors.push('Source snapshot is missing.');
} else {
  const seen = new Set();
  for (const artifact of snapshot) {
    if (
      typeof artifact.path !== 'string' ||
      path.isAbsolute(artifact.path) ||
      artifact.path.includes('..')
    ) {
      errors.push(`Unsafe source snapshot path: ${artifact.path}`);
      continue;
    }
    if (seen.has(artifact.path)) {
      errors.push(`Duplicate source snapshot path: ${artifact.path}`);
      continue;
    }
    seen.add(artifact.path);
    const absolute = path.join(repoRoot, artifact.path);
    if (!fs.existsSync(absolute)) {
      errors.push(`Source snapshot artifact is missing: ${artifact.path}`);
      continue;
    }
    const bytes = fs.statSync(absolute).size;
    const hash = sha256File(artifact.path);
    if (bytes !== artifact.bytes || hash !== artifact.sha256) {
      errors.push(`Source snapshot artifact drift: ${artifact.path}`);
    }
  }
  const payload = snapshot
    .map((artifact) => `${artifact.path}|${artifact.bytes}|${artifact.sha256}`)
    .join('\n');
  const snapshotHash = sha256Buffer(Buffer.from(payload, 'utf8'));
  if (snapshotHash !== manifest.source?.snapshot_sha256) {
    errors.push('Source snapshot aggregate SHA-256 mismatch.');
  }
}

if (
  manifest.gates?.srs?.status !== 'PASS' ||
  manifest.gates?.g5a?.status !== 'PASS' ||
  manifest.gates?.g4b?.status !== 'PASS' ||
  manifest.gates?.protected_paths?.status !== 'PASS'
) {
  errors.push('SRS, G5A, G4B and protected-path gates must all PASS.');
}
if (manifest.gates?.g5a?.decision_ids?.length !== 4) {
  errors.push('G5A must bind exactly four decision IDs.');
}
if (
  manifest.gates?.g4b?.w3_verdict !== 'PASS' ||
  manifest.gates?.g4b?.w8_verdict !== 'PASS' ||
  manifest.gates?.g4b?.w9_verdict !== 'PASS' ||
  manifest.gates?.g4b?.g4c_disposition !== 'VOICEOVER=G4C'
) {
  errors.push('G4B must bind W3/W8/W9 PASS and VoiceOver G4C.');
}
if (
  manifest.feature_flags?.PAWMATE_RESCUE_BROWSE_ENABLED !== false ||
  manifest.feature_flags?.PAWMATE_RESCUE_CREATE_ENABLED !== false
) {
  errors.push('D39 entry feature flags must remain false/false.');
}
if (
  manifest.day39_transition?.from !== 'NOT_STARTED' ||
  manifest.day39_transition?.to !== 'IN_PROGRESS' ||
  manifest.day39_transition?.entry !== 'OPEN'
) {
  errors.push('A passing D39 manifest must open the IN_PROGRESS transition.');
}
if (
  !manifest.reviewer ||
  !manifest.approver ||
  !manifest.captured_at ||
  Number.isNaN(Date.parse(manifest.captured_at))
) {
  errors.push('Reviewer, approver and captured_at are required.');
}

console.log(
  JSON.stringify(
    {
      status: errors.length === 0 ? 'PASS' : 'FAIL',
      manifest: manifestRelativePath.replaceAll('\\', '/'),
      sourceCommit: manifest.source?.commit,
      sourceSnapshotSha256: manifest.source?.snapshot_sha256,
      checks: manifest.checks?.length ?? 0,
      errors,
    },
    null,
    2,
  ),
);
process.exit(errors.length === 0 ? 0 : 1);

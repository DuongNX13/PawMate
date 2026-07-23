import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const manifestPath = path.join(
  root,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json',
);
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const errors = [];
const sha256File = (filePath) =>
  crypto
    .createHash('sha256')
    .update(fs.readFileSync(filePath))
    .digest('hex')
    .toUpperCase();
const required = [
  'schema_version',
  'evidence_id',
  'wave',
  'baseline_id',
  'parent_baseline_id',
  'change_control_id',
  'parent_evidence_manifest',
  'commit_sha',
  'dirty_snapshot_sha256',
  'source_snapshot_sha256',
  'source_snapshot',
  'platform',
  'device_runtime',
  'command',
  'status',
  'attempts',
  'artifacts',
  'executor',
  'reviewer',
  'contains_test_data_only',
  'redaction_status',
  'known_exceptions',
];
for (const key of required) {
  if (!(key in manifest)) errors.push(`Missing required key: ${key}`);
}
if (!/^[0-9a-f]{40}$/.test(manifest.commit_sha ?? '')) {
  errors.push('commit_sha is not a 40-character lowercase Git SHA');
}
if (!/^[A-F0-9]{64}$/.test(manifest.dirty_snapshot_sha256 ?? '')) {
  errors.push('dirty_snapshot_sha256 is not an uppercase SHA-256');
}
if (!/^[A-F0-9]{64}$/.test(manifest.source_snapshot_sha256 ?? '')) {
  errors.push('source_snapshot_sha256 is not an uppercase SHA-256');
}
if (manifest.wave !== 'W8') errors.push(`Expected wave W8, got ${manifest.wave}`);
if (manifest.change_control_id !== 'UI031-CHANGE-W8-P1-01-NO-RAILS-02') {
  errors.push(`Unexpected change_control_id: ${manifest.change_control_id}`);
}
const parentEvidence = manifest.parent_evidence_manifest ?? {};
if (
  typeof parentEvidence.path !== 'string' ||
  parentEvidence.path.includes('\\') ||
  path.isAbsolute(parentEvidence.path)
) {
  errors.push('parent_evidence_manifest.path is not portable');
} else {
  const parentAbsolute = path.resolve(root, parentEvidence.path);
  const parentRelative = path.relative(root, parentAbsolute);
  if (
    parentRelative.startsWith('..') ||
    path.isAbsolute(parentRelative) ||
    !fs.existsSync(parentAbsolute)
  ) {
    errors.push('parent_evidence_manifest.path is missing or outside the repository');
  } else {
    const parentManifest = JSON.parse(fs.readFileSync(parentAbsolute, 'utf8'));
    if (sha256File(parentAbsolute) !== parentEvidence.sha256) {
      errors.push('parent_evidence_manifest.sha256 does not match the archived file');
    }
    if (parentManifest.evidence_id !== parentEvidence.evidence_id) {
      errors.push('parent_evidence_manifest.evidence_id does not match the archived file');
    }
    if (
      parentManifest.baseline_id !== parentEvidence.baseline_id ||
      manifest.parent_baseline_id !== parentEvidence.baseline_id
    ) {
      errors.push('parent baseline linkage does not match the archived manifest');
    }
  }
}
if (typeof manifest.reviewer !== 'string' || manifest.reviewer.trim() === '') {
  errors.push('reviewer must be a non-empty string');
}
if (!Array.isArray(manifest.device_runtime) || manifest.device_runtime.length === 0) {
  errors.push('device_runtime must contain at least one runtime result');
} else {
  for (const runtime of manifest.device_runtime) {
    for (const key of ['platform', 'runtime', 'status', 'evidence']) {
      if (typeof runtime[key] !== 'string' || runtime[key].trim() === '') {
        errors.push(`device_runtime entry has invalid ${key}`);
      }
    }
  }
}
const attempts = manifest.attempts;
const allowedFailureClasses = new Set([
  'IOS_POSTCHANGE_NOT_RUN',
  'IOS_POSTCHANGE_INCOMPLETE',
  'IOS_POSTCHANGE_PROOF_INVALID',
  'IOS_POSTCHANGE_TEST_ENVIRONMENT',
  'IOS_POSTCHANGE_GOLDEN_HOST_MISMATCH',
  'IOS_POSTCHANGE_PASS',
]);
if (
  !Array.isArray(attempts) ||
  attempts.length === 0 ||
  attempts.some((attempt) => !allowedFailureClasses.has(attempt.failure_class))
) {
  errors.push('attempts contain an unknown iOS post-change failure class');
}
if (
  typeof manifest.status === 'string' &&
  manifest.status.includes('PASS') &&
  attempts?.at(-1)?.failure_class !== 'IOS_POSTCHANGE_PASS'
) {
  errors.push('a passing manifest must end with IOS_POSTCHANGE_PASS');
}

const seen = new Set();
const artifacts = manifest.artifacts ?? [];
for (const artifact of artifacts) {
  if (seen.has(artifact.path)) {
    errors.push(`Duplicate artifact path: ${artifact.path}`);
    continue;
  }
  seen.add(artifact.path);
  if (
    artifact.path.includes('\\') ||
    path.isAbsolute(artifact.path) ||
    !artifact.path.startsWith('output-evidence/ui-v031/')
  ) {
    errors.push(`Artifact path is not portable: ${artifact.path}`);
    continue;
  }
  const absolute = path.join(root, artifact.path);
  if (!fs.existsSync(absolute)) {
    errors.push(`Missing artifact: ${artifact.path}`);
    continue;
  }
  const bytes = fs.statSync(absolute).size;
  const sha256 = sha256File(absolute);
  if (bytes !== artifact.bytes) {
    errors.push(`Byte count mismatch: ${artifact.path}`);
  }
  if (sha256 !== artifact.sha256) {
    errors.push(`SHA-256 mismatch: ${artifact.path}`);
  }
}

function walkFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    return entry.isDirectory() ? walkFiles(absolute) : [absolute];
  });
}
const evidenceRoot = path.dirname(manifestPath);
const actualArtifactPaths = walkFiles(evidenceRoot)
  .filter((filePath) => filePath !== manifestPath)
  .filter((filePath) => fs.statSync(filePath).size > 0)
  .map((filePath) => path.relative(root, filePath).replaceAll('\\', '/'))
  .sort((left, right) => left.localeCompare(right));
const listedArtifactPaths = artifacts
  .map((artifact) => artifact.path)
  .sort((left, right) => left.localeCompare(right));
if (JSON.stringify(actualArtifactPaths) !== JSON.stringify(listedArtifactPaths)) {
  const listed = new Set(listedArtifactPaths);
  const actual = new Set(actualArtifactPaths);
  const missingFromManifest = actualArtifactPaths.filter((item) => !listed.has(item));
  const staleManifestEntries = listedArtifactPaths.filter((item) => !actual.has(item));
  errors.push(
    `Artifact set mismatch: missing=${missingFromManifest.join(',') || 'none'}; stale=${staleManifestEntries.join(',') || 'none'}`,
  );
}

const sourceSeen = new Set();
const sourceSnapshot = manifest.source_snapshot ?? [];
const sourcePaths = sourceSnapshot.map((item) => item.path);
const sortedSourcePaths = [...sourcePaths].sort((left, right) =>
  left.localeCompare(right),
);
if (JSON.stringify(sourcePaths) !== JSON.stringify(sortedSourcePaths)) {
  errors.push('source_snapshot paths are not deterministically sorted');
}
for (const source of sourceSnapshot) {
  if (sourceSeen.has(source.path)) {
    errors.push(`Duplicate source snapshot path: ${source.path}`);
    continue;
  }
  sourceSeen.add(source.path);
  const normalized = path.normalize(source.path);
  const absolute = path.resolve(root, normalized);
  const relativeFromRoot = path.relative(root, absolute);
  if (
    source.path.includes('\\') ||
    path.isAbsolute(source.path) ||
    relativeFromRoot.startsWith('..') ||
    path.isAbsolute(relativeFromRoot)
  ) {
    errors.push(`Source snapshot path is not portable: ${source.path}`);
    continue;
  }
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
    errors.push(`Missing source snapshot file: ${source.path}`);
    continue;
  }
  const bytes = fs.statSync(absolute).size;
  const sha256 = sha256File(absolute);
  if (bytes !== source.bytes) {
    errors.push(`Source byte count mismatch: ${source.path}`);
  }
  if (sha256 !== source.sha256) {
    errors.push(`Source SHA-256 mismatch: ${source.path}`);
  }
}
const sourceSnapshotPayload = sourceSnapshot
  .map((item) => `${item.path}:${item.sha256}:${item.bytes}`)
  .join('\n');
const sourceSnapshotSha256 = crypto
  .createHash('sha256')
  .update(Buffer.from(sourceSnapshotPayload, 'utf8'))
  .digest('hex')
  .toUpperCase();
if (sourceSnapshotSha256 !== manifest.source_snapshot_sha256) {
  errors.push('source_snapshot_sha256 does not match the source snapshot payload');
}

const redactionPath = path.join(
  root,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/redaction-scan.json',
);
const redaction = JSON.parse(fs.readFileSync(redactionPath, 'utf8'));
if (manifest.redaction_status !== redaction.status) {
  errors.push(
    `Redaction mismatch: manifest=${manifest.redaction_status} scan=${redaction.status}`,
  );
}

console.log(
  JSON.stringify(
    {
      status: errors.length === 0 ? 'PASS' : 'FAIL',
      waveStatus: manifest.status,
      artifacts: artifacts.length,
      sourceSnapshotFiles: sourceSnapshot.length,
      sourceSnapshotSha256: manifest.source_snapshot_sha256,
      redactionStatus: manifest.redaction_status,
      errors,
    },
    null,
    2,
  ),
);
if (errors.length > 0) process.exitCode = 1;

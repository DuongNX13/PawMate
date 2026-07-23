import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDirectory, '../../..');
const verifierPath = path.join(
  scriptDirectory,
  '../ui-v031/protected/verify-protected-paths.ps1',
);
const configPath = path.join(
  scriptDirectory,
  '../ui-v031/protected/protected-paths.json',
);
const baselinePath = path.join(
  repoRoot,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/protected/protected-baseline.json',
);
const priorApprovedDeltaPath = path.join(
  repoRoot,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/protected/approved-owner-delta-20260722.json',
);
const outputDirectory = path.join(repoRoot, 'output-evidence/day40/protected');
const outputPath = path.join(
  outputDirectory,
  'approved-owner-delta-20260723.json',
);
const verificationPath = path.join(
  outputDirectory,
  'protected-verify-after-approved-owner-delta.json',
);
const allowedAfterHashChanges = new Set([
  'docs/management/pawmate_execution_ledger_v1_1_2026-07-13.md',
]);

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''));
}

function runVerifier(extraArgs = []) {
  const result = spawnSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      verifierPath,
      '-Mode',
      'Verify',
      '-RepoRoot',
      repoRoot,
      '-ConfigPath',
      configPath,
      '-BaselineManifest',
      baselinePath,
      ...extraArgs,
    ],
    { cwd: repoRoot, encoding: 'utf8' },
  );
  if (result.error) throw result.error;
  return result;
}

function observeProtectedDelta() {
  const result = runVerifier();
  if (result.status !== 2) {
    throw new Error(
      `Expected fail-closed unapproved delta exit 2, got ${result.status}.`,
    );
  }
  const observed = JSON.parse(result.stdout);
  if (
    observed.status !== 'FAIL' ||
    observed.reason !== 'UNAPPROVED_PROTECTED_PATH_DELTA' ||
    !Array.isArray(observed.changes)
  ) {
    throw new Error('Protected verifier returned an unexpected payload.');
  }
  return observed;
}

function assertPriorApprovalContinuity(observed, priorApprovedDelta) {
  const previousByPath = new Map(
    priorApprovedDelta.changes.map((change) => [change.path, change]),
  );
  if (observed.changes.length !== priorApprovedDelta.changes.length) {
    throw new Error(
      `Protected path count drifted: observed ${observed.changes.length}, prior approval ${priorApprovedDelta.changes.length}.`,
    );
  }

  const changedAfterHashes = [];
  for (const change of observed.changes) {
    const previous = previousByPath.get(change.path);
    if (!previous) {
      throw new Error(`Unapproved protected path appeared: ${change.path}`);
    }
    if (
      previous.changeType !== change.changeType ||
      previous.beforeSha256 !== change.beforeSha256
    ) {
      throw new Error(
        `Protected baseline semantics drifted for ${change.path}.`,
      );
    }
    if (previous.afterSha256 !== change.afterSha256) {
      changedAfterHashes.push(change.path);
    }
  }

  const unexpected = changedAfterHashes.filter(
    (filePath) => !allowedAfterHashChanges.has(filePath),
  );
  if (unexpected.length > 0) {
    throw new Error(
      `Only the execution ledger may differ from the prior approved owner delta; unexpected: ${unexpected.join(', ')}`,
    );
  }
  if (
    changedAfterHashes.length !== allowedAfterHashChanges.size ||
    !changedAfterHashes.every((filePath) =>
      allowedAfterHashChanges.has(filePath),
    )
  ) {
    throw new Error(
      `Expected the exact Day 40 ledger delta, observed: ${changedAfterHashes.join(', ') || 'none'}.`,
    );
  }
}

function verifyApprovedDelta(ownerDeltaPath) {
  const result = runVerifier([
    '-OwnerDeltaManifest',
    ownerDeltaPath,
  ]);
  if (result.status !== 0) {
    throw new Error(
      `Approved protected-path verification failed with ${result.status}: ${result.stdout.trim()} ${result.stderr.trim()}`,
    );
  }
  const verified = JSON.parse(result.stdout);
  if (
    verified.status !== 'PASS_WITH_APPROVED_OWNER_DELTA' ||
    verified.approvedOwnerDelta !== true
  ) {
    throw new Error('Verifier did not accept the exact owner delta.');
  }
  return verified;
}

function main() {
  const observed = observeProtectedDelta();
  const baseline = readJson(baselinePath);
  const config = readJson(configPath);
  const priorApprovedDelta = readJson(priorApprovedDeltaPath);
  assertPriorApprovalContinuity(observed, priorApprovedDelta);

  const manifest = {
    schemaVersion: 1,
    kind: 'pawmate-protected-path-owner-delta',
    policyId: config.policyId,
    baselineId: baseline.baselineId,
    owner: 'Codex lead / Day 40 closure lane',
    approvedBy:
      'Product Owner (explicit Day 40-43 blocker-closure instruction, 2026-07-23)',
    reason:
      'Preserve the exact previously approved Day 37-38 protected path set while approving only the execution-ledger updates required to close Day 39-40 gates. W0 remains immutable and no protected path is added, removed, or rebaselined.',
    approvedAtUtc: '2026-07-23T11:26:07Z',
    expiresAtUtc: '2026-07-30T11:26:07Z',
    changes: observed.changes.map((change) => ({
      path: change.path,
      changeType: change.changeType,
      beforeSha256: change.beforeSha256 ?? null,
      afterSha256: change.afterSha256 ?? null,
    })),
  };

  fs.mkdirSync(outputDirectory, { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  const verified = verifyApprovedDelta(outputPath);
  fs.writeFileSync(
    verificationPath,
    `${JSON.stringify(verified, null, 2)}\n`,
    'utf8',
  );

  console.log(
    JSON.stringify({
      status: 'PASS',
      baselineId: baseline.baselineId,
      preservedPriorPathSet: true,
      changes: manifest.changes.length,
      added: manifest.changes.filter(
        (change) => change.changeType === 'added',
      ).length,
      modified: manifest.changes.filter(
        (change) => change.changeType === 'modified',
      ).length,
      approvedNewPaths: 0,
      rebaseline: false,
      output: path.relative(repoRoot, outputPath).replaceAll('\\', '/'),
      verification: path
        .relative(repoRoot, verificationPath)
        .replaceAll('\\', '/'),
      verificationStatus: verified.status,
    }),
  );
}

main();

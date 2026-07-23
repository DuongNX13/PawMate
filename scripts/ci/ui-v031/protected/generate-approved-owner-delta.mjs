import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDirectory, '../../../..');
const verifierPath = path.join(scriptDirectory, 'verify-protected-paths.ps1');
const configPath = path.join(scriptDirectory, 'protected-paths.json');
const baselinePath = path.join(
  repoRoot,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/protected/protected-baseline.json',
);
const defaultOutputPath = path.join(
  repoRoot,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/protected/approved-owner-delta-20260722.json',
);
const defaultVerificationPath = path.join(
  repoRoot,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/protected/protected-verify-after-approved-owner-delta.json',
);

function parseArgs(argv) {
  const args = {
    output: defaultOutputPath,
    check: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--check') {
      args.check = true;
    } else if (arg === '--output') {
      index += 1;
      if (!argv[index]) {
        throw new Error('--output requires a path');
      }
      args.output = path.resolve(repoRoot, argv[index]);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, ''));
}

function observeProtectedDelta() {
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
    ],
    { cwd: repoRoot, encoding: 'utf8' },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 2) {
    throw new Error(
      `Expected an unapproved protected delta (exit 2), got ${result.status}. stderr=${result.stderr.trim()}`,
    );
  }
  const observed = JSON.parse(result.stdout);
  if (
    observed.status !== 'FAIL' ||
    observed.reason !== 'UNAPPROVED_PROTECTED_PATH_DELTA' ||
    !Array.isArray(observed.changes) ||
    observed.changes.length === 0
  ) {
    throw new Error('Protected verifier did not return a non-empty fail-closed delta.');
  }
  return observed;
}

function verifyApprovedDelta(ownerDeltaPath) {
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
      '-OwnerDeltaManifest',
      ownerDeltaPath,
    ],
    { cwd: repoRoot, encoding: 'utf8' },
  );
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(
      `Approved protected-path verification failed with ${result.status}. stderr=${result.stderr.trim()} stdout=${result.stdout.trim()}`,
    );
  }
  const verified = JSON.parse(result.stdout);
  if (
    verified.status !== 'PASS_WITH_APPROVED_OWNER_DELTA' ||
    verified.approvedOwnerDelta !== true
  ) {
    throw new Error('Protected verifier did not accept the exact approved owner delta.');
  }
  return verified;
}

function stableManifest({ observed, config, baseline }) {
  return {
    schemaVersion: 1,
    kind: 'pawmate-protected-path-owner-delta',
    policyId: config.policyId,
    baselineId: baseline.baselineId,
    owner: 'Codex lead / Day 37-38 implementation lane',
    approvedBy: 'Product Owner (user approval bundle, 2026-07-22)',
    reason:
      'Exact reconciliation of the approved Day 37-38 implementation, G5A decisions, W2 no-use exception, W3 77-row/7-screen contract, v0.31/v0.32 allowlist, SRS v1.1 adoption, and VoiceOver move to G4C.',
    approvedAtUtc: '2026-07-22T09:41:12Z',
    expiresAtUtc: '2026-07-29T09:41:12Z',
    changes: observed.changes.map((change) => ({
      path: change.path,
      changeType: change.changeType,
      beforeSha256: change.beforeSha256 ?? null,
      afterSha256: change.afterSha256 ?? null,
    })),
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const observed = observeProtectedDelta();
  const manifest = stableManifest({
    observed,
    config: readJson(configPath),
    baseline: readJson(baselinePath),
  });
  const serialized = `${JSON.stringify(manifest, null, 2)}\n`;

  if (args.check) {
    if (!fs.existsSync(args.output)) {
      throw new Error(`Owner-delta manifest is missing: ${path.relative(repoRoot, args.output)}`);
    }
    const current = fs.readFileSync(args.output, 'utf8');
    if (current !== serialized) {
      throw new Error('Owner-delta manifest is stale relative to the current protected-path delta.');
    }
  } else {
    fs.mkdirSync(path.dirname(args.output), { recursive: true });
    fs.writeFileSync(args.output, serialized, 'utf8');
  }

  const verified = verifyApprovedDelta(args.output);
  if (!args.check) {
    fs.writeFileSync(
      defaultVerificationPath,
      `${JSON.stringify(verified, null, 2)}\n`,
      'utf8',
    );
  }

  console.log(
    JSON.stringify({
      status: 'PASS',
      mode: args.check ? 'CHECK' : 'WRITE',
      output: path.relative(repoRoot, args.output).replaceAll('\\', '/'),
      changes: manifest.changes.length,
      added: manifest.changes.filter((change) => change.changeType === 'added').length,
      modified: manifest.changes.filter((change) => change.changeType === 'modified').length,
      removed: manifest.changes.filter((change) => change.changeType === 'removed').length,
      verification_status: verified.status,
      verification_output: path
        .relative(repoRoot, defaultVerificationPath)
        .replaceAll('\\', '/'),
    }),
  );
}

main();

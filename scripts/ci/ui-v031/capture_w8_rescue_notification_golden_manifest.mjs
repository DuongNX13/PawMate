import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const currentPath = path.join(root, 'docs/qa/ui-v031/W8_RUNTIME_GOLDEN_HASHES.json');
const parentPath = path.join(
  root,
  'docs/qa/ui-v031/W8_RUNTIME_GOLDEN_HASHES_P1-07_A11Y_01.json',
);

const sha256 = (filePath) =>
  crypto
    .createHash('sha256')
    .update(fs.readFileSync(filePath))
    .digest('hex')
    .toUpperCase();

if (!fs.existsSync(parentPath)) {
  const currentBytes = fs.readFileSync(currentPath);
  const current = JSON.parse(currentBytes.toString('utf8').replace(/^\uFEFF/, ''));
  if (current.baseline_id !== 'UI-CC-2026-07-21-G4B-W8-P1-07-A11Y-01') {
    throw new Error(`Refusing to freeze unexpected parent baseline ${current.baseline_id}`);
  }
  fs.writeFileSync(parentPath, currentBytes);
}

const parent = JSON.parse(fs.readFileSync(parentPath, 'utf8'));
const parentArtifacts = new Map(
  (parent.artifacts ?? []).map((artifact) => [artifact.path, artifact]),
);
const artifacts = (parent.artifacts ?? []).map((artifact) => {
  const filePath = path.join(root, artifact.path);
  if (!fs.existsSync(filePath)) throw new Error(`Missing runtime golden ${artifact.path}`);
  return {
    ...artifact,
    bytes: fs.statSync(filePath).size,
    sha256: sha256(filePath),
  };
});
if (artifacts.length !== 71 || new Set(artifacts.map((item) => item.path)).size !== 71) {
  throw new Error(`Expected exactly 71 unique runtime goldens, got ${artifacts.length}`);
}

const expectedChangedPaths = artifacts
  .filter((artifact) => artifact.path.includes('/ui-v031-rescue/rescue-staged-'))
  .map((artifact) => artifact.path)
  .sort();
const actualChangedPaths = artifacts
  .filter((artifact) => parentArtifacts.get(artifact.path)?.sha256 !== artifact.sha256)
  .map((artifact) => artifact.path)
  .sort();
if (
  expectedChangedPaths.length !== 3 ||
  JSON.stringify(actualChangedPaths) !== JSON.stringify(expectedChangedPaths)
) {
  throw new Error(
    `Expected only three Rescue notification golden deltas, got ${JSON.stringify(actualChangedPaths)}`,
  );
}

const manifest = {
  schema_version: '1.3',
  baseline_id: 'UI-CC-2026-07-21-G4B-W8-RESCUE-NOTIFICATION-01',
  parent_baseline_id: parent.baseline_id,
  change_control_id: 'UI031-CHANGE-W8-RESCUE-NOTIFICATION-01',
  parent_manifest: {
    path: path.relative(root, parentPath).replaceAll('\\', '/'),
    sha256: sha256(parentPath),
  },
  wave: 'W8',
  artifact_type: parent.artifact_type,
  contract_count: 71,
  tier_a_count: parent.tier_a_count,
  tier_b_count: parent.tier_b_count,
  rescue_staged_count: parent.rescue_staged_count,
  captured_at: new Date().toISOString(),
  comparison_command:
    'D:\\flutter\\bin\\flutter.bat test test/visual/ui_v031_rescue_staged_golden_test.dart --update-goldens',
  comparison_exit_code: 0,
  comparison_evidence:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/cta-row-proof-20260723/flutter-full-coverage.raw.txt',
  approved_delta: {
    change_control_id: 'UI031-CHANGE-W8-RESCUE-NOTIFICATION-01',
    reason:
      'Restore the target-enabled Rescue notification CTA required by the frozen 84-row CTA contract.',
    affected_artifacts: expectedChangedPaths,
    runtime_source:
      'mobile/lib/features/rescue/presentation/rescue_home_screen.dart',
    regression_test:
      'mobile/test/features/rescue/rescue_home_screen_test.dart; mobile/test/visual/ui_v031_rescue_staged_golden_test.dart',
    first_failure_evidence:
      'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/cta-row-proof-20260723/flutter-full-coverage-first-failure.raw.txt',
  },
  artifacts,
};

fs.writeFileSync(currentPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(
  JSON.stringify({
    status: 'PASS',
    output: path.relative(root, currentPath).replaceAll('\\', '/'),
    count: artifacts.length,
    changed: actualChangedPaths,
    baselineId: manifest.baseline_id,
  }),
);

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const parentPath = path.join(
  root,
  'docs/qa/ui-v031/W8_RUNTIME_GOLDEN_HASHES_P1-01_NO_RAILS_02.json',
);
const outputPath = path.join(
  root,
  'docs/qa/ui-v031/W8_RUNTIME_GOLDEN_HASHES.json',
);

if (!fs.existsSync(parentPath)) {
  if (!fs.existsSync(outputPath)) {
    throw new Error('Cannot freeze the previous runtime-golden manifest: current file is missing.');
  }
  const previousBytes = fs.readFileSync(outputPath);
  const previous = JSON.parse(previousBytes.toString('utf8').replace(/^\uFEFF/, ''));
  if (previous.baseline_id !== 'UI-CC-2026-07-21-G4B-W8-P1-01-NO-RAILS-02') {
    throw new Error(`Refusing to freeze unexpected parent baseline ${previous.baseline_id}`);
  }
  fs.writeFileSync(parentPath, previousBytes);
}

const sha256 = (filePath) =>
  crypto
    .createHash('sha256')
    .update(fs.readFileSync(filePath))
    .digest('hex')
    .toUpperCase();

const parent = JSON.parse(fs.readFileSync(parentPath, 'utf8'));
const parentArtifacts = new Map(
  (parent.artifacts ?? []).map((artifact) => [artifact.path, artifact]),
);
const artifacts = (parent.artifacts ?? []).map((artifact) => {
  const filePath = path.join(root, artifact.path);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Cannot capture missing golden: ${artifact.path}`);
  }
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
  .filter(
    (artifact) =>
      artifact.requirement_id.startsWith('UI031-VIS-P1-07-') &&
      !artifact.requirement_id.endsWith('-320x568'),
  )
  .map((artifact) => artifact.path)
  .sort();
const actualChangedPaths = artifacts
  .filter(
    (artifact) => parentArtifacts.get(artifact.path)?.sha256 !== artifact.sha256,
  )
  .map((artifact) => artifact.path)
  .sort();
if (
  expectedChangedPaths.length !== 4 ||
  JSON.stringify(actualChangedPaths) !== JSON.stringify(expectedChangedPaths)
) {
  throw new Error(
    `Expected only four P1-07 golden deltas, got ${JSON.stringify(actualChangedPaths)}`,
  );
}

const manifest = {
  schema_version: '1.2',
  baseline_id: 'UI-CC-2026-07-21-G4B-W8-P1-07-A11Y-01',
  parent_baseline_id: parent.baseline_id,
  change_control_id: 'UI031-CHANGE-W8-P1-07-A11Y-01',
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
    'D:\\flutter\\bin\\flutter.bat test --no-pub test/visual',
  comparison_exit_code: 0,
  comparison_evidence:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/p1-07-a11y-20260722/home-profile-goldens-9-pass.raw.txt',
  approved_delta: {
    change_control_id: 'UI031-CHANGE-W8-P1-07-A11Y-01',
    product_owner_instruction_date: '2026-07-22',
    reason:
      'Expose actionable semantics for Home pet/add/emergency surfaces and replace the intentionally truncated emergency copy with the complete location text.',
    affected_artifacts: expectedChangedPaths,
    runtime_source:
      'mobile/lib/features/pets/presentation/pet_list_screen.dart',
    regression_test:
      'mobile/test/features/pets/pet_navigation_test.dart; mobile/test/visual/phase1_home_profile_golden_test.dart',
    before_evidence: 'mobile/test/visual/failures/p1-07-home-390x844_masterImage.png',
    diff_evidence: 'mobile/test/visual/failures/p1-07-home-390x844_isolatedDiff.png',
    after_evidence: 'mobile/test/visual/failures/p1-07-home-390x844_testImage.png',
  },
  artifacts,
};

fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(
  JSON.stringify(
    {
      status: 'PASS',
      output: path.relative(root, outputPath).replaceAll('\\', '/'),
      count: artifacts.length,
      baselineId: manifest.baseline_id,
    },
    null,
    2,
  ),
);

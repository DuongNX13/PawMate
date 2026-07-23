import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const runtimeManifestPath = path.join(
  root,
  'docs/qa/ui-v031/W8_RUNTIME_GOLDEN_HASHES.json',
);
const platformRoot = path.join(
  root,
  'mobile/test/visual/goldens/ui-v031-platform-primitives',
);
const expectedPlatformNames = [
  'android-actionSheet.png',
  'android-back.png',
  'android-bottomNav.png',
  'android-datePicker.png',
  'android-dialog.png',
  'android-timePicker.png',
  'iOS-actionSheet.png',
  'iOS-back.png',
  'iOS-bottomNav.png',
  'iOS-datePicker.png',
  'iOS-dialog.png',
  'iOS-timePicker.png',
];

const sha256 = (filePath) =>
  crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex').toUpperCase();

const errors = [];
const runtimeManifest = JSON.parse(
  fs.readFileSync(runtimeManifestPath, 'utf8'),
);
const runtimeArtifacts = runtimeManifest.artifacts ?? [];
const runtimePaths = new Set();

for (const artifact of runtimeArtifacts) {
  if (runtimePaths.has(artifact.path)) {
    errors.push(`Duplicate runtime golden path: ${artifact.path}`);
    continue;
  }
  runtimePaths.add(artifact.path);
  const filePath = path.join(root, artifact.path);
  if (!fs.existsSync(filePath)) {
    errors.push(`Missing runtime golden: ${artifact.path}`);
    continue;
  }
  const actual = sha256(filePath);
  if (actual !== artifact.sha256) {
    errors.push(
      `Runtime golden hash mismatch: ${artifact.path} expected=${artifact.sha256} actual=${actual}`,
    );
  }
}

if (runtimeManifest.contract_count !== 71 || runtimePaths.size !== 71) {
  errors.push(
    `Runtime denominator mismatch: manifest=${runtimeManifest.contract_count} unique=${runtimePaths.size}`,
  );
}

const actualPlatformNames = fs
  .readdirSync(platformRoot)
  .filter((name) => name.toLowerCase().endsWith('.png'))
  .sort();
const missingPlatform = expectedPlatformNames.filter(
  (name) => !actualPlatformNames.includes(name),
);
const unexpectedPlatform = actualPlatformNames.filter(
  (name) => !expectedPlatformNames.includes(name),
);
if (missingPlatform.length > 0) {
  errors.push(`Missing platform goldens: ${missingPlatform.join(', ')}`);
}
if (unexpectedPlatform.length > 0) {
  errors.push(`Unexpected platform goldens: ${unexpectedPlatform.join(', ')}`);
}

const platformArtifacts = expectedPlatformNames
  .filter((name) => fs.existsSync(path.join(platformRoot, name)))
  .map((name) => {
    const filePath = path.join(platformRoot, name);
    return {
      path: path.relative(root, filePath).replaceAll('\\', '/'),
      bytes: fs.statSync(filePath).size,
      sha256: sha256(filePath),
    };
  });

const result = {
  status: errors.length === 0 ? 'PASS' : 'FAIL',
  manifest: path.relative(root, runtimeManifestPath).replaceAll('\\', '/'),
  baselineId: runtimeManifest.baseline_id,
  runtime: {
    expected: 71,
    actual: runtimePaths.size,
    hashesMatched: errors.filter((error) =>
      error.startsWith('Runtime golden hash mismatch'),
    ).length === 0,
  },
  platform: {
    expected: 12,
    actual: platformArtifacts.length,
    artifacts: platformArtifacts,
  },
  total: runtimePaths.size + platformArtifacts.length,
  errors,
};

console.log(JSON.stringify(result, null, 2));
if (errors.length > 0) process.exitCode = 1;

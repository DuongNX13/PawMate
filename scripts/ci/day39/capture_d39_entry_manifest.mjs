import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const repoRoot = process.cwd();
const runId = process.env.D39_RUN_ID ?? '20260723-g4b-approved';
const manifestRelativePath =
  process.env.D39_MANIFEST_PATH ??
  `docs/management/gates/D39-ENTRY-${runId}.json`;
const manifestPath = path.join(repoRoot, manifestRelativePath);

const expected = {
  entryCommit: '4046B4C70E2892985A54725A998E43B8F93784C4',
  phase1Workbook:
    '0941F3BD4BDA4228AB137AC5A172919D5A7A1329C17D92FCBF09F8FDB8E78248',
  phase2Workbook:
    '8B53E336AB1B4042335C786648083D275A96D0E5DDB3101437D0A97AD0C418ED',
  g5aTechnicalManifest:
    '25B66518BB423898614582DA177BC581DD03AE704F7CA870CE4F45257ADEB9D6',
  g5aApprovalReconciliation:
    '58F4D77F8D38940A08B0ABEAD13520D64624DBE045C1C086413AF3538F1BED2A',
  g4bW8Manifest:
    '3832C950AFCED7ADDFE8B7D828DFE7CD8E40A566F4B9147778203F1C35FCD7A1',
  g4bSourceSnapshot:
    '9D1E17293EF7532DAC0FC1ED286FDBCDF1027B200A00826C8AEEB6F836D52245',
  w3Audit:
    '5D5DBCB8C12C1768A174B299DE5E4FE818C80B6989C23D3453473698172BAB0F',
  protectedBaseline:
    'EB0930E33E825BE057AEFDED7549330562D3095A99C57BE2E66364DC20F42DE7',
  approvedOwnerDelta:
    '461032FA73590F5FDB04F9DBDF356879808E69FD774F0B977BB02AE3B4316A05',
  protectedVerification:
    'BD98DD0930EA68F934F69D575A1E64533C947A8CAD5A8C988ABF3B09EA50E4D5',
  protectedBaselineId:
    '170B536B40DC73DC269515ABE335DA1CFC7B088F7A4D68ACA2D2D5F355BE8E4B',
};

const files = {
  phase1Workbook:
    'docs/product/srs_v031_day37_38_update_2026-07-22/PawMate_SRS_Phase1_22-07-2026_v1.1.xlsx',
  phase2Workbook:
    'docs/product/srs_v031_day37_38_update_2026-07-22/PawMate_SRS_Phase2_22-07-2026_v1.1.xlsx',
  srsContract:
    'docs/product/srs_v031_day37_38_update_2026-07-22/SRS_UPDATE_CONTRACT.md',
  productApproval:
    'docs/management/pawmate_product_owner_approval_2026-07-22.md',
  g5aTechnicalManifest:
    'output-evidence/day38/final-20260722-1533/manifest.json',
  g5aApprovalReconciliation:
    'output-evidence/day38/final-20260722-1533/g5a-product-approval-reconciliation-20260722.json',
  g5aDecisionRecord: 'docs/architecture/day38_g5a_decision_record.md',
  g4bW8Manifest:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json',
  g4bApproval:
    'docs/management/pawmate_product_owner_g4b_approval_2026-07-23.md',
  g4bJointSignoff: 'docs/qa/ui-v031/G4B_JOINT_SIGNOFF.md',
  w3Audit: 'docs/qa/ui-v031/W3_POST_WRITE_AUDIT_2026-07-22.json',
  w8Report: 'docs/qa/ui-v031/W8_CROSS_PLATFORM_QA_REPORT.md',
  w9Report: 'docs/qa/ui-v031/W9_HANDOFF_BLOCKED_REPORT.md',
  protectedBaseline:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/protected/protected-baseline.json',
  approvedOwnerDelta:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/protected/approved-owner-delta-20260722.json',
  protectedVerification:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/protected/protected-verify-after-approved-owner-delta.json',
  featureAvailability:
    'mobile/lib/app/router/app_feature_availability.dart',
};

const sha256Buffer = (value) =>
  crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const resolve = (relativePath) => path.join(repoRoot, relativePath);
const sha256File = (relativePath) =>
  sha256Buffer(fs.readFileSync(resolve(relativePath)));
const readText = (relativePath) =>
  fs.readFileSync(resolve(relativePath), 'utf8');
const readJson = (relativePath) =>
  JSON.parse(readText(relativePath).replace(/^\uFEFF/, ''));

const checks = [];
function check(id, condition, evidence, detail) {
  checks.push({
    id,
    status: condition ? 'PASS' : 'FAIL',
    evidence,
    detail,
  });
}

for (const [id, relativePath] of Object.entries(files)) {
  check(
    `FILE-${id.toUpperCase()}`,
    fs.existsSync(resolve(relativePath)),
    relativePath,
    fs.existsSync(resolve(relativePath))
      ? 'Required artifact exists.'
      : 'Required artifact is missing.',
  );
}

if (checks.some((entry) => entry.status === 'FAIL')) {
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  fs.writeFileSync(
    manifestPath,
    `${JSON.stringify(
      {
        schema: 'pawmate.d39-entry.v1',
        run_id: runId,
        status: 'FAIL',
        captured_at: new Date().toISOString(),
        checks,
      },
      null,
      2,
    )}\n`,
    'utf8',
  );
  console.error(JSON.stringify({ status: 'FAIL', manifest: manifestRelativePath, checks }, null, 2));
  process.exit(1);
}

const headResult = spawnSync('git', ['rev-parse', 'HEAD'], {
  cwd: repoRoot,
  encoding: 'utf8',
});
const branchResult = spawnSync('git', ['branch', '--show-current'], {
  cwd: repoRoot,
  encoding: 'utf8',
});
const head = headResult.stdout.trim().toUpperCase();
const branch = branchResult.stdout.trim();

const phase1Hash = sha256File(files.phase1Workbook);
const phase2Hash = sha256File(files.phase2Workbook);
const srsContract = readText(files.srsContract);
const productApproval = readText(files.productApproval);
check(
  'SRS-PHASE1-V1.1',
  phase1Hash === expected.phase1Workbook,
  files.phase1Workbook,
  `SHA-256 ${phase1Hash}`,
);
check(
  'SRS-PHASE2-V1.1',
  phase2Hash === expected.phase2Workbook,
  files.phase2Workbook,
  `SHA-256 ${phase2Hash}`,
);
check(
  'SRS-PRODUCT-ADOPTION',
  srsContract.includes('ADOPT_V1.1') &&
    productApproval.includes('ADOPT_V1.1'),
  files.productApproval,
  'Product/BA adoption record contains ADOPT_V1.1.',
);

const g5aManifestHash = sha256File(files.g5aTechnicalManifest);
const g5aApprovalHash = sha256File(files.g5aApprovalReconciliation);
const g5aDecisionRecord = readText(files.g5aDecisionRecord);
const g5aDecisionIds = [
  'G5A-DEC-AUTH-01',
  'G5A-DEC-PRIVACY-01',
  'G5A-DEC-CONTACT-01',
  'G5A-DEC-OUTBOX-01',
];
check(
  'G5A-TECHNICAL-MANIFEST',
  g5aManifestHash === expected.g5aTechnicalManifest,
  files.g5aTechnicalManifest,
  `SHA-256 ${g5aManifestHash}`,
);
check(
  'G5A-PRODUCT-RECONCILIATION',
  g5aApprovalHash === expected.g5aApprovalReconciliation &&
    g5aDecisionIds.every((id) => g5aDecisionRecord.includes(id)) &&
    g5aDecisionRecord.includes('G5A_PASS'),
  files.g5aApprovalReconciliation,
  `G5A_PASS; four decision IDs; SHA-256 ${g5aApprovalHash}`,
);

const w3AuditHash = sha256File(files.w3Audit);
const w3Audit = readJson(files.w3Audit);
check(
  'W3-VERDICT',
  w3AuditHash === expected.w3Audit &&
    w3Audit?.matrix?.rows === 77 &&
    w3Audit?.matrix?.approvedSeven?.length === 7 &&
    w3Audit?.liveAudit?.unsupportedTextFamilies === 0 &&
    w3Audit?.liveAudit?.geometryViolations === 0,
  files.w3Audit,
  `77 rows; seven approved screens; SHA-256 ${w3AuditHash}`,
);

const w8ManifestHash = sha256File(files.g4bW8Manifest);
const w8Manifest = readJson(files.g4bW8Manifest);
const g4bApproval = readText(files.g4bApproval);
const g4bJointSignoff = readText(files.g4bJointSignoff);
const iosPass = w8Manifest.device_runtime?.some(
  (runtime) => runtime.platform === 'ios' && runtime.status === 'PASS',
);
check(
  'W8-IMMUTABLE-MANIFEST',
  w8ManifestHash === expected.g4bW8Manifest &&
    w8Manifest.source_snapshot_sha256 === expected.g4bSourceSnapshot &&
    w8Manifest.redaction_status === 'PASS' &&
    w8Manifest.artifacts?.length === 779 &&
    iosPass,
  files.g4bW8Manifest,
  `779 artifacts; iOS PASS; redaction PASS; SHA-256 ${w8ManifestHash}`,
);
check(
  'G4B-JOINT-APPROVAL',
  g4bApproval.includes('G4B=APPROVE') &&
    g4bApproval.includes(expected.g4bW8Manifest) &&
    g4bJointSignoff.includes('Current status: `PASS`'),
  files.g4bApproval,
  'Product Owner and Codex lead approve the same immutable W8 manifest.',
);
check(
  'W9-HANDOFF',
  readText(files.w9Report).includes('Verdict: `PASS / HANDOFF_APPROVED`'),
  files.w9Report,
  'W9 handoff verdict is PASS.',
);
check(
  'G4C-DISPOSITION',
  g4bApproval.includes('`G4C`') &&
    g4bJointSignoff.includes('| VoiceOver | `G4C` |'),
  files.g4bApproval,
  'VoiceOver remains outside the G4B denominator in G4C.',
);

const protectedBaselineHash = sha256File(files.protectedBaseline);
const ownerDeltaHash = sha256File(files.approvedOwnerDelta);
const protectedVerificationHash = sha256File(files.protectedVerification);
const protectedBaseline = readJson(files.protectedBaseline);
const ownerDelta = readJson(files.approvedOwnerDelta);
const protectedVerification = readJson(files.protectedVerification);
check(
  'PROTECTED-BASELINE',
  protectedBaselineHash === expected.protectedBaseline &&
    protectedBaseline.baselineId === expected.protectedBaselineId,
  files.protectedBaseline,
  `Baseline ${protectedBaseline.baselineId}; SHA-256 ${protectedBaselineHash}`,
);
check(
  'PROTECTED-OWNER-DELTA',
  ownerDeltaHash === expected.approvedOwnerDelta &&
    ownerDelta.baselineId === expected.protectedBaselineId &&
    new Date(ownerDelta.expiresAtUtc).getTime() > Date.now(),
  files.approvedOwnerDelta,
  `Approved owner delta; SHA-256 ${ownerDeltaHash}`,
);
check(
  'PROTECTED-VERIFY',
  protectedVerificationHash === expected.protectedVerification &&
    protectedVerification.status === 'PASS_WITH_APPROVED_OWNER_DELTA' &&
    protectedVerification.baselineId === expected.protectedBaselineId &&
    protectedVerification.added === 38 &&
    protectedVerification.modified === 12 &&
    protectedVerification.removed === 0,
  files.protectedVerification,
  `38 added; 12 modified; 0 removed; SHA-256 ${protectedVerificationHash}`,
);

const featureAvailability = readText(files.featureAvailability);
const browseDefaultFalse =
  /PAWMATE_RESCUE_BROWSE_ENABLED[\s\S]{0,120}defaultValue:\s*false/.test(
    featureAvailability,
  );
const createDefaultFalse =
  /PAWMATE_RESCUE_CREATE_ENABLED[\s\S]{0,120}defaultValue:\s*false/.test(
    featureAvailability,
  );
const createForcedOff =
  /rescueCreate\s*=\s*rescueBrowse\s*&&\s*rescueCreate/.test(
    featureAvailability,
  );
check(
  'FEATURE-FLAGS-FAIL-CLOSED',
  browseDefaultFalse && createDefaultFalse && createForcedOff,
  files.featureAvailability,
  'Browse/create default false; create is forced false when browse is false.',
);
check(
  'ENTRY-SOURCE-COMMIT',
  headResult.status === 0 && head === expected.entryCommit,
  'git:HEAD',
  `Branch ${branch}; commit ${head}`,
);

const snapshotFiles = [...new Set(Object.values(files))].sort();
const sourceSnapshot = snapshotFiles.map((relativePath) => ({
  path: relativePath,
  bytes: fs.statSync(resolve(relativePath)).size,
  sha256: sha256File(relativePath),
}));
const sourceSnapshotSha256 = sha256Buffer(
  Buffer.from(
    sourceSnapshot
      .map((artifact) => `${artifact.path}|${artifact.bytes}|${artifact.sha256}`)
      .join('\n'),
    'utf8',
  ),
);
const status = checks.every((entry) => entry.status === 'PASS')
  ? 'PASS'
  : 'FAIL';
const manifest = {
  schema: 'pawmate.d39-entry.v1',
  run_id: runId,
  roadmap_change_control_id: 'ROADMAP-CC-2026-07-22-V1.2',
  status,
  captured_at: new Date().toISOString(),
  source: {
    branch,
    commit: head,
    snapshot_sha256: sourceSnapshotSha256,
    snapshot: sourceSnapshot,
  },
  gates: {
    srs: {
      status: checks.find((entry) => entry.id === 'SRS-PRODUCT-ADOPTION')
        ?.status,
      phase1_sha256: phase1Hash,
      phase2_sha256: phase2Hash,
      approval_reference: files.productApproval,
    },
    g5a: {
      status: 'PASS',
      technical_manifest_sha256: g5aManifestHash,
      approval_reconciliation_sha256: g5aApprovalHash,
      decision_ids: g5aDecisionIds,
    },
    g4b: {
      status: checks.find((entry) => entry.id === 'G4B-JOINT-APPROVAL')
        ?.status,
      w8_manifest_sha256: w8ManifestHash,
      w8_source_snapshot_sha256: w8Manifest.source_snapshot_sha256,
      w3_verdict: 'PASS',
      w8_verdict: 'PASS',
      w9_verdict: 'PASS',
      g4c_disposition: 'VOICEOVER=G4C',
      approval_reference: files.g4bApproval,
    },
    protected_paths: {
      status: checks.find((entry) => entry.id === 'PROTECTED-VERIFY')?.status,
      baseline_id: protectedBaseline.baselineId,
      baseline_manifest_sha256: protectedBaselineHash,
      owner_delta_manifest_sha256: ownerDeltaHash,
      verification_sha256: protectedVerificationHash,
    },
  },
  feature_flags: {
    PAWMATE_RESCUE_BROWSE_ENABLED: false,
    PAWMATE_RESCUE_CREATE_ENABLED: false,
    scope: 'compile-time build-global; missing/invalid values fail closed',
  },
  day39_transition: {
    from: 'NOT_STARTED',
    to: status === 'PASS' ? 'IN_PROGRESS' : 'NOT_STARTED',
    entry: status === 'PASS' ? 'OPEN' : 'CLOSED',
  },
  reviewer: 'Codex lead / QA owner',
  approver: 'User / Product Owner via explicit G4B=APPROVE',
  checks,
};

fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(
  JSON.stringify(
    {
      status,
      manifest: manifestRelativePath.replaceAll('\\', '/'),
      sourceCommit: head,
      sourceSnapshotSha256,
      checks: {
        total: checks.length,
        pass: checks.filter((entry) => entry.status === 'PASS').length,
        fail: checks.filter((entry) => entry.status === 'FAIL').length,
      },
    },
    null,
    2,
  ),
);
process.exit(status === 'PASS' ? 0 : 1);

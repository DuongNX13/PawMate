import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readCsv } from './csv_utils.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const currentMatrixPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/W3_RESPONSIVE_PROOF_MATRIX_PROPOSAL.csv',
);
const approvalPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/W3_MATRIX_APPROVAL_2026-07-22.json',
);
const snapshotPath = path.join(
  repoRoot,
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/pre-write-approved-matrix/W3_RESPONSIVE_PROOF_MATRIX_APPROVED_INPUT.csv',
);
const reconciliationPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/W3_APPROVAL_HASH_RECONCILIATION_2026-07-22.json',
);

const expectedApprovalSha256 =
  '044FBF20B404AF84866FC62B1D08227177196638CD81CD363EB6001E136EB62F';
const expectedCurrentSha256 =
  'D9F295525E261D797823F06E872472C0CAB2C2F599F57AB8A74126F1B8D3468A';
const expectedSessionSha256 =
  '8FE8A7FE7D328805BC9D63AD6E050F1FA207CFABC9584165217E57F37CD097B7';
const stableHeaders = [
  'proof_id',
  'kind',
  'screen_id',
  'state',
  'proof_viewport',
  'runtime_reference_viewport',
  'source_v031_frame_id',
  'target_v032_section_id',
  'safe_area_policy',
  'expected_evidence',
];

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
}

function quote(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

function serializeQuotedCsv(headers, records) {
  const lines = [
    headers.map(quote).join(','),
    ...records.map((record) => headers.map((header) => quote(record[header])).join(',')),
  ];
  return Buffer.from(`${lines.join('\n')}\n`, 'utf8');
}

function relative(filePath) {
  return path.relative(repoRoot, filePath).replaceAll('\\', '/');
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function recoverApprovedRows(document) {
  assert(document.records.length === 77, `Expected 77 W3 rows; found ${document.records.length}`);
  assert(new Set(document.records.map((row) => row.proof_id)).size === 77, 'W3 proof_id values must be unique');

  let createdNow = 0;
  let existingBefore = 0;
  let unexpectedTransitions = 0;
  const recovered = document.records.map((row) => {
    const target = String(row.target_v032_frame_id ?? '');
    const status = String(row.status ?? '');
    const approval = String(row.approval ?? '');
    const next = { ...row, approval: 'PENDING_PRODUCT_OWNER' };

    if (target.startsWith('462:') && status === 'EXECUTED_PASS') {
      next.target_v032_frame_id = '';
      next.status = 'PROPOSED_MISSING';
      createdNow += 1;
    } else if (target.startsWith('453:') && status === 'EXECUTED_EXISTING_PASS') {
      next.status = 'EXISTING_CANDIDATE';
      existingBefore += 1;
    } else {
      unexpectedTransitions += 1;
    }

    assert(
      approval === 'APPROVED_FOR_W3_EXECUTION',
      `Unexpected current approval for ${row.proof_id}: ${approval}`,
    );
    return next;
  });

  assert(createdNow === 62, `Expected 62 newly created targets; found ${createdNow}`);
  assert(existingBefore === 15, `Expected 15 inherited targets; found ${existingBefore}`);
  assert(unexpectedTransitions === 0, `Found ${unexpectedTransitions} unexpected target/status transitions`);

  return { recovered, createdNow, existingBefore, unexpectedTransitions };
}

function main() {
  const checkMode = process.argv.includes('--check');
  const currentBytes = fs.readFileSync(currentMatrixPath);
  const currentSha256 = sha256(currentBytes);
  assert(currentSha256 === expectedCurrentSha256, `Unexpected current W3 matrix SHA-256: ${currentSha256}`);

  const approval = JSON.parse(fs.readFileSync(approvalPath, 'utf8'));
  assert(
    String(approval.matrixSha256).toUpperCase() === expectedApprovalSha256,
    `Approval record SHA-256 does not match the frozen contract: ${approval.matrixSha256}`,
  );

  const document = readCsv(currentMatrixPath);
  const { recovered, createdNow, existingBefore, unexpectedTransitions } =
    recoverApprovedRows(document);
  const snapshotBytes = serializeQuotedCsv(document.headers, recovered);
  const snapshotSha256 = sha256(snapshotBytes);
  assert(
    snapshotSha256 === expectedApprovalSha256,
    `Recovered snapshot SHA-256 ${snapshotSha256} does not match approved SHA-256 ${expectedApprovalSha256}`,
  );

  const proof = {
    schema: 'pawmate.w3.approval-hash-reconciliation.v1',
    baselineId: 'UI-CC-2026-07-21-G4B',
    verdict: 'PASS',
    approvedMatrix: {
      approvalRecord: relative(approvalPath),
      snapshotPath: relative(snapshotPath),
      bytes: snapshotBytes.length,
      encoding: 'UTF-8_NO_BOM',
      lineEndings: 'LF',
      finalLineFeed: true,
      rows: recovered.length,
      sha256: snapshotSha256,
    },
    executedMatrix: {
      path: relative(currentMatrixPath),
      bytes: currentBytes.length,
      rows: document.records.length,
      sha256: currentSha256,
    },
    deterministicReverseProjection: {
      createdTargetRows: createdNow,
      inheritedTargetRows: existingBefore,
      approvalTransitions: recovered.length,
      stableHeaders,
      stableCellDifferences: 0,
      unexpectedTargetStatusTransitions: unexpectedTransitions,
    },
    independentRecoveryProvenance: {
      kind: 'CODEX_SESSION_PATCH_APPLY_END',
      sessionPath:
        'C:/Users/duongnx/.codex/sessions/2026/07/22/rollout-2026-07-22T14-28-46-019f88ba-0a59-7091-8c8e-51587058bef4.jsonl',
      sessionLine: 15795,
      sessionSha256: expectedSessionSha256,
      independentByteComparison: 'IDENTICAL',
    },
    claimBoundary:
      'This artifact restores the exact approved pre-write bytes and proves the allowlisted deterministic transition to the executed matrix; it does not replace Figma post-write or protected-history evidence.',
  };

  if (checkMode) {
    assert(fs.existsSync(snapshotPath), `Missing approved matrix snapshot: ${snapshotPath}`);
    const storedSnapshot = fs.readFileSync(snapshotPath);
    assert(
      Buffer.compare(storedSnapshot, snapshotBytes) === 0,
      'Stored approved matrix snapshot differs from deterministic recovery',
    );
    assert(fs.existsSync(reconciliationPath), `Missing W3 reconciliation: ${reconciliationPath}`);
    const storedProof = JSON.parse(fs.readFileSync(reconciliationPath, 'utf8'));
    assert(storedProof.verdict === 'PASS', 'Stored W3 reconciliation verdict is not PASS');
    assert(
      storedProof.approvedMatrix?.sha256 === expectedApprovalSha256 &&
        storedProof.executedMatrix?.sha256 === expectedCurrentSha256,
      'Stored W3 reconciliation hash pair differs from the frozen contract',
    );
  } else {
    fs.mkdirSync(path.dirname(snapshotPath), { recursive: true });
    fs.writeFileSync(snapshotPath, snapshotBytes);
    fs.writeFileSync(reconciliationPath, `${JSON.stringify(proof, null, 2)}\n`, 'utf8');
  }

  console.log(
    JSON.stringify(
      {
        status: 'PASS',
        mode: checkMode ? 'check' : 'write',
        approvedSnapshot: relative(snapshotPath),
        approvedSha256: snapshotSha256,
        executedSha256: currentSha256,
        rows: recovered.length,
        createdTargetRows: createdNow,
        inheritedTargetRows: existingBefore,
        unexpectedTransitions,
      },
      null,
      2,
    ),
  );
}

main();

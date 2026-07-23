import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { clean, readCsv } from './csv_utils.mjs';
import {
  executionOverlayHeaders,
  executionOverlayPath,
} from './generate_traceability.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const verifiedAt = '2026-07-22T17:50:00+07:00';
const reviewer =
  'Codex deterministic evidence reconciliation; Product Owner G4B sign-off pending';

const files = {
  inventory: 'docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv',
  w3Matrix: 'docs/qa/ui-v031/W3_RESPONSIVE_PROOF_MATRIX_PROPOSAL.csv',
  w3Audit: 'docs/qa/ui-v031/W3_POST_WRITE_AUDIT_2026-07-22.json',
  w5Routes: 'docs/qa/ui-v031/W5_ROUTE_TEST_TRACEABILITY.csv',
  w6Goldens: 'docs/qa/ui-v031/W6_RUNTIME_GOLDEN_MATRIX.csv',
  w8RuntimeGoldenHashes: 'docs/qa/ui-v031/W8_RUNTIME_GOLDEN_HASHES.json',
  ctas: 'docs/qa/ui-v031/cta_matrix.csv',
  ctaProofIndex:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/cta-row-proof-20260723/cta-row-proof-index.json',
  talkBackProofIndex:
    'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/talkback-journeys-20260723/talkback-journey-index.json',
};

const evidence = {
  w3Section: {
    path: 'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/post-write-v032-section.png',
    sha256: '7C27ACB71E3FE54D02D56992701B02FD15EFD37EF9412786CE758060CB99D050',
  },
  w6Visual: {
    path: 'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/cta-row-proof-20260723/runtime-goldens-71-pass.raw.txt',
    sha256: 'EC6E7E073BC62B22C34AD873A5CACC993CFC2AE3B8BDE7670297CB3DDA0DA274',
  },
  w5Routes: {
    path: 'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W5/trace-row-reconciliation-20260722/route-trace-9-files-108-pass.raw.txt',
    sha256: '381B7FD216DFC9A439B3772DB66C3095A38B96726F807B8473597D2FFB790579',
  },
  reminderCta: {
    path: 'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W6/B/root-verification/codex-rtk-safe-20260721-182731-d5444ca8.raw.txt',
    sha256: '981C814AC4D525034918954B8F32068D25923CC657AF529A0D8FCAF4EB271F92',
  },
  rescueCta: {
    path: 'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W6/trace-row-reconciliation-20260722/rescue-cta-and-golden-6-pass.raw.txt',
    sha256: 'CF913C529B7B64B01DDB55FCAD8CBD35A196119271B98E9E4F2FBEED930CAFB1',
  },
};

function absolute(relativePath) {
  return path.join(repoRoot, ...relativePath.split('/'));
}

function sha256File(relativePath) {
  return crypto
    .createHash('sha256')
    .update(fs.readFileSync(absolute(relativePath)))
    .digest('hex')
    .toUpperCase();
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertEvidence(reference) {
  assert(fs.existsSync(absolute(reference.path)), `Missing evidence: ${reference.path}`);
  const actual = sha256File(reference.path);
  assert(
    actual === reference.sha256,
    `Evidence hash mismatch for ${reference.path}: expected ${reference.sha256}, got ${actual}`,
  );
}

function assertPassingTestLog(reference, testFiles) {
  const log = fs.readFileSync(absolute(reference.path), 'utf8');
  assert(log.includes('All tests passed!'), `Evidence is not a passing Flutter test log: ${reference.path}`);
  for (const testFile of testFiles) {
    const basename = path.basename(testFile);
    assert(
      log.includes(basename),
      `Passing evidence ${reference.path} does not name required test ${basename}`,
    );
  }
}

function walkFiles(directory) {
  const results = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) results.push(...walkFiles(child));
    else results.push(child);
  }
  return results;
}

function csvEscape(value) {
  const text = String(value ?? '');
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function serialize(rows) {
  return `${[
    executionOverlayHeaders.join(','),
    ...rows.map((row) =>
      executionOverlayHeaders.map((header) => csvEscape(row[header])).join(','),
    ),
  ].join('\n')}\n`;
}

function makeOverlayRow(overrides) {
  return Object.fromEntries(
    executionOverlayHeaders.map((header) => [
      header,
      Object.hasOwn(overrides, header) ? overrides[header] : 'N/A',
    ]),
  );
}

export function buildTraceExecutionOverlay() {
  for (const reference of Object.values(evidence)) assertEvidence(reference);

  const inventory = readCsv(absolute(files.inventory));
  const w3Matrix = readCsv(absolute(files.w3Matrix));
  const w5Routes = readCsv(absolute(files.w5Routes));
  const w6Goldens = readCsv(absolute(files.w6Goldens));
  const ctas = readCsv(absolute(files.ctas));
  const w3Audit = JSON.parse(fs.readFileSync(absolute(files.w3Audit), 'utf8'));
  const runtimeGoldenManifest = JSON.parse(
    fs.readFileSync(absolute(files.w8RuntimeGoldenHashes), 'utf8'),
  );

  const w3MatrixSha256 = sha256File(files.w3Matrix);
  const w3AuditSha256 = sha256File(files.w3Audit);
  assert(
    clean(w3Audit?.evidence?.matrixSha256) === w3MatrixSha256,
    'W3 audit does not bind the current post-write matrix hash',
  );
  assert(clean(w3Audit?.result) === 'W3_POST_WRITE_PASS', 'W3 audit result is not PASS');
  assert(w3Audit?.matrix?.rows === 77, 'W3 audit does not bind the 77-row denominator');
  assert(
    w3Audit?.liveAudit?.unsupportedTextFamilies === 0 &&
      w3Audit?.liveAudit?.geometryViolations === 0,
    'W3 audit contains unsupported fonts or geometry violations',
  );
  assert(
    (w3Audit?.protectedAfter ?? []).every(
      (entry) => entry.childIdsUnchangedAgainstSnapshot === true,
    ),
    'W3 audit does not prove unchanged protected historical fingerprints',
  );

  const canonicalByScreen = new Map(
    w3Matrix.records
      .filter((row) => clean(row.kind) === 'canonical_screen')
      .map((row) => [clean(row.screen_id), row]),
  );
  const goldenByScreen = new Map(
    w6Goldens.records
      .filter(
        (row) =>
          clean(row.viewport) === '390x844' && clean(row.status) === 'PASS',
      )
      .map((row) => [clean(row.screen_id), row]),
  );
  const frozenGoldenByPath = new Map(
    (runtimeGoldenManifest.artifacts ?? []).map((artifact) => [
      clean(artifact.path),
      artifact,
    ]),
  );
  const inventoryByScreen = new Map(
    inventory.records.map((row) => [clean(row.screen_id), row]),
  );

  const rows = [];
  for (const screen of inventory.records) {
    const screenId = clean(screen.screen_id);
    const canonical = canonicalByScreen.get(screenId);
    assert(canonical, `Missing W3 canonical proof for ${screenId}`);
    assert(
      ['EXECUTED_PASS', 'EXECUTED_EXISTING_PASS'].includes(clean(canonical.status)) &&
        clean(canonical.approval) === 'APPROVED_FOR_W3_EXECUTION',
      `W3 canonical row ${screenId} is not executed under the approved contract`,
    );
    assert(
      /^\d+:\d+$/.test(clean(canonical.target_v032_frame_id)),
      `Missing W3 target node for ${screenId}`,
    );

    const runtime = clean(screen.phase) === 'P1' || screenId === 'P2-01';
    const golden = runtime ? goldenByScreen.get(screenId) : null;
    if (runtime) assert(golden, `Missing 390x844 runtime golden for ${screenId}`);
    const frozenGolden = runtime
      ? frozenGoldenByPath.get(clean(golden.golden_path))
      : null;
    if (runtime) {
      assert(frozenGolden, `Missing frozen runtime golden hash for ${screenId}`);
      assert(clean(frozenGolden.status) === 'PASS', `Frozen runtime golden ${screenId} is not PASS`);
      const actualGoldenSha256 = sha256File(clean(golden.golden_path));
      assert(
        actualGoldenSha256 === clean(frozenGolden.sha256),
        `Runtime golden hash mismatch for ${screenId}: expected ${clean(frozenGolden.sha256)}, got ${actualGoldenSha256}`,
      );
      assertPassingTestLog(evidence.w6Visual, [clean(golden.test_file)]);
    }
    const evidenceReference = runtime ? evidence.w6Visual : evidence.w3Section;
    rows.push(
      makeOverlayRow({
        trace_id: `UI031-TRACE-SCREEN-${screenId}`,
        status: 'PASS',
        proof_kind: runtime
          ? 'SCREEN_RUNTIME_GOLDEN_AND_W3'
          : 'SCREEN_W3_DESIGN',
        test_id: runtime
          ? `${clean(golden.test_file)}#${clean(golden.test_name)}`
          : 'N/A',
        golden_id: runtime ? clean(golden.golden_path) : 'N/A',
        golden_sha256: runtime ? clean(frozenGolden.sha256) : 'N/A',
        design_node_id: clean(canonical.target_v032_frame_id),
        device_evidence_id: 'N/A',
        evidence_path: evidenceReference.path,
        evidence_sha256: evidenceReference.sha256,
        verified_at: verifiedAt,
        reviewer,
        notes_append: [
          `proof_id=${clean(canonical.proof_id)}`,
          `w3_matrix_sha256=${w3MatrixSha256}`,
          `w3_audit_sha256=${w3AuditSha256}`,
          runtime ? `golden_manifest=${files.w8RuntimeGoldenHashes}` : null,
        ]
          .filter(Boolean)
          .join(';'),
      }),
    );
  }

  const testFilesByBasename = new Map();
  for (const testFile of walkFiles(path.join(repoRoot, 'mobile/test')).filter(
    (file) => file.endsWith('_test.dart'),
  )) {
    const basename = path.basename(testFile);
    const repoRelative = path.relative(repoRoot, testFile).replaceAll('\\', '/');
    if (!testFilesByBasename.has(basename)) testFilesByBasename.set(basename, []);
    testFilesByBasename.get(basename).push(repoRelative);
  }

  for (const route of w5Routes.records) {
    const routeId = clean(route.matrix_id);
    assert(clean(route.status) === 'PASS', `W5 route ${routeId} is not PASS`);
    const basenames = [
      ...new Set(clean(route.test_or_evidence).match(/[A-Za-z0-9_]+_test\.dart/g) ?? []),
    ];
    const resolvedTests = basenames.map((basename) => {
      const matches = testFilesByBasename.get(basename) ?? [];
      assert(matches.length === 1, `Expected one test path for ${basename}; got ${matches.length}`);
      return matches[0];
    });
    assert(resolvedTests.length > 0, `W5 route ${routeId} has no exact test file`);
    assertPassingTestLog(evidence.w5Routes, resolvedTests);
    rows.push(
      makeOverlayRow({
        trace_id: `UI031-TRACE-ROUTE-${routeId}`,
        status: 'PASS',
        proof_kind: 'ROUTE_FOCUSED_TEST',
        test_id: resolvedTests.join(';'),
        golden_id: 'N/A',
        golden_sha256: 'N/A',
        design_node_id: 'INHERIT',
        device_evidence_id: 'N/A',
        evidence_path: evidence.w5Routes.path,
        evidence_sha256: evidence.w5Routes.sha256,
        verified_at: verifiedAt,
        reviewer,
        notes_append: `proof_id=${files.w5Routes}#${routeId};verified_contract=${clean(route.verified_contract)}`,
      }),
    );
  }

  const ctaById = new Map(ctas.records.map((row) => [clean(row.cta_id), row]));
  const ctaProofIndex = JSON.parse(
    fs.readFileSync(absolute(files.ctaProofIndex), 'utf8'),
  );
  assert(
    ctaProofIndex.schema === 'pawmate.ui-v031.cta-row-proof-index.v1',
    'CTA row proof index has an unexpected schema',
  );
  assert(ctaProofIndex.row_count === 82, 'CTA row proof index must contain 82 rows');
  const ctaProofs = [
    {
      ctaId: 'CTA-P1-07-DISMISS-REMINDER',
      proofKind: 'CTA_FOCUSED_TEST',
      testId:
        'mobile/test/features/pets/pet_navigation_test.dart#Pet home defer CTA snoozes a real reminder by one hour',
      goldenId: 'N/A',
      evidence: evidence.reminderCta,
      requiredTestFiles: ['mobile/test/features/pets/pet_navigation_test.dart'],
    },
    {
      ctaId: 'CTA-P2-01-POST-ALERT',
      proofKind: 'CTA_FAIL_CLOSED_TEST_AND_GOLDEN',
      testId:
        'mobile/test/features/rescue/rescue_home_screen_test.dart#rescue home fails closed without fabricated cases',
      goldenId:
        'mobile/test/visual/goldens/ui-v031-rescue/rescue-staged-390x844.png',
      evidence: evidence.rescueCta,
      requiredTestFiles: [
        'mobile/test/features/rescue/rescue_home_screen_test.dart',
        'mobile/test/visual/ui_v031_rescue_staged_golden_test.dart',
      ],
    },
    ...ctaProofIndex.rows.map((entry) => ({
      ctaId: clean(entry.cta_id),
      proofKind: 'CTA_ROW_EXECUTION_MANIFEST',
      testId: clean(entry.focused_test_id),
      goldenId: 'N/A',
      evidence: {
        path: clean(entry.manifest_path),
        sha256: clean(entry.manifest_sha256).toUpperCase(),
      },
      requiredTestFiles: [],
    })),
  ];

  for (const proof of ctaProofs) {
    const cta = ctaById.get(proof.ctaId);
    assert(cta, `Missing CTA matrix row ${proof.ctaId}`);
    assert(clean(cta.test_status) === 'PASS', `CTA ${proof.ctaId} is not PASS`);
    const screen = inventoryByScreen.get(clean(cta.screen_id));
    assert(screen, `CTA ${proof.ctaId} has no inventory screen`);
    if (proof.proofKind === 'CTA_ROW_EXECUTION_MANIFEST') {
      assertEvidence(proof.evidence);
      const manifest = JSON.parse(
        fs.readFileSync(absolute(proof.evidence.path), 'utf8'),
      );
      assert(
        manifest.schema === 'pawmate.ui-v031.cta-row-proof.v1',
        `CTA ${proof.ctaId} has an unexpected row manifest schema`,
      );
      assert(
        clean(manifest.cta_id) === proof.ctaId,
        `CTA ${proof.ctaId} row manifest is bound to ${clean(manifest.cta_id)}`,
      );
      assert(
        clean(manifest.focused_test_id) === proof.testId,
        `CTA ${proof.ctaId} focused test mismatch`,
      );
    } else {
      assertPassingTestLog(proof.evidence, proof.requiredTestFiles);
    }
    const goldenSha256 = proof.goldenId === 'N/A' ? 'N/A' : sha256File(proof.goldenId);
    rows.push(
      makeOverlayRow({
        trace_id: `UI031-TRACE-${proof.ctaId}`,
        status: 'PASS',
        proof_kind: proof.proofKind,
        test_id: proof.testId,
        golden_id: proof.goldenId,
        golden_sha256: goldenSha256,
        design_node_id: clean(screen.figma_source_node_id),
        device_evidence_id: 'N/A',
        evidence_path: proof.evidence.path,
        evidence_sha256: proof.evidence.sha256,
        verified_at: verifiedAt,
        reviewer,
        notes_append: `proof_id=${files.ctas}#${proof.ctaId};cta_test_status=PASS`,
      }),
    );
  }

  const talkBackProofIndex = JSON.parse(
    fs.readFileSync(absolute(files.talkBackProofIndex), 'utf8'),
  );
  assert(
    talkBackProofIndex.schema === 'pawmate.ui-v031.talkback-journey-index.v1',
    'TalkBack journey proof index has an unexpected schema',
  );
  assert(
    talkBackProofIndex.row_count === 7 && talkBackProofIndex.rows.length === 7,
    'TalkBack journey proof index must contain seven rows',
  );
  for (const entry of talkBackProofIndex.rows) {
    const journeyId = clean(entry.journey_id);
    const screen = inventoryByScreen.get(clean(entry.screen_id));
    const manifestReference = {
      path: clean(entry.manifest_path),
      sha256: clean(entry.manifest_sha256).toUpperCase(),
    };
    assert(screen, `${journeyId} has no inventory screen`);
    assertEvidence(manifestReference);
    const manifest = JSON.parse(
      fs.readFileSync(absolute(manifestReference.path), 'utf8'),
    );
    assert(
      manifest.schema === 'pawmate.ui-v031.talkback-journey.v1',
      `${journeyId} has an unexpected TalkBack manifest schema`,
    );
    assert(
      clean(manifest.journey_id) === journeyId &&
        clean(manifest.evidence_id) === clean(entry.evidence_id),
      `${journeyId} manifest identity mismatch`,
    );
    rows.push(
      makeOverlayRow({
        trace_id: `UI031-TRACE-${journeyId}`,
        status: 'PASS',
        proof_kind: 'ANDROID_TALKBACK_JOURNEY_MANIFEST',
        test_id: 'Android TalkBack live traversal at text scale 2.0',
        golden_id: 'N/A',
        golden_sha256: 'N/A',
        design_node_id: clean(screen.figma_source_node_id),
        device_evidence_id: clean(entry.evidence_id),
        evidence_path: manifestReference.path,
        evidence_sha256: manifestReference.sha256,
        verified_at: clean(talkBackProofIndex.generated_at),
        reviewer,
        notes_append: `proof_id=${files.talkBackProofIndex}#${journeyId};talkback_version=${clean(manifest.talkback_version)};apk_sha256=${clean(manifest.apk_sha256)}`,
      }),
    );
  }

  assert(rows.length === 191, `Expected 191 PASS overlay rows; got ${rows.length}`);
  const traceIds = rows.map((row) => row.trace_id);
  assert(new Set(traceIds).size === rows.length, 'Trace execution overlay has duplicate IDs');
  return rows;
}

function main() {
  const checkOnly = process.argv.slice(2).includes('--check');
  const rows = buildTraceExecutionOverlay();
  const generated = serialize(rows);
  if (checkOnly) {
    const current = fs.readFileSync(executionOverlayPath, 'utf8');
    if (current !== generated) {
      console.error('Trace execution overlay is stale');
      process.exitCode = 1;
      return;
    }
  } else {
    fs.writeFileSync(executionOverlayPath, generated, 'utf8');
  }
  console.log(
    JSON.stringify({
      status: 'PASS',
      mode: checkOnly ? 'check' : 'write',
      file: executionOverlayPath,
      passRows: rows.length,
      remainingPlannedRows: 0,
    }),
  );
}

if (path.resolve(process.argv[1] ?? '') === scriptPath) main();

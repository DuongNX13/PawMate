import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseCsv, readCsv } from './csv_utils.mjs';
import { normalizeLcovSourcePath } from './lcov_path_utils.mjs';
import {
  readContractMatrices,
  validateContractMatrices,
} from './validate_matrices.mjs';
import { validateInventoryDocument } from './validate_inventory.mjs';
import {
  traceabilityHeaders,
  traceabilityDenominators,
  validateTraceabilityDocument,
} from './validate_traceability.mjs';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDirectory, '../../..');
const inventory = readCsv(
  path.join(
    repoRoot,
    'docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv',
  ),
);
const matrices = readContractMatrices();
const traceability = readCsv(
  path.join(repoRoot, 'docs/qa/ui-v031/ui_v031_traceability.csv'),
);

function traceDocument(overrides = {}) {
  const record = Object.fromEntries(traceabilityHeaders.map((header) => [header, 'N/A']));
  Object.assign(record, {
    trace_id: 'UI031-TRACE-P1-01-001',
    requirement_id: 'UI031-NAV-ONBOARDING',
    source_requirement_id: 'P1-IM-001-NAV',
    screen_id: 'P1-01',
    route: '/onboarding',
    state_id: 'N/A',
    platform: 'BOTH',
    viewport: '390x844',
    text_scale: '1.0',
    test_id: 'mobile/test/features/onboarding/onboarding_screen_test.dart',
    design_node_id: '1:1',
    expected_result: 'Onboarding opens and preserves the draft',
    evidence_path:
      'output-evidence/ui-v031/test-baseline/W8/both/onboarding-proof.txt',
    evidence_sha256: 'A'.repeat(64),
    proof_kind: 'SCREEN_W3_DESIGN',
    status: 'PASS',
    cta_enabled: 'FALSE',
    owner: 'onboarding',
    verified_at: '2026-07-22T17:50:00+07:00',
    reviewer: 'validator fixture',
    notes: '',
    ...overrides,
  });
  return { headers: traceabilityHeaders, records: [record] };
}

test('CSV parser preserves a quoted comma and escaped quote', () => {
  const parsed = parseCsv('id,note\n1,"hello, ""PawMate"""\n', 'fixture');
  assert.equal(parsed.records[0].note, 'hello, "PawMate"');
});

test('LCOV source paths normalize relative and absolute Windows forms', () => {
  assert.equal(
    normalizeLcovSourcePath('lib/core/widgets/pawmate_button.dart', {
      repoRoot,
    }),
    'mobile/lib/core/widgets/pawmate_button.dart',
  );
  assert.equal(
    normalizeLcovSourcePath('mobile/lib/core/widgets/pawmate_button.dart', {
      repoRoot,
    }),
    'mobile/lib/core/widgets/pawmate_button.dart',
  );
  assert.equal(
    normalizeLcovSourcePath(
      `${repoRoot.replaceAll('/', '\\')}\\mobile\\lib\\core\\widgets\\pawmate_button.dart`,
      { repoRoot },
    ),
    'mobile/lib/core/widgets/pawmate_button.dart',
  );
});

test('authoritative live inventory passes the 56-row contract', () => {
  assert.deepEqual(
    validateInventoryDocument(inventory, { expectedCount: 56 }),
    [],
  );
});

test('route CTA and state matrices pass their W1 contracts', () => {
  assert.deepEqual(validateContractMatrices(matrices, inventory), []);
  assert.equal(matrices.routes.records.length, 44);
  assert.equal(matrices.ctas.records.length, 84);
  assert.equal(matrices.states.records.length, 24);
});

test('populated traceability applies only evidence-backed PASS transitions', () => {
  assert.deepEqual(
    validateTraceabilityDocument(traceability, inventory, {
      matrices,
      enforceDenominators: true,
      verifyEvidenceFiles: true,
      evidenceRoot: repoRoot,
    }),
    [],
  );
  assert.deepEqual(traceabilityDenominators(traceability), {
    totalRows: 191,
    screenRows: 56,
    routeRows: 44,
    ctaRows: 84,
    stateRows: 24,
    accessibilityJourneys: 7,
    statusCounts: { PASS: 191 },
  });
  assert.equal(traceability.records.filter((record) => record.status === 'PASS').length, 191);
});

test('P1-01 trace records the approved no-rails change control', () => {
  const row = traceability.records.find(
    (record) => record.trace_id === 'UI031-TRACE-SCREEN-P1-01',
  );
  assert.ok(row);
  assert.match(row.expected_result, /does not display progress rails/);
  assert.match(
    row.notes,
    /change_control=UI031-CHANGE-W8-P1-01-NO-RAILS-02/,
  );
  assert.equal(row.status, 'PASS');
});

test('resolved CTA matrix contains no enabled no-op handlers', () => {
  const noOps = matrices.ctas.records.filter(
    (record) => record.current_handler === 'callback:NO_OP',
  );
  assert.deepEqual(noOps, []);
  assert.equal(
    matrices.ctas.records
      .filter((record) =>
        ['CTA-P1-07-DISMISS-REMINDER', 'CTA-P2-01-POST-ALERT'].includes(
          record.cta_id,
        ),
      )
      .every((record) => record.test_status === 'PASS'),
    true,
  );
});

test('header-only traceability fails by default and is allowed only explicitly', () => {
  const empty = { headers: traceabilityHeaders, records: [] };
  assert.equal(
    validateTraceabilityDocument(empty, inventory).some((error) =>
      error.includes('header-only'),
    ),
    true,
  );
  assert.deepEqual(
    validateTraceabilityDocument(empty, inventory, { allowEmpty: true }),
    [],
  );
});

test('valid PASS trace row satisfies inventory and evidence rules', () => {
  assert.deepEqual(validateTraceabilityDocument(traceDocument(), inventory), []);
});

test('unknown screen ID fails referential integrity', () => {
  const errors = validateTraceabilityDocument(
    traceDocument({ screen_id: 'P1-99' }),
    inventory,
  );
  assert.equal(errors.some((error) => error.includes('absent from inventory')), true);
});

test('enabled CTA requires an actionable handler reference', () => {
  const errors = validateTraceabilityDocument(
    traceDocument({
      cta_enabled: 'TRUE',
      cta_id: 'CTA-P1-01-CONTINUE',
      handler_ref: 'N/A',
    }),
    inventory,
  );
  assert.equal(errors.some((error) => error.includes('requires handler_ref')), true);
});

test('PASS rejects a machine-local absolute evidence path', () => {
  const errors = validateTraceabilityDocument(
    traceDocument({ evidence_path: 'D:\\private\\proof.txt' }),
    inventory,
  );
  assert.equal(
    errors.some((error) => error.includes('repo-relative evidence_path')),
    true,
  );
});

test('PASS rejects traversal even when file verification is disabled', () => {
  const errors = validateTraceabilityDocument(
    traceDocument({
      evidence_path: 'output-evidence/ui-v031/../../../../Windows/win.ini',
    }),
    inventory,
  );
  assert.equal(errors.some((error) => error.includes('repo-relative evidence_path')), true);
});

test('PASS rejects malformed verification timestamps', () => {
  const errors = validateTraceabilityDocument(
    traceDocument({ verified_at: 'not-a-date' }),
    inventory,
  );
  assert.equal(errors.some((error) => error.includes('ISO verified_at')), true);
});

test('runtime screen PASS verifies the actual golden hash', () => {
  const liveRow = traceability.records.find(
    (record) => record.trace_id === 'UI031-TRACE-SCREEN-P1-01',
  );
  const errors = validateTraceabilityDocument(
    { headers: traceabilityHeaders, records: [{ ...liveRow, golden_sha256: 'A'.repeat(64) }] },
    inventory,
    { verifyEvidenceFiles: true, evidenceRoot: repoRoot },
  );
  assert.equal(errors.some((error) => error.includes('golden_sha256 mismatch')), true);
});

test('route PASS rejects a test that is absent from its passing log', () => {
  const liveRow = traceability.records.find(
    (record) => record.proof_kind === 'ROUTE_FOCUSED_TEST',
  );
  const errors = validateTraceabilityDocument(
    {
      headers: traceabilityHeaders,
      records: [{ ...liveRow, test_id: 'mobile/test/missing/not_in_log_test.dart' }],
    },
    inventory,
    { verifyEvidenceFiles: true, evidenceRoot: repoRoot },
  );
  assert.equal(errors.some((error) => error.includes('does not name required test')), true);
});

test('CTA row PASS rejects a trace-to-manifest binding mismatch', () => {
  const liveRow = traceability.records.find(
    (record) => record.proof_kind === 'CTA_ROW_EXECUTION_MANIFEST',
  );
  assert.ok(liveRow, 'expected at least one live CTA row manifest');

  const errors = validateTraceabilityDocument(
    {
      headers: traceabilityHeaders,
      records: [
        {
          ...liveRow,
          test_id: 'mobile/test/missing/forged_cta_test.dart::forged test',
        },
      ],
    },
    inventory,
    { verifyEvidenceFiles: true, evidenceRoot: repoRoot },
  );

  assert.equal(
    errors.some(
      (error) =>
        error.includes('focused_test_id must equal') ||
        error.includes('focused test binding must match'),
    ),
    true,
  );
});

test('accessibility PASS rejects a non-TalkBack proof', () => {
  const liveRoute = traceability.records.find(
    (record) => record.proof_kind === 'ROUTE_FOCUSED_TEST',
  );
  const errors = validateTraceabilityDocument(
    traceDocument({
      platform: 'ANDROID',
      text_scale: '2.0',
      proof_kind: 'ROUTE_FOCUSED_TEST',
      test_id: liveRoute.test_id,
      evidence_path: liveRoute.evidence_path,
      evidence_sha256: liveRoute.evidence_sha256,
      accessibility_journey_id: 'A11Y-AUTH',
      device_evidence_id: 'fake-A11Y-AUTH',
    }),
    inventory,
    { verifyEvidenceFiles: true, evidenceRoot: repoRoot },
  );
  assert.equal(
    errors.some((error) => error.includes('ANDROID_TALKBACK_JOURNEY_MANIFEST')),
    true,
  );
});

test('TalkBack PASS rejects duplicate focus labels and bounds', () => {
  const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'pawmate-talkback-'));
  const evidenceDirectory = path.join(
    fixtureRoot,
    'output-evidence/ui-v031/test/W8/talkback',
  );
  fs.mkdirSync(evidenceDirectory, { recursive: true });
  const hash = (value) =>
    crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
  const focusLabel = 'Cứu hộ thú cưng\nTriển khai theo từng giai đoạn';
  const xml =
    '<hierarchy><node content-desc="Cứu hộ thú cưng&#10;Triển khai theo từng giai đoạn" bounds="[10,20][110,120]" /></hierarchy>';
  const screenshotOne = Buffer.from('focus-one');
  const screenshotTwo = Buffer.from('focus-two');
  fs.writeFileSync(path.join(evidenceDirectory, 'step-1.png'), screenshotOne);
  fs.writeFileSync(path.join(evidenceDirectory, 'step-2.png'), screenshotTwo);
  fs.writeFileSync(path.join(evidenceDirectory, 'step-1.xml'), xml, 'utf8');
  fs.writeFileSync(path.join(evidenceDirectory, 'step-2.xml'), xml, 'utf8');

  const relativeDirectory = 'output-evidence/ui-v031/test/W8/talkback';
  const manifest = {
    schema: 'pawmate.ui-v031.talkback-journey.v1',
    journey_id: 'A11Y-HOME',
    evidence_id: 'android-api36-A11Y-HOME',
    platform: 'ANDROID',
    android_api_level: 36,
    device_serial: 'emulator-fixture',
    talkback_enabled: true,
    talkback_version: 'fixture',
    text_scale: '2.0',
    package_name: 'com.pawmate.pawmate_mobile',
    apk_sha256: 'B'.repeat(64),
    captured_at: '2026-07-22T18:30:00+07:00',
    focus_steps: [1, 2].map((order) => ({
      order,
      focus_label: focusLabel,
      focus_bounds: '[10,20][110,120]',
      screenshot_path: `${relativeDirectory}/step-${order}.png`,
      screenshot_sha256: hash(order === 1 ? screenshotOne : screenshotTwo),
      ui_xml_path: `${relativeDirectory}/step-${order}.xml`,
      ui_xml_sha256: hash(Buffer.from(xml)),
    })),
  };
  const manifestBytes = `${JSON.stringify(manifest, null, 2)}\n`;
  fs.writeFileSync(path.join(evidenceDirectory, 'manifest.json'), manifestBytes, 'utf8');

  const errors = validateTraceabilityDocument(
    traceDocument({
      screen_id: 'P1-07',
      route: '/pets',
      platform: 'ANDROID',
      text_scale: '2.0',
      test_id: 'TalkBack live traversal',
      proof_kind: 'ANDROID_TALKBACK_JOURNEY_MANIFEST',
      accessibility_journey_id: 'A11Y-HOME',
      device_evidence_id: 'android-api36-A11Y-HOME',
      evidence_path: `${relativeDirectory}/manifest.json`,
      evidence_sha256: hash(Buffer.from(manifestBytes)),
    }),
    inventory,
    { verifyEvidenceFiles: true, evidenceRoot: fixtureRoot },
  );
  assert.equal(
    errors.some((error) => error.includes('distinct labels/bounds')),
    true,
  );
  assert.equal(
    errors.some((error) => error.includes('label/bounds are not bound')),
    false,
  );
  fs.rmSync(fixtureRoot, { recursive: true, force: true });
});

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  clean,
  meaningful,
  printResult,
  readCsv,
  requireHeaders,
} from './csv_utils.mjs';
import { generatedTraceabilityHeaders } from './generate_traceability.mjs';
import {
  defaultCtaMatrixPath,
  defaultRouteMatrixPath,
  defaultStateMatrixPath,
  readContractMatrices,
  validateContractMatrices,
} from './validate_matrices.mjs';
import { validateInventoryDocument } from './validate_inventory.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const defaultTraceabilityPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/ui_v031_traceability.csv',
);
const defaultInventoryPath = path.join(
  repoRoot,
  'docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv',
);

export const traceabilityHeaders = generatedTraceabilityHeaders;

const platforms = new Set([
  'ANDROID',
  'IOS',
  'BOTH',
  'PLATFORM_NEUTRAL',
  'DESIGN',
]);
const statuses = new Set([
  'PLANNED',
  'READY',
  'PASS',
  'FAIL',
  'BLOCKED',
  'NOT_APPLICABLE',
]);
const ctaStates = new Set(['TRUE', 'FALSE', 'N/A']);
const textScales = new Set(['1.0', '1.3', '2.0', 'N/A']);
const actionableHandler = /^(route|callback|command|external|overlay):/;
const passProofKinds = new Set([
  'SCREEN_RUNTIME_GOLDEN_AND_W3',
  'SCREEN_W3_DESIGN',
  'ROUTE_FOCUSED_TEST',
  'CTA_FOCUSED_TEST',
  'CTA_FAIL_CLOSED_TEST_AND_GOLDEN',
  'CTA_ROW_EXECUTION_MANIFEST',
  'ANDROID_TALKBACK_JOURNEY_MANIFEST',
]);

function parseArguments(args) {
  const options = {
    file: defaultTraceabilityPath,
    inventory: defaultInventoryPath,
    routes: defaultRouteMatrixPath,
    ctas: defaultCtaMatrixPath,
    states: defaultStateMatrixPath,
    allowEmpty: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--allow-empty') {
      options.allowEmpty = true;
    } else if (['--inventory', '--routes', '--ctas', '--states'].includes(argument)) {
      const next = args[index + 1];
      if (!next) throw new Error(`${argument} requires a file path`);
      options[argument.slice(2)] = next;
      index += 1;
    } else if (argument.startsWith('--')) {
      throw new Error(`Unknown option: ${argument}`);
    } else {
      options.file = argument;
    }
  }

  return options;
}

function portableEvidencePath(value) {
  const segments = value.split('/');
  return (
    value.startsWith('output-evidence/ui-v031/') &&
    !value.includes('\\') &&
    !value.startsWith('/') &&
    !/^[A-Za-z]:/.test(value) &&
    !segments.some((segment) => segment === '..' || segment === '.' || segment === '')
  );
}

function portableGoldenPath(value) {
  const segments = value.split('/');
  return (
    value.startsWith('mobile/test/visual/goldens/') &&
    value.toLowerCase().endsWith('.png') &&
    !value.includes('\\') &&
    !value.startsWith('/') &&
    !/^[A-Za-z]:/.test(value) &&
    !segments.some((segment) => segment === '..' || segment === '.' || segment === '')
  );
}

function validIsoTimestamp(value) {
  return (
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value) &&
    !Number.isNaN(Date.parse(value))
  );
}

function hashFile(filePath) {
  return crypto
    .createHash('sha256')
    .update(fs.readFileSync(filePath))
    .digest('hex')
    .toUpperCase();
}

function resolveInside(root, repoRelativePath) {
  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(resolvedRoot, ...repoRelativePath.split('/'));
  const inside =
    resolvedPath === resolvedRoot || resolvedPath.startsWith(`${resolvedRoot}${path.sep}`);
  return { resolvedRoot, resolvedPath, inside };
}

function validateTalkBackJourneyManifest({
  record,
  manifestPath,
  evidenceRoot,
  errors,
  prefix,
}) {
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    errors.push(`${prefix}: TalkBack evidence is not valid JSON: ${error.message}`);
    return;
  }

  const journeyId = clean(record.accessibility_journey_id);
  const deviceEvidenceId = clean(record.device_evidence_id);
  const requiredPairs = [
    ['schema', 'pawmate.ui-v031.talkback-journey.v1'],
    ['journey_id', journeyId],
    ['evidence_id', deviceEvidenceId],
    ['platform', 'ANDROID'],
    ['text_scale', '2.0'],
  ];
  for (const [field, expected] of requiredPairs) {
    if (String(manifest?.[field] ?? '') !== expected) {
      errors.push(`${prefix}: TalkBack manifest ${field} must equal ${expected}`);
    }
  }
  if (manifest?.talkback_enabled !== true) {
    errors.push(`${prefix}: TalkBack manifest must prove talkback_enabled=true`);
  }
  if (!/^\d+$/.test(String(manifest?.android_api_level ?? ''))) {
    errors.push(`${prefix}: TalkBack manifest requires android_api_level`);
  }
  for (const field of ['device_serial', 'talkback_version', 'package_name']) {
    if (!meaningful(manifest?.[field])) {
      errors.push(`${prefix}: TalkBack manifest requires ${field}`);
    }
  }
  if (!/^[A-F0-9]{64}$/.test(String(manifest?.apk_sha256 ?? '').toUpperCase())) {
    errors.push(`${prefix}: TalkBack manifest requires apk_sha256`);
  }
  if (!validIsoTimestamp(String(manifest?.captured_at ?? ''))) {
    errors.push(`${prefix}: TalkBack manifest requires an ISO captured_at timestamp`);
  }

  const steps = Array.isArray(manifest?.focus_steps) ? manifest.focus_steps : [];
  if (steps.length < 2) {
    errors.push(`${prefix}: TalkBack manifest requires at least two ordered focus_steps`);
  }
  const focusKeys = new Set();
  const screenshotHashes = new Set();
  steps.forEach((step, index) => {
    const focusLabel = clean(step?.focus_label);
    const focusBounds = clean(step?.focus_bounds);
    if (Number(step?.order) !== index + 1 || !meaningful(focusLabel)) {
      errors.push(`${prefix}: TalkBack focus step ${index + 1} has invalid order or focus_label`);
    }
    if (!/^\[\d+,\d+\]\[\d+,\d+\]$/.test(focusBounds)) {
      errors.push(`${prefix}: TalkBack focus step ${index + 1} requires valid focus_bounds`);
    }
    const focusKey = `${focusLabel}\u0000${focusBounds}`;
    if (focusKeys.has(focusKey)) {
      errors.push(`${prefix}: TalkBack focus steps must identify distinct labels/bounds`);
    }
    focusKeys.add(focusKey);

    const screenshotSha256 = clean(step?.screenshot_sha256).toUpperCase();
    if (screenshotHashes.has(screenshotSha256)) {
      errors.push(`${prefix}: TalkBack focus steps must use distinct screenshots`);
    }
    screenshotHashes.add(screenshotSha256);

    for (const [pathField, hashField] of [
      ['screenshot_path', 'screenshot_sha256'],
      ['ui_xml_path', 'ui_xml_sha256'],
    ]) {
      const artifactPath = clean(step?.[pathField]);
      const expectedSha256 = clean(step?.[hashField]).toUpperCase();
      if (!portableEvidencePath(artifactPath) || !/^[A-F0-9]{64}$/.test(expectedSha256)) {
        errors.push(`${prefix}: TalkBack focus step ${index + 1} has invalid ${pathField}/${hashField}`);
        continue;
      }
      const resolved = resolveInside(evidenceRoot, artifactPath);
      if (!resolved.inside || !fs.existsSync(resolved.resolvedPath)) {
        errors.push(`${prefix}: TalkBack focus artifact is missing: ${artifactPath}`);
      } else if (hashFile(resolved.resolvedPath) !== expectedSha256) {
        errors.push(`${prefix}: TalkBack focus artifact hash mismatch: ${artifactPath}`);
      }
    }

    const xmlPath = clean(step?.ui_xml_path);
    const resolvedXml = resolveInside(evidenceRoot, xmlPath);
    if (resolvedXml.inside && fs.existsSync(resolvedXml.resolvedPath)) {
      const xml = fs.readFileSync(resolvedXml.resolvedPath, 'utf8');
      const escapedLabel = focusLabel
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\r', '&#13;')
        .replaceAll('\n', '&#10;');
      const labelBound =
        xml.includes(`content-desc="${escapedLabel}"`) ||
        xml.includes(`text="${escapedLabel}"`);
      if (!labelBound || !xml.includes(`bounds="${focusBounds}"`)) {
        errors.push(
          `${prefix}: TalkBack focus step ${index + 1} label/bounds are not bound to its UI XML`,
        );
      }
    }
  });
}

function validatePassingFlutterLog({ record, evidencePath, errors, prefix }) {
  const proofKind = clean(record.proof_kind);
  if (
    !new Set([
      'SCREEN_RUNTIME_GOLDEN_AND_W3',
      'ROUTE_FOCUSED_TEST',
      'CTA_FOCUSED_TEST',
      'CTA_FAIL_CLOSED_TEST_AND_GOLDEN',
    ]).has(proofKind)
  ) {
    return;
  }
  const log = fs.readFileSync(evidencePath, 'utf8');
  if (!log.includes('All tests passed!')) {
    errors.push(`${prefix}: ${proofKind} evidence is not a passing Flutter test log`);
  }
  const testPaths = clean(record.test_id)
    .split(';')
    .map((entry) => entry.split('#')[0])
    .filter(meaningful);
  if (testPaths.length === 0) {
    errors.push(`${prefix}: ${proofKind} requires test_id`);
  }
  for (const testPath of testPaths) {
    const basename = path.posix.basename(testPath.replaceAll('\\', '/'));
    if (!log.includes(basename)) {
      errors.push(`${prefix}: passing evidence does not name required test ${basename}`);
    }
  }
}

function validateCtaRowExecutionManifest({
  record,
  ctaRecord,
  manifestPath,
  evidenceRoot,
  errors,
  prefix,
}) {
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    errors.push(`${prefix}: CTA row evidence is not valid JSON: ${error.message}`);
    return;
  }
  if (manifest?.schema !== 'pawmate.ui-v031.cta-row-proof.v1') {
    errors.push(`${prefix}: CTA row manifest has an unexpected schema`);
  }
  const expectedBindings = [
    ['cta_id', clean(record.cta_id)],
    ['screen_id', clean(record.screen_id)],
    ['target_enabled', clean(ctaRecord?.target_enabled)],
    ['target_handler', clean(record.handler_ref)],
    ['focused_test_id', clean(record.test_id)],
  ];
  for (const [field, expected] of expectedBindings) {
    if (clean(manifest?.[field]) !== expected) {
      errors.push(`${prefix}: CTA row manifest ${field} must equal ${expected}`);
    }
  }
  if (clean(ctaRecord?.cta_id) !== clean(record.cta_id)) {
    errors.push(`${prefix}: CTA row manifest cannot resolve its matrix row`);
  }
  const expectedTraceEnabled =
    clean(ctaRecord?.target_enabled) === 'FALSE' ? 'FALSE' : 'TRUE';
  if (clean(record.cta_enabled) !== expectedTraceEnabled) {
    errors.push(
      `${prefix}: CTA trace enabled state must normalize ${clean(ctaRecord?.target_enabled)} to ${expectedTraceEnabled}`,
    );
  }
  const source = manifest?.source ?? {};
  const sourcePath = clean(source.path);
  const sourceResolved = resolveInside(evidenceRoot, sourcePath);
  if (!sourcePath || !sourceResolved.inside || !fs.existsSync(sourceResolved.resolvedPath)) {
    errors.push(`${prefix}: CTA row manifest source path is missing or unsafe`);
  } else {
    if (!/^[A-F0-9]{64}$/.test(clean(source.file_sha256).toUpperCase())) {
      errors.push(`${prefix}: CTA row manifest source file hash is invalid`);
    } else if (hashFile(sourceResolved.resolvedPath) !== clean(source.file_sha256).toUpperCase()) {
      errors.push(`${prefix}: CTA row manifest source file hash mismatch`);
    }
    const sourceText = fs.readFileSync(sourceResolved.resolvedPath, 'utf8');
    if (!meaningful(source.anchor) || !sourceText.includes(clean(source.anchor))) {
      errors.push(`${prefix}: CTA row manifest source anchor is not present`);
    }
    const start = Number(source.excerpt_start_line);
    const end = Number(source.excerpt_end_line);
    const lines = sourceText.split(/\r?\n/);
    if (!Number.isInteger(start) || !Number.isInteger(end) || start < 1 || end < start) {
      errors.push(`${prefix}: CTA row manifest excerpt range is invalid`);
    } else {
      const excerpt = lines.slice(start - 1, end).join('\n');
      const excerptHash = crypto
        .createHash('sha256')
        .update(Buffer.from(excerpt, 'utf8'))
        .digest('hex')
        .toUpperCase();
      if (excerptHash !== clean(source.excerpt_sha256).toUpperCase()) {
        errors.push(`${prefix}: CTA row manifest excerpt hash mismatch`);
      }
    }
  }

  for (const [pathField, hashField] of [
    ['test_log_path', 'test_log_sha256'],
    ['coverage_path', 'coverage_sha256'],
  ]) {
    const artifactPath = clean(manifest?.[pathField]);
    const artifactHash = clean(manifest?.[hashField]).toUpperCase();
    const resolved = resolveInside(evidenceRoot, artifactPath);
    if (!portableEvidencePath(artifactPath) || !resolved.inside || !fs.existsSync(resolved.resolvedPath)) {
      errors.push(`${prefix}: CTA row manifest ${pathField} is missing or unsafe`);
      continue;
    }
    if (!/^[A-F0-9]{64}$/.test(artifactHash) || hashFile(resolved.resolvedPath) !== artifactHash) {
      errors.push(`${prefix}: CTA row manifest ${hashField} mismatch`);
      continue;
    }
    if (pathField === 'test_log_path') {
      const log = fs.readFileSync(resolved.resolvedPath, 'utf8');
      const [testPath, testName] = clean(manifest.focused_test_id).split('#');
      if (
        !log.includes('All tests passed!') ||
        !log.includes(path.posix.basename(testPath.replaceAll('\\', '/'))) ||
        !testName ||
        !log.includes(testName)
      ) {
        errors.push(`${prefix}: CTA row manifest is not bound to its exact passing test case`);
      }
    }
  }
  if (
    sourcePath.startsWith('mobile/') &&
    !(Number(manifest?.source_coverage?.hits) > 0)
  ) {
    errors.push(`${prefix}: runtime CTA row requires executed source-file coverage`);
  }
  if (!validIsoTimestamp(clean(manifest?.verified_at)) || !meaningful(manifest?.reviewer)) {
    errors.push(`${prefix}: CTA row manifest requires verified_at and reviewer`);
  }
}

function routeOrSurface(value) {
  const route = clean(value);
  return (
    route === 'N/A' ||
    route.startsWith('/') ||
    route.startsWith('proposed:/') ||
    route.startsWith('modal:') ||
    route.startsWith('action:') ||
    route.startsWith('native:') ||
    route.startsWith('external:') ||
    route.startsWith('registry:') ||
    route.startsWith('unavailable:') ||
    route.includes(' | ')
  );
}

function duplicateValues(records, field) {
  const seen = new Map();
  const duplicates = [];
  records.forEach((record, index) => {
    const value = clean(record[field]);
    if (!meaningful(value)) return;
    if (seen.has(value)) duplicates.push({ value, row: index + 2, first: seen.get(value) });
    else seen.set(value, index + 2);
  });
  return duplicates;
}

function notesContain(record, marker) {
  return clean(record.notes).split(';').includes(marker);
}

export function traceabilityDenominators(document) {
  const statusCounts = {};
  for (const record of document.records) {
    const status = clean(record.status);
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;
  }
  return {
    totalRows: document.records.length,
    screenRows: document.records.filter((record) => notesContain(record, 'screen-denominator')).length,
    routeRows: document.records.filter((record) => notesContain(record, 'route-denominator')).length,
    ctaRows: document.records.filter((record) => meaningful(record.cta_id)).length,
    stateRows: new Set(
      document.records
        .map((record) => clean(record.state_id))
        .filter((stateId) => /^ST-\d{2}$/.test(stateId)),
    ).size,
    accessibilityJourneys: new Set(
      document.records
        .map((record) => clean(record.accessibility_journey_id))
        .filter((journeyId) => meaningful(journeyId)),
    ).size,
    statusCounts,
  };
}

function validateDenominators(document, inventory, matrices, errors) {
  const screenRows = document.records.filter((record) =>
    notesContain(record, 'screen-denominator'),
  );
  const screenRowCount = new Map();
  for (const record of screenRows) {
    const screenId = clean(record.screen_id);
    screenRowCount.set(screenId, (screenRowCount.get(screenId) ?? 0) + 1);
  }
  for (const screen of inventory.records) {
    const screenId = clean(screen.screen_id);
    const count = screenRowCount.get(screenId) ?? 0;
    if (count !== 1) errors.push(`Screen denominator ${screenId} must have exactly one row; found ${count}`);
  }
  if (screenRows.length !== inventory.records.length) {
    errors.push(`Screen denominator must equal inventory count ${inventory.records.length}; found ${screenRows.length}`);
  }

  const routeRows = document.records.filter((record) =>
    notesContain(record, 'route-denominator'),
  );
  const routeRowCount = new Map();
  for (const record of routeRows) {
    const routeId = clean(record.route_id);
    routeRowCount.set(routeId, (routeRowCount.get(routeId) ?? 0) + 1);
  }
  for (const route of matrices.routes.records) {
    const routeId = clean(route.route_id);
    const count = routeRowCount.get(routeId) ?? 0;
    if (count !== 1) errors.push(`Route denominator ${routeId} must have exactly one row; found ${count}`);
  }

  const ctaTraceById = new Map();
  for (const record of document.records) {
    const ctaId = clean(record.cta_id);
    if (meaningful(ctaId)) {
      if (!ctaTraceById.has(ctaId)) ctaTraceById.set(ctaId, []);
      ctaTraceById.get(ctaId).push(record);
    }
  }
  for (const cta of matrices.ctas.records) {
    const ctaId = clean(cta.cta_id);
    const traces = ctaTraceById.get(ctaId) ?? [];
    if (traces.length !== 1) {
      errors.push(`CTA denominator ${ctaId} must have exactly one trace row; found ${traces.length}`);
      continue;
    }
    const trace = traces[0];
    const expectedEnabled = clean(cta.target_enabled) === 'FALSE' ? 'FALSE' : 'TRUE';
    if (clean(trace.cta_enabled) !== expectedEnabled) errors.push(`CTA ${ctaId}: trace enabled state disagrees with CTA matrix`);
    if (clean(trace.handler_ref) !== clean(cta.target_handler)) errors.push(`CTA ${ctaId}: trace handler disagrees with CTA matrix`);
    if (clean(trace.feature_flag) !== clean(cta.feature_flag)) errors.push(`CTA ${ctaId}: trace feature flag disagrees with CTA matrix`);
  }

  const stateIds = new Set(
    document.records.map((record) => clean(record.state_id)).filter((value) => meaningful(value)),
  );
  for (const state of matrices.states.records) {
    const stateId = clean(state.state_id);
    if (!stateIds.has(stateId)) errors.push(`State denominator ${stateId} has no trace row`);
  }

  const journeys = document.records.filter((record) =>
    meaningful(record.accessibility_journey_id),
  );
  if (journeys.length < 7) {
    errors.push(`Accessibility denominator requires at least 7 journeys; found ${journeys.length}`);
  }
  for (const duplicate of duplicateValues(journeys, 'accessibility_journey_id')) {
    errors.push(
      `Duplicate accessibility_journey_id "${duplicate.value}" at row ${duplicate.row}; first used at row ${duplicate.first}`,
    );
  }
}

export function validateTraceabilityDocument(
  document,
  inventory,
  {
    allowEmpty = false,
    matrices = null,
    enforceDenominators = false,
    verifyEvidenceFiles = false,
    evidenceRoot = repoRoot,
  } = {},
) {
  const errors = [];
  requireHeaders(document.headers, traceabilityHeaders, errors);

  if (document.records.length === 0) {
    if (!allowEmpty) {
      errors.push(
        'Traceability is header-only. Use --allow-empty only while the file is an explicit skeleton.',
      );
    }
    return errors;
  }

  if (inventory.records.length === 0) {
    errors.push('Traceability rows cannot be validated against an empty inventory');
    return errors;
  }

  const screenIds = new Set(inventory.records.map((record) => clean(record.screen_id)));
  const routeIds = new Set(
    matrices?.routes.records.map((record) => clean(record.route_id)) ?? [],
  );
  const ctaIds = new Set(
    matrices?.ctas.records.map((record) => clean(record.cta_id)) ?? [],
  );
  const stateIds = new Set(
    matrices?.states.records.map((record) => clean(record.state_id)) ?? [],
  );
  const seenTraceIds = new Map();

  document.records.forEach((record, index) => {
    const rowNumber = index + 2;
    const prefix = `Row ${rowNumber}`;
    const required = [
      'trace_id',
      'requirement_id',
      'screen_id',
      'route_id',
      'route',
      'state_id',
      'platform',
      'viewport',
      'text_scale',
      'expected_result',
      'status',
      'cta_enabled',
      'owner',
    ];
    for (const field of required) {
      if (!clean(record[field])) errors.push(`${prefix}: ${field} is required`);
    }

    const traceId = clean(record.trace_id);
    if (!/^UI031-[A-Z0-9-]+$/.test(traceId)) {
      errors.push(`${prefix}: invalid trace_id "${traceId}"`);
    }
    if (seenTraceIds.has(traceId)) {
      errors.push(
        `${prefix}: duplicate trace_id "${traceId}" first used at row ${seenTraceIds.get(traceId)}`,
      );
    } else {
      seenTraceIds.set(traceId, rowNumber);
    }

    const requirementId = clean(record.requirement_id);
    if (!/^UI031-[A-Z0-9-]+$/.test(requirementId)) {
      errors.push(`${prefix}: invalid requirement_id "${requirementId}"`);
    }

    const screenId = clean(record.screen_id);
    if (!screenIds.has(screenId)) {
      errors.push(`${prefix}: screen_id "${screenId}" is absent from inventory`);
    }

    const routeId = clean(record.route_id);
    if (meaningful(routeId)) {
      if (!/^(RT|RB)-\d{3}$/.test(routeId)) errors.push(`${prefix}: invalid route_id "${routeId}"`);
      if (matrices && !routeIds.has(routeId)) errors.push(`${prefix}: route_id "${routeId}" is absent from route matrix`);
    }

    const route = clean(record.route);
    if (!routeOrSurface(route)) {
      errors.push(`${prefix}: route is not a recognized route action or surface`);
    }

    const stateId = clean(record.state_id);
    if (meaningful(stateId)) {
      if (!/^ST-\d{2}$/.test(stateId)) errors.push(`${prefix}: invalid state_id "${stateId}"`);
      if (matrices && !stateIds.has(stateId)) errors.push(`${prefix}: state_id "${stateId}" is absent from state matrix`);
    }

    const platform = clean(record.platform);
    if (!platforms.has(platform)) errors.push(`${prefix}: invalid platform "${platform}"`);

    const viewport = clean(record.viewport);
    if (viewport !== 'N/A' && !/^\d+x\d+$/.test(viewport)) {
      errors.push(`${prefix}: viewport must be <width>x<height> or N/A`);
    }

    const textScale = clean(record.text_scale);
    if (!textScales.has(textScale)) errors.push(`${prefix}: invalid text_scale "${textScale}"`);

    const status = clean(record.status);
    if (!statuses.has(status)) errors.push(`${prefix}: invalid status "${status}"`);

    const ctaEnabled = clean(record.cta_enabled);
    if (!ctaStates.has(ctaEnabled)) errors.push(`${prefix}: invalid cta_enabled "${ctaEnabled}"`);
    const ctaId = clean(record.cta_id);
    if (meaningful(ctaId) && matrices && !ctaIds.has(ctaId)) {
      errors.push(`${prefix}: cta_id "${ctaId}" is absent from CTA matrix`);
    }
    if (ctaEnabled === 'TRUE') {
      for (const field of ['cta_id', 'handler_ref']) {
        if (!meaningful(record[field])) errors.push(`${prefix}: enabled CTA requires ${field}`);
      }
      if (!meaningful(route)) errors.push(`${prefix}: enabled CTA requires a target route or action`);
      const handler = clean(record.handler_ref);
      if (meaningful(handler) && !actionableHandler.test(handler)) {
        errors.push(`${prefix}: enabled CTA handler_ref must be actionable`);
      }
    }
    if (ctaEnabled === 'FALSE' && meaningful(ctaId) && !clean(record.handler_ref).startsWith('disabled:')) {
      errors.push(`${prefix}: disabled CTA trace requires a disabled: handler_ref`);
    }

    const goldenId = clean(record.golden_id);
    const goldenSha256 = clean(record.golden_sha256).toUpperCase();
    if (meaningful(goldenId) && !meaningful(viewport)) {
      errors.push(`${prefix}: golden_id requires a concrete viewport`);
    }
    if (meaningful(goldenId) && !portableGoldenPath(goldenId)) {
      errors.push(`${prefix}: golden_id must be a repo-relative PNG under mobile/test/visual/goldens/`);
    }
    if (!meaningful(goldenId) && meaningful(goldenSha256)) {
      errors.push(`${prefix}: golden_sha256 requires golden_id`);
    }

    const designNodeId = clean(record.design_node_id);
    if (meaningful(designNodeId) && !/^\d+:\d+$/.test(designNodeId)) {
      errors.push(`${prefix}: design_node_id is not a Figma node ID`);
    }

    if (status === 'PASS') {
      const evidencePath = clean(record.evidence_path);
      const evidenceSha256 = clean(record.evidence_sha256).toUpperCase();
      const proofKind = clean(record.proof_kind);
      const verifiedAt = clean(record.verified_at);
      if (!portableEvidencePath(evidencePath)) {
        errors.push(
          `${prefix}: PASS requires a repo-relative evidence_path under output-evidence/ui-v031/`,
        );
      }
      if (
        ![
          record.test_id,
          record.golden_id,
          record.design_node_id,
          record.device_evidence_id,
        ].some(meaningful)
      ) {
        errors.push(`${prefix}: PASS requires at least one real proof identifier`);
      }
      if (!/^[A-F0-9]{64}$/.test(evidenceSha256)) {
        errors.push(`${prefix}: PASS requires a 64-character evidence_sha256`);
      }
      if (!passProofKinds.has(proofKind)) {
        errors.push(`${prefix}: PASS proof_kind is not allowlisted: ${proofKind}`);
      }
      if (
        proofKind === 'SCREEN_RUNTIME_GOLDEN_AND_W3' &&
        (!meaningful(record.test_id) || !meaningful(goldenId) || !meaningful(record.design_node_id))
      ) {
        errors.push(`${prefix}: runtime screen PASS requires test, golden, and design node proof`);
      }
      if (
        proofKind === 'SCREEN_W3_DESIGN' &&
        !meaningful(record.design_node_id)
      ) {
        errors.push(`${prefix}: design screen PASS requires design_node_id`);
      }
      if (
        proofKind === 'CTA_FAIL_CLOSED_TEST_AND_GOLDEN' &&
        (!meaningful(record.test_id) || !meaningful(goldenId))
      ) {
        errors.push(`${prefix}: CTA test-and-golden PASS requires test_id and golden_id`);
      }
      if (!validIsoTimestamp(verifiedAt)) {
        errors.push(`${prefix}: PASS requires an ISO verified_at timestamp`);
      }
      for (const field of ['proof_kind', 'verified_at', 'reviewer']) {
        if (!meaningful(record[field])) {
          errors.push(`${prefix}: PASS requires ${field}`);
        }
      }

      if (verifyEvidenceFiles && portableEvidencePath(evidencePath)) {
        const resolved = resolveInside(evidenceRoot, evidencePath);
        if (!resolved.inside) {
          errors.push(`${prefix}: evidence_path escapes the repository root`);
        } else if (!fs.existsSync(resolved.resolvedPath)) {
          errors.push(`${prefix}: evidence file does not exist: ${evidencePath}`);
        } else if (/^[A-F0-9]{64}$/.test(evidenceSha256)) {
          const actualSha256 = hashFile(resolved.resolvedPath);
          if (actualSha256 !== evidenceSha256) {
            errors.push(
              `${prefix}: evidence_sha256 mismatch for ${evidencePath}; expected ${evidenceSha256}, got ${actualSha256}`,
            );
          }
        }

        if (fs.existsSync(resolved.resolvedPath)) {
          validatePassingFlutterLog({
            record,
            evidencePath: resolved.resolvedPath,
            errors,
            prefix,
          });
        }

        if (
          meaningful(record.accessibility_journey_id) &&
          proofKind === 'ANDROID_TALKBACK_JOURNEY_MANIFEST' &&
          fs.existsSync(resolved.resolvedPath)
        ) {
          validateTalkBackJourneyManifest({
            record,
            manifestPath: resolved.resolvedPath,
            evidenceRoot,
            errors,
            prefix,
          });
        }
        if (
          meaningful(record.cta_id) &&
          proofKind === 'CTA_ROW_EXECUTION_MANIFEST' &&
          fs.existsSync(resolved.resolvedPath)
        ) {
          const ctaRecord = matrices?.ctas.records.find(
            (candidate) => clean(candidate.cta_id) === clean(record.cta_id),
          );
          validateCtaRowExecutionManifest({
            record,
            ctaRecord,
            manifestPath: resolved.resolvedPath,
            evidenceRoot,
            errors,
            prefix,
          });
        }
      }

      if (meaningful(goldenId)) {
        if (!/^[A-F0-9]{64}$/.test(goldenSha256)) {
          errors.push(`${prefix}: PASS with golden_id requires golden_sha256`);
        }
        if (verifyEvidenceFiles && portableGoldenPath(goldenId)) {
          const resolvedGolden = resolveInside(evidenceRoot, goldenId);
          if (!resolvedGolden.inside || !fs.existsSync(resolvedGolden.resolvedPath)) {
            errors.push(`${prefix}: golden file does not exist: ${goldenId}`);
          } else if (
            /^[A-F0-9]{64}$/.test(goldenSha256) &&
            hashFile(resolvedGolden.resolvedPath) !== goldenSha256
          ) {
            errors.push(`${prefix}: golden_sha256 mismatch for ${goldenId}`);
          }
        }
      }

      if (meaningful(ctaId) && matrices) {
        const ctaRecord = matrices.ctas.records.find(
          (candidate) => clean(candidate.cta_id) === ctaId,
        );
        if (clean(ctaRecord?.test_status) !== 'PASS') {
          errors.push(
            `${prefix}: CTA PASS requires row-specific CTA matrix test_status=PASS`,
          );
        }
      }

      const journeyId = clean(record.accessibility_journey_id);
      if (meaningful(journeyId)) {
        if (proofKind !== 'ANDROID_TALKBACK_JOURNEY_MANIFEST') {
          errors.push(`${prefix}: accessibility PASS requires ANDROID_TALKBACK_JOURNEY_MANIFEST`);
        }
        if (!clean(record.device_evidence_id).includes(journeyId)) {
          errors.push(
            `${prefix}: accessibility PASS requires device_evidence_id bound to ${journeyId}`,
          );
        }
        if (!evidencePath.toLowerCase().endsWith('.json')) {
          errors.push(`${prefix}: accessibility PASS evidence_path must be a JSON manifest`);
        }
      }
    }

    if (status === 'NOT_APPLICABLE' && !meaningful(record.notes)) {
      errors.push(`${prefix}: NOT_APPLICABLE requires a justification in notes`);
    }
  });

  if (matrices && enforceDenominators && !allowEmpty) {
    validateDenominators(document, inventory, matrices, errors);
  }

  return errors;
}

function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
    const inventory = readCsv(options.inventory);
    const inventoryErrors = validateInventoryDocument(inventory, {
      allowEmpty: options.allowEmpty,
      expectedCount: 56,
    });
    const matrices = readContractMatrices(options);
    const matrixErrors = validateContractMatrices(matrices, inventory);
    const document = readCsv(options.file);
    const errors = [
      ...inventoryErrors.map((error) => `Inventory: ${error}`),
      ...matrixErrors.map((error) => `Contract matrix: ${error}`),
      ...validateTraceabilityDocument(document, inventory, {
        allowEmpty: options.allowEmpty,
        matrices,
        enforceDenominators: true,
        verifyEvidenceFiles: true,
        evidenceRoot: repoRoot,
      }),
    ];
    printResult({
      validator: 'pawmate-ui-v031-traceability',
      file: document.absolutePath,
      records: document.records.length,
      errors,
      details: {
        inventory: inventory.absolutePath,
        inventoryRecords: inventory.records.length,
        routeMatrix: matrices.routes.absolutePath,
        routeRecords: matrices.routes.records.length,
        ctaMatrix: matrices.ctas.absolutePath,
        ctaRecords: matrices.ctas.records.length,
        stateMatrix: matrices.states.absolutePath,
        stateRecords: matrices.states.records.length,
        denominators: traceabilityDenominators(document),
        skeletonAllowed: options.allowEmpty,
      },
    });
  } catch (error) {
    printResult({
      validator: 'pawmate-ui-v031-traceability',
      file: path.resolve(options?.file ?? defaultTraceabilityPath),
      records: 0,
      errors: [error instanceof Error ? error.message : String(error)],
    });
  }
}

if (path.resolve(process.argv[1] ?? '') === scriptPath) main();

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { clean, readCsv } from './csv_utils.mjs';
import {
  defaultCtaMatrixPath,
  defaultRouteMatrixPath,
  defaultStateMatrixPath,
  readContractMatrices,
} from './validate_matrices.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const inventoryPath = path.join(
  repoRoot,
  'docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv',
);
const outputPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/ui_v031_traceability.csv',
);
export const executionOverlayPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/ui_v031_trace_execution_overlay.csv',
);

export const generatedTraceabilityHeaders = [
  'trace_id',
  'requirement_id',
  'source_requirement_id',
  'screen_id',
  'route_id',
  'route',
  'state_id',
  'platform',
  'viewport',
  'text_scale',
  'test_id',
  'golden_id',
  'golden_sha256',
  'design_node_id',
  'device_evidence_id',
  'expected_result',
  'evidence_path',
  'evidence_sha256',
  'proof_kind',
  'status',
  'cta_id',
  'cta_enabled',
  'handler_ref',
  'feature_flag',
  'accessibility_journey_id',
  'owner',
  'verified_at',
  'reviewer',
  'notes',
];

export const executionOverlayHeaders = [
  'trace_id',
  'status',
  'proof_kind',
  'test_id',
  'golden_id',
  'golden_sha256',
  'design_node_id',
  'device_evidence_id',
  'evidence_path',
  'evidence_sha256',
  'verified_at',
  'reviewer',
  'notes_append',
];

const canonicalScreenRoute = new Map([
  ['P2-02', '/rescue/create'],
  ['P2-03', '/rescue/create/details'],
  ['P2-04', '/rescue/:caseId'],
  ['P2-05', '/rescue/map'],
  ['P2-06', '/rescue/:caseId/comment'],
  ['P2-07', '/rescue/:caseId/status'],
  ['P2-08', '/rescue/:caseId/discussion'],
]);

const representativeByRouteId = new Map([
  ['RT-001', 'P1-01'],
  ['RT-002', 'P1-01'],
  ['RT-003', 'P1-02'],
  ['RT-004', 'P1-03'],
  ['RT-005', 'P1-04'],
  ['RT-006', 'P1-07'],
  ['RT-007', 'P1-05'],
  ['RT-008', 'P1-06'],
  ['RT-009', 'P1-06'],
  ['RT-010', 'P1-05'],
  ['RT-011', 'P1-08'],
  ['RT-012', 'P1-09'],
  ['RT-013', 'P1-10'],
  ['RT-014', 'P1-12'],
  ['RT-015', 'P1-13'],
  ['RT-016', 'P1-14'],
  ['RT-017', 'P1-15'],
  ['RT-018', 'P1-07'],
  ['RT-019', 'P2-09'],
  ['RT-020', 'P2-16'],
  ['RT-021', 'P2-15'],
  ['RT-022', 'P1-16'],
  ['RT-023', 'P2-01'],
  ['RT-024', 'P2-02'],
  ['RT-025', 'P2-03'],
  ['RT-026', 'P2-05'],
  ['RT-027', 'P2-04'],
  ['RT-028', 'P2-06'],
  ['RT-029', 'P2-07'],
  ['RT-030', 'P2-08'],
  ['RT-031', 'P2-10'],
  ['RT-032', 'P2-11'],
  ['RT-033', 'P2-12'],
  ['RT-034', 'ST-20'],
  ['RT-035', 'P2-14'],
  ['RT-036', 'P1-11'],
  ['RB-001', 'P1-02'],
  ['RB-002', 'P1-02'],
  ['RB-003', 'P1-07'],
  ['RB-004', 'P1-07'],
  ['RB-005', 'P1-07'],
  ['RB-006', 'P1-07'],
  ['RB-007', 'P1-07'],
  ['RB-008', 'P1-07'],
]);

const accessibilityJourneys = [
  {
    id: 'A11Y-AUTH',
    screenId: 'P1-02',
    routeId: 'RT-003',
    route: '/auth/login',
    owner: 'auth',
    expected: 'TalkBack and VoiceOver announce labels errors loading and focus order at text scale 2.0',
  },
  {
    id: 'A11Y-HOME',
    screenId: 'P1-07',
    routeId: 'RT-006',
    route: '/pets',
    owner: 'pets',
    expected: 'HOME cards and five-tab navigation keep logical semantics focus order and 48dp touch targets at text scale 2.0',
  },
  {
    id: 'A11Y-VET',
    screenId: 'P1-08',
    routeId: 'RT-011',
    route: '/vets/map',
    owner: 'vets',
    expected: 'VET map has a list alternative and never relies only on pin color or location permission',
  },
  {
    id: 'A11Y-HEALTH',
    screenId: 'P1-12',
    routeId: 'RT-014',
    route: '/health',
    owner: 'health',
    expected: 'HEALTH timeline reminder and add action remain operable and readable at text scale 2.0',
  },
  {
    id: 'A11Y-NOTIFICATIONS',
    screenId: 'P1-15',
    routeId: 'RT-017',
    route: '/notifications',
    owner: 'notifications',
    expected: 'Notification read state errors and dynamic targets are announced without color-only meaning',
  },
  {
    id: 'A11Y-PROFILE',
    screenId: 'P1-16',
    routeId: 'RT-022',
    route: '/profile',
    owner: 'profile',
    expected: 'PROFILE rows expose button roles selected state and honest unavailable destinations at text scale 2.0',
  },
  {
    id: 'A11Y-RESCUE',
    screenId: 'P2-01',
    routeId: 'RT-023',
    route: '/rescue',
    owner: 'rescue',
    expected: 'RESCUE staged state announces feature availability and never exposes exact location or an enabled inert CTA',
  },
];

function csvEscape(value) {
  const text = String(value ?? '');
  if (/[",\r\n]/.test(text)) return `"${text.replaceAll('"', '""')}"`;
  return text;
}

function makeRow(overrides) {
  return Object.fromEntries(
    generatedTraceabilityHeaders.map((header) => [
      header,
      Object.hasOwn(overrides, header) ? overrides[header] : 'N/A',
    ]),
  );
}

function platformForScreen(screen) {
  const screenId = clean(screen.screen_id);
  if (clean(screen.phase) === 'P1' || screenId === 'P2-01') return 'BOTH';
  return 'DESIGN';
}

function routeIdForScreen(screen, routeByPath) {
  const screenId = clean(screen.screen_id);
  const canonical = canonicalScreenRoute.get(screenId);
  if (canonical) return routeByPath.get(canonical)?.route_id ?? 'N/A';
  const surface = clean(screen.runtime_route_or_surface);
  if (routeByPath.has(surface)) return clean(routeByPath.get(surface).route_id);
  if (surface.includes(' | ')) {
    const first = surface.split(' | ')[0];
    return clean(routeByPath.get(first)?.route_id ?? 'N/A');
  }
  return 'N/A';
}

export function buildTraceabilityRows(inventory, matrices) {
  const inventoryById = new Map(
    inventory.records.map((record) => [clean(record.screen_id), record]),
  );
  const routeByPath = new Map(
    matrices.routes.records
      .filter((record) => clean(record.record_type) === 'ROUTE')
      .map((record) => [clean(record.path), record]),
  );
const rows = [];

  const screenChangeControl = new Map([
    [
      'P1-01',
      {
        expectedResult:
          'P1-01 Onboarding appears exactly once in the v0.31 denominator, shows the clean hero and photo picker, and does not display progress rails',
        note: 'change_control=UI031-CHANGE-W8-P1-01-NO-RAILS-02',
      },
    ],
  ]);

  for (const screen of inventory.records) {
    const screenId = clean(screen.screen_id);
    const approvedChange = screenChangeControl.get(screenId);
    rows.push(
      makeRow({
        trace_id: `UI031-TRACE-SCREEN-${screenId}`,
        requirement_id: `UI031-VIS-SCREEN-${screenId}`,
        screen_id: screenId,
        route_id: routeIdForScreen(screen, routeByPath),
        route: clean(screen.runtime_route_or_surface),
        state_id: screenId.startsWith('ST-') ? screenId : 'N/A',
        platform: platformForScreen(screen),
        viewport: '390x844',
        text_scale: '1.0',
        design_node_id: clean(screen.figma_source_node_id),
        expected_result:
          approvedChange?.expectedResult ??
          `${screenId} ${clean(screen.screen_name)} appears exactly once in the v0.31 denominator and preserves its locked scope`,
        status: 'PLANNED',
        cta_enabled: 'N/A',
        owner: clean(screen.module_owner),
        notes: [
          `screen-denominator;classification=${clean(screen.classification)};source_node=${clean(screen.figma_source_node_id)}`,
          approvedChange?.note,
        ]
          .filter(Boolean)
          .join(';'),
      }),
    );
  }

  for (const route of matrices.routes.records) {
    const routeId = clean(route.route_id);
    const screenId = representativeByRouteId.get(routeId);
    const screen = inventoryById.get(screenId);
    if (!screen) throw new Error(`No representative inventory screen for ${routeId}`);
    rows.push(
      makeRow({
        trace_id: `UI031-TRACE-ROUTE-${routeId}`,
        requirement_id: `UI031-NAV-${routeId}`,
        screen_id: screenId,
        route_id: routeId,
        route: clean(route.path),
        state_id: 'N/A',
        platform: clean(route.current_state) === 'FUTURE_ABSENT' ? 'DESIGN' : 'BOTH',
        viewport: '390x844',
        text_scale: '1.0',
        design_node_id: clean(screen.figma_source_node_id),
        expected_result: clean(route.expected_result),
        status: 'PLANNED',
        cta_enabled: 'N/A',
        feature_flag: clean(route.feature_flag),
        owner: clean(route.owner),
        notes: `route-denominator;record_type=${clean(route.record_type)};current_state=${clean(route.current_state)}`,
      }),
    );
  }

  for (const cta of matrices.ctas.records) {
    const screen = inventoryById.get(clean(cta.screen_id));
    if (!screen) throw new Error(`CTA ${clean(cta.cta_id)} references an unknown screen`);
    const target = clean(cta.target_route_or_action);
    const routeId = clean(routeByPath.get(target)?.route_id ?? 'N/A');
    rows.push(
      makeRow({
        trace_id: `UI031-TRACE-${clean(cta.cta_id)}`,
        requirement_id: `UI031-ACTION-${clean(cta.cta_id)}`,
        source_requirement_id: clean(cta.source_requirement_id),
        screen_id: clean(cta.screen_id),
        route_id: routeId,
        route: target,
        state_id: 'N/A',
        platform: platformForScreen(screen),
        viewport: '390x844',
        text_scale: '1.0',
        design_node_id: clean(screen.figma_source_node_id),
        expected_result: `${clean(cta.cta_id)} matches its documented enabled state handler and fail-closed behavior`,
        status: 'PLANNED',
        cta_id: clean(cta.cta_id),
        cta_enabled: clean(cta.target_enabled) === 'FALSE' ? 'FALSE' : 'TRUE',
        handler_ref: clean(cta.target_handler),
        feature_flag: clean(cta.feature_flag),
        owner: clean(cta.owner),
        notes: `cta-denominator;current_enabled=${clean(cta.current_enabled)};test_status=${clean(cta.test_status)}`,
      }),
    );
  }

  for (const journey of accessibilityJourneys) {
    const screen = inventoryById.get(journey.screenId);
    rows.push(
      makeRow({
        trace_id: `UI031-TRACE-${journey.id}`,
        requirement_id: `UI031-${journey.id}`,
        screen_id: journey.screenId,
        route_id: journey.routeId,
        route: journey.route,
        state_id: 'N/A',
        // Product Owner decision `VOICEOVER=G4C` removes the real-device
        // VoiceOver half from the G4B denominator.  Keep the seven journey
        // rows in the frozen traceability set, but make their executable G4B
        // contract Android TalkBack only; the iOS proof is tracked in G4C.
        platform: 'ANDROID',
        viewport: '390x844',
        text_scale: '2.0',
        design_node_id: clean(screen.figma_source_node_id),
        expected_result: `${journey.expected}; VoiceOver real-device proof is deferred to G4C`,
        status: 'PLANNED',
        cta_enabled: 'N/A',
        accessibility_journey_id: journey.id,
        owner: journey.owner,
        notes: 'accessibility-denominator;G4B=TalkBack;G4C=VoiceOver;requires Android TalkBack evidence before PASS',
      }),
    );
  }

  return rows;
}

export function applyTraceabilityExecutionOverlay(rows, overlayDocument) {
  const missingHeaders = executionOverlayHeaders.filter(
    (header) => !overlayDocument.headers.includes(header),
  );
  if (missingHeaders.length > 0) {
    throw new Error(
      `Trace execution overlay is missing headers: ${missingHeaders.join(', ')}`,
    );
  }

  const rowByTraceId = new Map(rows.map((row) => [clean(row.trace_id), row]));
  const overlayByTraceId = new Map();
  for (const record of overlayDocument.records) {
    const traceId = clean(record.trace_id);
    if (!traceId) throw new Error('Trace execution overlay contains a blank trace_id');
    if (overlayByTraceId.has(traceId)) {
      throw new Error(`Trace execution overlay contains duplicate trace_id ${traceId}`);
    }
    if (!rowByTraceId.has(traceId)) {
      throw new Error(`Trace execution overlay references unknown trace_id ${traceId}`);
    }
    overlayByTraceId.set(traceId, record);
  }

  const mutableFields = [
    'status',
    'proof_kind',
    'test_id',
    'golden_id',
    'golden_sha256',
    'design_node_id',
    'device_evidence_id',
    'evidence_path',
    'evidence_sha256',
    'verified_at',
    'reviewer',
  ];

  return rows.map((row) => {
    const overlay = overlayByTraceId.get(clean(row.trace_id));
    if (!overlay) return row;

    const merged = { ...row };
    for (const field of mutableFields) {
      const value = clean(overlay[field]);
      if (!value) {
        throw new Error(
          `Trace execution overlay ${row.trace_id} has a blank ${field}; use N/A to clear an optional field`,
        );
      }
      if (value === 'INHERIT') continue;
      merged[field] = value;
    }

    const notesAppend = clean(overlay.notes_append);
    if (!notesAppend) {
      throw new Error(
        `Trace execution overlay ${row.trace_id} has blank notes_append`,
      );
    }
    merged.notes = [
      clean(row.notes),
      notesAppend === 'N/A' ? null : notesAppend,
      `execution_overlay=${path.relative(repoRoot, executionOverlayPath).replaceAll('\\', '/')}`,
    ]
      .filter(Boolean)
      .join(';');
    return merged;
  });
}

export function serializeTraceability(rows) {
  return `${[
    generatedTraceabilityHeaders.join(','),
    ...rows.map((row) =>
      generatedTraceabilityHeaders.map((header) => csvEscape(row[header])).join(','),
    ),
  ].join('\n')}\n`;
}

function main() {
  const checkOnly = process.argv.slice(2).includes('--check');
  const inventory = readCsv(inventoryPath);
  const matrices = readContractMatrices({
    routes: defaultRouteMatrixPath,
    ctas: defaultCtaMatrixPath,
    states: defaultStateMatrixPath,
  });
  const baseRows = buildTraceabilityRows(inventory, matrices);
  const executionOverlay = fs.existsSync(executionOverlayPath)
    ? readCsv(executionOverlayPath)
    : { headers: executionOverlayHeaders, records: [] };
  const rows = applyTraceabilityExecutionOverlay(baseRows, executionOverlay);
  const generated = serializeTraceability(rows);

  if (checkOnly) {
    const current = fs.readFileSync(outputPath, 'utf8');
    if (current !== generated) {
      console.error(`Traceability is stale. Run node ${path.relative(repoRoot, scriptPath)}`);
      process.exitCode = 1;
      return;
    }
  } else {
    fs.writeFileSync(outputPath, generated, { encoding: 'utf8' });
  }

  console.log(
    JSON.stringify(
      {
        status: 'PASS',
        mode: checkOnly ? 'check' : 'write',
        file: outputPath,
        records: rows.length,
        denominators: {
          screens: inventory.records.length,
          routes: matrices.routes.records.length,
          ctas: matrices.ctas.records.length,
          accessibilityJourneys: accessibilityJourneys.length,
          states: matrices.states.records.length,
        },
        executionOverlayRecords: executionOverlay.records.length,
      },
      null,
      2,
    ),
  );
}

if (path.resolve(process.argv[1] ?? '') === scriptPath) main();

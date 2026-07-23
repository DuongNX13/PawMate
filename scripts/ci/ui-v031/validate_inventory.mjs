import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  clean,
  printResult,
  readCsv,
  requireHeaders,
} from './csv_utils.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const defaultInventoryPath = path.join(
  repoRoot,
  'docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv',
);

export const inventoryHeaders = [
  'screen_id',
  'phase',
  'screen_name',
  'figma_source_section_id',
  'figma_source_node_id',
  'source_node_name',
  'classification',
  'runtime_route_or_surface',
  'module_owner',
  'bottom_nav',
  'safe_area_policy',
  'status',
];

const enumValues = {
  phase: new Set(['P1', 'P2', 'STATE']),
  classification: new Set([
    'RUNTIME_PHASE1',
    'STAGED_PHASE2_FLAG_OFF',
    'DESIGN_ONLY_PHASE2',
    'STATE_REFERENCE',
  ]),
  bottom_nav: new Set(['yes', 'no', 'contextual']),
  safe_area_policy: new Set([
    'system-insets',
    'system-insets-and-ime',
    'shell-insets',
    'map-edge-to-edge-with-safe-controls',
  ]),
  status: new Set(['LOCKED']),
};

function addDuplicateErrors(records, field, errors) {
  const seen = new Map();
  records.forEach((record, index) => {
    const value = clean(record[field]);
    if (!value) return;
    if (seen.has(value)) {
      errors.push(
        `Duplicate ${field} "${value}" at rows ${seen.get(value) + 2} and ${index + 2}`,
      );
    } else {
      seen.set(value, index);
    }
  });
}

export function validateInventoryDocument(
  document,
  { allowEmpty = false, expectedCount = 56 } = {},
) {
  const errors = [];
  requireHeaders(document.headers, inventoryHeaders, errors);

  if (document.records.length === 0) {
    if (!allowEmpty) {
      errors.push(
        'Inventory is header-only. Use --allow-empty only while the file is an explicit skeleton.',
      );
    }
    return errors;
  }

  if (document.records.length !== expectedCount) {
    errors.push(
      `Inventory has ${document.records.length} rows; expected ${expectedCount}`,
    );
  }

  addDuplicateErrors(document.records, 'screen_id', errors);
  addDuplicateErrors(document.records, 'figma_source_node_id', errors);

  const phaseCounts = { P1: 0, P2: 0, STATE: 0 };

  document.records.forEach((record, index) => {
    const rowNumber = index + 2;
    const prefix = `Row ${rowNumber}`;
    const required = [
      'screen_id',
      'screen_name',
      'phase',
      'figma_source_section_id',
      'figma_source_node_id',
      'source_node_name',
      'classification',
      'runtime_route_or_surface',
      'bottom_nav',
      'safe_area_policy',
      'module_owner',
      'status',
    ];

    for (const field of required) {
      if (!clean(record[field])) errors.push(`${prefix}: ${field} is required`);
    }

    const screenId = clean(record.screen_id);
    if (!/^(P1|P2|ST)-\d{2}$/.test(screenId)) {
      errors.push(`${prefix}: invalid screen_id "${screenId}"`);
    }

    for (const [field, allowed] of Object.entries(enumValues)) {
      const value = clean(record[field]);
      if (value && !allowed.has(value)) {
        errors.push(
          `${prefix}: ${field} "${value}" is not one of ${[...allowed].join('|')}`,
        );
      }
    }

    const phase = clean(record.phase);
    if (phase in phaseCounts) phaseCounts[phase] += 1;
    if (screenId.startsWith('P1-') && phase !== 'P1') {
      errors.push(`${prefix}: ${screenId} must use phase P1`);
    }
    if (screenId.startsWith('P2-') && phase !== 'P2') {
      errors.push(`${prefix}: ${screenId} must use phase P2`);
    }
    if (screenId.startsWith('ST-') && phase !== 'STATE') {
      errors.push(`${prefix}: ${screenId} must use phase STATE`);
    }

    for (const field of ['figma_source_section_id', 'figma_source_node_id']) {
      const value = clean(record[field]);
      if (value && !/^\d+:\d+$/.test(value)) {
        errors.push(`${prefix}: ${field} "${value}" is not a Figma node ID`);
      }
      if (/TBD|TODO|UNKNOWN|GUESS|PLACEHOLDER/i.test(value)) {
        errors.push(`${prefix}: ${field} must come from live Figma, not a placeholder`);
      }
    }

    const classification = clean(record.classification);
    if (phase === 'P1' && classification !== 'RUNTIME_PHASE1') {
      errors.push(`${prefix}: P1 rows must use classification RUNTIME_PHASE1`);
    }
    if (
      phase === 'P2' &&
      !['STAGED_PHASE2_FLAG_OFF', 'DESIGN_ONLY_PHASE2'].includes(classification)
    ) {
      errors.push(`${prefix}: P2 row has invalid classification ${classification}`);
    }
    if (phase === 'STATE' && classification !== 'STATE_REFERENCE') {
      errors.push(`${prefix}: STATE rows must use classification STATE_REFERENCE`);
    }

    const route = clean(record.runtime_route_or_surface);
    const routeParts = route.split(' | ');
    const validRoute = routeParts.every(
      (part) =>
        part === 'N/A' ||
        part.startsWith('/') ||
        /^proposed:\//.test(part) ||
        /^modal:[a-z0-9-]+$/.test(part),
    );
    if (!validRoute) {
      errors.push(
        `${prefix}: runtime_route_or_surface contains an invalid route/surface`,
      );
    }
  });

  if (expectedCount === 56 && document.records.length === 56) {
    const expectedPhases = { P1: 16, P2: 16, STATE: 24 };
    for (const [phase, expected] of Object.entries(expectedPhases)) {
      if (phaseCounts[phase] !== expected) {
        errors.push(`${phase} has ${phaseCounts[phase]} rows; expected ${expected}`);
      }
    }
  }

  return errors;
}

function parseArguments(args) {
  let file = defaultInventoryPath;
  let allowEmpty = false;
  let expectedCount = 56;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--allow-empty') {
      allowEmpty = true;
    } else if (argument === '--expected-count') {
      const next = args[index + 1];
      if (!next || !/^\d+$/.test(next)) {
        throw new Error('--expected-count requires a non-negative integer');
      }
      expectedCount = Number(next);
      index += 1;
    } else if (argument.startsWith('--')) {
      throw new Error(`Unknown option: ${argument}`);
    } else {
      file = argument;
    }
  }

  return { file, allowEmpty, expectedCount };
}

function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
    const document = readCsv(options.file);
    const errors = validateInventoryDocument(document, options);
    printResult({
      validator: 'pawmate-ui-v031-inventory',
      file: document.absolutePath,
      records: document.records.length,
      errors,
      details: {
        expectedCount: options.expectedCount,
        skeletonAllowed: options.allowEmpty,
      },
    });
  } catch (error) {
    printResult({
      validator: 'pawmate-ui-v031-inventory',
      file: path.resolve(options?.file ?? defaultInventoryPath),
      records: 0,
      errors: [error instanceof Error ? error.message : String(error)],
    });
  }
}

if (path.resolve(process.argv[1] ?? '') === scriptPath) main();

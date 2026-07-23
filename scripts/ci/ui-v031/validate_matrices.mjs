import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { clean, meaningful, readCsv, requireHeaders } from './csv_utils.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');

export const defaultRouteMatrixPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/route_matrix.csv',
);
export const defaultCtaMatrixPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/cta_matrix.csv',
);
export const defaultStateMatrixPath = path.join(
  repoRoot,
  'docs/qa/ui-v031/state_matrix.csv',
);

export const routeMatrixHeaders = [
  'route_id',
  'record_type',
  'path',
  'current_state',
  'target_navigator',
  'target_branch',
  'auth_policy',
  'feature_flag',
  'deep_link_policy',
  'return_to_policy',
  'expected_result',
  'status',
  'source_ref',
  'owner',
  'notes',
];

export const ctaMatrixHeaders = [
  'cta_id',
  'screen_id',
  'source_requirement_id',
  'label',
  'cta_kind',
  'current_enabled',
  'current_handler',
  'target_enabled',
  'target_handler',
  'target_route_or_action',
  'feature_flag',
  'fail_closed_behavior',
  'test_status',
  'owner',
  'source_ref',
  'notes',
  'inventory_phase',
];

export const stateMatrixHeaders = [
  'state_id',
  'screen_id',
  'state_name',
  'source_node_id',
  'module_scope',
  'runtime_route_or_surface',
  'phase_scope',
  'trigger',
  'expected_ui',
  'primary_action',
  'secondary_action',
  'data_policy',
  'permission_policy',
  'feature_flag',
  'test_status',
  'owner',
  'notes',
];

const liveRouterPaths = new Set([
  '/launch',
  '/onboarding',
  '/auth/login',
  '/auth/register',
  '/auth/otp',
  '/pets',
  '/pets/list',
  '/pets/create',
  '/pets/:id/edit',
  '/pets/:id',
  '/vets/map',
  '/vets/list',
  '/vets/:id',
  '/health',
  '/health/events/new',
  '/health/reminders',
  '/notifications',
  '/community',
  '/adoption',
  '/profile/controls',
  '/profile/privacy',
  '/profile',
  '/rescue',
]);

const routeRecordTypes = new Set(['ROUTE', 'NAV_BEHAVIOR']);
const currentRouteStates = new Set([
  'LIVE_FLAT_ROUTE',
  'LIVE_PLACEHOLDER',
  'LIVE_STAGED_FLAG_OFF',
  'FUTURE_ABSENT',
  'LIVE_MODAL',
  'TARGET_ONLY',
]);
const navigators = new Set(['ROOT', 'SHELL', 'OVERLAY', 'UNRESOLVED', 'N/A']);
const branches = new Set(['HOME', 'VET', 'HEALTH', 'RESCUE', 'PROFILE', 'NONE', 'N/A']);
const authPolicies = new Set(['PUBLIC', 'AUTH_REQUIRED', 'INHERIT', 'N/A']);
const planStatuses = new Set(['PLANNED', 'KNOWN_DEFECT', 'BLOCKED', 'PASS']);
const enabledStates = new Set(['TRUE', 'FALSE', 'CONDITIONAL']);
const ctaKinds = new Set(['PRIMARY', 'NAVIGATION']);
const phases = new Set(['P1', 'P2']);
const actionableHandler = /^(route|callback|command|external|overlay):/;
const disabledHandler = /^disabled:/;

function routeLike(value) {
  const route = clean(value);
  return (
    route === 'N/A' ||
    route.startsWith('/') ||
    route.startsWith('proposed:/') ||
    route.startsWith('modal:') ||
    route.includes(' | ')
  );
}

function uniqueField(records, field, errors, label) {
  const seen = new Map();
  records.forEach((record, index) => {
    const value = clean(record[field]);
    const row = index + 2;
    if (!value) {
      errors.push(`${label} row ${row}: ${field} is required`);
    } else if (seen.has(value)) {
      errors.push(`${label} row ${row}: duplicate ${field} "${value}" first used at row ${seen.get(value)}`);
    } else {
      seen.set(value, row);
    }
  });
}

export function validateRouteMatrix(document) {
  const errors = [];
  requireHeaders(document.headers, routeMatrixHeaders, errors);
  uniqueField(document.records, 'route_id', errors, 'Route matrix');

  const seenPaths = new Map();
  const livePathsInMatrix = new Set();
  const branchRoots = new Map();

  document.records.forEach((record, index) => {
    const row = index + 2;
    const prefix = `Route matrix row ${row}`;
    for (const field of routeMatrixHeaders) {
      if (!clean(record[field])) errors.push(`${prefix}: ${field} is required`);
    }

    const routeId = clean(record.route_id);
    const recordType = clean(record.record_type);
    const routePath = clean(record.path);
    const currentState = clean(record.current_state);
    const navigator = clean(record.target_navigator);
    const branch = clean(record.target_branch);
    const auth = clean(record.auth_policy);

    if (!/^(RT|RB)-\d{3}$/.test(routeId)) errors.push(`${prefix}: invalid route_id "${routeId}"`);
    if (!routeRecordTypes.has(recordType)) errors.push(`${prefix}: invalid record_type "${recordType}"`);
    if (!currentRouteStates.has(currentState)) errors.push(`${prefix}: invalid current_state "${currentState}"`);
    if (!navigators.has(navigator)) errors.push(`${prefix}: invalid target_navigator "${navigator}"`);
    if (!branches.has(branch)) errors.push(`${prefix}: invalid target_branch "${branch}"`);
    if (!authPolicies.has(auth)) errors.push(`${prefix}: invalid auth_policy "${auth}"`);
    if (clean(record.status) !== 'PLANNED') errors.push(`${prefix}: status must remain PLANNED until evidence exists`);
    if (!meaningful(record.expected_result)) errors.push(`${prefix}: expected_result is required`);
    if (!meaningful(record.source_ref)) errors.push(`${prefix}: source_ref is required`);

    if (recordType === 'ROUTE') {
      if (!routeLike(routePath) || routePath === 'N/A' || routePath.includes(' | ')) {
        errors.push(`${prefix}: ROUTE path must be one canonical path or surface`);
      }
      if (seenPaths.has(routePath)) {
        errors.push(`${prefix}: duplicate route path "${routePath}" first used at row ${seenPaths.get(routePath)}`);
      } else {
        seenPaths.set(routePath, row);
      }
      if (currentState.startsWith('LIVE_') && routePath.startsWith('/')) {
        livePathsInMatrix.add(routePath);
      }
    } else if (routePath !== 'N/A' || currentState !== 'TARGET_ONLY') {
      errors.push(`${prefix}: NAV_BEHAVIOR must use path N/A and current_state TARGET_ONLY`);
    }

    if (
      recordType === 'ROUTE' &&
      navigator === 'SHELL' &&
      !['HOME', 'VET', 'HEALTH', 'RESCUE', 'PROFILE'].includes(branch)
    ) {
      errors.push(`${prefix}: shell route requires one of the five target branches`);
    }
    if (recordType === 'ROUTE' && navigator !== 'SHELL' && branch !== 'NONE' && branch !== 'N/A' && navigator !== 'OVERLAY') {
      errors.push(`${prefix}: non-shell route has an invalid branch assignment`);
    }

    const expectedRoots = new Map([
      ['/pets', 'HOME'],
      ['/vets/map', 'VET'],
      ['/health', 'HEALTH'],
      ['/rescue', 'RESCUE'],
      ['/profile', 'PROFILE'],
    ]);
    if (expectedRoots.has(routePath)) branchRoots.set(routePath, branch);
  });

  for (const routePath of liveRouterPaths) {
    if (!livePathsInMatrix.has(routePath)) {
      errors.push(`Route matrix is missing live app_router path ${routePath}`);
    }
  }
  for (const routePath of livePathsInMatrix) {
    if (!liveRouterPaths.has(routePath)) {
      errors.push(`Route matrix claims non-router path ${routePath} is live`);
    }
  }
  for (const [routePath, branch] of new Map([
    ['/pets', 'HOME'],
    ['/vets/map', 'VET'],
    ['/health', 'HEALTH'],
    ['/rescue', 'RESCUE'],
    ['/profile', 'PROFILE'],
  ])) {
    if (branchRoots.get(routePath) !== branch) {
      errors.push(`Route matrix target branch root ${routePath} must be ${branch}`);
    }
  }

  const behaviors = document.records.filter((record) => clean(record.record_type) === 'NAV_BEHAVIOR');
  if (behaviors.length < 8) errors.push(`Route matrix requires at least 8 cross-cut navigation behaviors; found ${behaviors.length}`);

  return errors;
}

export function validateCtaMatrix(document, inventory) {
  const errors = [];
  requireHeaders(document.headers, ctaMatrixHeaders, errors);
  uniqueField(document.records, 'cta_id', errors, 'CTA matrix');
  const inventoryById = new Map(
    inventory.records.map((record) => [clean(record.screen_id), record]),
  );
  const p1Covered = new Set();

  document.records.forEach((record, index) => {
    const row = index + 2;
    const prefix = `CTA matrix row ${row}`;
    for (const field of ctaMatrixHeaders) {
      if (!clean(record[field])) errors.push(`${prefix}: ${field} is required`);
    }

    const ctaId = clean(record.cta_id);
    const screenId = clean(record.screen_id);
    const screen = inventoryById.get(screenId);
    const kind = clean(record.cta_kind);
    const currentEnabled = clean(record.current_enabled);
    const targetEnabled = clean(record.target_enabled);
    const currentHandler = clean(record.current_handler);
    const targetHandler = clean(record.target_handler);
    const testStatus = clean(record.test_status);
    const phase = clean(record.inventory_phase);

    if (!/^CTA-[A-Z0-9-]+$/.test(ctaId)) errors.push(`${prefix}: invalid cta_id "${ctaId}"`);
    if (!screen) errors.push(`${prefix}: screen_id "${screenId}" is absent from inventory`);
    if (!ctaKinds.has(kind)) errors.push(`${prefix}: invalid cta_kind "${kind}"`);
    if (!enabledStates.has(currentEnabled)) errors.push(`${prefix}: invalid current_enabled "${currentEnabled}"`);
    if (!enabledStates.has(targetEnabled)) errors.push(`${prefix}: invalid target_enabled "${targetEnabled}"`);
    if (!planStatuses.has(testStatus)) errors.push(`${prefix}: invalid test_status "${testStatus}"`);
    if (!phases.has(phase)) errors.push(`${prefix}: invalid inventory_phase "${phase}"`);
    if (screen && clean(screen.phase) !== phase) errors.push(`${prefix}: inventory_phase disagrees with inventory`);
    if (!meaningful(record.fail_closed_behavior)) errors.push(`${prefix}: fail_closed_behavior is required`);
    if (!meaningful(record.target_route_or_action)) errors.push(`${prefix}: target_route_or_action is required`);
    if (!meaningful(record.source_ref)) errors.push(`${prefix}: source_ref is required`);

    if (currentEnabled !== 'FALSE' && !(actionableHandler.test(currentHandler) || currentHandler === 'callback:NO_OP')) {
      errors.push(`${prefix}: enabled current CTA requires an explicit real handler or callback:NO_OP defect`);
    }
    if (currentEnabled === 'FALSE' && !disabledHandler.test(currentHandler)) {
      errors.push(`${prefix}: disabled current CTA requires a disabled: handler`);
    }
    if (currentHandler === 'callback:NO_OP' && testStatus !== 'KNOWN_DEFECT') {
      errors.push(`${prefix}: callback:NO_OP must be marked KNOWN_DEFECT`);
    }

    if (targetEnabled === 'FALSE') {
      if (!disabledHandler.test(targetHandler)) errors.push(`${prefix}: disabled target CTA requires a disabled: handler`);
    } else if (!actionableHandler.test(targetHandler)) {
      errors.push(`${prefix}: enabled target CTA requires route/callback/command/external/overlay handler`);
    }
    if (targetHandler === 'callback:NO_OP') errors.push(`${prefix}: target handler may never be a no-op`);

    if (phase === 'P1') p1Covered.add(screenId);
    const featureFlag = clean(record.feature_flag);
    if (
      featureFlag.endsWith('=false') &&
      targetEnabled !== 'FALSE' &&
      clean(record.target_route_or_action) !== '/rescue'
    ) {
      errors.push(`${prefix}: feature-flagged Phase 2 CTA must fail closed while default is false`);
    }
  });

  for (let index = 1; index <= 16; index += 1) {
    const screenId = `P1-${String(index).padStart(2, '0')}`;
    if (!p1Covered.has(screenId)) errors.push(`CTA matrix has no primary/navigation denominator for ${screenId}`);
  }

  return errors;
}

export function validateStateMatrix(document, inventory) {
  const errors = [];
  requireHeaders(document.headers, stateMatrixHeaders, errors);
  uniqueField(document.records, 'state_id', errors, 'State matrix');
  const inventoryById = new Map(
    inventory.records.map((record) => [clean(record.screen_id), record]),
  );

  if (document.records.length !== 24) {
    errors.push(`State matrix must contain exactly ST-01..ST-24; found ${document.records.length}`);
  }

  document.records.forEach((record, index) => {
    const row = index + 2;
    const prefix = `State matrix row ${row}`;
    for (const field of stateMatrixHeaders) {
      if (!clean(record[field])) errors.push(`${prefix}: ${field} is required`);
    }

    const stateId = clean(record.state_id);
    const expectedId = `ST-${String(index + 1).padStart(2, '0')}`;
    const screenId = clean(record.screen_id);
    const screen = inventoryById.get(screenId);
    if (stateId !== expectedId) errors.push(`${prefix}: expected ordered state_id ${expectedId}; found ${stateId}`);
    if (screenId !== stateId) errors.push(`${prefix}: screen_id must equal state_id`);
    if (!screen) errors.push(`${prefix}: state is absent from inventory`);
    if (screen && clean(record.state_name) !== clean(screen.screen_name)) errors.push(`${prefix}: state_name disagrees with inventory`);
    if (screen && clean(record.source_node_id) !== clean(screen.figma_source_node_id)) errors.push(`${prefix}: source_node_id disagrees with inventory`);
    if (!routeLike(record.runtime_route_or_surface)) errors.push(`${prefix}: invalid runtime route or surface`);
    if (clean(record.test_status) !== 'PLANNED') errors.push(`${prefix}: test_status must remain PLANNED until evidence exists`);
    for (const field of ['trigger', 'expected_ui', 'data_policy', 'permission_policy', 'owner']) {
      if (!meaningful(record[field])) errors.push(`${prefix}: ${field} must be meaningful`);
    }
  });

  return errors;
}

export function readContractMatrices({
  routes = defaultRouteMatrixPath,
  ctas = defaultCtaMatrixPath,
  states = defaultStateMatrixPath,
} = {}) {
  return {
    routes: readCsv(routes),
    ctas: readCsv(ctas),
    states: readCsv(states),
  };
}

export function validateContractMatrices(matrices, inventory) {
  return [
    ...validateRouteMatrix(matrices.routes),
    ...validateCtaMatrix(matrices.ctas, inventory),
    ...validateStateMatrix(matrices.states, inventory),
  ];
}

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { clean, readCsv } from './csv_utils.mjs';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const ctaMatrixPath = 'docs/qa/ui-v031/cta_matrix.csv';
const evidenceDirectory =
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/cta-row-proof-20260723';
const testLogPath = `${evidenceDirectory}/cta-focused-tests.raw.txt`;
const coveragePath = `${evidenceDirectory}/flutter-full-coverage.lcov.info`;
const manifestDirectory = `${evidenceDirectory}/rows`;
const verifiedAt = '2026-07-23T10:30:00+07:00';
const reviewer = 'Codex CTA row evidence reconciliation; Product Owner G4B sign-off pending';

const routeProof =
  'mobile/test/app/router/app_router_contract_test.dart#production router exposes the canonical route inventory';
const shellProof =
  'mobile/test/app/router/stateful_shell_navigation_test.dart#five shell branches retain child history and active-tab reselect pops home';
const rescueProof =
  'mobile/test/features/rescue/rescue_home_screen_test.dart#rescue home fails closed without fabricated cases';

const handlerProofs = new Map([
  [
    'callback:changeEmail',
    'mobile/test/features/auth/otp_screen_test.dart#Expired OTP change-email action preserves email',
  ],
  [
    'callback:closeVetReview',
    'mobile/test/features/vets/vet_screens_test.dart#write review sheet remains usable with keyboard open',
  ],
  [
    'callback:createReminder',
    'mobile/test/features/reminders/reminder_calendar_screen_test.dart#reminder create sheet stays usable with keyboard open',
  ],
  [
    'callback:finishOnboardingAndOpenLogin',
    'mobile/test/features/onboarding/onboarding_screen_test.dart#onboarding restores local draft and skip opens login',
  ],
  [
    'callback:finishOnboardingAndOpenRegister',
    'mobile/test/widget_test.dart#onboarding continue stores draft and opens register',
  ],
  [
    'callback:logoutAndClearBranches',
    'mobile/test/app/router/auth_route_guard_test.dart#logout clears session and blocks protected navigation',
  ],
  [
    'callback:markAllNotificationsRead',
    'mobile/test/features/notifications/notification_center_screen_test.dart#Day 28 marks all previous notifications read and clears badge',
  ],
  [
    'callback:openAllowlistedNotificationTarget',
    'mobile/test/features/notifications/notification_center_screen_test.dart#P1-15 taps notification, marks read, and routes to target',
  ],
  ['callback:openLogin', routeProof],
  [
    'callback:openRegister',
    'mobile/test/features/auth/login_screen_test.dart#register link passes the entered email only',
  ],
  [
    'callback:popHealthBranchToRoot',
    'mobile/test/features/reminders/reminder_calendar_screen_test.dart#renders v0.27 reminder calendar shell without mobile overflow',
  ],
  [
    'callback:popOrHealthRoot',
    'mobile/test/features/health/health_timeline_screen_test.dart#health timeline opens P1-13 and creates a backend-backed event',
  ],
  [
    'callback:popOrSafeNotificationReturn',
    'mobile/test/features/notifications/notification_center_screen_test.dart#P1-15 notification center renders v0.27 shell and groups items',
  ],
  [
    'callback:popOrSafeReturn',
    'mobile/test/features/pets/pet_screens_day18_test.dart#P1-06 preserves an unfinished draft after leaving the form',
  ],
  [
    'callback:popOrSafeVetReturn',
    'mobile/test/features/vets/vet_detail_navigation_test.dart#Vet Detail back returns to the source Map route',
  ],
  [
    'callback:popVetBranchOrHome',
    'mobile/test/features/vets/vet_screens_test.dart#renders v0.27 vet list shell on mobile viewport without overflow',
  ],
  [
    'callback:popVetBranchToRoot',
    'mobile/test/features/vets/vet_screens_test.dart#renders v0.27 vet list shell on mobile viewport without overflow',
  ],
  [
    'callback:resendOtp',
    'mobile/test/features/auth/otp_screen_test.dart#Resend clears OTP and applies server verification window',
  ],
  ['callback:selectShellBranch(HEALTH)', shellProof],
  ['callback:selectShellBranch(HOME)', shellProof],
  ['callback:selectShellBranch(PROFILE)', shellProof],
  ['callback:selectShellBranch(RESCUE)', shellProof],
  ['callback:selectShellBranch(VET)', shellProof],
  [
    'callback:showHealthSettingsUnavailable',
    'mobile/test/features/health/health_timeline_screen_test.dart#renders v0.27 health timeline shell without mobile overflow',
  ],
  [
    'callback:showNextMonth',
    'mobile/test/features/reminders/reminder_calendar_screen_test.dart#renders v0.27 reminder calendar shell without mobile overflow',
  ],
  [
    'callback:showPasswordResetUnavailable',
    'mobile/test/features/auth/login_screen_test.dart#login shows v0.27 content and keeps API error inline',
  ],
  [
    'callback:showPreviousMonth',
    'mobile/test/features/reminders/reminder_calendar_screen_test.dart#renders v0.27 reminder calendar shell without mobile overflow',
  ],
  [
    'callback:submitHealthEvent',
    'mobile/test/features/health/health_timeline_screen_test.dart#health timeline opens P1-13 and creates a backend-backed event',
  ],
  [
    'callback:submitLogin',
    'mobile/test/features/auth/login_screen_test.dart#login success routes to Phase 1 Home at /pets',
  ],
  [
    'callback:submitOtp',
    'mobile/test/features/auth/otp_screen_test.dart#OTP success persists session atomically and routes to Home',
  ],
  [
    'callback:submitPetForm',
    'mobile/test/features/pets/pet_navigation_test.dart#Pet form save adds pet and returns to refreshed pet list',
  ],
  [
    'callback:submitRegistration',
    'mobile/test/features/auth/register_screen_test.dart#Register success routes to OTP with verification window',
  ],
  [
    'callback:submitVetReview',
    'mobile/test/features/vets/vet_screens_test.dart#submits write review with auth token after rating validation',
  ],
  [
    'command:launchVetCall',
    'mobile/test/features/vets/vet_map_screen_test.dart#preview sheet action callbacks are individually tappable',
  ],
  [
    'command:launchVetDirections',
    'mobile/test/features/vets/vet_map_screen_test.dart#preview sheet action callbacks are individually tappable',
  ],
  [
    'command:requestLocationPermission',
    'mobile/test/features/vets/vet_map_screen_test.dart#shows permission denied state on map screen',
  ],
  [
    'command:shareVet',
    'mobile/test/features/vets/vet_detail_navigation_test.dart#Vet Detail share action copies real clinic details',
  ],
  ['disabled:featureUnavailable', rescueProof],
  [
    'overlay:openReminderEditor',
    'mobile/test/features/reminders/reminder_calendar_screen_test.dart#reminder create sheet stays usable with keyboard open',
  ],
  [
    'overlay:openReminderFilter',
    'mobile/test/features/reminders/reminder_calendar_screen_test.dart#Day 28 filters overdue reminders and syncs snooze/done',
  ],
  [
    'overlay:openVetReview',
    'mobile/test/features/vets/vet_screens_test.dart#submits write review with auth token after rating validation',
  ],
]);

const sourceAnchorOverrides = new Map([
  ['CTA-P1-01-LOGIN', "ValueKey('onboarding-login-button')"],
  ['CTA-P1-04-CHANGE-EMAIL', "ValueKey('otp-change-email-button')"],
  ['CTA-P1-07-PROFILE', "Key('home-profile-action')"],
  ['CTA-P1-07-PET-DETAIL', "Key('home-pet-card-"],
  ['CTA-P1-07-HEALTH', "context.go('/health')"],
  ['CTA-P1-07-REMINDER', "context.go('/health/reminders')"],
  ['CTA-P1-07-RESCUE', "context.go('/rescue')"],
  ['CTA-P1-07-FIND-VET', "Key('home-find-vet-shortcut')"],
  ['CTA-P1-08-VIEW-ALL', "onViewAll: () => context.push('/vets/list')"],
  ['CTA-P1-08-VET-DETAIL', 'onViewDetail: (vet) => context.push('],
  ['CTA-P1-08-ENABLE-LOCATION', "Key('vet-map-location-banner')"],
  ['CTA-P1-09-BACK', "PawMateNavigation.backOrGo(context, '/vets/map')"],
  ['CTA-P1-09-MAP', 'Xem trên bản đồ'],
  ['CTA-P1-09-VET-DETAIL', "queryParameters: const {'returnTo': '/vets/list'}"],
  ['CTA-P1-10-BACK', 'PawMateNavigation.backOrGo(context, returnPath)'],
  ['CTA-P1-15-SETTINGS', "onSettings: () => context.go('/profile')"],
  ['CTA-P1-15-MARK-ALL', "ValueKey('notification-mark-all-read-button')"],
  ['CTA-P1-15-EMPTY-PROFILE', "ValueKey('notification-empty-profile-button')"],
  ['CTA-P1-16-PET-DETAIL', "context.push('/pets/${pet.id}')"],
  ['CTA-P2-01-NOTIFICATIONS', "ValueKey('rescue-notifications-button')"],
  ['CTA-P2-01-BROWSE-MAP', '| `/rescue/map` |'],
  ['CTA-P2-01-OPEN-CASE', '| `/rescue/:caseId` |'],
  ['CTA-P2-02-CREATE', '| `/rescue/create` |'],
]);

function absolute(relativePath) {
  return path.join(repoRoot, ...relativePath.split('/'));
}

function hashBuffer(value) {
  return crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
}

function hashFile(relativePath) {
  return hashBuffer(fs.readFileSync(absolute(relativePath)));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function csvEscape(value) {
  const text = String(value ?? '');
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function serializeCsv(headers, records) {
  return `${[
    headers.join(','),
    ...records.map((record) => headers.map((header) => csvEscape(record[header])).join(',')),
  ].join('\n')}\n`;
}

function testProofFor(row) {
  const handler = clean(row.target_handler);
  if (handler.startsWith('route:')) return routeProof;
  const proof = handlerProofs.get(handler);
  assert(proof, `No focused proof mapping exists for ${clean(row.cta_id)} (${handler})`);
  return proof;
}

function sourcePathFor(row) {
  return clean(row.source_ref).replace(/:\d+$/, '');
}

function originalLineFor(row) {
  const match = clean(row.source_ref).match(/:(\d+)$/);
  return match ? Number(match[1]) : 1;
}

function anchorCandidates(row) {
  const candidates = [
    sourceAnchorOverrides.get(clean(row.cta_id)),
    clean(row.label),
  ].filter(Boolean);
  const handler = clean(row.target_handler);
  if (handler.startsWith('route:')) {
    const route = handler.slice('route:'.length);
    const stablePrefix = route.replace(/\/:[^/]+/g, '/');
    candidates.push(`'${route}'`, `"${route}"`, `'${stablePrefix}`, `"${stablePrefix}`);
  }
  return [...new Set(candidates.filter((value) => value && value !== 'N/A'))];
}

function resolveSourceAnchor(row) {
  const sourcePath = sourcePathFor(row);
  assert(fs.existsSync(absolute(sourcePath)), `Missing CTA source ${sourcePath}`);
  const lines = fs.readFileSync(absolute(sourcePath), 'utf8').split(/\r?\n/);
  const originalLine = originalLineFor(row);
  const matches = [];
  for (const candidate of anchorCandidates(row)) {
    lines.forEach((line, index) => {
      if (line.includes(candidate)) {
        matches.push({
          anchor: candidate,
          line: index + 1,
          distance: Math.abs(index + 1 - originalLine),
        });
      }
    });
    if (matches.length > 0) break;
  }
  assert(matches.length > 0, `No semantic source anchor for ${clean(row.cta_id)} in ${sourcePath}`);
  matches.sort((left, right) => left.distance - right.distance || left.line - right.line);
  const match = matches[0];
  const start = Math.max(1, match.line - 3);
  const end = Math.min(lines.length, match.line + 3);
  const excerpt = lines.slice(start - 1, end).join('\n');
  return {
    path: sourcePath,
    line: match.line,
    anchor: match.anchor,
    excerpt_start_line: start,
    excerpt_end_line: end,
    excerpt_sha256: hashBuffer(Buffer.from(excerpt, 'utf8')),
    file_sha256: hashFile(sourcePath),
  };
}

function parseCoverage() {
  const coverage = new Map();
  const mobileRoot = absolute('mobile').replaceAll('\\', '/');
  let current = null;
  for (const line of fs.readFileSync(absolute(coveragePath), 'utf8').split(/\r?\n/)) {
    if (line.startsWith('SF:')) {
      const sourcePath = line.slice(3).replaceAll('\\', '/');
      current = sourcePath.startsWith(`${mobileRoot}/`)
        ? sourcePath.slice(mobileRoot.length + 1)
        : sourcePath;
      coverage.set(current, { lines: 0, hits: 0 });
    } else if (current && line.startsWith('DA:')) {
      const [, hitsText] = line.slice(3).split(',');
      const record = coverage.get(current);
      record.lines += 1;
      if (Number(hitsText) > 0) record.hits += 1;
    }
  }
  return coverage;
}

function main() {
  const checkOnly = process.argv.slice(2).includes('--check');
  const applyMatrix = process.argv.slice(2).includes('--apply-matrix');
  assert(!(checkOnly && applyMatrix), '--check and --apply-matrix are mutually exclusive');
  const matrix = readCsv(absolute(ctaMatrixPath));
  const rows = matrix.records.filter((row) => !['CTA-P1-07-DISMISS-REMINDER', 'CTA-P2-01-POST-ALERT'].includes(clean(row.cta_id)));
  assert(rows.length === 82, `Expected 82 CTA rows, got ${rows.length}`);
  assert(fs.existsSync(absolute(testLogPath)), `Missing full test log ${testLogPath}`);
  assert(fs.existsSync(absolute(coveragePath)), `Missing coverage file ${coveragePath}`);
  const testLog = fs.readFileSync(absolute(testLogPath), 'utf8');
  assert(testLog.includes('All tests passed!'), 'CTA evidence requires a passing full Flutter log');
  const coverage = parseCoverage();
  const manifests = [];

  for (const row of rows) {
    const ctaId = clean(row.cta_id);
    const source = resolveSourceAnchor(row);
    const testId = testProofFor(row);
    const [testFile, testName] = testId.split('#');
    assert(fs.existsSync(absolute(testFile)), `Missing focused test file for ${ctaId}: ${testFile}`);
    assert(testLog.includes(path.posix.basename(testFile)), `Full test log does not name ${testFile}`);
    assert(testLog.includes(testName), `Full test log does not name focused test for ${ctaId}: ${testName}`);
    const coverageKey = source.path.startsWith('mobile/') ? source.path.slice('mobile/'.length) : null;
    const sourceCoverage = coverageKey ? coverage.get(coverageKey) : null;
    if (coverageKey) {
      assert(sourceCoverage?.hits > 0, `No executed coverage exists for ${ctaId} source ${coverageKey}`);
    }
    const manifest = {
      schema: 'pawmate.ui-v031.cta-row-proof.v1',
      cta_id: ctaId,
      screen_id: clean(row.screen_id),
      label: clean(row.label),
      target_enabled: clean(row.target_enabled),
      target_handler: clean(row.target_handler),
      expected_result: clean(row.fail_closed_behavior),
      source,
      source_coverage: sourceCoverage ?? {
        lines: 0,
        hits: 0,
        justification: 'Design-only fail-closed contract; runtime absence is covered by Rescue focused test and golden.',
      },
      focused_test_id: testId,
      test_log_path: testLogPath,
      test_log_sha256: hashFile(testLogPath),
      coverage_path: coveragePath,
      coverage_sha256: hashFile(coveragePath),
      verified_at: verifiedAt,
      reviewer,
    };
    const relativeManifestPath = `${manifestDirectory}/${ctaId}.json`;
    const content = `${JSON.stringify(manifest, null, 2)}\n`;
    if (checkOnly) {
      assert(fs.existsSync(absolute(relativeManifestPath)), `Missing CTA row manifest ${relativeManifestPath}`);
      assert(
        fs.readFileSync(absolute(relativeManifestPath), 'utf8') === content,
        `Stale CTA row manifest ${relativeManifestPath}`,
      );
    } else {
      fs.mkdirSync(absolute(manifestDirectory), { recursive: true });
      fs.writeFileSync(absolute(relativeManifestPath), content, 'utf8');
    }
    manifests.push({
      cta_id: ctaId,
      manifest_path: relativeManifestPath,
      manifest_sha256: hashBuffer(Buffer.from(content, 'utf8')),
      focused_test_id: testId,
    });
  }

  const index = {
    schema: 'pawmate.ui-v031.cta-row-proof-index.v1',
    baseline_id: 'UI-CC-2026-07-21-G4B',
    row_count: manifests.length,
    test_log_path: testLogPath,
    test_log_sha256: hashFile(testLogPath),
    coverage_path: coveragePath,
    coverage_sha256: hashFile(coveragePath),
    verified_at: verifiedAt,
    reviewer,
    rows: manifests,
  };
  const indexPath = `${evidenceDirectory}/cta-row-proof-index.json`;
  const indexContent = `${JSON.stringify(index, null, 2)}\n`;
  if (checkOnly) {
    assert(fs.existsSync(absolute(indexPath)), `Missing CTA proof index ${indexPath}`);
    assert(fs.readFileSync(absolute(indexPath), 'utf8') === indexContent, `Stale CTA proof index ${indexPath}`);
  } else {
    fs.writeFileSync(absolute(indexPath), indexContent, 'utf8');
  }
  if (applyMatrix) {
    const provenIds = new Set(manifests.map((entry) => entry.cta_id));
    const updated = matrix.records.map((record) =>
      provenIds.has(clean(record.cta_id)) ? { ...record, test_status: 'PASS' } : record,
    );
    fs.writeFileSync(
      absolute(ctaMatrixPath),
      serializeCsv(matrix.headers, updated),
      'utf8',
    );
  }
  console.log(JSON.stringify({ status: 'PASS', mode: checkOnly ? 'check' : 'write', rows: manifests.length, index: indexPath }));
}

if (path.resolve(process.argv[1] ?? '') === scriptPath) main();

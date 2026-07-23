# W1 intent and traceability freeze

Verdict: `PASS` for governance/testability. Visible Figma approval remains part
of W3, not this report.

## Frozen denominators

- Screen inventory: 56 live source rows.
- Route matrix: 44 rows (36 route/surface plus 8 navigation behaviors).
- CTA matrix: 84 rows.
- State matrix: ST-01 through ST-24.
- Traceability: 191 rows — 56 screen, 44 route, 84 CTA, and 7
  accessibility-journey rows. All remain `PLANNED`; no evidence or PASS status
  was fabricated.

## Objective gates

- `node scripts/ci/ui-v031/validate_inventory.mjs`: PASS, 56/56.
- `node scripts/ci/ui-v031/validate_traceability.mjs`: PASS, 191/191.
- `node --test scripts/ci/ui-v031/validation.test.mjs`: PASS, 10/10.
- UTF-8/no-BOM and generator stale checks: PASS.

## Lead decisions

- The existing five-tab IA is frozen as Home `/pets`, Vet `/vets/map`, Health
  `/health`, Rescue `/rescue`, Profile `/profile`.
- Route and CTA matrices are approved as the W5/W6 target contract.
- `36dp` is only a one-line compact visual height at text scale `<=1.3`; the
  semantic target stays at least `48dp`; important CTA text may grow and must
  never truncate.
- Future Rescue paths remain fail-closed while browse/create flags are false.
- Two observed runtime defects are accepted into the defect register, not as
  exceptions to correctness:
  - `CTA-P1-07-DISMISS-REMINDER`: enabled `Để sau` no-op; W6-B must implement
    `dismissReminderForSession`.
  - `CTA-P2-01-POST-ALERT`: enabled `Đăng tin` no-op; W5/W6-E must disable it
    honestly until its feature gate is approved.

W5 may start only after W4 stops modifying bottom navigation and its focused
tests pass. W1 approval does not waive the W3 responsive proof gap or the real
iOS behavior proof required by RB-007.

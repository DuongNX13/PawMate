# PawMate v0.31 — Test retry and flaky-result policy

Baseline: `ui-v031-20260721-4910aa0e`

## 1. Default rule

The first result is evidence and is never deleted or overwritten. A retry does
not convert a real product failure into a clean PASS.

| Gate type | Automatic retry | Maximum manual retry | Result after retry passes |
|---|---:|---:|---|
| Analyze, lint, unit, widget, provider | 0 | 0 | Not applicable; diagnose or fix, then start a new execution ID |
| Golden/visual compare | 0 | 0 | Not applicable; never update goldens to hide a failure |
| Build/compiler | 0 | 0 | Diagnose or fix, then start a new execution ID |
| API/contract assertion | 0 | 0 | Diagnose or fix, then start a new execution ID |
| Device/emulator transport or harness reset | 0 | 1 | `PASS_WITH_FLAKE`, never clean `PASS` |
| External cloud service transient failure | 0 | 1 after health/status evidence | `PASS_WITH_FLAKE` or `BLOCKED_EXTERNAL` |

## 2. A valid infrastructure retry

One retry is allowed only when all conditions are true:

1. Failure happened outside a product assertion, for example disconnected ADB,
   simulator boot failure, runner loss, or a documented harness reset timeout.
2. No source, test, golden, dependency, configuration, seed, or command argument
   changes between attempt 1 and attempt 2.
3. Attempt 1 log and artifact hashes are retained.
4. The evidence manifest links both attempts using the same execution ID and
   records an infrastructure classification plus reviewer.
5. The retry starts from a cleanly re-established device/service health check.

If any input changes, the next run is a new execution, not a retry.

## 3. Exit criteria after a flaky pass

`PASS_WITH_FLAKE` does not satisfy final G4B by itself. Before sign-off, choose
one of these paths:

- Fix the root cause and produce three consecutive clean runs with separate
  evidence IDs; or
- Obtain a written approver waiver that states scope, expiry/reconsideration
  trigger, first-failure evidence, and residual release risk.

The earlier combined `flutter drive` reset timeout is a historical example, not
a permanent blanket exception for future device failures.

## 4. Golden-specific stop rule

On any golden mismatch:

1. Preserve the generated failure set and log.
2. Compare dimensions, changed-pixel percentage, font/toolchain lock, clock,
   locale, DPR, text scale, image cache, and animations.
3. If the design changed intentionally, obtain approval and create a distinct
   baseline-update execution.
4. Never run `--update-goldens` inside the failed verification execution.

## 5. Reporting

Every attempt records:

- attempt number and immutable evidence ID;
- command and working directory;
- start/end timestamps and exit code;
- failure class: `PRODUCT`, `TEST_HARNESS`, `DEVICE_TRANSPORT`,
  `EXTERNAL_SERVICE`, or `TOOLCHAIN_DRIFT`;
- input hashes and whether any input changed;
- first-failure artifact path and SHA-256;
- reviewer and final status.

# W5 router report — UI-CC-2026-07-21-G4B

Verdict: `IMPLEMENTATION_PASS_ROUTE_MATRIX_PASS_VISUAL_EXIT_BLOCKED`.

The atomic router migration and all executable Route/Navigation behavior rows
pass. W5 cannot receive an unconditional wave exit because the complete visual
harness still reports 30 legacy golden mismatches after the earlier global
theme migration. No golden was updated in W5. Upstream W3 also remains
fail-closed at `15/77` responsive proof frames.

## Delivered router contract

- Five unique `StatefulShellRoute.indexedStack` branches with frozen roots:
  Home `/pets`, Vet `/vets/map`, Health `/health`, Rescue `/rescue`, and Profile
  `/profile`.
- Branch child history survives tab switches; active-tab reselect pops only the
  selected branch to root. A second root reselect scrolls its primary controller
  to offset zero.
- Android root back delegates to the system exit path. Root-pushed screens use
  `CupertinoPage` on iOS and `MaterialPage` elsewhere; the iOS page exposes the
  interactive pop gesture.
- `returnTo` now uses an explicit authenticated-route allowlist. External,
  malformed, public-loop, unknown, and historical alias destinations fail
  closed.
- Unknown routes render an honest in-app fallback rather than a blank screen.
- Rescue flags are centralized and default off. Disabled or not-yet-wired
  Rescue routes never call API or show fabricated data. The activation and
  rollback contract is frozen in `contracts/FEATURE_AVAILABILITY.md`.
- App and router restoration IDs are enabled. No duplicate `GlobalKey` appears
  through branch switching/reselect tests.

## Route traceability

All `RT-001..RT-036` and `RB-001..RB-008` rows have explicit executable
evidence in `W5_ROUTE_TEST_TRACEABILITY.csv`.

## Verification

| Gate | Result | Evidence |
|---|---|---|
| Focused router/auth/nav suite | PASS, `80/80` | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W5/root-verification/focused-router-auth-nav-80-pass.raw.txt` |
| Non-visual behavioral suite | PASS, `293` + `1` intentional skip | `W5/root-verification/behavioral-suite-293-pass.raw.txt` |
| `flutter analyze --no-pub` | PASS | `W5/root-verification/flutter-analyze-pass.raw.txt` |
| v0.31 Android/iOS primitive goldens | PASS, `12/12` | `W5/root-verification/platform-goldens-12-pass.raw.txt` |
| `flutter build bundle --no-pub` | PASS | `W5/root-verification/flutter-bundle-pass.meta.json` (exit code `0`; raw stdout is empty) |
| Day 37/38 protected paths | PASS, `182` files unchanged | `W5/root-verification/protected-paths-pass.json` |
| Full suite including historical goldens | BLOCKED, `323` pass + `1` skip + `30` golden mismatches | `W5/root-verification/full-suite-legacy-golden-fail.raw.txt` |

Approved launcher: `D:/flutter/bin/flutter.bat`.

## Visual blocker classification

All 30 failures are pixel comparisons in historical Day 10/14/18/19/23/24
goldens. The W5 diff changes navigation topology, route actions, restoration,
and tests; it does not change Chocomint colors, typography, spacing, or golden
masters. The new v0.31 primitive golden set remains green. This strongly
classifies the failures as an unsettled pre-W6/W7 rebaseline, but W5 has no
pre-migration visual fingerprint proving byte-identical failure output.
Therefore the strict W5 visual exit remains blocked and no golden is accepted
by inference.

## Rollback and scope integrity

- Rollback snapshot: `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W5/pre-snapshot/`.
- Backend, native configuration, and Day 37/38 protected paths were not changed.
- No commit, push, or remote feature activation was performed.

## Exit recommendation

Accept the W5 implementation and route matrix as technically complete, but do
not mark the formal wave `PASS` until W6 finishes screen migration and W7
reviews/rebaselines the 30 historical goldens, or an approved pre-W5 visual
fingerprint proves an allowed baseline exception. W6 work may proceed only as
conditional implementation work; downstream release gates stay closed.

## W8 defect addendum — 2026-07-21

W8 route sweeping exposed duplicate default Flutter Hero tags on the Health,
Reminder, and Vet branch FABs. The fix returned to the W5 router/component
allowlist and assigned stable tags `health-add-event-fab`,
`reminder-create-fab`, and `vet-list-map-fab`. The production route sweep and
full 411-test suite now pass without Hero or GlobalKey collision. This addendum
does not alter the original conditional W5 verdict.

## Post-W3 revalidation addendum — 2026-07-22 17:18 ICT

W3 is now `PASS`, removing the upstream responsive-proof condition. The exact
focused router/auth/navigation suite was rerun and passed 82/82 with exit code
0:

`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W5/post-w3-revalidation-20260722/codex-rtk-safe-20260722-171546-b6889937.raw.txt`

The historical 30-golden mismatch blocker recorded in the original report is
cleared by the W6 post-rebaseline full suite (`411` passed plus one intentional
skip, exit code 0). No golden was updated during this revalidation. Formal W5
status is therefore promoted to `PASS`; native iOS compile/render remains W7,
and row-level accessibility evidence remains W8/G4C.

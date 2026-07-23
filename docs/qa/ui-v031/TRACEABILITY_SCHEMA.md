# PawMate v0.31 - UI traceability schema

Status: `W1_DENOMINATORS_LOCKED`; the authoritative inventory contains 56 live
Figma source rows. The traceability overlay is populated with `PLANNED` rows
only; no row claims test or evidence completion.

## Purpose and source hierarchy

`ui_v031_traceability.csv` is the execution/evidence overlay for the existing
product traceability source:

1. Product requirements and existing route/API intent remain in
   `docs/qa/pawmate_traceability_matrix_v1.csv`.
2. `docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv` defines the exact
   v0.31 screen denominator and live Figma source identity. Clone identity is a
   separate W3 output and must not mutate this locked source inventory.
3. `ui_v031_traceability.csv` links requirement, state, platform, viewport,
   test, golden/device/design evidence, and final status.
4. `route_matrix.csv`, `cta_matrix.csv`, and `state_matrix.csv` freeze the W1
   route/behavior, enabled action, and ST-01..ST-24 denominators consumed by
   the overlay.

The overlay must not silently replace or contradict the product matrix. If a
conflict is found, stop W1 and resolve it through change control.

## Population rule

- Do not infer live node IDs from filenames or screenshots.
- The authoritative inventory was populated from a read-only live Figma
  inventory and contains 56 unique rows: 16 Phase 1, 16 Phase 2, and 24
  state-reference rows.
- Use one trace row per requirement x state x platform x viewport/text-scale
  proof case. A requirement may therefore appear in multiple rows.
- `trace_id` is the unique row key; `requirement_id` may repeat.
- The committed W1 baseline has 191 `PLANNED` rows: 56 screens, 44
  route/navigation records, 84 CTA records, and 7 accessibility journeys.
- The 24 state IDs are linked by the 24 `STATE` screen-denominator rows; they
  are not counted again as synthetic duplicate traces.

## Authoritative `SCREEN_INVENTORY.csv` fields

| Field | Required | Contract |
|---|---:|---|
| `screen_id` | yes | Stable `P1-01`, `P2-01`, or `ST-01` style ID |
| `phase` | yes | `P1`, `P2`, or `STATE` |
| `screen_name` | yes | Human-readable canonical screen/state name |
| `figma_source_section_id` | yes | Live Figma source-section ID |
| `figma_source_node_id` | yes | Unique live Figma source-frame ID |
| `source_node_name` | yes | Exact live source name |
| `classification` | yes | `RUNTIME_PHASE1`, `STAGED_PHASE2_FLAG_OFF`, `DESIGN_ONLY_PHASE2`, or `STATE_REFERENCE` |
| `runtime_route_or_surface` | yes | Runtime/proposed route, modal surface, route set, or `N/A` |
| `module_owner` | yes | Stable module/role owner, not a guessed person |
| `bottom_nav` | yes | `yes`, `no`, or `contextual` |
| `safe_area_policy` | yes | `system-insets`, `system-insets-and-ime`, `shell-insets`, or `map-edge-to-edge-with-safe-controls` |
| `status` | yes | Locked source status; currently `LOCKED` |

## `ui_v031_traceability.csv` fields

| Field | Required | Contract |
|---|---:|---|
| `trace_id` | yes | Unique `UI031-*` row ID |
| `requirement_id` | yes | Stable v0.31 requirement/behavior ID |
| `source_requirement_id` | conditional | Existing Impact/Test ID where one exists |
| `screen_id` | yes | Must exist in authoritative `SCREEN_INVENTORY.csv` |
| `route_id` | yes | `RT-*`, `RB-*`, or `N/A`; non-`N/A` value must exist in `route_matrix.csv` |
| `route` | yes | Canonical route, action/surface, route set, or `N/A` |
| `state_id` | yes | `ST-01`..`ST-24` from `state_matrix.csv` or `N/A` |
| `platform` | yes | `ANDROID`, `IOS`, `BOTH`, `PLATFORM_NEUTRAL`, or `DESIGN` |
| `viewport` | yes | `<width>x<height>` or `N/A` |
| `text_scale` | yes | `1.0`, `1.3`, `2.0`, or `N/A` |
| `test_id` | conditional | Automated test ID/path or `N/A` |
| `golden_id` | conditional | Golden artifact ID/path or `N/A` |
| `design_node_id` | conditional | Figma clone/proof node ID or `N/A` |
| `device_evidence_id` | conditional | Device/CI evidence ID or `N/A` |
| `expected_result` | yes | Objective observable result |
| `evidence_path` | required for PASS | Repo/CI-relative path under `output-evidence/ui-v031/` |
| `status` | yes | `PLANNED`, `READY`, `PASS`, `FAIL`, `BLOCKED`, or `NOT_APPLICABLE` |
| `cta_id` | conditional | Stable CTA ID or `N/A` |
| `cta_enabled` | yes | `TRUE`, `FALSE`, or `N/A` |
| `handler_ref` | required when CTA enabled | Real route/callback/command reference |
| `feature_flag` | conditional | Flag ID or `N/A` |
| `accessibility_journey_id` | conditional | TalkBack/VoiceOver journey ID or `N/A` |
| `owner` | yes | Responsible role/module |
| `notes` | no | Exception, risk, dependency, or approved `change_control=<ID>` reference |

## Stable ID conventions

- Behavior/requirement: `UI031-NAV-*`, `UI031-CTA-*`, `UI031-STATE-*`,
  `UI031-A11Y-*`, `UI031-VIS-*`, or `UI031-PLATFORM-*`.
- Trace row: `UI031-TRACE-<screen>-<sequence>`.
- CTA: `CTA-<screen>-<action>`.
- Test: checked-in test name/path; do not invent a passing test ID before the
  test exists.
- Evidence: `<baseline-id>/<wave>/<platform>/<artifact-id>` in its manifest,
  with a corresponding repo/CI-relative artifact path.
- Product-approved design delta: retain the frozen row identity and record
  `change_control=<stable-id>` in `notes`; never rewrite the source inventory.

## Measurable denominators

- **Screen completeness:** exactly 56 trace rows marked `screen-denominator`,
  one for every authoritative inventory row.
- **Route/navigation completeness:** exactly 44 trace rows marked
  `route-denominator`: 36 route/surface records plus 8 cross-cut behaviors.
- **CTA integrity:** exactly 84 trace rows linked one-to-one to
  `cta_matrix.csv`. Every target-enabled CTA has an actionable handler; every
  target-disabled CTA has an explicit `disabled:` handler and fail-closed rule.
- **State completeness:** all 24 IDs from `state_matrix.csv` referenced at
  least once.
- **Accessibility completeness:** 7 named TalkBack/VoiceOver journeys.
- **Current W1 trace total:** 191 rows; all 191 are `PLANNED`.
- **Figma responsive completeness:** 77 v0.32 proof frames.
- **Runtime responsive goldens:** 71.
- **Platform primitive goldens:** 12.
- **Minimum runtime goldens:** 83, not 71 plus duplicated canonical 390 rows.
- **Behavior coverage:** all required non-`NOT_APPLICABLE` trace rows.
- **Historical-node preservation:** every source-node row in the frozen source
  manifest, compared by ID/name/parent/metadata fingerprint.
- **TalkBack/VoiceOver coverage:** the explicitly frozen accessibility journey
  IDs, never an undefined phrase such as "main journeys".

## Status transitions

- `PLANNED`: requirement is known; implementation/test/evidence may not exist.
- `READY`: inputs and implementation exist; proof is ready to run.
- `PASS`: expected result observed, proof identifier exists, portable evidence
  path exists, and the artifact is hash-listed.
- `FAIL`: expected result not observed.
- `BLOCKED`: proof cannot run because an external/input dependency is missing.
- `NOT_APPLICABLE`: justified in `notes`; it is excluded from the denominator.

No row may jump directly from `PLANNED` to `PASS` without a real proof ID and
evidence artifact.

## Determinism and privacy

- Freeze locale, timezone/clock, font loading, device-pixel ratio, text scale,
  network, location, permission service, map canvas, data seed, and animation.
- Use deterministic map placeholders in goldens; do not use live map tiles.
- Use test accounts and synthetic data. Do not store a real token, email,
  address, precise Rescue location, or identifiable person/property.
- Secret-scan and redact evidence before upload.
- Synthetic Rescue imagery belongs only to design/test fixtures and must not be
  production-bundled.

## Validation commands

From the repository root:

```powershell
node scripts/ci/ui-v031/validate_inventory.mjs
node scripts/ci/ui-v031/generate_traceability.mjs --check
node scripts/ci/ui-v031/validate_traceability.mjs
node --test scripts/ci/ui-v031/validation.test.mjs
```

`validate_traceability.mjs` must pass without `--allow-empty`; it validates the
three matrices, referential integrity, and every denominator. To regenerate
the initial W1 `PLANNED` overlay after an approved matrix change:

```powershell
node scripts/ci/ui-v031/generate_traceability.mjs
```

`--allow-empty` remains only for an explicit temporary skeleton in isolated
tests. It is not an acceptable committed W1 state. Regeneration intentionally
resets rows to `PLANNED`; do not run it over later evidence-bearing execution
rows without an approved migration.

# PawMate v0.31 - Wave contracts W0-W9

Status: `DRAFT_GOVERNANCE_BASELINE`

This document turns the v0.31 UI rework into auditable wave contracts. It does
not reopen or overwrite any historical Day result. A wave may advance only
when its objective PASS conditions are met and its evidence manifest is
complete.

## Global execution rules

- Preserve the existing information architecture:
  `Home / Vet / Health / Rescue / Profile`.
- Keep Phase 2 screens that are not implemented by the roadmap marked
  `DESIGN_ONLY`. Before Day 39, Rescue remains staged/unavailable; Day 40 is
  the first point at which Create Lost Alert may be enabled.
- Store portable evidence under
  `output-evidence/ui-v031/<baseline-id>/<wave>/`. A local absolute path may be
  recorded as secondary metadata, never as the only evidence locator.
- Every wave must produce `wave-manifest.json` containing: wave, baseline ID,
  commit SHA, toolchain lock hash, allowlist, denylist, commands, start/end
  timestamps, exit codes, artifact paths and SHA-256 hashes, executor,
  reviewer, test-data-only flag, and redaction status.
- Every exception must have an ID, baseline fingerprint, owner, impact,
  expiry/reconsideration trigger, and evidence. P0/P1 defects cannot be waived
  for a wave PASS.
- No retry is allowed for analysis, compilation, deterministic unit/contract
  tests, or golden comparison. A device/CI infrastructure operation may be
  retried once only after retaining the first failure and registering a
  `FLAKE-*` exception. A retry never erases the first result.
- `--update-goldens` is forbidden in QA/sign-off waves. Golden masters may be
  changed only in the owning implementation wave after an approved visual
  diff.
- Flutter coverage means line coverage. The target is global production line
  coverage >=80% and changed production line coverage >=90%. Generated l10n,
  `*.g.dart`, `*.freezed.dart`, and plugin registrants are excluded by the
  checked-in coverage validator. Branch coverage is not claimed unless a
  separate supported tool is introduced and locked.
- The UI lane must not write to Day 37/38 backend paths. A protected-path hash
  change caused by a concurrent Day 37/38 owner is acceptable only when the
  owner attribution and evidence are attached; it must never be staged as part
  of the UI delivery.
- Approvers are roles, not invented people. The Codex lead may approve
  objective technical gates. The user/Product Owner approves flow/visible
  design at W1 and W3, and final acceptance at W9. The Day 37/38 owner alone may
  approve a protected-path exception.

## Protected historical and backend sources

Unless a later contract explicitly narrows an exception, these paths are
denylisted throughout the rollout:

- Figma source nodes `442:2`, `444:3050`, `447:4266`, and all v0.27/v0.28
  historical sections. Do not rename, move, reparent, lock, or change their
  metadata.
- `backend/**`.
- `docs/engineering/day34*` through `docs/engineering/day38*`.
- `docs/qa/phase2/day34*` through `docs/qa/phase2/day38*`.
- Historical ledger rows and historical UI reports.

## Toolchain observation to reverify at W0

The following values were observed on 2026-07-21 and are not a substitute for
the W0 lock artifact:

| Surface | Observed value |
|---|---|
| Flutter | 3.41.6 stable, revision `db50e20168` |
| Dart | 3.11.4 |
| Java | Temurin 17.0.19 |
| Android Gradle Plugin | 8.11.1 |
| Gradle wrapper | 9.1.0 |
| Kotlin plugin | 2.2.20 |
| `mobile/pubspec.lock` SHA-256 | `98FCD39FCC334F491ED9212B8738B60001B92E8B6D586509C325CB6F22F8B6B7` |
| flutter_map / geolocator / image_picker | 8.3.0 / 14.0.2 / 1.2.1 |
| Font bundle | Be Vietnam Pro 400/500/600/700 |

Codemagic currently uses floating `flutter: stable`, `xcode: latest`, and
`cocoapods: default`. W0 must discover a proven simulator combination; W7 must
pin supported values before sign-off. If Figma/Stitch/MCP does not expose a
version, record `not_exposed`, capability metadata, project/file IDs, timestamp,
prompt hash, and output IDs rather than inventing a version.

## W0 - Source lock, screen inventory, toolchain, and baseline

**Definition of Ready / required input**

- Repository and Figma source are readable.
- Current commit and dirty-worktree state can be recorded.
- No UI mutation has started under this change-control ID.

**Allowlist**

- `docs/design/pawmate-v031-platform-ui/**`
- `docs/qa/ui-v031/**`
- `scripts/ci/ui-v031/**`
- `output-evidence/ui-v031/**`
- A new PawMate knowledge-log checkpoint

**Denylist**

- All production code and native configuration.
- Backend and historical sources listed above.
- Figma writes of any kind.

**Required output**

- Scoped source backup and binary patch for in-scope tracked files.
- Classified dirty-file manifest; do not archive the entire untracked tree.
- Authoritative
  `docs/design/pawmate-v031-platform-ui/SCREEN_INVENTORY.csv` with exactly 56
  verified live rows: 16 Phase 1, 16 Phase 2, and 24 state-reference rows.
- Toolchain lock, package/font inventory, protected-path manifest, baseline
  result fingerprints, evidence/privacy policy, and exception registry.

**Required commands**

- Repo root: `git rev-parse HEAD`, scoped `git status --porcelain=v1`, scoped
  `git diff --binary`, and SHA-256 generation.
- Repo root: `flutter --version`, `dart --version`, `flutter doctor -v`,
  `java -version`, and Gradle wrapper metadata/version.
- Repo root:
  `powershell -NoProfile -File scripts/ci/ui-v031/toolchain/verify-toolchain-preflight.ps1`.
- Create the protected baseline with
  `scripts/ci/ui-v031/protected/verify-protected-paths.ps1 -Mode Snapshot` and
  capture its stdout at the approved evidence root as documented in
  `contracts/PROTECTED_PATHS.md`; never write it into a protected source
  directory.
- `mobile/`: `flutter pub get`, `flutter analyze`, `flutter test`,
  `flutter test test/visual`, and `flutter build apk --debug`.
- `backend/`: `npm run lint`, `npm test`, `npm run build`,
  `npm run test:coverage`, and `npm audit --omit=dev` as read-only regression
  evidence for the UI lane.
- Trigger Codemagic workflow `ios-appetize-simulator-smoke` and retain its
  environment/version metadata.

**PASS / Definition of Done**

- All 56 live screen/source rows are unique, classified, and validated against
  the authoritative inventory.
- Every dirty UI/native file is classified as owned, protected, generated, or
  unrelated.
- A restore spot-check matches recorded hashes.
- Every baseline result has an objective fingerprint and no production file
  was changed by W0 governance work.

**FAIL / stop condition**

- Backup or hash mismatch, source-node access failure, an unclassified
  overlapping file, or a historical source mutation.

**Rollback point**

- Scoped W0 archive plus manifest. Cache/build/temp directories are excluded.

**Approver**

- Codex lead.

**Known exceptions**

- W0 may PASS as a baseline-capture wave with an existing test failure only
  when it has a stable fingerprint and exception ID. A signing-only iOS failure
  blocks G4C real-device proof, not the G4B simulator gate.

## W1 - Intent, design contract, and traceability freeze

**Definition of Ready / required input**

- W0 PASS, source lock available, and the existing five-tab IA confirmed.
- The authoritative inventory has 56 verified live rows; no guessed Figma node
  IDs are allowed.

**Allowlist**

- v0.31 design/governance documents, QA matrices, and validators.
- Read-only Figma inventory operations.

**Denylist**

- Flutter/native/backend code and all Figma writes.

**Required output**

- UI/UX brief, `DESIGN.md`, route/CTA/state matrices, screen inventory,
  `ui_v031_traceability.csv`, token/contrast contract, runtime versus
  `DESIGN_ONLY` classification, and generation-call budget.

**Required commands**

- Run inventory validator and traceability referential-integrity validator.
- Run the checked-in contrast/token validator when `DESIGN.md` is populated.
- Read Figma metadata for screen, component, variable, style, font, and node
  counts without mutation.

**PASS / Definition of Done**

- 56/56 verified inventory rows with no duplicate screen/source node.
- Every enabled CTA maps to a real route or callback contract.
- Every percentage/`100%` statement has a defined denominator in traceability.
- No orphan screen, requirement, state, test, golden, or evidence ID.
- CTA sizing is internally consistent: 36dp may be a one-line visual minimum;
  touch target is >=48dp; wrapping/accessibility text grows without a 52dp cap.

**FAIL / stop condition**

- Missing/duplicate source mapping, unapproved IA change, orphan route/CTA, or
  a design rule that cannot satisfy text scale 2.0.

**Rollback point**

- W1 governance-document snapshot.

**Approver**

- User/Product Owner for flow and visible design; Codex lead for testability.

**Known exceptions**

- An MCP version that is not exposed is recorded as `not_exposed`; it does not
  authorize skipping output-node and prompt-hash evidence.

## W2 - Stitch and Image Gen exploration

**Definition of Ready / required input**

- W1 PASS, prompt hashes frozen, generation stop-loss approved, and the new
  Stitch project verified `PRIVATE`.

**Allowlist**

- New Stitch project and design system.
- `docs/design/pawmate-v031-platform-ui/generated/**`.
- Synthetic image fixtures under design/test-only paths.

**Denylist**

- Historical Stitch/Figma projects, Flutter production code, backend, and
  production-bundled synthetic fixtures.

**Required output**

- Five named Stitch pilots, two privacy-safe Rescue WebP fixtures, and a
  prompt/result/rejection manifest.

**Required commands**

- Authorized Stitch/Image Gen calls within the nine-call cap.
- `ffmpeg` metadata-stripping/conversion, `ffprobe` dimension/size inspection,
  file hashing, and manual visual/privacy review.

**PASS / Definition of Done**

- At most nine model calls; all hard locks pass.
- Each image is one animal, 4:3, no larger than 1024px on the long edge, no
  larger than 250KB, metadata-free, and contains no text or identifiable
  person/property/location.
- Synthetic fixtures cannot enter the production asset bundle.

**FAIL / stop condition**

- Non-private project, repeated IA violation on the second pilot, privacy or
  anatomy failure, or budget overrun.

**Rollback point**

- Abandon only the new project/assets; never mutate or delete historical work.

**Approver**

- Codex lead/design reviewer.

**Known exceptions**

- One reserve call may be used for either one Stitch edit or one image regen,
  not both.

## W3 - Figma v0.31/v0.32

**Definition of Ready / required input**

- W2 PASS and a verified source-to-target inventory.

**Allowlist**

- New clone snapshot and new v0.31/v0.32 sections only.

**Denylist**

- All historical nodes. No rename, move, reparent, lock, or metadata change.

**Required output**

- A newly cloned v0.29 snapshot, 56 v0.31 screens, 77 responsive proof frames,
  semantic variables/components, source-to-clone node map, and font audit.

**Required commands**

- Incremental Figma MCP writes. After each batch, read metadata and capture a
  screenshot; run node-map, count, font, and overflow validators.

**PASS / Definition of Done**

- 56/56 one-to-one clones, 77/77 responsive proof frames, unsupported fonts =
  0, no overflow, and historical names/parents/metadata unchanged.

**FAIL / stop condition**

- Any historical mutation, count/map mismatch, unsupported font, or use of a
  Stitch reference as the canonical runtime source.

**Rollback point**

- Discard only the newly created section IDs.

**Approver**

- User/Product Owner.

**Known exceptions**

- Future Phase 2 screens remain clearly labeled `DESIGN_ONLY`.

## W4 - Flutter design-system foundation

**Definition of Ready / required input**

- W3 approved, toolchain lock active, and baseline exceptions reviewed.

**Allowlist**

- `mobile/lib/app/theme/**`
- Scoped `mobile/lib/app/pawmate_app.dart`
- `mobile/lib/core/widgets/**`
- Flutter l10n configuration/generated inputs, `mobile/pubspec.*`
- Foundation tests and goldens

**Denylist**

- Router, feature business/data logic, native Android/iOS, and backend.

**Required output**

- Semantic/status tokens, adaptive primitives, safe-area policy, l10n
  foundation, and 12 platform primitive goldens.

**Required commands**

- `flutter pub get`, `flutter analyze`, focused theme/widget/accessibility
  tests, platform primitive golden tests, and full widget smoke.

**PASS / Definition of Done**

- Component states, semantics, focus, contrast, and reduced-motion behavior
  pass; 12/12 platform primitive goldens pass; no raw brand color exists outside
  token sources; important CTA text never truncates.

**FAIL / stop condition**

- Accessibility target failure, CTA overflow/truncation, or route behavior
  changing outside scope.

**Rollback point**

- W4-pre scoped snapshot.

**Approver**

- Codex lead.

**Known exceptions**

- Light phone portrait only; dark mode and tablet are outside scope.

## W5 - Atomic router and tab-shell migration

**Definition of Ready / required input**

- W4 tests PASS, Route/CTA matrix approved, baseline deep-link tests retained,
  and every dirty router change classified.

**Allowlist**

- `mobile/lib/app/router/**`
- Exact app-shell/bottom-nav files and a frozen list of navigation call sites
- Router/nav tests and test support

**Denylist**

- Feature data/domain logic, native config, and backend.

**Required output**

- Indexed stateful shell, branch keys, reselect/back/deep-link behavior,
  centralized feature availability, and route tests.

**Required commands**

- Focused router/auth/nav tests, `flutter analyze`, full `flutter test`, and the
  visual harness without golden updates.

**PASS / Definition of Done**

- Every route behavior row has a passing test. Auth redirect, `returnTo`, deep
  links, branch restoration, tab reselect, Android root-back, and iOS pushed
  route behavior pass. There is no GlobalKey collision or enabled route without
  a handler.

**FAIL / stop condition**

- Route-matrix mismatch, auth loop, lost branch state, broken tab history, or
  an unsettled golden harness.

**Rollback point**

- W5-pre router/shell snapshot.

**Approver**

- Codex lead.

**Known exceptions**

- Future routes must fail closed to an honest unavailable screen.

## W6 - Module migration, subgates A-E

**Definition of Ready / required input**

- W5 PASS and each module has approved design/state fixtures.

**Allowlist**

- A: Auth/Onboarding presentation/application and scoped tests.
- B: Pet/Home/Profile presentation/application and scoped tests.
- C: Vet presentation/application/data adapters and scoped tests.
- D: Health/Reminder/Notification presentation/application and scoped tests.
- E: Rescue staged presentation and scoped tests.

**Denylist**

- Backend Rescue, native config, and router/theme outside an approved
  integration fix.

**Required output**

- Runtime Phase 1 UI, staged Rescue UI, module reports, and 71 runtime
  responsive goldens.

**Required commands**

- Focused tests, module goldens, and analyze after each A-E subgate; full test
  and visual suites at wave exit.

**PASS / Definition of Done**

- A-E each pass independently; 71/71 runtime responsive goldens pass; no
  enabled CTA is a no-op; state/overflow/keyboard/text-scale rows have evidence;
  Rescue browse/create remain disabled.

**FAIL / stop condition**

- P0/P1, overflow, route/state mismatch, or need for an unapproved backend/API
  schema change.

**Rollback point**

- Per-module W6-A through W6-E checkpoints.

**Approver**

- Codex lead; user approval only if implementation departs from W3.

**Known exceptions**

- Future Phase 2 stays `DESIGN_ONLY`; Day 39/40 flags remain off.

## W7 - Native branding and platform configuration

**Definition of Ready / required input**

- W6 PASS, native files backed up, and iOS simulator baseline compilation clean
  or its blocker resolved.

**Allowlist**

- Android manifest/resources and scoped Gradle configuration.
- iOS plist/project/assets.
- `codemagic.yaml` and icon/splash configuration.

**Denylist**

- Feature/router/business logic and backend.

**Required output**

- PawMate name, portrait/iPhone-only settings, permissions, icons/splash, and
  pinned CI toolchain values.

**Required commands**

- Analyze/tests, Android debug build/install, native config validators, and the
  Codemagic iOS simulator workflow.

**PASS / Definition of Done**

- Android build/install and iOS simulator compile/render pass; permissions,
  orientation, display name, icons, splash, and pinned CI values match W0/W3.

**FAIL / stop condition**

- Compilation regression or native configuration mismatch.

**Rollback point**

- W7-pre native snapshot.

**Approver**

- Codex lead.

**Known exceptions**

- Signing-only failure blocks G4C, not G4B. Compile/test failure blocks W7 and
  G4B. CI outage is not a product regression but still prevents G4B PASS.

## W8 - Cross-platform QA

**Definition of Ready / required input**

- W7 PASS, traceability frozen, golden masters approved, and device/runtime
  matrix available.

**Allowlist**

- Tests, evidence, and defect reports. A defect fix returns to its owning
  wave's allowlist.

**Denylist**

- Direct golden updates to hide differences and all protected backend paths.

**Required output**

- Completed traceability, Android/iOS evidence, at least 83 goldens, coverage,
  accessibility/performance reports, and defect register.

**Required commands**

- `flutter analyze`, full tests, coverage, visual suite, Android build/device
  runs on API 34/35/36, Codemagic iOS simulator, and backend lint/test/build/
  coverage/audit smoke.

**PASS / Definition of Done**

- At least 83/83 goldens: 71 responsive runtime plus 12 Android/iOS primitive
  variants. Every required trace row passes, P0/P1 = 0, coverage thresholds
  pass, no unexpected visual diff remains, and required TalkBack journeys pass.

**FAIL / stop condition**

- Missing evidence, accessibility/coverage failure, P0/P1, or protected-path
  violation.

**Rollback point**

- Last accepted checkpoint of the wave that owns the defect.

**Approver**

- Codex lead acting as QA owner.

**Known exceptions**

- Real-iPhone/real-VoiceOver proof may be deferred to G4C and must not be
  reported as verified.

## W9 - Append-only sign-off and handoff

**Definition of Ready / required input**

- W8 PASS, evidence manifest complete, redaction scan pass, and protected-path
  reconciliation complete.

**Allowlist**

- G4B addendum, evidence manifest, roadmap impact report, append-only status
  entry, and knowledge-log checkpoint.

**Denylist**

- Production code, historical rows/reports/Figma, and Day 37/38 files.

**Required output**

- G4B report, portable evidence manifest, source/clone map, command summary,
  known gaps, and explicit Day 39 readiness recommendation.

**Required commands**

- Final allow/deny diff, artifact hash verification, secret/PII scan,
  `scripts/ci/ui-v031/protected/verify-protected-paths.ps1 -Mode Verify`, and
  final analyze/test/golden/build smoke.

**PASS / Definition of Done**

- Evidence is repo/CI-relative and hash-valid, contains no secrets/PII,
  historical state is untouched, protected changes are absent or owner-
  attributed, G4B is signed, and G5A is separately verified before Day 39.

**FAIL / stop condition**

- Manifest mismatch, unredacted evidence, P0/P1, historical overwrite, or an
  unattributed protected-path change.

**Rollback point**

- W8 accepted checkpoint; only W9 documents are rolled back.

**Approver**

- User/Product Owner and Codex lead.

**Known exceptions**

- G4C real-iPhone proof may be deferred explicitly. Production rollout and
  monitoring are `OUT_OF_SCOPE` unless separately authorized.

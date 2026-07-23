# W8 Cross-Platform QA Report

Baseline: `UI-CC-2026-07-21-G4B`
Execution date: `2026-07-21`; latest audit: `2026-07-22`
Verdict: `PARTIAL_PASS / FAIL_CLOSED`

## Outcome

All executable Flutter, Android, backend, golden, coverage, and protected-path
gates pass. Three product/asset defects and two environment/test-harness defects
discovered by W8 were fixed and regression-tested. No open P0/P1 product defect
was found by the executable runtime checks.

W8 is not formally complete because its Definition of Ready inherited an
unpassed W7, and its Definition of Done still lacks the post-change iOS simulator
run, 77/77 W3 responsive proof, seven complete TalkBack journeys, and
evidence-backed status transitions for all 191 trace rows.

## Gate results

| Gate | Result | Evidence |
|---|---|---|
| Flutter analyze | PASS, zero issues | `W8/onboarding-rails-removal/03-flutter-analyze-no-pub-pass.raw.log` |
| Full Flutter tests | PASS, 411 + 1 intentional skip | `W8/onboarding-rails-removal/04-flutter-full-coverage-pass.raw.log` |
| Global line coverage | PASS, 82.45% >= 80% | `W8/onboarding-rails-removal/06-coverage-contract-pass.log` |
| Changed-source coverage | PASS, 95.89% >= 90%; P1-01 source is verified as deletion-only (`+0/-42`) | Same coverage contract |
| W4/W5/W6 group coverage | PASS; 94.31 / 98.99 / 100 / 93.10 / 100 / 100 / 96.30 | Same coverage contract |
| Runtime goldens | PASS, 71/71 | `W8_RUNTIME_GOLDEN_HASHES.json` |
| Platform primitive goldens | PASS, 12/12 | `W8/onboarding-rails-removal/07-golden-contract-83-pass.log` |
| Total golden contract | PASS, 83/83 | Same validator |
| Android API 34/35/36 | PASS; P1-01 successor recaptured on all three APIs | `W8_DEVICE_MATRIX.csv` |
| Final Android APK | PASS; 205,311,745 bytes; SHA-256 `73F48FBAF04FF10AC3D88C74C4352CE78D4EF319A46E70C5737CCF7806B35075` | `W8/onboarding-rails-removal/pawmate-ui-v031-p1-01-no-rails-debug.apk` |
| Backend lint/test/build/coverage/Prisma/audit | PASS | `W8/backend/`; 28 test suites and 212 tests pass, three suites/eight tests remain intentionally skipped; audit reports zero vulnerabilities |
| Toolchain preflight | PASS_WITH_KNOWN_GAPS; 33 checks, zero required failures | `W9/pre-signoff/toolchain-preflight-p1-01-no-rails.json` |
| Day 37/38 protected paths | PASS; 182 files, 0 added/removed/modified | `W9/pre-signoff/protected-final.json` |
| Evidence hash validation | PASS, 370 artifacts and 519 source-snapshot files | `W9/pre-signoff/w8-evidence-manifest-validation.json` |
| Secret/PII scan | PASS | `W8/redaction-scan.json`; raw originals remain in the external Codex evidence store and repo copies use portable path tokens |
| Post-change iOS simulator | NOT RUN / BLOCKING | `W7_NATIVE_REPORT.md` |
| Trace execution status | BLOCKED, 191 PLANNED | `W8_TRACEABILITY_STATUS.md` |
| Seven TalkBack journeys | BLOCKED | `W8_ACCESSIBILITY_PERFORMANCE_REPORT.md` |
| W3 responsive proof | PASS; 77/77, zero unsupported fonts, zero geometry violations | `W3_POST_WRITE_AUDIT_2026-07-22.json` |

## Approved onboarding visual correction

The source raster contained its own progress rails, camera control, and bottom
panel edge. The original asset and five original onboarding masters were copied
to W8 evidence before modification. ImageGen removed only those baked controls,
the image was resized deterministically to `390x334`, and the new screen was
inspected at 320x568, 390x844, and Android APIs 34/35/36.

The pre-update golden run failed all five onboarding viewports as expected and
was retained. Only then were those five masters updated. A complete nine-file
runtime comparison passed, and the W8 hash manifest records the exact approved
delta instead of rewriting the W6 historical manifest.

### Product Owner P1-01 no-rails successor

Change control `UI031-CHANGE-W8-P1-01-NO-RAILS-02` removes the three remaining
Flutter progress rails. The clean raster did not change. Figma v0.31 frame
`453:7378` now uses clean image node `459:11570` and separate photo-picker nodes
`459:11571`/`459:11572`; old image node `453:7383` is hidden for rollback.

The Flutter rail overlay and obsolete rail classes were removed. Targeted
function tests pass `8/8`, including `320x568` at text scale `2.0`. A pre-update
golden comparison failed exactly the five P1-01 artifacts (`0.47%` to `0.72%`
pixel delta); those five prior masters and diffs were archived, then only those
five masters were updated. Targeted comparison passes `5/5` and the complete
visual suite passes `101/101`. The new golden manifest parents the preserved
`W8_RUNTIME_GOLDEN_HASHES_ONBOARDING_RASTER_FIX_01.json` rather than rewriting
that historical correction. The successor APK was rebuilt after all tests and
rendered on Android APIs 34, 35, and 36 with no rails. API 36 also retains a
separate TalkBack-focus and text-scale-2.0 screenshot; this is useful component
evidence but does not replace the seven journey-level accessibility gates.

## Evidence portability

`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json`
contains 370 hash-verified repo-relative artifacts and binds 519 source-snapshot
files. It parents the archived 313-artifact manifest through its exact path,
SHA-256, evidence ID, and baseline ID. Its validator also checks that the
manifest artifact set exactly equals every non-empty file currently present in
the W8 evidence root, in addition to verifying bytes and hashes. The source
snapshot covers the changed app, tests, QA/design contracts, CI scripts, native
branding files, and W3 live-audit artifacts.
Copied text logs were redacted mechanically to replace machine-local paths with
`<USER_HOME>`, `<REPO_ROOT>`, or `<CODEX_OUTPUT_EVIDENCE>`; canonical raw logs
remain preserved outside the repository.

## Exit recommendation

Do not sign W8 or open W9 final sign-off. Resolve the four evidence/upstream
gates above, rerun the post-change iOS and named accessibility journeys, attach
proof to all trace rows, then repeat the final manifest/protected-path checks.

## Approval update — 2026-07-22 16:41 ICT

The Product Owner approved W2's no-use exception, the exact 77-row W3 matrix,
the v0.31/v0.32 allowlist, SRS v1.1 adoption and the G4C VoiceOver split.
Accordingly, the W3 upstream blocker is removed and the seven real-device
VoiceOver journeys are no longer in the G4B denominator. W8 is still
`FAIL_CLOSED` until W3 post-write proof, W7 post-change iOS compile/render and
the remaining non-VoiceOver trace rows are rerun.

Approval evidence: [Product Owner approval record](../../management/pawmate_product_owner_approval_2026-07-22.md).

## Post-W3 revalidation addendum — 2026-07-22 17:24 ICT

W3 post-write is now `PASS` at 77/77, so it is no longer an open W8 blocker.
The updated trace generator/CSV applies the approved G4C split to the seven
accessibility rows; all 191 rows remain structurally valid but `PLANNED` until
row-level evidence is attached. Deterministic checks are green:

| Gate | Result | Evidence |
|---|---|---|
| Traceability validator | `PASS`, 191 rows, 11 validator tests | `node scripts/ci/ui-v031/validate_traceability.mjs` |
| Golden contract | `PASS`, 83/83 | `node scripts/ci/ui-v031/validate_golden_contract.mjs` |
| Changed/global coverage | `PASS`, 95.89% / 82.45% | `node scripts/ci/ui-v031/validate_mobile_coverage.mjs` |
| Native branding | `PASS`, 33/33 | `node scripts/ci/ui-v031/validate_native_branding.mjs` |
| Portable W8 manifest | `PASS`, 370 artifacts / 529 source files, redaction PASS; exact bytes and hashes are checked by the manifest validator | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json` |

W8 remains `PARTIAL_PASS / FAIL_CLOSED` solely for post-change iOS proof and
row-level Android TalkBack evidence; VoiceOver is a G4C follow-up.

## Successor current-state overlay — 2026-07-22 18:28 ICT

This overlay supersedes the historical `33/33` native result, the
`191 PLANNED / 0 PASS` trace result and the statement that only iOS and
TalkBack remained. No current manifest artifact/file counts are claimed here;
the portable manifest must be regenerated after all current evidence and
governance changes are final.

| Gate | Current result |
|---|---|
| W3 matrix/hash chain | `PASS`: approved bytes and executed matrix reconciled; 77 rows (`62` created, `15` inherited, `0` unexpected) |
| Native branding | `PASS`: 50 checks, 0 failures (`46` unique IDs + `4` repeated asset checks) |
| Trace execution | `PARTIAL_PASS`: 102/191 `PASS`; 89/191 `PLANNED` (`82` CTA + `7` Android TalkBack) |
| Trace validator | `PASS`: 16/16 validator tests |
| Fresh bound suites | runtime `73/73`, route `108/108`, Rescue `6/6` |
| Post-change iOS compile/render | `PENDING` |
| VoiceOver | G4C follow-up, outside G4B |

W8 remains `PARTIAL_PASS / FAIL_CLOSED`. The remaining row-level CTA and
Android TalkBack proof, post-change iOS proof, final protected-path/evidence
reconciliation, and downstream sign-off must be completed before G4B can pass.

## Terminal revalidation overlay — 2026-07-22 19:05 ICT

This overlay supersedes only the stale counts and protected-path blocker in the
preceding checkpoint; historical results remain audit evidence.

| Gate | Terminal result |
|---|---|
| Flutter full suite | `PASS`: 411 tests + 1 intentional skip |
| Flutter analyze | `PASS`: no issues |
| Trace validator | `PASS`: 17/17 tests; 191 rows structurally valid |
| Trace execution | `PARTIAL_PASS`: 102 PASS / 89 PLANNED (`82` CTA + `7` Android TalkBack) |
| Golden contract | `PASS`: 71 runtime + 12 platform = 83 |
| Coverage | `PASS`: 82.45% global / 96.20% changed lines |
| Native/static contract | `PASS`: 50 checks / 0 failures |
| Protected paths | `PASS_WITH_APPROVED_OWNER_DELTA`: 38 added + 12 modified + 0 removed |
| Post-change iOS compile/render | `PENDING` |

The HOME TalkBack experiment remains negative evidence, not a PASS transition:
six XML dumps are byte-identical and no distinct accessibility target movement
is proven. Therefore protected reconciliation is no longer a blocker, while W8
still remains `PARTIAL_PASS / FAIL_CLOSED` for 89 row-level proofs and the
post-change iOS gate.

## Row-level and Android delivery closure — 2026-07-23 11:59 ICT

This overlay supersedes the remaining `89` row-level blockers above.

| Gate | Current result |
|---|---|
| Flutter analyze | `PASS`: no issues |
| Flutter full suite | `PASS`: 411 tests + 1 intentional skip |
| CTA focused suite | `PASS`: 148/148 |
| Runtime golden suite | `PASS`: 73/73 |
| Trace validator | `PASS`: 19/19 validator tests |
| Trace execution | `PASS`: 191/191; 0 `PLANNED` |
| Android TalkBack | `PASS`: 7/7 named journeys |
| Android normal APK after instrumentation | `PASS`: build/install/hash/cold-launch proof |
| Post-change iOS compile/render | `PENDING`: requires a CI-visible source revision and macOS runner |
| VoiceOver | G4C follow-up, outside G4B |

The Android normal artifact and installed `base.apk` are byte-identical:
`194835309` bytes, SHA-256
`C5153B1775B65B1678122E9B6FD3612861C5527F68B2F147792E25CC1F09A540`.
Cold launch returned `LaunchState: COLD`, P1-01 rendered at font scale `2.0`,
and the runtime log contains no fatal crash/ANR/Flutter error fingerprint.
Canonical proof:
`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/normal-apk-post-talkback-20260723/normal-apk-proof.json`.

The `ios-appetize-simulator-smoke` workflow now includes deterministic
simulator selection, boot, install, app launch, screenshot/hash capture and
fatal-log scanning. YAML parsing and Bash syntax checks pass locally. It cannot
produce post-change proof until this dirty local source is published as an
authorized CI-visible revision. W8 therefore remains fail-closed only on the
iOS gate; cross-platform PASS is not claimed yet.

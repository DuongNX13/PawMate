# G4B Joint Sign-Off

Baseline: `UI-CC-2026-07-21-G4B`

Current status: `PASS`

Day 39 entry: `READY_FOR_D39_MANIFEST`

## Sign-off contract

G4B is PASS only when every row below is PASS, the final W8 evidence manifest
validates after the last artifact is attached, and both signatories approve the
same evidence baseline.

| Gate | Status | Evidence |
|---|---|---|
| W3 exact responsive proof | `PASS` | `W3_POST_WRITE_AUDIT_2026-07-22.json`; 77/77 |
| CTA row evidence | `PASS` | 82/82 manifests; CTA matrix 84/84 PASS |
| Android TalkBack journeys | `PASS` | 7/7 journey manifests |
| Unified traceability | `PASS` | 191/191 PASS; 0 PLANNED |
| Flutter analyze/tests/goldens/coverage | `PASS` | analyze clean; 411 + 1 skip; 73 runtime goldens; coverage gate PASS |
| Android normal APK after instrumentation | `PASS` | preserved/installed SHA-256 match; cleared-data cold launch PASS |
| Native/static and protected paths | `PASS` | 50/50 native; approved owner delta 38 added / 12 modified / 0 removed |
| Evidence redaction and manifest validation | `PASS` | 779 artifacts; redaction PASS; manifest validator errors 0 |
| Post-change iOS simulator compile/render | `PASS` | Codemagic build `6a61c58e95159f0929dd483e`; compile, launch, screenshot/hash and Runner scan |
| VoiceOver | `G4C` | explicitly outside the G4B denominator |

## Current signatories

| Signatory | Decision | Condition / authority |
|---|---|---|
| Codex lead / QA owner | `APPROVE` | All G4B evidence gates pass and terminal W8 manifest validates |
| Product Owner | `APPROVE` | Explicit `G4B=APPROVE` recorded on `2026-07-23T15:47:52+07:00` for the immutable W8 manifest SHA-256 `3832C950AFCED7ADDFE8B7D828DFE7CD8E40A566F4B9147778203F1C35FCD7A1` |

## Remaining execution sequence

1. Generate and validate the machine-verifiable `D39-ENTRY` manifest.
2. Only after that manifest passes, move Day 39 from `NOT STARTED` to
   `IN PROGRESS`.

## Fail-closed rule

The pre-change Codemagic build `6a5f426f3432213ac398e71a` remains historical
baseline evidence only. The post-change row is satisfied by build
`6a61c58e95159f0929dd483e`; Product Owner approval closes G4B. Day 39 remains
fail-closed only until the separate `D39-ENTRY` manifest validates.

## Post-change iOS and terminal manifest addendum — 2026-07-23 15:08 ICT

Codemagic build `6a61c58e95159f0929dd483e` (index 13) ran on branch
`evidence/g4b-ios-postchange-20260723`, commit `9afdb53`, Mac mini M2.
All workflow steps passed:

- platform-neutral tests: `316 PASS + 1 intentional skip`;
- iOS Simulator debug build: PASS;
- Simulator install/launch/screenshot: PASS;
- screenshot sidecar hash: PASS;
- Runner fatal/crash scan: PASS;
- Appetize simulator ZIP and artifact ZIP: published.

Canonical evidence is under
`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/ios-post-change-20260723/codemagic-build-6a61c58e95159f0929dd483e`.
The terminal manifest contains `779` artifacts, redaction `PASS`, and validator
`PASS` with wave status `PASS_PENDING_G4B_SIGNOFF`.

The simulator log records an Apple data-migration warning during boot, but the
script continued to launch the app, captured the screenshot, and completed the
step with exit code `0`. Runner log fatal fingerprint count is `0`.

## Product Owner approval closure — 2026-07-23 15:47 ICT

The Product Owner explicitly confirmed `G4B=APPROVE` for the immutable terminal
W8 manifest SHA-256
`3832C950AFCED7ADDFE8B7D828DFE7CD8E40A566F4B9147778203F1C35FCD7A1`
and source snapshot
`9D1E17293EF7532DAC0FC1ED286FDBCDF1027B200A00826C8AEEB6F836D52245`.

Approval record:
`docs/management/pawmate_product_owner_g4b_approval_2026-07-23.md`.
G4B is now `PASS`; VoiceOver remains in G4C. `D39-ENTRY` is eligible for
machine evaluation but is not implicitly passed by this document.

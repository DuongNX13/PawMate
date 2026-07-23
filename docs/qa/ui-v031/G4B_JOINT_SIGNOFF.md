# G4B Joint Sign-Off

Baseline: `UI-CC-2026-07-21-G4B`

Current status: `PENDING_PRODUCT_OWNER`

Day 39 entry: `CLOSED`

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
| Codex lead / QA owner | `RECOMMEND_APPROVE_AFTER_MANIFEST` | All G4B evidence gates pass and terminal W8 manifest validates; Product Owner decision is still required |
| Product Owner | `PENDING` | Must explicitly approve the completed G4B baseline; Codex cannot self-sign Product Owner authority |

## Remaining execution sequence

1. Obtain explicit Product Owner approval, for example `G4B=APPROVE`.
2. Only then set G4B to PASS and open the Day 39 entry manifest.

## Fail-closed rule

The pre-change Codemagic build `6a5f426f3432213ac398e71a` remains historical
baseline evidence only. The post-change row is now satisfied by build
`6a61c58e95159f0929dd483e`; G4B and Day 39 remain fail-closed only until the
Product Owner signs the same manifest baseline.

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

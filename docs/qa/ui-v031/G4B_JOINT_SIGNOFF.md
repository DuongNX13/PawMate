# G4B Joint Sign-Off

Baseline: `UI-CC-2026-07-21-G4B`

Current status: `PENDING_IOS_AND_PRODUCT_OWNER`

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
| Evidence redaction and manifest validation | `PASS_WITH_BLOCKED_WAVE_STATUS` | 764 artifacts; redaction PASS; manifest validator errors 0 |
| Post-change iOS simulator compile/render | `PENDING` | CI-visible revision and Codemagic execution required |
| VoiceOver | `G4C` | explicitly outside the G4B denominator |

## Current signatories

| Signatory | Decision | Condition / authority |
|---|---|---|
| Codex lead / QA owner | `RECOMMEND_APPROVE_AFTER_IOS_PASS` | All locally executable G4B gates pass; recommendation becomes final only after post-change iOS proof and terminal manifest recapture |
| Product Owner | `PENDING` | Must explicitly approve the completed G4B baseline; Codex cannot self-sign Product Owner authority |

## Remaining execution sequence

1. Publish an authorized isolated source revision containing the current
   allowlisted UI, tests, QA contracts and Codemagic render-proof workflow.
2. Run `ios-appetize-simulator-smoke`.
3. Require compile, install, launch, screenshot/hash and fatal-log scan PASS.
4. Download and bind the Codemagic artifacts to this baseline.
5. Recapture the W8 evidence manifest under quiescence and validate it
   immediately.
6. Obtain explicit Product Owner approval, for example `G4B=APPROVE`.
7. Only then set G4B to PASS and open the Day 39 entry manifest.

## Fail-closed rule

The pre-change Codemagic build `6a5f426f3432213ac398e71a` is baseline evidence
only. It cannot satisfy the post-change iOS row. Until the steps above complete,
W8/W9/G4B remain fail-closed and Day 39 must not start.

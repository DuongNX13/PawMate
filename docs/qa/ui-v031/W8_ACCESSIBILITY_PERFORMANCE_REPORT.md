# W8 Accessibility and Performance Report

Baseline: `UI-CC-2026-07-21-G4B`
Current verdict: `AUTOMATED_AND_TALKBACK_PASS / VOICEOVER_G4C`

Opening checkpoint (superseded): `AUTOMATED_PASS / DEVICE_JOURNEYS_INCOMPLETE`

## Accessibility

- The focused accessibility/widget suite passes `35/35`.
- The full Flutter suite passes `411` tests with one intentional skip.
- API 36 ran real TalkBack with system font scale `2.0`. The UI hierarchy exposes
  the onboarding illustration, add-photo button, heading, and description as
  separate labeled semantic nodes; the screen wraps without horizontal overflow.
- API 34 captured a real TalkBack focus rectangle on the final clean hero and a
  separate normal screenshot after TalkBack was disabled.
- Touch-target, focus, semantics, text-scale, dialog and platform primitive
  behavior is also covered by the automated suite and 12 platform goldens.
- The P1-01 successor test runs at `320x568` with text scale `2.0`, proves the
  progress-rail key is absent, preserves hero semantics and the photo-picker
  tooltip/button/tap contract, keeps both actions at least 48dp tall, and reports
  no Flutter overflow.

| Named journey | Android TalkBack | iOS VoiceOver | W8 status |
|---|---|---|---|
| A11Y-AUTH | Automated semantics only | NOT RUN | BLOCKED |
| A11Y-HOME | Automated semantics only | NOT RUN | BLOCKED |
| A11Y-VET | Automated semantics only | NOT RUN | BLOCKED |
| A11Y-HEALTH | Automated semantics only | NOT RUN | BLOCKED |
| A11Y-NOTIFICATIONS | Automated semantics only | NOT RUN | BLOCKED |
| A11Y-PROFILE | Automated semantics only | NOT RUN | BLOCKED |
| A11Y-RESCUE | Automated semantics only | NOT RUN | BLOCKED |

Real-iPhone/VoiceOver proof may be deferred to G4C, but the seven required
TalkBack journeys cannot be reported as PASS from one onboarding sample.

## Performance evidence

| Runtime | Debug cold start | Result |
|---|---:|---|
| Android API 34 | 10,998 ms | Render PASS; fresh AVD/debug timing only |
| Android API 35 | 3,983 ms | PASS |
| Android API 36 | 3,957 ms | PASS |

These are debug-emulator observations, not release performance benchmarks. They
show no blank screen or launch crash, but do not establish production startup,
frame-jank, memory, map, or image-decode budgets. Release profiling remains a
separate gate if the Product Owner brings it into scope.

## Post-W3/G4C disposition addendum — 2026-07-22 17:24 ICT

Product Owner approval `VOICEOVER=G4C` is now applied to the trace contract:
the seven real-device VoiceOver journeys are tracked in G4C and are excluded
from the G4B denominator. The seven Android TalkBack rows remain in G4B, but
only the onboarding component proof exists today; no aggregate suite result is
promoted to seven journey-level PASS rows. W8 therefore remains
`AUTOMATED_PASS / DEVICE_JOURNEYS_INCOMPLETE` until row-level TalkBack evidence
is attached.

## Android TalkBack journey closure — 2026-07-23 11:59 ICT

All seven required G4B Android journeys now have distinct device traversal
evidence on `emulator-5554`, Android `16` / API `36`, TalkBack
`16.0.0.738667889`, touch exploration enabled and font scale `2.0`.

| Named journey | Android TalkBack | Bound evidence |
|---|---|---|
| A11Y-AUTH | `PASS` | `A11Y-AUTH.manifest.json` |
| A11Y-HOME | `PASS` | `A11Y-HOME.manifest.json` |
| A11Y-VET | `PASS` | `A11Y-VET.manifest.json` |
| A11Y-HEALTH | `PASS` | `A11Y-HEALTH.manifest.json` |
| A11Y-NOTIFICATIONS | `PASS` | `A11Y-NOTIFICATIONS.manifest.json` |
| A11Y-PROFILE | `PASS` | `A11Y-PROFILE.manifest.json` |
| A11Y-RESCUE | `PASS` | `A11Y-RESCUE.manifest.json` |

Canonical index:
`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/talkback-journeys-20260723/talkback-journey-index.json`.
The tested accessibility APK is immutable at SHA-256
`8742CE8708BBD8DB27D89E2D6E25D4BF20E0419D45190020E0ECD6C1670E1237`.
The duplicate-label/bounds negative-control rule is covered by the
`19/19 PASS` validator suite.

Two accessibility defects found during device execution were fixed and
regression-tested: state-view copy no longer merges its recovery action into a
single semantic node, and enabled `PawMateButton` controls expose the TalkBack
tap action. The full Flutter suite remains `411 PASS + 1 intentional skip`.

After instrumentation, a normal APK was rebuilt and cold-launched from cleared
app data. Its preserved and installed hashes match exactly at
`C5153B1775B65B1678122E9B6FD3612861C5527F68B2F147792E25CC1F09A540`;
P1-01 rendered successfully and no fatal runtime fingerprint was found.

This does not claim release-performance completion: the normal debug cold start
was `5,948 ms` and logged `59` skipped frames on the emulator at text scale
`2.0`. Release/profile startup and jank budgets remain residual performance
risk, not a G4B accessibility blocker. VoiceOver remains assigned to G4C.

## iOS post-change runtime cross-check — 2026-07-23 15:08 ICT

Codemagic build `6a61c58e95159f0929dd483e` completed the iOS Simulator
compile/install/launch/render path on commit `9afdb53`. The captured proof is
`1260×2736`, its SHA-256 sidecar matches, and the Runner log has zero
fatal/crash/Flutter-error fingerprints. This is a runtime smoke/render
cross-check, not a VoiceOver claim; VoiceOver remains explicitly assigned to
G4C.

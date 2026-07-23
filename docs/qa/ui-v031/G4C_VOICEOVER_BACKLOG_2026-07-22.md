# G4C VoiceOver backlog — 2026-07-22

Status: `PENDING / OUTSIDE_G4B_DENOMINATOR`

Product Owner decision `VOICEOVER=G4C` moves the seven real-device iOS
VoiceOver journeys out of G4B. This document is the versioned backlog pointer;
it does not claim that any journey has run.

## Frozen journey set

| Journey ID | Screen/route | Required evidence | Status |
|---|---|---|---|
| `A11Y-AUTH` | P1-02 `/auth/login` | iPhone VoiceOver focus/order, labels, errors and loading at text scale 2.0 | `PLANNED` |
| `A11Y-HOME` | P1-07 `/pets` | Cards, five-tab navigation, roles and 48dp targets | `PLANNED` |
| `A11Y-VET` | P1-08 `/vets/map` | Map/list alternative, permission semantics and non-color meaning | `PLANNED` |
| `A11Y-HEALTH` | P1-12 `/health` | Timeline, reminder and add action at text scale 2.0 | `PLANNED` |
| `A11Y-NOTIFICATIONS` | P1-15 `/notifications` | Read state, errors and dynamic target announcements | `PLANNED` |
| `A11Y-PROFILE` | P1-16 `/profile` | Roles, selected state and unavailable destinations | `PLANNED` |
| `A11Y-RESCUE` | P2-01 `/rescue` | Staged availability, privacy and disabled-action semantics | `PLANNED` |

## Entry and exit

- Entry: W7 post-change iOS app is buildable on a CI-visible source revision;
  test account and deterministic fixture are available; no real location or
  personal data is used.
- Evidence: one redacted artifact per journey containing device/runtime,
  iOS version, text scale, VoiceOver interaction result, screenshot or screen
  recording reference, and SHA-256 manifest entry.
- Exit: 7/7 journeys pass the expected result, no P0/P1 accessibility defect,
  and the G4C manifest is reviewed by QA/Product Owner.
- Failure: keep G4C `PENDING` or `BLOCKED`; never turn a G4B row to PASS from
  Android/TalkBack evidence alone.

The corresponding G4B trace rows remain `platform=ANDROID`, `status=PLANNED`
until the seven Android TalkBack journeys receive their own row-level proof.

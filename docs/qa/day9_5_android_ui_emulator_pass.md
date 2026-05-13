# PawMate Day 9.5 Android UI Emulator Pass

Date: 2026-05-12 18:32 +07:00
Last updated: 2026-05-13 12:35 +07:00

## Scope

- Built and installed the latest local `main` debug APK on Android Emulator `emulator-5554` / Pixel 7 API 34.
- API base: `https://pawmate-api-yteu.onrender.com`.
- Route forcing: `PAWMATE_INITIAL_ROUTE`.
- Evidence folder: `temp/qa/day9_5_android_ui/`.
- Appetize was not used in this pass because Android is the Day 9.5 first QA surface and Appetize should wait until UI is stable.

## Build Proof

- APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Verification commands:
  - `flutter analyze` from `P:\mobile`: PASS, no issues found.
  - `flutter test` from `P:\mobile`: PASS, 33 tests.
  - 2026-05-13 automated closeout:
    - `flutter analyze --no-pub`: PASS, no issues found.
    - `flutter test --no-pub --no-test-assets -r expanded`: PASS, 43 tests.
    - `flutter build apk --debug --no-pub --dart-define=PAWMATE_API_BASE_URL=https://pawmate-api-yteu.onrender.com`: PASS.
- Build logs:
  - `temp/qa/day9_5_android_ui/stable-00-pets-build.log`
  - `temp/qa/day9_5_android_ui/stable-01-vets-list-build.log`
  - `temp/qa/day9_5_android_ui/stable-03-vet-detail-build.log`
  - `temp/qa/day9_5_android_ui/stable-06-notifications-build.log`
  - `temp/qa/day9_5_android_ui/stable-07-profile-build.log`
  - `temp/qa/day9_5_android_ui/stable-08-login-build.log`
  - `temp/qa/day9_5_android_ui/large-01-vets-list-build.log`
  - `temp/qa/day9_5_android_ui/large-05-reminders-build.log`
  - `temp/qa/day9_5_android_ui/large-08-login-build.log`

## Screenshot Evidence

Normal text:

- `temp/qa/day9_5_android_ui/stable-00-pets.png`
- `temp/qa/day9_5_android_ui/stable-01-vets-list.png`
- `temp/qa/day9_5_android_ui/normal-02-vets-map.png`
- `temp/qa/day9_5_android_ui/stable-03-vet-detail.png`
- `temp/qa/day9_5_android_ui/normal-04-health.png`
- `temp/qa/day9_5_android_ui/normal-05-reminders.png`
- `temp/qa/day9_5_android_ui/stable-06-notifications.png`
- `temp/qa/day9_5_android_ui/stable-07-profile.png`
- `temp/qa/day9_5_android_ui/stable-08-login.png`

Large text (`font_scale=1.3`, restored to `1.0` after capture):

- `temp/qa/day9_5_android_ui/large-01-vets-list.png`
- `temp/qa/day9_5_android_ui/large-05-reminders.png`
- `temp/qa/day9_5_android_ui/large-08-login.png`

Post-fix normal text:

- `temp/qa/day9_5_android_ui/fix-00-pets.png`
- `temp/qa/day9_5_android_ui/fix-01-vets-list.png`
- `temp/qa/day9_5_android_ui/fix2-02-vets-map.png`
- `temp/qa/day9_5_android_ui/fix2-03-vet-detail.png`
- `temp/qa/day9_5_android_ui/fix-04-health.png`
- `temp/qa/day9_5_android_ui/fix-05-reminders.png`
- `temp/qa/day9_5_android_ui/fix-07-profile.png`
- `temp/qa/day9_5_android_ui/fix-08-login.png`

Post-fix large text (`font_scale=1.3`, restored to `1.0` after capture):

- `temp/qa/day9_5_android_ui/fix3-large-01-vets-list.png`
- `temp/qa/day9_5_android_ui/fix2-large-03-vet-detail.png`
- `temp/qa/day9_5_android_ui/fix2-large-05-reminders.png`
- `temp/qa/day9_5_android_ui/fix2-large-08-login.png`

## Findings

| ID | Severity | Surface | Status | Finding | Evidence |
|---|---|---|---|---|---|
| UI-001 | P0 -> fixed | Vet list | VERIFIED | Typography and fixed chip/card layout overflow were fixed by compact text tokens, responsive chips, and less aggressive card typography. | `fix-01-vets-list.png`, `fix3-large-01-vets-list.png` |
| UI-002 | P1 -> fixed | Pets, Profile | VERIFIED | Main-tab routes `/pets` and `/profile` now render the shared bottom nav. | `fix-00-pets.png`, `fix-07-profile.png` |
| UI-003 | P1 -> fixed/clarified | Vet detail | VERIFIED | Baseline used stale route `/vets/hcm-001`. Current production vet ID `/vets/hn-001` renders the detail page with stable actions and no bottom-nav overlap. | `fix2-03-vet-detail.png`, `fix2-large-03-vet-detail.png` |
| UI-004 | P1 -> fixed | Vet map/list | VERIFIED | Filter chips were replaced with responsive pill controls; labels remain readable in compact portrait. | `fix2-02-vets-map.png`, `fix3-large-01-vets-list.png` |
| UI-005 | P1 -> fixed | Health/reminders | VERIFIED | Dense list screens use compact icon FABs on narrow or large-text layouts, and keyboard-open create sheets have automated regression tests. | `fix-04-health.png`, `fix-05-reminders.png`, `fix2-large-05-reminders.png`, `health_timeline_screen_test.dart`, `reminder_calendar_screen_test.dart` |
| UI-006 | P2 -> fixed | Login | VERIFIED | Login remains usable at large text; register CTA wraps as two controlled text runs and routes to register in an automated test. Primary contrast is covered by token tests. | `fix-08-login.png`, `fix2-large-08-login.png`, `login_screen_test.dart`, `accessibility_guidelines_test.dart` |
| UI-007 | P2 | Pets | OPEN/ENV | Pets list renders with the fixed nav. Backend sync banner remains an environment/auth data issue, not a current layout blocker. | `fix-00-pets.png` |

## Go/No-Go

Day 9.5 Android visual smoke and automated closeout are complete. The captured Android pass no longer shows a P0/P1 visual blocker on the core MVP routes that were retested, and the automated regression suite now covers the remaining overflow, accessibility, and keyboard-sheet blockers.

Day 10 RC can proceed to RC-specific gates. Remaining non-blocking follow-up:

1. Optional Appetize visual smoke after RC packaging, only if quota allows.
2. Continue broadening screen-level accessibility tests when new surfaces are added.

# PawMate Day 9.5 Full App UI Test Plan

Date: `2026-05-12`

## Purpose

Day 9.5 retests the whole PawMate mobile UI before Day 10 RC Gate. It targets the issues visible in current screenshots: inconsistent typography, oversized text, clipped long content, cramped buttons/cards, and accessibility risk under large text.

## Current Assessment

Day 9 map functionality is signed off, but the app should not enter Day 10 RC Gate until full-app UI stabilization is done.

Highest-risk areas from agent audits:

- Vet list/detail typography and layout density.
- Main tab bottom nav consistency.
- Health/reminder/write-review/report bottom sheets with keyboard open.
- Vet map preview sheet with long clinic names and addresses.
- Small portrait and large-text rendering.
- Contrast, tap target, and semantic-label coverage.

## P0 Findings To Verify/Fix

| ID | Area | Risk | Files |
|---|---|---|---|
| UI95-P0-01 | Main navigation | `/pets` and `/profile` can lose the main bottom nav after tab navigation | `mobile/lib/app/router/app_router.dart`, `mobile/lib/core/widgets/pawmate_bottom_nav.dart`, `mobile/lib/features/pets/presentation/pet_list_screen.dart`, `mobile/lib/core/widgets/placeholder_screen.dart` |
| UI95-P0-02 | Health/reminder sheets | Submit buttons can be hidden by keyboard or overflow on small screens because modal body is not scroll-safe | `mobile/lib/features/health/presentation/health_timeline_screen.dart`, `mobile/lib/features/reminders/presentation/reminder_calendar_screen.dart` |
| UI95-P0-03 | Vet preview sheet | Long clinic/address/services can push action buttons off-screen | `mobile/lib/features/vets/presentation/vet_map_screen.dart`, `mobile/lib/features/vets/presentation/vet_preview_sheet.dart` |
| UI95-P0-04 | Vet typography | `displaySmall` is used but not defined in app theme, causing fallback Material sizing | `mobile/lib/app/theme/app_theme.dart`, `mobile/lib/features/vets/presentation/vet_list_screen.dart`, `mobile/lib/features/vets/presentation/vet_map_screen.dart` |

## P1 Findings To Verify/Fix

| ID | Area | Risk | Files |
|---|---|---|---|
| UI95-P1-01 | Vet detail | Fixed hero widths and oversized quick facts/action text break long data | `mobile/lib/features/vets/presentation/vet_detail_screen.dart` |
| UI95-P1-02 | Vet map controls | Two `OutlinedButton.icon` controls in one row can overflow under large text | `mobile/lib/features/vets/presentation/vet_map_screen.dart` |
| UI95-P1-03 | Auth/onboarding/OTP | Small portrait plus keyboard can overflow because some layouts are not scroll-safe | `mobile/lib/features/onboarding/presentation/onboarding_screen.dart`, `mobile/lib/features/auth/presentation/otp_screen.dart` |
| UI95-P1-04 | Notifications | Long notification title/body has no dedicated small-screen coverage | `mobile/lib/features/notifications/presentation/notification_center_screen.dart` |
| UI95-P1-05 | Contrast | White on orange/gradient and muted label colors may not meet contrast target | `mobile/lib/app/theme/app_theme.dart`, `mobile/lib/core/widgets/primary_gradient_button.dart` |

## P2 Findings To Verify/Fix

| ID | Area | Risk | Files |
|---|---|---|---|
| UI95-P2-01 | Pets/profile | Long pet names/breeds and app bar titles need small-screen tests | `mobile/lib/features/pets/presentation/*.dart` |
| UI95-P2-02 | Tap target labels | Custom `GestureDetector` and icon-only controls need semantic/tooltip check | shared widgets and vet/review controls |
| UI95-P2-03 | Test coverage | Current tests mostly verify functional text, not UI overflow under real screen constraints | `mobile/test/features/**/*.dart` |

## Automated Test Plan

Run all mobile commands through the temporary no-space drive:

```powershell
if (Test-Path P:) { subst P: /D }
subst P: "D:\My Playground\PawMate"
cd P:\mobile
flutter analyze --no-pub
flutter test --no-pub --no-test-assets -r expanded
```

Add targeted Day 9.5 widget tests:

| Suite | Required Checks |
|---|---|
| `vet_screens_test.dart` | Long clinic name/address/URL/services at `360x800`, `390x844`, text scale `1.3`; no overflow exception; action buttons visible |
| `vet_map_screen_test.dart` | Map controls and preview sheet with 80+ char clinic name and 120+ char address; action buttons visible/tappable |
| `health_timeline_screen_test.dart` | Add-event sheet at `320x568`, keyboard/viewInsets open, submit button visible/tappable |
| `reminder_calendar_screen_test.dart` | Add-reminder sheet at `320x568`, keyboard/viewInsets open, submit button visible/tappable |
| `notification_center_screen_test.dart` | Long unread title/body, read/dismiss actions, scroll to bottom above bottom nav |
| `auth` tests | Login/register/OTP keyboard-open forms at small portrait |
| `pets` tests | Long pet name/breed, create form, detail app bar, list card no overflow |

For each targeted test:

- set surface size,
- wrap with `MediaQuery(textScaler: TextScaler.linear(1.3))`,
- use `AppTheme.light()` where possible,
- assert `expect(tester.takeException(), isNull)`,
- verify primary CTA and bottom nav are visible/tappable.

Accessibility checks:

- `meetsGuideline(androidTapTargetGuideline)`,
- `meetsGuideline(labeledTapTargetGuideline)`,
- `meetsGuideline(textContrastGuideline)`,
- manual verification for icon-only controls and review photo remove button.

## Manual Android/Appetize Smoke

Android first:

1. Build/install APK with `PAWMATE_API_BASE_URL=https://pawmate-api-yteu.onrender.com`.
2. Normal text pass.
3. Large text pass: `adb shell settings put system font_scale 1.3`.
4. Small screen pass if needed: `adb shell wm size 360x800`.
5. Restore with `adb shell wm size reset` and `adb shell settings put system font_scale 1.0`.

Appetize optional:

- Use only after Android pass is stable.
- Enable Network Logs/Debug Logs.
- Capture screenshots quickly.
- Close the simulator tab/session immediately after evidence.

Manual route checklist:

- Onboarding -> login verified QA account.
- Pets list/create/detail.
- Vet list filters/search/sort -> map -> marker preview -> detail -> call/directions.
- Write review sheet, report review sheet, photo add/remove controls.
- Health timeline -> add event sheet.
- Reminders -> month arrows, long pet name, create reminder sheet.
- Notifications -> read/read-all/dismiss.
- Bottom nav visible/tappable on every main tab.

## Acceptance Criteria

Day 9.5 passes when:

- full analyze/test suite passes from `P:\mobile`,
- targeted responsive/a11y widget tests pass for `360x800` and `390x844` at text scale `1.3`,
- no P0/P1 overflow, hidden CTA, keyboard-blocked submit, unreadable primary text, or unlabeled primary icon action remains,
- all primary controls have at least 48dp hit area or equivalent padded hit area,
- contrast meets `4.5:1` for normal text and `3:1` for large text/icon UI,
- Android screenshot evidence is captured for normal and large text,
- Appetize evidence is refreshed only if quota allows,
- Day 10 RC Gate remains blocked until Day 9.5 is signed off.

# PawMate Day 8 Manual QA And Accessibility Report

Date: `2026-05-11`

## Current Status

Day 8 QA large-text accessibility is now closed for the Android QA surface. The highest-risk backend/Appetize blocker is cleared, Android normal-text and large-text E2E have been run on the emulator, local automated gates are green, GitHub CI/Compose Smoke are green on `main`, Render core API smoke passes, and Appetize deep-login evidence is captured.

Known Day 7 carry-over:

- Render backend is live at `https://pawmate-api-yteu.onrender.com`.
- Appetize Network Logs already proved real backend traffic:
  - `POST /auth/register` -> `201`
  - `POST /auth/login` after fresh register -> `403 AUTH_006`
- `403 AUTH_006` is expected email-verification policy, not an infrastructure blocker.
- Deep-login demo requires a verified QA account.
- A verified QA account has been seeded in the cloud database and public Render `/auth/login` returned `200` for it.
- Day 8 Appetize Network Logs captured `POST https://pawmate-api-yteu.onrender.com/auth/login` -> `200`.
- Day 8 Appetize reached the authenticated pet-list surface after login.
- Day 8 Android debug APK now includes `INTERNET` permission, builds with Render API base, installs on emulator, and logs in with the verified QA account.
- Android normal-text run found and fixed P0/P1 visual issues in pet cards, health timeline/selector, and the reminder pet selector.
- Android large-text run used system `font_scale=1.3`; Reminders, Notifications, Health, Vet list/detail, Create Pet, and Review sheet showed no severe clipping or unreachable core CTA after the bottom-padding fix.

## Manual QA Matrix

| Area | Flow | Status | Notes |
|---|---|---|---|
| Auth | Register fresh account | POLICY_PASS | Day 7/Day 8 evidence confirms `201`; verify-email policy is expected |
| Auth | Login fresh unverified account | ACCEPTED_POLICY | Expect `403 AUTH_006` |
| Auth | Login verified QA account | APPETIZE_PASS | Appetize Network Logs show `/auth/login` `200` |
| Pet Profile | List pets | ANDROID_PASS | Verified QA account reached live pet list with 5 Day 8 pets; pet card overflow fixed |
| Pet Profile | Create/edit pet | ANDROID_ROUTE_PASS_API_PASS | Create-pet route renders; Render API smoke created and read a pet; full edit UX remains backlog if edit is exposed later |
| Vet Finder | Search/list/detail | ANDROID_LIST_PASS_API_PASS | Android reached live vet list with backend data; Render `/vets/search?limit=1` returned `200`; runtime seed regression added |
| Reviews | Submit/read review core | AUTOMATED_PASS_PENDING_ANDROID_MANUAL | Widget/API tests cover submit, duplicate, helpful/report, list pagination; Android manual review submit can run after a clean vet/review dataset is prepared |
| Health Records | Timeline/create/list | ANDROID_PASS_API_PASS | Timeline reached from Android; selector/title overflow fixed; Render API smoke created and listed a health record |
| Reminders | Create/list/due reminder | ANDROID_PASS_API_PASS | User-reported selector vertical-text bug fixed; Render API smoke created/listed/process-due reminder; scheduled cron remains disabled |
| Notifications | List/read/read-all | ANDROID_PASS_API_PASS | Android notification center reached from health; Render API smoke listed notifications after processing due reminder |

## Accessibility Checklist

| Check | Status | Notes |
|---|---|---|
| Contrast | ANDROID_PASS | No severe contrast issue observed on exercised Android/Appetize auth, pets, vet list/detail, health, reminders, notifications surfaces |
| Text scale | ANDROID_LARGE_TEXT_PASS | Android `font_scale=1.3` pass covered pets, create-pet, vet list/detail, health, reminders, notifications, and review sheet; user-reported reminder vertical-text issue stayed fixed |
| Tap targets | ANDROID_LARGE_TEXT_PASS | Top actions, bottom nav, health/reminder FABs, calendar controls, notification actions, vet map FAB, and primary CTAs were tappable in the large-text run |
| Form labels | ANDROID_LARGE_TEXT_PASS | Create-pet form and write-review bottom sheet remained readable at large text with visible submit controls |
| Error states | POLICY_PASS | Fresh unverified login shows policy failure instead of infra failure |
| Loading/empty states | ANDROID_NORMAL_PASS | Pets, reminders, notifications, and health showed non-blank loading/empty/error states during the run |
| Navigation semantics | ANDROID_NORMAL_PASS | Auth -> pets, pets -> vet list, health -> notifications/reminders worked in the Android run; route-specific initial builds are kept out of evidence because of emulator renderer instability |

## Appetize Evidence Targets

Captured Day 8 deep-login evidence:

- `temp/qa/day8-appetize-deep-login/appetize-network-tab-after-login.png` shows `POST https://pawmate-api-yteu.onrender.com/auth/login` -> `200` and `GET https://pawmate-api-yteu.onrender.com/pets` -> `200`.
- `temp/qa/day8-appetize-deep-login/appetize-after-manual-login-12s.png` shows PawMate reached the authenticated pet-list surface.
- Simulator/browser tab was closed after capture to avoid Appetize quota burn.

Existing Day 7 evidence:

- `temp/qa/appetize-auth-network-logs-register201-login403.png`

Day 8 evidence:

- Backend gates + coverage + audit: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-115607-06034398.raw.txt`
- Mobile gates through no-space `P:` path: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-115706-b65961ad.raw.txt`
- Android build/analyze/test with Render QA defines: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-152400-24ae924a.raw.txt`
- Android final analyze/test after reminder selector regression test: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-152954-768ca2d9.raw.txt`
- Android final build/install on emulator: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-153018-29c153c6.raw.txt`
- Android large-text analyze: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-161518-7ca2bcdb.raw.txt`
- Android large-text test: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-161657-38340603.raw.txt`
- Android large-text build: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-161731-c2457afb.raw.txt`
- Android large-text install: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-161938-3835794c.raw.txt`
- Android large-text pet list: `temp/qa/day8-android-large-text/12-postfix-launch.png`
- Android large-text create-pet route: `temp/qa/day8-android-large-text/03-large-create-pet.png`
- Android large-text reminders: `temp/qa/day8-android-large-text/19-postfix-reminders.png`
- Android large-text notifications: `temp/qa/day8-android-large-text/20-postfix-notifications.png`
- Android large-text health scroll: `temp/qa/day8-android-large-text/18-postfix-health-scroll.png`
- Android large-text vet list scroll: `temp/qa/day8-android-large-text/15-postfix-vet-list-scroll.png`
- Android large-text vet detail scroll: `temp/qa/day8-android-large-text/22-postfix-vet-detail-scroll.png`
- Android large-text review sheet: `temp/qa/day8-android-large-text/11-large-review-sheet.png`
- Android verified login/current build screenshot: `temp/qa/day8-android-e2e/36-final-installed-current-build.png`
- Android pet list after login: `temp/qa/day8-android-e2e/22-after-clean-login.png`
- Android vet list: `temp/qa/day8-android-e2e/23-vet-list-from-pets.png`
- Android health selector after fix: `temp/qa/day8-android-e2e/27-health-after-selector-fix.png`
- Android notifications: `temp/qa/day8-android-e2e/28-notifications-from-health.png`
- Android reminder selector after fix: `temp/qa/day8-android-e2e/34-reminders-after-selector-fix.png`
- Android Vietnamese UI after copy cleanup: `temp/qa/day8-android-e2e/35-vietnamese-ui-after-launch.png`
- Dependency audit fix: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110940-4f9f2eae.raw.txt`
- Render core API smoke: `temp/qa/day8-appetize-deep-login/day8-render-api-core-smoke.json`
- GitHub Actions `main` commit `c768850`: `temp/qa/day8-appetize-deep-login/github-actions-c768850-pass.png`
- Codemagic Appetize build: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/6a0157cb3a8de0b0c8f17cf5`

## Open Findings

- D8-F01: CLOSED. Appetize deep-login browser proof is captured with `/auth/login` `200`, `/pets` `200`, and authenticated pet-list screenshot.
- D8-F02: CLOSED_FOR_ANDROID_NORMAL_TEXT. Android E2E covered core auth, pets, create-pet route, vet list, health, reminders, and notifications. API smoke already covers auth, pets, health records, reminders, notifications, and vet search.
- D8-F03: CLOSED_LARGE_TEXT. Android `font_scale=1.3` accessibility pass is captured. Health, Reminders, Vet list/detail, and Notifications now have enough bottom padding for content to scroll clear of the bottom nav/FAB; no severe clipping or unreachable core CTA remains on exercised Day 8 surfaces.
- D8-F04: CLOSED. `Lịch nhắc` selected-pet dropdown rendered the pet name vertically on Android. Fixed by moving the selected pet label into the main row text with one-line ellipsis and keeping the dropdown selected builder icon-only. Regression test added in `mobile/test/features/reminders/reminder_calendar_screen_test.dart`.
- D8-F05: CLOSED. Bottom navigation and major MVP copy now use Vietnamese-first labels with accents. Remaining English strings from test keys/internal filenames are not user-facing.
- D8-F06: ACCEPTED_FOR_DAY8. Direct `PAWMATE_INITIAL_ROUTE` builds can hit emulator renderer black-screen/Impeller instability. Default installed app navigation works and is the accepted Android QA path for Day 8 evidence.

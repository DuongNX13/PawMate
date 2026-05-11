# PawMate Day 8 Execution Board

Date: `2026-05-11`

## Scope

Day 8 is the Phase 1 full manual QA and accessibility pass. The main goal is to lock core MVP quality before map/release packaging work.

Day 8 also owns the Appetize deep-login follow-up from Day 7:

- Fresh register on Render can return `201`.
- Immediate login for the same fresh email can return `403 AUTH_006`.
- That is expected email verification policy, not infrastructure failure.
- Deep login proof should use a verified QA account and must not add a public auto-verify endpoint.

## Task Status

| ID | Task | Status | Evidence |
|---|---|---|---|
| D8-01 | Day 7/Day 8 documentation closeout | DONE | `docs/management/phase1_quality_first_plan_2026-04-23.md`, `docs/management/day7_hardening_board.md` |
| D8-02 | Verified QA auth account path for Appetize | DONE | `backend/scripts/seed-mobile-e2e-user.cjs`, `mobile/lib/features/auth/presentation/auth_qa_defaults.dart`, `codemagic.yaml`; public Render `/auth/login` returned `200` for the verified QA account |
| D8-03 | Appetize deep-login Network Logs proof | DONE | `temp/qa/day8-appetize-deep-login/appetize-network-tab-after-login.png`, `temp/qa/day8-appetize-deep-login/appetize-after-manual-login-12s.png` |
| D8-04 | Full manual QA matrix | ANDROID_CORE_NORMAL_PASS_WITH_FIXES | `temp/qa/day8-appetize-deep-login/day8-render-api-core-smoke.json`, `temp/qa/day8-android-e2e/34-reminders-after-selector-fix.png`, `temp/qa/day8-android-e2e/36-final-installed-current-build.png`, `docs/qa/day8_manual_qa_accessibility_report.md` |
| D8-05 | Accessibility pass | ANDROID_NORMAL_PARTIAL_PASS_LARGE_TEXT_PENDING | `docs/qa/day8_manual_qa_accessibility_report.md`; normal Android pass found and fixed core overflow/copy issues |
| D8-06 | CI/Ops proof | DONE | Backend/mobile gates, coverage, audit, Render health, GitHub CI #34, and Compose Smoke #34 passed on `main` commit `c768850` |
| D8-07 | Android functional testcase package | DONE | `docs/qa/day8_android_functional_testcases.md` |
| D8-08 | Android UI/UX Figma audit package | DONE | `docs/qa/day8_android_uiux_figma_audit.md` |
| D8-09 | Android UI regression fixes and retest | DONE | `mobile/test/features/reminders/reminder_calendar_screen_test.dart`; latest mobile gates `31/31` pass |

## Implementation Notes

- Appetize is the default browser-based iOS QA surface for Day 8.
- BrowserStack is out of scope for Day 8.
- Apple Developer/App Store Connect signing remains a final-day release-parity gap because the separate PawMate Apple team/payment path is still pending.
- Reminder Worker schedule remains disabled; manual dispatch remains available.
- `PAWMATE_QA_AUTH_EMAIL` is now supported as a compile-time mobile QA override. If omitted, the app keeps the old random QA email fallback.
- `PAWMATE_E2E_SKIP_ENV_LOCAL=1` can be used when seeding a cloud QA user so `.env.local` does not override the intended `DATABASE_URL`.
- Vet Search on Render required committing `backend/prisma/data/day2_vet_seed_candidates.json` and `backend/prisma/data/day3_vet_geo_pilot.json`; CI now has a regression test proving the default runtime seed files load.
- Mobile reminder processing now sends an explicit empty JSON body to avoid content-type ambiguity when calling `POST /notifications/process-due-reminders`.
- Android Day 8 QA found and fixed the user-visible `Lịch nhắc` pet selector overflow where the selected pet name rendered vertically.
- Android UI copy was normalized to Vietnamese-first labels on bottom navigation, pets, reminders, notifications, vet/review text, and placeholder routes.

## Verification Checklist

- [x] Render `/health` returns `200`.
- [x] Backend `npm run prisma:validate` passes.
- [x] Backend `npm run lint` passes.
- [x] Backend `npm run build` passes.
- [x] Backend `npm test` passes.
- [x] Backend `npm run test:coverage` passes.
- [x] Backend `npm audit --audit-level=high` passes.
- [x] Mobile `flutter analyze` passes.
- [x] Mobile `flutter test` passes.
- [x] Android debug APK builds and installs on emulator.
- [x] Android core normal-text E2E covers auth, pets, pet detail, create-pet route, vet list, health timeline, notifications, and reminder calendar.
- [x] User-reported `Lịch nhắc` pet selector vertical-text bug is fixed and covered by a widget regression test.
- [x] Public Render `/auth/login` returns `200` for the verified QA account.
- [x] Appetize Network Logs show `/auth/login` `200` for verified QA account.
- [x] Appetize app reaches `/pets` after login.
- [x] Public Render core API smoke covers auth, pets, health records, reminders, notifications, and vet search.
- [x] GitHub CI #34 and Compose Smoke #34 passed for `c768850`.
- [x] Android normal-text visual QA across exercised core MVP screens has no remaining P0/P1 core-flow bugs after fixes.
- [ ] Full screen-by-screen large-text accessibility pass has no severe contrast/tap-target/text-scale issues.

## Evidence

- Backend gates + coverage + audit: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-115607-06034398.raw.txt`
- Mobile gates through no-space `P:` path: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-115706-b65961ad.raw.txt`
- Android build/analyze/test with Render QA defines: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-152400-24ae924a.raw.txt`
- Android final analyze/test after reminder regression test: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-152954-768ca2d9.raw.txt`
- Android final build/install on emulator: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-153018-29c153c6.raw.txt`
- Android login/current build screenshot: `temp/qa/day8-android-e2e/36-final-installed-current-build.png`
- Android reminder selector fix screenshot: `temp/qa/day8-android-e2e/34-reminders-after-selector-fix.png`
- Android Vietnamese UI screenshot: `temp/qa/day8-android-e2e/35-vietnamese-ui-after-launch.png`
- Dependency audit fix: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110940-4f9f2eae.raw.txt`
- Existing Appetize Day 7 register-policy proof: `temp/qa/appetize-auth-network-logs-register201-login403.png`
- Codemagic Day 8 Appetize build: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/6a0157cb3a8de0b0c8f17cf5`
- Appetize simulator artifact: `temp/qa/day8-appetize-deep-login/PawMate-appetize-simulator-6a0157cb.zip`
- Appetize app build id: `b_z5cfcpmgqpfgf4sy4wwoiifu4m`
- Appetize Network Logs proof: `temp/qa/day8-appetize-deep-login/appetize-network-tab-after-login.png`
- Appetize authenticated pets surface: `temp/qa/day8-appetize-deep-login/appetize-after-manual-login-12s.png`
- Render core API smoke: `temp/qa/day8-appetize-deep-login/day8-render-api-core-smoke.json`
- GitHub Actions proof for `c768850`: `temp/qa/day8-appetize-deep-login/github-actions-c768850-pass.png`

## Risk Register

| Risk | Severity | Status | Mitigation |
|---|---|---|---|
| Fresh register cannot immediately login because email is unverified | Known policy | ACCEPTED | Use verified QA account for deep-login proof |
| Appetize quota burn during browser automation | Medium | MITIGATED | Session was closed after Network Logs and `/pets` evidence capture |
| Apple signing assets unavailable | Release parity | DEFERRED | Move to final-day Apple Developer lane |
| Reminder Worker cron spam | Low | MITIGATED | Cron removed; manual dispatch kept |
| Route-specific `PAWMATE_INITIAL_ROUTE` Android builds can hit an emulator renderer black-screen/Impeller issue | Medium | ACCEPTED_FOR_DAY8 | Default installed app route works; use in-app navigation/default build for QA evidence and keep renderer issue as emulator-specific follow-up |

## Exit Gate

Day 8 can close when:

- core MVP screens are visually signed off at normal text scale,
- no P0/P1 manual QA or accessibility issue remains,
- Appetize deep-login has `/auth/login` `200` evidence,
- Render health and local CI gates are green,
- Apple signing remains tracked as a final-day gap only.

Large-text accessibility remains the only Day 8 exit item not fully closed by the Android normal-text run.

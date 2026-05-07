# PawMate Day 7 Hardening Board

Date: 2026-05-05

## Scope

Day 7 starts productionization hardening after Day 6 Android-local sign-off. The first patch moves reminder due processing from a user-triggered-only endpoint to an explicit backend worker command that can be scheduled by Fly cron, GitHub Actions, Windows Task Scheduler, or another trusted runner.

## Task Status

| Task | Status | Evidence |
| --- | --- | --- |
| D7-01 Worker command for due reminders | DONE | `backend/src/jobs/process-due-reminders.ts`, `backend/src/jobs/process-due-reminders-job.ts`, `npm run reminders:process-due -- --limit 100` |
| D7-02 Worker unit tests | DONE | `backend/tests/process-due-reminders-job.test.ts` |
| D7-03 Supabase cloud SQL proof | DONE | Supabase SQL Editor cloud bootstrap and smoke passed: `temp/qa/day7-supabase-cloud-proof/08-cloud-schema-verify-result.png`, `temp/qa/day7-supabase-cloud-proof/11-cloud-crud-smoke-confirmed-result.txt` |
| D7-04 iOS real-device smoke | DONE_CORE_SMOKE + APPETIZE_BACKEND_AUTH_NETWORK_PROOF / RELEASE_SIGNING_GAP | BrowserStack re-sign path produced and installed `PawMate-browserstack-unsigned.ipa` on real `iPhone 15 Pro Max v17.3`; Appetize simulator path launched `Pawmate Mobile` on `iPhone 14 Pro iOS 16.2`; Appetize Network Logs captured backend `POST /auth/register` status `201` and backend `POST /auth/login` status `200`; release/TestFlight parity still requires Apple Developer signing assets |
| D7-05 GitHub scheduled reminder worker | DONE_LOCAL / BLOCKED_CLOUD_SECRET | `.github/workflows/reminder-worker.yml` exists; production run still requires `PAWMATE_REMINDER_DATABASE_URL` / `DATABASE_URL` secret with a real Supabase Postgres URL |
| D7-06 Scheduler/cloud proof runbook | DONE | `docs/management/day7_scheduler_runbook.md`, `docs/management/day7_blocker_resolution_plan.md` |
| D7-07 Manual GitHub cloud proof workflow | DONE | `.github/workflows/day7-cloud-schema-proof.yml` can run `apply-and-verify` or `verify-only` after `PAWMATE_DB_MIGRATION_URL` is configured |
| D7-08 Cloud iOS proof path | DONE_CORE_SMOKE + APPETIZE_SIM_DEMO_TEXT_ENTRY / RELEASE_SIGNING_GAP | Codemagic build `69fb0916be8a3ba0bd3513b0` produced `PawMate-browserstack-unsigned.ipa` for BrowserStack re-sign; Codemagic build `69fb188bbe4ca8fb32575ccc` produced `PawMate-appetize-simulator.zip` for Appetize; release/TestFlight build still requires Apple Developer signing assets |

## Operational Notes

- The worker requires `DATABASE_URL`; it intentionally fails fast if no database URL exists.
- The worker prints a safe JSON summary with `processedCount`, `reminderIds`, `ranAt`, and `limit`; it does not print credentials or full user/pet records.
- API endpoint `POST /notifications/process-due-reminders` remains available for MVP manual/local sync, but production scheduling should prefer the worker command.
- On this Windows workspace, run Flutter through the portable SDK path `D:\My Playground\tools\flutter\bin\flutter.bat`. If native-asset tooling breaks on the space in `D:\My Playground`, use a temporary `subst` drive and `--no-pub`.
- iOS real-device proof should use the cloud path in `codemagic.yaml`; do not treat a Windows iOS simulator/emulator as valid Day 7 proof.
- Codemagic is no longer blocked by login/config detection. The Apple Ad Hoc signing path is still blocked because Codemagic could not find a matching `ad_hoc` provisioning profile for bundle id `com.pawmate.pawmateMobile`.
- D7-04 was unblocked for core real-device smoke by using BrowserStack's re-sign behavior: Codemagic built a real-device no-codesign IPA, BrowserStack accepted the upload, installed it on a real iPhone, and launched PawMate.
- BrowserStack free trial limits each device to about 2 minutes, so the captured D7-04 evidence covers install, launch, Login screen, and Login -> Register navigation. Broader tab-by-tab exploratory QA still needs a longer BrowserStack plan or another real iPhone.
- Appetize is now usable as a Windows-friendly iOS simulator demo path: Codemagic builds a simulator `.app` ZIP, the ZIP uploads to Appetize, and PawMate launches on `iPhone 14 Pro iOS 16.2`. This supplements BrowserStack but does not replace real-device signing proof.
- Appetize Register/Login backend traffic is now signed off from simulator Network Logs after rebuilding with `PAWMATE_ENABLE_SYSTEM_PROXY=true`; the remaining iOS gap is release signing, not simulator auth reachability.
- Supabase API URL, publishable key, and service-role key are not enough for the Prisma scheduled worker; cloud production scheduling still requires a Postgres connection string.
- D7-03 was unblocked without resetting the database password by running the generated schema bootstrap and Day 6 CRUD smoke directly in Supabase SQL Editor.

## Verification

- `npm run prisma:validate`: passed.
- `npm run lint`: passed.
- `npm run build`: passed.
- Supabase SQL Editor cloud bootstrap: passed with `Success. No rows returned`.
- Supabase SQL Editor cloud schema verify: passed with `status: ok`, `missing: []`, `table_count: 12`, `enum_count: 10`.
- Supabase SQL Editor cloud CRUD smoke: passed with `status: ok`; reminder moved to `done`, notification dismissed, and temporary rows cleaned up.
- `npm run db:day6:cloud-proof -- --verify-only`: passed against local PostgreSQL, verifying Day 6 schema and reminder/notification CRUD smoke.
- `npm run reminders:process-due -- --limit 100 --now 1970-01-01T00:00:00.000Z`: passed with `processedCount: 0`.
- `npx jest --runInBand --config jest.config.cjs tests/process-due-reminders-job.test.ts`: 5 tests passed.
- `npm test`: 15 suites, 68 tests passed.
- `npm run test:coverage`: 15 suites, 68 tests passed; all-files statements 83.34%, lines 83.12%.
- `npm audit --audit-level=high`: 0 vulnerabilities.
- `flutter analyze --no-pub`: passed through temporary no-space `subst` path.
- `flutter test --no-pub --no-test-assets -r expanded`: 30 tests passed through temporary no-space `subst` path.
- Codemagic `Day 7 iOS Real Device Smoke` build on `develop`: failed before IPA creation with `No matching profiles found for bundle identifier "com.pawmate.pawmateMobile" and distribution type "ad_hoc"`.
- Codemagic `Day 7 iOS BrowserStack Re-sign Smoke` build on `develop`: produced artifact `PawMate-browserstack-unsigned.ipa` `[8.22 MB]`.
- BrowserStack App Live upload: accepted `PawMate-browserstack-unsigned.ipa` as `v1.0.0`.
- BrowserStack real iPhone smoke: `iPhone 15 Pro Max v17.3` installed/launched `com.pawmate.pawmateMobile`; Login screen rendered and Register screen opened.
- Codemagic `Day 7 iOS Appetize Simulator Smoke` build on `develop`: passed; artifact `PawMate-appetize-simulator.zip` `[55.70 MB]`.
- Appetize upload: accepted the simulator ZIP and created iOS app `Pawmate Mobile` with `appId=com.pawmate.pawmateMobile`.
- Appetize simulator smoke: `iPhone 14 Pro iOS 16.2` launched PawMate; onboarding and Register screen rendered. Evidence: `temp/qa/day7-ios-cloud-proof/52-appetize-pawmate-started-30s.png`, `temp/qa/day7-ios-cloud-proof/53-appetize-after-onboarding-start.png`.
- Appetize Register text-entry smoke: passed via `record=true` Appetize session and direct `playAction`; email, password, confirm password, terms switch, and Register CTA were visible with valid values. Evidence: `temp/qa/day7-ios-cloud-proof/97-appetize-after-text-entry-keyboard-hidden.png`, `temp/qa/day7-ios-cloud-proof/99-appetize-register-submit-coord-result.png`.
- Appetize backend-backed Register Network Logs proof: proxy-aware Codemagic build `69fc2cbd2f5a4736dae72725` was uploaded to Appetize as build `b_ckyj2jwaqmbjjf63ovx4xjfpny`; Appetize HAR captured `POST https://fed-spears-genetics-reviewing.trycloudflare.com/auth/register` status `201`. Evidence: `temp/qa/day7-ios-cloud-proof/appetize-network-captures-run6_register-4b411586.redacted.har.json`.
- Appetize backend-backed Login UI Network Logs proof: Appetize Login UI submitted verified account `qa07121901@pawmate.local`; Appetize HAR captured `POST https://fed-spears-genetics-reviewing.trycloudflare.com/auth/login` status `200` with tokens redacted. Evidence: `temp/qa/day7-ios-cloud-proof/appetize-network-captures-run11_login200-3346819a.redacted.har.json`, `temp/qa/day7-ios-cloud-proof/appetize-auth-network-summary-run6-run11-69fc2cbd.json`.
- Backend runtime health: local backend was reachable on `127.0.0.1:3000`, the temporary Cloudflare public URL returned `GET /health` status `200`, and public `POST /auth/login` for the Appetize-created account returned `200`.
- Remaining blocker execution check on 2026-05-07: GitHub API access via Windows Credential Manager verified `ADMIN` permission on `DuongNX13/PawMate`, but GitHub Actions secrets and variables are currently empty; `npm run prisma:validate` passed and `npm run reminders:process-due -- --limit 1` passed locally. External blockers remain Supabase Session Pooler secret, Fly auth/billing/app creation, Apple Developer signing assets, and BrowserStack/real-device extended time. Evidence: `docs/management/day7_remaining_blocker_execution_status_2026-05-07.md`.

## Next Actions

1. Get a real Supabase Session Pooler URL with database password and store it as `PAWMATE_REMINDER_DATABASE_URL` in GitHub Actions secrets.
2. Run `Reminder Worker` manually once before relying on the scheduled run.
3. For release parity, configure Apple Developer signing in Codemagic for `com.pawmate.pawmateMobile`, then rerun `ios-real-device-smoke`.
4. For broader QA, use Appetize for simulator demo/exploration and rerun BrowserStack with a paid/extended session for real-device tab-by-tab smoke beyond the current Login/Register evidence.

# PawMate Day 8 Manual QA And Accessibility Report

Date: `2026-05-11`

## Current Status

Day 8 QA is open with the highest-risk blocker cleared. Local automated gates are green, GitHub CI/Compose Smoke are green on `main`, Render core API smoke passes, and Appetize deep-login evidence is captured.

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

## Manual QA Matrix

| Area | Flow | Status | Notes |
|---|---|---|---|
| Auth | Register fresh account | POLICY_PASS | Day 7/Day 8 evidence confirms `201`; verify-email policy is expected |
| Auth | Login fresh unverified account | ACCEPTED_POLICY | Expect `403 AUTH_006` |
| Auth | Login verified QA account | APPETIZE_PASS | Appetize Network Logs show `/auth/login` `200` |
| Pet Profile | List pets | APPETIZE_PASS | Appetize reached `Thú cưng của tôi` authenticated pet-list surface |
| Pet Profile | Create/edit pet | API_PASS_PENDING_VISUAL | Render API smoke created and read a pet; visual create/edit still needs broader manual pass |
| Vet Finder | Search/list/detail | API_PASS_PENDING_VISUAL | Render `/vets/search?limit=1` returned `200`; runtime seed regression added |
| Reviews | Submit/read review core | READY | Verify one-review and error behavior where available |
| Health Records | Timeline/create/list | API_PASS_PENDING_VISUAL | Render API smoke created and listed a health record |
| Reminders | Create/list/due reminder | API_PASS_PENDING_VISUAL | Render API smoke created/listed/process-due reminder; scheduled cron remains disabled |
| Notifications | List/read/read-all | API_PASS_PENDING_VISUAL | Render API smoke listed notifications after processing due reminder |

## Accessibility Checklist

| Check | Status | Notes |
|---|---|---|
| Contrast | PARTIAL_PASS | No severe issue observed on exercised Appetize auth/pets surface |
| Text scale | PARTIAL_PASS | No clipped primary text observed on exercised Appetize auth/pets surface |
| Tap targets | PARTIAL_PASS | Login and primary navigation controls were tappable in Appetize |
| Form labels | PARTIAL_PASS | Login surface was usable; full auth/pet/health/reminder label audit remains |
| Error states | POLICY_PASS | Fresh unverified login shows policy failure instead of infra failure |
| Loading/empty states | PARTIAL_PASS | Authenticated pets empty state rendered with CTA, not blank screen |
| Navigation semantics | PARTIAL_PASS | Auth -> pets transition worked in Appetize; broader tab-by-tab pass remains |

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
- Dependency audit fix: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110940-4f9f2eae.raw.txt`
- Render core API smoke: `temp/qa/day8-appetize-deep-login/day8-render-api-core-smoke.json`
- GitHub Actions `main` commit `c768850`: `temp/qa/day8-appetize-deep-login/github-actions-c768850-pass.png`
- Codemagic Appetize build: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/6a0157cb3a8de0b0c8f17cf5`

## Open Findings

- D8-F01: CLOSED. Appetize deep-login browser proof is captured with `/auth/login` `200`, `/pets` `200`, and authenticated pet-list screenshot.
- D8-F02: OPEN. Full visual manual QA still needs screen-by-screen execution beyond the Appetize auth/pets surface. API smoke already covers auth, pets, health records, reminders, notifications, and vet search.
- D8-F03: OPEN. Full accessibility audit is still partial; no severe issue was observed on exercised auth/pets surfaces, but health/reminder/vet/review screens still need visual accessibility pass.

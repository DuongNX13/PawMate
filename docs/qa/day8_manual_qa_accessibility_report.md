# PawMate Day 8 Manual QA And Accessibility Report

Date: `2026-05-11`

## Current Status

Day 8 QA is open. Local automated gates are green; Appetize deep-login browser evidence is still pending.

Known Day 7 carry-over:

- Render backend is live at `https://pawmate-api-yteu.onrender.com`.
- Appetize Network Logs already proved real backend traffic:
  - `POST /auth/register` -> `201`
  - `POST /auth/login` after fresh register -> `403 AUTH_006`
- `403 AUTH_006` is expected email-verification policy, not an infrastructure blocker.
- Deep-login demo requires a verified QA account.
- A verified QA account has been seeded in the cloud database and public Render `/auth/login` returned `200` for it.

## Manual QA Matrix

| Area | Flow | Status | Notes |
|---|---|---|---|
| Auth | Register fresh account | READY | Expect `201` and verify-email prompt |
| Auth | Login fresh unverified account | ACCEPTED_POLICY | Expect `403 AUTH_006` |
| Auth | Login verified QA account | API_PASS_PENDING_APPETIZE | Public Render login returned `200`; Appetize Network Logs still needed |
| Pet Profile | List pets | READY | Check empty/loading/authenticated state |
| Pet Profile | Create/edit pet | READY | Verify form validation and nav return |
| Vet Finder | Search/list/detail | READY | Verify remote data states and empty states |
| Reviews | Submit/read review core | READY | Verify one-review and error behavior where available |
| Health Records | Timeline/create/list | READY | Verify persisted state where backend route is available |
| Reminders | Create/list/due reminder | READY | Do not re-enable scheduled worker cron |
| Notifications | List/read/read-all | READY | Verify unread/read visual state |

## Accessibility Checklist

| Check | Status | Notes |
|---|---|---|
| Contrast | PENDING | Core screens must have no severe contrast issue |
| Text scale | PENDING | No clipped text at larger text scale |
| Tap targets | PENDING | Primary controls should be reliably tappable |
| Form labels | PENDING | Auth/pet/health/reminder inputs need clear labels |
| Error states | PENDING | User-facing messages must be understandable |
| Loading/empty states | PENDING | No blank unexplained screen |
| Navigation semantics | PENDING | Back/CTA/bottom nav behavior remains predictable |

## Appetize Evidence Targets

Required Day 8 deep-login evidence:

- screenshot or Network Logs capture showing `POST https://pawmate-api-yteu.onrender.com/auth/login` -> `200`;
- screenshot showing PawMate reached `/pets` or the authenticated pet-list surface;
- note that simulator/browser tab was closed after capture.

Existing Day 7 evidence:

- `temp/qa/appetize-auth-network-logs-register201-login403.png`

Day 8 local evidence:

- Backend gates: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110946-244b74f6.raw.txt`
- Mobile gates: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110627-b5d2d7c3.raw.txt`
- Dependency audit fix: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110940-4f9f2eae.raw.txt`

## Open Findings

- D8-F01: Appetize deep-login browser proof is not captured yet. Backend-side verified login is proven with public `/auth/login` `200`; remaining work is Codemagic/Appetize artifact upload and Network Logs capture.

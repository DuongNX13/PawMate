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
| D8-02 | Verified QA auth account path for Appetize | BACKEND_READY | `backend/scripts/seed-mobile-e2e-user.cjs`, `mobile/lib/features/auth/presentation/auth_qa_defaults.dart`, `codemagic.yaml`; public Render `/auth/login` returned `200` for the verified QA account |
| D8-03 | Appetize deep-login Network Logs proof | BLOCKED_ON_APPETIZE_RUN | Requires uploaded simulator app built with `PAWMATE_QA_AUTH_EMAIL` and `PAWMATE_QA_AUTH_PASSWORD` |
| D8-04 | Full manual QA matrix | READY | `docs/qa/day8_manual_qa_accessibility_report.md` |
| D8-05 | Accessibility pass | READY | `docs/qa/day8_manual_qa_accessibility_report.md` |
| D8-06 | CI/Ops proof | DONE_LOCAL | Backend/mobile gates, coverage, audit, and Render health check passed locally |

## Implementation Notes

- Appetize is the default browser-based iOS QA surface for Day 8.
- BrowserStack is out of scope for Day 8.
- Apple Developer/App Store Connect signing remains a final-day release-parity gap because the separate PawMate Apple team/payment path is still pending.
- Reminder Worker schedule remains disabled; manual dispatch remains available.
- `PAWMATE_QA_AUTH_EMAIL` is now supported as a compile-time mobile QA override. If omitted, the app keeps the old random QA email fallback.
- `PAWMATE_E2E_SKIP_ENV_LOCAL=1` can be used when seeding a cloud QA user so `.env.local` does not override the intended `DATABASE_URL`.

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
- [x] Public Render `/auth/login` returns `200` for the verified QA account.
- [ ] Appetize Network Logs show `/auth/login` `200` for verified QA account.
- [ ] Appetize app reaches `/pets` after login.
- [ ] Manual QA has no P0/P1 core-flow bugs.
- [ ] Accessibility pass has no severe contrast/tap-target/text-scale issues.

## Evidence

- Backend gates: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110946-244b74f6.raw.txt`
- Mobile gates: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110627-b5d2d7c3.raw.txt`
- Dependency audit fix: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-110940-4f9f2eae.raw.txt`
- Existing Appetize Day 7 register-policy proof: `temp/qa/appetize-auth-network-logs-register201-login403.png`

## Risk Register

| Risk | Severity | Status | Mitigation |
|---|---|---|---|
| Fresh register cannot immediately login because email is unverified | Known policy | ACCEPTED | Use verified QA account for deep-login proof |
| Appetize quota burn during browser automation | Medium | OPEN | Keep session short and close simulator tab after evidence capture |
| Apple signing assets unavailable | Release parity | DEFERRED | Move to final-day Apple Developer lane |
| Reminder Worker cron spam | Low | MITIGATED | Cron removed; manual dispatch kept |

## Exit Gate

Day 8 can close when:

- core MVP screens are visually signed off,
- no P0/P1 manual QA or accessibility issue remains,
- Appetize deep-login either has `/auth/login` `200` evidence or is explicitly moved to backlog with the email-verification policy reason,
- Render health and local CI gates are green,
- Apple signing remains tracked as a final-day gap only.

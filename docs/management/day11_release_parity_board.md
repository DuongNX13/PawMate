# PawMate Day 11 Release Parity Board

Date: `2026-05-13`

## Scope

Day 11 starts after Day 10 RC sign-off. The goal is final-day release parity prep, not a new feature sprint.

Day 10 result: `GO_WITH_KNOWN_ISSUES` for internal Android/Render RC.

Day 11 owns:

- release-parity blocker inventory,
- Apple signing/Codemagic handoff clarity,
- optional Appetize iOS simulator parity plan,
- Reminder Worker anti-spam verification,
- current live backend and GitHub verification refresh.

Out of scope:

- creating or paying for a separate PawMate Apple Developer team,
- claiming TestFlight/App Store readiness before signing assets exist,
- spending Appetize quota unless final parity evidence is explicitly needed,
- re-enabling Reminder Worker schedule.

## Current State

| Area | Status | Evidence |
|---|---|---|
| Android/Render RC | READY_WITH_KNOWN_ISSUES | Day 10 board/report closed on `ce5bb2b` |
| GitHub CI | GREEN | `CI` and `Compose Smoke` succeeded on latest `main` |
| Render backend | GREEN_WITH_COLD_START | `/health`, `/vets/search`, `/vets/nearby` returned `200`; first response can take about 24s on free tier |
| Reminder Worker email spam | MITIGATED | `.github/workflows/reminder-worker.yml` has only `workflow_dispatch`; no `schedule` trigger |
| Appetize iOS parity | OPTIONAL | Day 8 already has `/auth/login 200` and `/pets` proof; rerun only if quota is acceptable |
| Apple signing/TestFlight parity | EXTERNAL_BLOCKER | Waiting for Apple Developer team/payment/signing assets |

## Day 11 Task Plan

| ID | Task | Status | Evidence |
|---|---|---|---|
| D11-01 | Rehydrate Day 10 source of truth | DONE | Latest knowledge log plus Day 10 board/report |
| D11-02 | Refresh live Render smoke | DONE | `/health`, `/vets/search`, `/vets/nearby` return `200` |
| D11-03 | Refresh GitHub Actions status | DONE | Latest `main` CI and Compose Smoke are `success` |
| D11-04 | Verify Reminder Worker anti-spam state | DONE | Workflow has no `schedule` trigger |
| D11-05 | Fix stale scheduler runbook | DONE | `docs/management/day7_scheduler_runbook.md` now says manual-only |
| D11-06 | Create release parity readiness report | DONE | `docs/qa/day11_release_parity_readiness_report.md` |
| D11-07 | Repo-local verification | DONE | Backend URL preflight, Prisma validate, and focused reminder tests |
| D11-08 | Push Day 11 changes and verify Actions | DONE | Commit/push and GitHub Actions verification handled in Day 11 closeout |
| D11-09 | Fix Windows Node v24 preflight exit crash | DONE | `scripts/ci/validate-mobile-backend-url.mjs` no longer exits inside active `fetch` success path |

## Final-Day Handoff

Apple signing lane remains the only hard release-parity blocker:

1. Finish PawMate Apple Developer team/payment setup.
2. Connect Apple Developer/App Store Connect API in Codemagic.
3. Add provisioning profile/certificate for `com.pawmate.pawmateMobile`.
4. Run Codemagic `ios-real-device-smoke`.
5. Use TestFlight or physical iPhone proof for final release parity.

Optional iOS simulator lane:

1. Run Codemagic `ios-appetize-simulator-smoke` only when quota is acceptable.
2. Ensure `PAWMATE_API_BASE_URL=https://pawmate-api-yteu.onrender.com`.
3. Use a verified QA account and keep `PAWMATE_QA_AUTH_PASSWORD` in Codemagic secrets, not in source.
4. Upload the simulator ZIP to Appetize.
5. Capture `/auth/login 200` and `/pets 200`, then close the Appetize session.

## Known Issues

| Issue | Class | Day 11 Disposition |
|---|---|---|
| Apple signing unavailable | EXTERNAL_BLOCKER | Not repo-owned; move to final-day signing lane |
| Appetize not rerun after Day 10 | OPTIONAL_PARITY | Save quota; existing Day 8 proof is enough until final iOS parity is requested |
| Render free cold start | P2_OPS | Accept; Codemagic preflight already has 70s timeout |
| Local Node v24 preflight assertion after successful `fetch` | RESOLVED_DAY11 | Success path now exits after handles are cleared |
| Reminder Worker production schedule disabled | INTENTIONAL | Manual dispatch only; do not re-enable cron until worker policy is re-approved |

## Recommendation

`READY_FOR_FINAL_DAY_SIGNING_HANDOFF`.

Day 11 repo-local work is complete: docs/code changes are ready for final push verification, and the only remaining blocker is external Apple signing.

# PawMate Day 10 Execution Board

Date: `2026-05-11`

## Scope

Day 10 is the RC Gate. The goal is to decide whether the current PawMate MVP is `RC-ready` for internal candidate use, while keeping TestFlight/App Store signing as a separate final-day dependency.

Out of scope for Day 10:

- Creating or paying for a separate PawMate Apple Developer team.
- Claiming TestFlight/App Store readiness before Apple signing assets exist.
- Expanding all 80 Day 2 vet seed candidates into map-ready records.
- Replacing the current Render/Appetize/Android emulator QA surface with BrowserStack.

## Blocker Disposition

| Blocker | Status | Owner | Decision / Evidence |
|---|---|---|---|
| Render `/vets/nearby` returned empty on live backend | RESOLVED | Repo/backend | Fixed in `84dc545`; live Render returns 4 HCM nearby clinics |
| Android map marker/detail and large-text proof | RESOLVED | Mobile QA | Evidence captured in `temp/qa/day9-android-map/15-map-live-nearby-reloaded.png`, `16-marker-preview-sheet.png`, `17-preview-detail-route.png`, `21-large-text-map.png`, `22-large-text-marker-preview.png` |
| External call/directions app launch risk | RESOLVED_LOCAL | Mobile | Android/iOS URL scheme declarations added for `tel`, directions, Google navigation, Waze; `flutter analyze` and targeted vet map test passed |
| Fresh register -> login in Appetize blocked by email verification | NOT_INFRA_BLOCKER | Product policy | Expected `AUTH_006` for unverified fresh email; deep login requires verified QA account or internal test verification |
| Apple Developer/App Store Connect signing | EXTERNAL_DEPENDENCY | User/account | Final-day release parity only; blocked until PawMate Apple team/payment/signing assets are ready |
| Pre-existing dirty/generated files in worktree | NOT_PROJECT_BLOCKER | Local workspace | Left untouched; do not revert without explicit user request |

## Day 10 Task Plan

| ID | Task | Status | Acceptance |
|---|---|---|---|
| D10-01 | Refresh blocker inventory from Day 7-9 | DONE | Blocker disposition table is current and separates repo-owned vs external blockers |
| D10-02 | Harden external call/directions declarations | DONE | AndroidManifest and iOS Info.plist include the schemes used by vet call/directions actions |
| D10-03 | Verify local mobile gate after blocker hardening | DONE | `flutter analyze --no-pub` and targeted vet map screen test pass |
| D10-04 | Full RC backend gate | TODO | `npm run prisma:validate`, `npm run lint`, `npm run build`, `npm test` pass on candidate commit |
| D10-05 | Full RC mobile gate | DONE | `flutter analyze --no-pub`, `flutter test --no-pub --no-test-assets`, and `flutter build apk --debug --no-pub --dart-define=PAWMATE_API_BASE_URL=https://pawmate-api-yteu.onrender.com` pass through `P:` path |
| D10-06 | Render API smoke refresh | TODO | `/health`, `/vets/search`, `/vets/nearby`, and auth login smoke return expected statuses |
| D10-07 | Android RC smoke pass | TODO | Login, pets, vet list/detail/map, review, health, reminders, notifications have no P0/P1 issue |
| D10-08 | Appetize/iOS simulator sanity check | OPTIONAL | Reuse Appetize only if quota allows; no BrowserStack dependency |
| D10-09 | Known issues list | TODO | Known issues are classified as RC blocker, release-parity dependency, or backlog |
| D10-10 | Go/no-go recommendation | TODO | A concrete `GO`, `GO_WITH_KNOWN_ISSUES`, or `NO_GO` is recorded with evidence paths |
| D10-11 | Final-day Apple signing handoff | TODO | App Store Connect/Codemagic steps are listed without blocking Android/Render RC gate |

## RC Acceptance

Day 10 can sign off `RC-ready` when:

- no P0/P1 issue remains in exercised Android core MVP flows,
- backend and mobile full gates pass,
- GitHub CI and Compose Smoke pass on the candidate commit,
- Render live API smoke passes,
- known issues are explicit and do not block internal candidate use,
- Apple signing is tracked as release-parity dependency, not hidden as an unresolved app blocker.

## Day 10 Recommended Order

1. Commit and push the local blocker hardening patch.
2. Wait for GitHub CI and Compose Smoke.
3. Run full backend/mobile local gates if CI passes.
4. Run Android RC smoke with Render API base.
5. Write `docs/qa/day10_rc_gate_report.md`.
6. Give final go/no-go recommendation.

## Current Recommendation

Proceed into Day 10 RC Gate. Current evidence supports `Day 9 sign-off`; there is no remaining repo-owned Day 9 blocker. The only major unresolved dependency is Apple signing/TestFlight, which should stay on the final-day release parity lane.

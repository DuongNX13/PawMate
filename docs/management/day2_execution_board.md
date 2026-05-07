# PawMate Day 2 Execution Board

Project root: `D:\My Playground\PawMate`  
Snapshot updated: `2026-04-23`

## Day 2 Goal

- Register/login flow runs end to end in backend thin-slice
- Pet profile flow is usable in Flutter thin-slice
- Auth and pet tests are green
- UI direction follows the Day 2 handoff docs and uses the public Stitch project as the user-declared source of truth

## Design source of truth

- Public Stitch project: `https://stitch.withgoogle.com/projects/2278694761146796664`
- Current verification state:
  - the public project link is reachable
  - automated extraction of the actual rendered screens is still not reliable from the CLI/headless environment
  - current mobile implementation is aligned to `docs/design/day2_hifi_specs.md` and should still be manually compared against Stitch before claiming final visual fidelity

## Execution notes

- This wave did not spawn role-emulating workers for OpenClaw lanes.
- Existing Day 2 artifacts created earlier in the repo were reviewed and then turned into executable backend/mobile thin-slices.
- Backend was prioritized first because it is not blocked by incomplete visual extraction from Stitch.
- Current MVP scope explicitly keeps Google and Apple sign-in turned off for now.

## Task status

| Task | Owner lane | Status | Notes |
|---|---|---|---|
| `D2-01` AC Auth - Happy Path | Morpheus | DONE | Covered in `docs/product/day2_acceptance_criteria.md` |
| `D2-02` AC Auth - Edge Cases & Errors | Morpheus | DONE | Covered in `docs/product/day2_acceptance_criteria.md` |
| `D2-03` AC Vet Finder - Search & Filter | Morpheus | DONE | Covered in `docs/product/day2_acceptance_criteria.md` |
| `D2-04` Seed Data - 80 Phong Kham | Oracle | DONE | `backend/prisma/data/day2_vet_seed_candidates.json` now contains `80` curated seed candidates: `30` Hà Nội, `30` TP Hồ Chí Minh, `10` Hải Phòng, `10` Đà Nẵng |
| `D2-05` Auth Sequence Diagram | Architect | DONE | Documented in `docs/architecture/auth_sequence_diagrams.md` |
| `D2-06` Error Response Schema Standard | Architect | DONE | OpenAPI error envelope is live and backend error handling now returns `{success,error,requestId}` |
| `D2-07` Pet Profile Data Contract | Architect | DONE | Prisma schema is aligned, local DB is synced, and `backend/prisma/sql/day2_auth_pet_contract_patch.sql` now captures the patch |
| `D2-08` HiFi - Onboarding | Trinity | PARTIAL | Screen implemented locally, but manual Stitch visual comparison is still pending |
| `D2-09` HiFi - Login & Register Screens | Trinity | PARTIAL | Theme is now aligned to Figma token direction, auth screens are rebuilt with `Be Vietnam Pro` + `Inter`, and Google/Apple buttons are removed to match current MVP scope |
| `D2-10` HiFi - Pet Profile Form & List | Trinity | PARTIAL | Pet list/form remain locally runnable; vet list/detail visual direction is now also rebuilt from the current Figma intake page |
| `D2-11` API - POST /auth/register | Neo | DONE | Live proof is now green on the resumed Supabase project: register returns `201`, remote Supabase user is created, verify-email returns `200`, and login-after-verify returns `200`; immediate resend is correctly throttled for `59` seconds by the provider |
| `D2-12` API - POST /auth/login + JWT Refresh | Neo | DONE | JWT rotation, lockout policy, max active sessions, logout-all-session behavior, and Redis-backed refresh session storage are now live and runtime-smoke verified |
| `D2-13` API - POST /auth/oauth (Google + Apple) | Neo | DEFERRED | Backend verifier and route guard are in place, but `AUTH_SOCIAL_LOGIN_ENABLED=false` keeps social login disabled for the current MVP so this is intentionally out of the active Day 2 critical path |
| `D2-14` API - Pet CRUD + Photo Upload | Neo | DONE | CRUD, ownership checks, real base64 image upload, local file persistence, and public asset serving are live and covered by route tests |
| `D2-15` Flutter - Onboarding Screens | Neo | PARTIAL | Implemented and verified by `flutter analyze` and `flutter test`; backend-independent UI flow only |
| `D2-16` Flutter - Login & Register & OTP | Neo | PARTIAL | Login/register/OTP now call the real backend register -> verify-email -> login path, persist a local session marker, and are verified by Flutter analyze/test; still pending on-device smoke and manual Stitch QA |
| `D2-17` Flutter - Pet Profile Form & List | Neo | PARTIAL | Implemented and verified by `flutter analyze` and `flutter test`; state is local Riverpod demo state |
| `D2-18` Tests - Auth Endpoints Unit | Cypher | DONE | Jest suite is green in `backend/tests/auth.service.test.ts` |
| `D2-19` Tests - Pet CRUD Integration | Cypher | DONE | HTTP integration tests cover create/list/update/photo upload/delete; local runtime smoke is green again after restoring portable PostgreSQL and Redis on `localhost:5432` / `localhost:6379` |
| `D2-20` Tests - OAuth Real Device | Cypher | DEFERRED | User explicitly cut Google/Apple sign-in from the current MVP scope, so real-device OAuth is removed from the active critical path |

## Delta since 2026-04-22

- `D2-04` seed data was regenerated with explicit placeholder fields for `latitude`, `longitude`, `openHours`, `services`, `photoUrls`, and enrichment flags so Day 3 prep can see what is still missing for nearby-map delivery.
- `D2-11` is now live-proven on the resumed Supabase project:
  - `npm run supabase:bootstrap` is green again
  - `AUTH_LIVE_PROOF_EMAIL=<real-email> npm run auth:live-proof` proves the real register -> verify-email -> login path
  - resend verification is rate-limited by provider cooldown, which is expected behavior rather than a blocker
- `D2-16` auth UI is no longer a backend-free thin-slice:
  - register sends the real request
  - OTP verifies the account in-app
  - login persists a local session marker for the launch gate
  - this avoids relying on fragile email-link redirects for the current MVP path
- Localhost auth redirect no longer falls into a raw backend 404:
  - `GET /` and `GET /auth/callback` now render a friendly HTML landing page
  - the page reads Supabase hash/query state and explains success, expiry, or next steps
- `D2-13` should now be treated as `DEFERRED`, not merely `PARTIAL`, because social login is intentionally outside the current MVP scope.
- `D2-19` no longer carries a stale runtime-smoke warning.

## Verified in this wave

- Backend:
  - `npm run build`
  - `npm run lint`
  - `npm test`
  - `npm run test:coverage`
  - `npm audit --omit=dev`
  - `npm run smoke:runtime` -> PASS after portable PostgreSQL/Redis were restarted
  - `AUTH_LIVE_PROOF_EMAIL=<real-email> npm run auth:live-proof` -> PASS for register, verify-email, and login-after-verify on the resumed Supabase project
  - `npm run supabase:bootstrap` -> PASS
  - `prisma db push --skip-generate --accept-data-loss`
  - `psql -f backend/prisma/sql/day2_auth_pet_contract_patch.sql`
  - `npm run seed:vets:build`
- Mobile:
  - `dart.exe packages/flutter_tools/bin/flutter_tools.dart analyze --no-pub` -> PASS
  - `dart.exe packages/flutter_tools/bin/flutter_tools.dart test --no-pub` -> PASS
  - local Flutter verification was restored without admin by rehydrating `C:\Users\duongnx\.puro\envs\stable\flutter\bin\cache` with the correct engine stamps and a `dart-sdk` junction

## Key artifacts touched or added

- Backend
  - `backend/src/app.ts`
  - `backend/src/config/env.ts`
  - `backend/src/errors/app-error.ts`
  - `backend/src/errors/error-codes.ts`
  - `backend/src/infrastructure/prisma.ts`
  - `backend/src/infrastructure/redis.ts`
  - `backend/src/infrastructure/pet-photo-storage.ts`
  - `backend/src/integrations/oauth-verifier.ts`
  - `backend/src/repositories/prisma-auth-user-store.ts`
  - `backend/src/repositories/prisma-pet-store.ts`
  - `backend/src/repositories/redis-auth-session-store.ts`
  - `backend/src/routes/auth.ts`
  - `backend/src/routes/pets.ts`
  - `backend/src/services/auth/auth-service.ts`
  - `backend/src/services/pets/pet-service.ts`
  - `backend/scripts/day2-auth-live-proof.ts`
  - `backend/scripts/build-day2-vet-seed-candidates.mjs`
  - `backend/scripts/day2-runtime-smoke.ts`
  - `backend/prisma/data/day2_vet_seed_candidates.json`
  - `backend/prisma/sql/day2_auth_pet_contract_patch.sql`
  - `backend/tests/auth.service.test.ts`
  - `backend/tests/auth.routes.test.ts`
  - `backend/tests/pet.routes.test.ts`
  - `backend/tests/persistence.test.ts`
  - `backend/tests/infrastructure.test.ts`
  - `backend/tests/oauth-verifier.test.ts`
- Mobile
  - `mobile/lib/app/theme/app_theme.dart`
  - `mobile/lib/app/theme/app_tokens.dart`
  - `mobile/lib/features/onboarding/presentation/onboarding_screen.dart`
  - `mobile/lib/features/auth/presentation/login_screen.dart`
  - `mobile/lib/features/auth/presentation/register_screen.dart`
  - `mobile/lib/features/auth/presentation/otp_screen.dart`
  - `mobile/lib/core/widgets/primary_gradient_button.dart`
  - `mobile/lib/core/widgets/pawmate_bottom_nav.dart`
  - `mobile/lib/features/pets/application/pet_list_provider.dart`
  - `mobile/lib/features/pets/domain/pet_profile.dart`
  - `mobile/lib/features/pets/presentation/create_pet_screen.dart`
  - `mobile/lib/features/pets/presentation/pet_list_screen.dart`
  - `mobile/lib/features/pets/presentation/pet_detail_screen.dart`
  - `mobile/lib/features/vets/domain/vet_demo_data.dart`
  - `mobile/lib/features/vets/presentation/vet_list_screen.dart`
  - `mobile/lib/features/vets/presentation/vet_detail_screen.dart`
  - `mobile/test/widget_test.dart`

## Next critical path

1. Use `backend/prisma/data/day2_vet_seed_candidates.json` as a list/detail seed source, but treat geo-hours-services enrichment as a required Day 3 prep wave before nearby-map delivery.
2. Run a manual Stitch-vs-Flutter comparison for the rebuilt auth and pet screens before calling the Day 2 UI visually done.
3. Keep `D2-13` and `D2-20` deferred until the MVP scope re-enables Google/Apple sign-in.

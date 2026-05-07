# PawMate Day 2 Status Summary

Project root: `D:\My Playground\PawMate`  
Snapshot updated: `2026-04-23`

## Executive summary

- Day 2 now has a working backend thin-slice for auth and pet flows.
- Mobile thin-slice for onboarding, auth, OTP, pet create/list/detail is updated and locally verified.
- Vet discovery now also has a cleaner UI direction:
  - shared theme tokens aligned to the current Figma intake page
  - rebuilt login/register screens without Google/Apple buttons
  - rebuilt vet list/detail screens using researched clinic demo data
- Auth Day 2 is one step closer to production:
  - register now has Supabase-backed verify-email and resend-verification paths
  - mobile auth now verifies signup by OTP inside the app instead of depending on the clicked email link
  - OAuth now has a direct backend verifier for Google and Apple tokens and only falls back to Supabase when no direct audience config exists
  - social login is intentionally disabled in the current MVP scope via `AUTH_SOCIAL_LOGIN_ENABLED=false`
- The live environment picture is now clearer:
  - portable PostgreSQL and Redis are back up locally and `npm run smoke:runtime` is green again
  - the resumed Supabase project is reachable again
  - real register proof is now green through the live path
- The largest remaining gap is no longer basic scaffolding; it is the jump from verified Day 2 thin-slice into stronger Day 3 production inputs:
  - manual visual verification against the Stitch design
  - backend import plus enrichment of the new vet seed dataset for Day 3 nearby-map work

## Current counts

- `12/20` tasks are effectively done at artifact or verified-code level.
- `6/20` tasks are partially closed with runnable thin-slice output.
- `2/20` tasks are explicitly deferred by MVP scope.

## What was completed in this wave

### Backend

- Added a shared error contract and runtime error handler returning:
  - `success`
  - `error.code`
  - `error.message`
  - `error.field`
  - `requestId`
- Implemented auth service behavior for:
  - register
  - verify email
  - resend verification email
  - login
  - refresh token rotation
  - logout
  - pluggable OAuth verification
  - access token verification
  - account lockout after failed attempts
  - max active session policy
- Implemented pet service behavior for:
  - list
  - get detail
  - create
  - update
  - soft delete
  - attach photo reference URL
- Added backend tests for:
  - auth service unit flows
  - auth route integration
  - pet route integration
  - repository and infrastructure layers
- Added route coverage for:
  - `POST /auth/verify-email`
  - `POST /auth/resend-verification`
- Added unit coverage for:
  - verify-email success path
  - resend-verification success/already-verified path
  - OAuth verifier context forwarding
- Added direct OpenID OAuth verification for Day 2:
  - Google ID token verification now uses Google's public JWKS
  - Apple identity token verification now uses Apple's public JWKS
  - verifier instances cache JWKS per app instance instead of refetching on every request
  - route can bypass disabled Supabase Google/Apple providers when direct audiences are configured
- Added verifier-focused tests for:
  - remote JWKS loading and caching
  - malformed JWT rejection
  - missing email / subject claims
  - audience mismatch
  - Apple nonce mismatch
  - fallback vs no-fallback behavior
- Fixed a critical register consistency gap:
  - if Supabase email delivery fails, the local user is now rolled back instead of being left orphaned in the database
- Fixed env loading for normal backend runtime:
  - app startup now loads both `.env` and `.env.local`
- Added an auth live-proof script:
  - `AUTH_LIVE_PROOF_EMAIL=<real-email> npm run auth:live-proof`
- Added runtime smoke verification in `backend/scripts/day2-runtime-smoke.ts`
- Kept runtime smoke local-only by stubbing external email delivery in the smoke script
- Synced the local PostgreSQL schema to the updated Day 2 contract
- Added SQL patch artifact for the Day 2 auth/pet schema update
- Upgraded Fastify to `5.8.5`, removing the previously reported high-severity advisory
- Added real pet photo upload handling:
  - accepts base64 image payloads
  - stores image files locally
  - serves saved assets back through `/assets/pet-photos/:petId/:fileName`

- Added a repeatable vet seed build script:
  - `npm run seed:vets:build`
  - outputs `backend/prisma/data/day2_vet_seed_candidates.json`
  - current dataset count: `80`
  - split: `30` Hà Nội, `30` TP Hồ Chí Minh, `10` Hải Phòng, `10` Đà Nẵng

- Seed readiness note for Day 3:
  - the regenerated seed file now makes missing nearby-map inputs explicit via placeholder fields:
    - `latitude`
    - `longitude`
    - `openHours`
    - `services`
    - `photoUrls`
    - `enrichmentStatus`

### Mobile

- Refined onboarding to follow the Day 2 hi-fi direction more closely:
  - brand header
  - richer hero block
  - stable CTA row
  - updated copy from the handoff
- Refined login/register/OTP flows with clearer hierarchy, inline guidance, and real backend hookup
- Rebuilt theme tokens to match the current Figma intake page:
  - primary `#FF8A5B`
  - secondary `#2D5A88`
  - tertiary `#FFD700`
  - typography split between `Be Vietnam Pro` and `Inter`
- Rebuilt vet list/detail from placeholder cards into a more realistic Day 2 discovery flow
- Expanded pet local model and form flow to cover more Day 2 contract fields:
  - gender
  - color
  - microchip
  - neutered state
  - health status
- Improved pet list/detail presentation and empty state

## Quality gates

- Backend
  - `npm run build` -> PASS
  - `npm run lint` -> PASS
  - `npm test` -> PASS
  - `npm run test:coverage` -> PASS (`83.08%` lines)
  - `npm audit --omit=dev` -> PASS (`0` high/critical)
  - `npm run smoke:runtime` -> PASS after portable PostgreSQL and Redis were restarted
- Backend runtime env
  - `npm run supabase:bootstrap` -> PASS on the resumed Supabase project
  - `AUTH_LIVE_PROOF_EMAIL=<real-email> npm run auth:live-proof` -> PASS for register, verify-email, and login-after-verify
- Mobile
  - `dart.exe packages/flutter_tools/bin/flutter_tools.dart analyze --no-pub` -> PASS
  - `dart.exe packages/flutter_tools/bin/flutter_tools.dart test --no-pub` -> PASS
  - Flutter verification on this machine is working again without admin after rehydrating `C:\Users\duongnx\.puro\envs\stable\flutter\bin\cache`
- Backend localhost auth UX
  - `GET /` and `GET /auth/callback` now return a friendly HTML auth landing page instead of raw `Route GET:/ not found`
  - this page can interpret Supabase hash/query state and point the user back to the in-app OTP flow when needed

## Important caveats

- The current Day 2 backend is intentionally a thin-slice:
  - live email-first auth is now proven on the real Supabase project
- The current Day 2 mobile screens are implementation-ready, but final design fidelity against Stitch is not yet proven from automation alone.
- The current MVP-safe verify path is OTP inside the app; the raw Supabase email-link confirm UX can still misroute if dashboard URL/template settings stay on an old localhost-style config.
- The seed dataset is curated from public toplist sources:
  - exact public star ratings are still `null` on purpose until a verified rating source is added

## Main blockers and risks

- `D2-13` and `D2-20` are intentionally deferred while social login stays out of the current MVP scope
- Day 3 nearby-map work cannot start honestly from the current seed file until geo-hours-services enrichment happens
- the public Stitch project is reachable, but the actual rendered screen extraction still needs manual visual review

## Recommended next step

Move straight into the current MVP critical path:

1. import `backend/prisma/data/day2_vet_seed_candidates.json` only as a list/detail seed and schedule a Day 3 enrichment wave for geo-hours-services before nearby-map delivery
2. do a manual Stitch-vs-Flutter review sweep for the rebuilt auth and pet screens
3. keep social login work deferred until the MVP scope re-enables it

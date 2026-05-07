# PawMate Day 2 Output Review

Snapshot date: `2026-04-09`

## Scope reviewed

- Product handoff:
  - `docs/product/day2_acceptance_criteria.md`
- Design handoff:
  - `docs/design/day2_hifi_specs.md`
- Architecture handoff:
  - `docs/architecture/auth_sequence_diagrams.md`
  - `docs/architecture/pet_profile_data_contract.md`
  - `docs/architecture/openapi.phase1.yaml`
- Backend implementation and tests
- Mobile implementation and tests

## Fixed during review

1. `logout` behavior was aligned to Day 2 task intent so it now revokes all active refresh sessions for the user, not just the current one.
2. `PetCreateRequest` contract requires `gender`, and backend validation now enforces that instead of silently defaulting it.
3. Runtime persistence was moved out of memory:
   - Prisma now persists user and pet records
   - Redis now persists auth session state
4. Backend runtime verification now exists as a repeatable script: `npm run smoke:runtime`.
5. Fastify was upgraded to `5.8.4`, removing the previously reported high-severity `npm audit` finding.
6. Pet photo upload now accepts real image payloads, writes them to local storage, and serves them back through `/assets/pet-photos/:petId/:fileName`.
7. Register now has explicit `verify-email` and `resend-verification` backend paths wired to a Supabase auth gateway abstraction.
8. OAuth now forwards provider token context (`accessToken`, `nonce`, `redirectUri`) through the backend service boundary and into the verifier abstraction.
9. Register now rolls back the local user if Supabase email delivery fails, preventing orphaned users after external provider errors.
10. Normal backend runtime now loads `.env.local`, matching the existing bootstrap and no-admin setup flow.
11. OAuth now has a direct OpenID verifier using Google and Apple public JWKS, with per-app-instance JWKS caching instead of a hard dependency on enabled Supabase providers.
12. Backend test coverage now clears the Day 2 quality bar at `83.44%` lines, and the production dependency audit is clean.

## Current findings

1. `D2-11` and `D2-13` are now code-complete at the backend boundary, but they are still not fully product-complete because the external auth path is constrained by live provider state.
   Files:
   - `backend/src/services/auth/auth-service.ts`
   - `backend/src/routes/auth.ts`
   - `backend/src/integrations/supabase-auth-gateway.ts`
   - `backend/src/integrations/oauth-verifier.ts`
   - `backend/scripts/day2-auth-live-proof.ts`
   Why it matters:
   - the real Supabase project currently returns `email rate limit exceeded` on the register success path
   - backend OAuth no longer depends on `google=false` / `apple=false` in Supabase, but live Google still needs the real allowed audience/client ID configured locally before the direct verifier can prove a real token

2. The Flutter screens are implementation-ready, but final visual fidelity against the Stitch project is still unproven.
   Files:
   - `mobile/lib/features/onboarding/presentation/onboarding_screen.dart`
   - `mobile/lib/features/auth/presentation/login_screen.dart`
   - `mobile/lib/features/auth/presentation/register_screen.dart`
   - `mobile/lib/features/pets/presentation/create_pet_screen.dart`
   Why it matters:
   - the public Stitch link is reachable, but the actual rendered design still needs a manual review sweep before the UI should be called final

3. Real-device OAuth validation remains blocked outside this workspace.
   Files:
   - `docs/management/day2_execution_board.md`
   - `docs/qa/day2_oauth_real_device_runbook.md`
   Why it matters:
   - the Day 2 acceptance bar for Apple/Google sign-in on actual devices is not something this machine can close alone

## Evidence used in the review

- Backend quality gates:
  - `npm run build`
  - `npm run lint`
  - `npm test`
  - `npm run test:coverage`
  - `npm audit --omit=dev`
  - `npm run smoke:runtime`
  - `npm run prisma:validate`
  - `AUTH_LIVE_PROOF_EMAIL=<real-email> npm run auth:live-proof`
- Mobile quality gates:
  - `flutter analyze`
  - `flutter test`
- Local runtime evidence:
  - PostgreSQL reachable at `127.0.0.1:5432`
  - Redis reachable at `127.0.0.1:6379`
  - runtime smoke showed persisted user, persisted pet, and Redis session data
  - real Supabase storage bootstrap succeeded for project `qeoowayxfqyhfcgnrfnv`
  - real auth live-proof showed:
    - register hits Supabase email and currently fails on provider rate limit
    - failed register no longer leaves a local orphan user
    - verify-email and login succeed with real Supabase signup tokens
    - Google and Apple JWT verification logic is now covered locally by direct JWKS-based tests

## Review verdict

- No critical code defects remain in the implemented Day 2 auth/pet slice.
- The remaining gaps are now concentrated in external identity provider quota/configuration and manual design verification, not in the core runtime path.

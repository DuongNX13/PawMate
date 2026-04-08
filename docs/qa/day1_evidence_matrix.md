# PawMate Day 1 Evidence Matrix

This file maps the Day 1 board to concrete proof so the team can distinguish scaffolded work from verified work.

| Task | Status basis | Evidence |
|---|---|---|
| `D1-02` | Blocked by remote auth | `CONTRIBUTING.md` exists, portable `gh` is installed, and `scripts/dev/bootstrap-github-no-admin.ps1` reaches the expected auth boundary, but remote GitHub branch protection is still missing |
| `D1-03` | Documented | `docs/architecture/openapi.phase1.yaml` |
| `D1-04` | Documented | `docs/architecture/openapi.phase1.yaml` |
| `D1-05` | Documented | `docs/architecture/erd.md` |
| `D1-06` | Documented | `docs/architecture/adr.md` |
| `D1-07` | Documented and improved | `docs/product/day1_user_stories_and_dod.md` |
| `D1-08` | Documented and operationalized | `docs/product/day1_user_stories_and_dod.md`, `docs/qa/day1_evidence_matrix.md` |
| `D1-09` | Documented | `docs/design/day1_design_system.md` |
| `D1-10` | Documented | `docs/design/day1_design_system.md` |
| `D1-11` | Documented | `docs/design/day1_wireframes_and_states.md` |
| `D1-12` | Documented and improved | `docs/design/day1_wireframes_and_states.md`, `docs/design/day1_flutter_handoff_matrix.md` |
| `D1-13` | Verified | `npm run lint`, `npm test`, `npm run build`, live `/health` check |
| `D1-14` | Verified for scaffold | Flutter SDK installed, `mobile/` scaffold exists, `flutter analyze` passes, `flutter test` passes via `subst` path alias |
| `D1-15` | Verified local runtime | `backend/prisma/schema.prisma`, `npm run prisma:validate`, `npx prisma db push --skip-generate`, `backend/prisma/sql/day1_postgis_patch.sql`, `postgis_full_version()`, `pg_indexes` proof for `vets_location_gist_idx` |
| `D1-16` | Partially verified | `.env.example`, `backend/src/config/env.ts`, `scripts/dev/bootstrap-supabase-env.ps1`, `backend/scripts/supabase-bootstrap.cjs`, portable Redis `PONG`, verified start/stop helper scripts, documented Supabase contract |
| `D1-17` | Enforceable once pushed | `.github/workflows/ci.yml` plus backend lint/test/prisma and mobile analyze/test/build lanes |
| `D1-18` | Partially verified | `docker-compose.yml`, `backend/Dockerfile`, `backend/.dockerignore`, `deploy/fly.staging.template.toml`, `scripts/dev/fly-first-deploy.ps1`, `.github/workflows/compose-smoke.yml`, `.github/workflows/fly-staging.yml`, portable `flyctl version` |

## Day 1 proof commands

Run in `backend`:

```bash
npm ci
npm run lint
npm test
npm run build
npm run prisma:validate
```

Run in `mobile`:

```bash
flutter analyze
flutter test
```

On this Windows machine, local `flutter test` currently uses a temporary `subst` drive alias to avoid a space-in-path native-assets issue.

Run local portable infrastructure from the repo root:

```powershell
powershell -File scripts/dev/start-portable-postgres.ps1
powershell -File scripts/dev/start-portable-redis.ps1
```

Portable cloud CLI checks:

```powershell
D:\My Playground\tools\gh\bin\gh.exe --version
D:\My Playground\tools\flyctl\flyctl.exe version
```

Bootstrap helpers:

```powershell
powershell -File scripts/dev/bootstrap-github-no-admin.ps1 -Owner "<owner>" -Repo "PawMate"
powershell -File scripts/dev/bootstrap-supabase-env.ps1 -SupabaseUrl "https://<project-ref>.supabase.co" -PublishableKey "<key>" -SecretKey "<key>"
powershell -File scripts/dev/fly-first-deploy.ps1 -AppName "<fly-app-name>" -GenerateOnly
```

## Still external

- Remote GitHub branch protection
- Supabase project and keys
- Fly.io credentials and staging app
- Full local Docker runtime verification on this machine
- Android SDK for local APK build

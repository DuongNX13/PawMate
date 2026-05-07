# PawMate Day 1 Status Summary

Project root: `D:\My Playground\PawMate`  
Snapshot updated: `2026-04-08`

## Executive summary

- `16/18` tasks are fully done for Day 1.
- `2/18` tasks are partially closed and now have a no-admin completion path prepared in the repo.
- `0/18` tasks remain hard-blocked by local admin rights.

## What was re-verified in this pass

- Backend:
  - `npm run lint`
  - `npm test`
  - `npm run build`
  - `npm run prisma:validate`
  - live `GET /health` -> `{"status":"ok"}`
- Mobile:
  - `flutter analyze`
  - `flutter test`
- Database:
  - official PostgreSQL 17.9 Windows binary archive provisioned under `D:\My Playground\tools\pgsql`
  - PostGIS 3.6.2 bundle applied locally
  - `prisma db push --skip-generate` succeeded against local `pawmate`
  - `SELECT postgis_full_version();` succeeded
  - `vets.location` exists as `geography`
  - `vets_location_gist_idx` is created through raw SQL patch
  - repo helper scripts can now start and stop the portable PostgreSQL/PostGIS runtime
- Cache:
  - portable Redis runtime provisioned under `D:\My Playground\tools\redis-portable`
  - `redis-cli ping` -> `PONG`
  - repo helper scripts can now start and stop the portable Redis runtime
- Remote tooling:
  - portable GitHub CLI is provisioned under `D:\My Playground\tools\gh`
  - portable Fly CLI is provisioned under `D:\My Playground\tools\flyctl`
  - GitHub publish helper now exists in `scripts/dev/bootstrap-github-no-admin.ps1`
  - Fly-first helper now exists in `scripts/dev/fly-first-deploy.ps1`
- Supabase:
  - env bootstrap helper now exists in `scripts/dev/bootstrap-supabase-env.ps1`
  - bucket bootstrap helper now exists in `backend/scripts/supabase-bootstrap.cjs`
- CI and staging:
  - hosted compose smoke workflow now exists in `.github/workflows/compose-smoke.yml`
  - hosted Fly deploy workflow now exists in `.github/workflows/fly-staging.yml`

## Task status

| Task | Current status | Tracking note |
|---|---|---|
| `D1-01` Kick-off & Tracking Board | DONE | Board and load plan exist |
| `D1-02` GitHub Repo + Branch Strategy | DONE | Repo-local commit exists, `main` and `develop` are pushed to `DuongNX13/PawMate`, and branch protection now requires PR + 1 review on both branches |
| `D1-03` OpenAPI Contract - Auth Module | DONE | Documented |
| `D1-04` OpenAPI Contract - Pet/Vet/Review/Health | DONE | Documented |
| `D1-05` Database ERD | DONE | Documented |
| `D1-06` Architecture Decision Records | DONE | Documented |
| `D1-07` User Stories - Phase 1 | DONE | Documented |
| `D1-08` Definition of Done - Phase 1 | DONE | Documented |
| `D1-09` Design System - Colors & Typography | DONE | Documented |
| `D1-10` Design System - Spacing & Components | DONE | Documented |
| `D1-11` Wireframe - Phase 1 Flows | DONE | Documented |
| `D1-12` Define 5 UI States Standard | DONE | Documented |
| `D1-13` Init Backend - Fastify + TypeScript | DONE | Re-verified locally in this pass |
| `D1-14` Init Flutter Project | DONE | Re-verified locally in this pass; APK build still needs Android SDK |
| `D1-15` Setup PostgreSQL + PostGIS + Prisma | DONE | Portable PostgreSQL/PostGIS local runtime works; Prisma sync plus spatial patch verified |
| `D1-16` Setup Redis + Supabase | PARTIAL | Redis local runtime works, and Supabase env/storage bootstrap is now scripted; the actual project API URL and provider credentials are still missing |
| `D1-17` Setup GitHub Actions CI | DONE | Workflow file exists and reflects backend/mobile lanes |
| `D1-18` Setup Docker Compose + Fly.io Staging | PARTIAL | Compose, hosted smoke workflow, Fly template, and Fly-first deploy workflow exist; Fly token works, but billing must be added before app creation can continue |

## Remaining blockers

### External or account-bound

- `D1-16`: Supabase project API URL and auth provider setup
- `D1-18`: Fly billing, app creation, and hosted workflow execution after repo push

### Heavy local runtime not yet provisioned

- Android SDK for `flutter build apk --debug`
- Docker Desktop/runtime for local-only compose use, but not for the new Fly-first/hosted-runner path

## Local runtime shortcuts added in this pass

- PostgreSQL/PostGIS:
  - start: `scripts/dev/start-portable-postgres.ps1`
  - stop: `scripts/dev/stop-portable-postgres.ps1`
- Redis:
  - start: `scripts/dev/start-portable-redis.ps1`
  - stop: `scripts/dev/stop-portable-redis.ps1`
- GitHub CLI:
  - binary: `D:\My Playground\tools\gh\bin\gh.exe`
  - current state: GitHub CLI itself is not logged in, but Git push and GitHub API access work through Git Credential Manager
  - helper: `scripts/dev/bootstrap-github-no-admin.ps1`
- Git remote:
  - `origin` -> `https://github.com/DuongNX13/PawMate.git`
  - remote branches are live: `main`, `develop`
  - branch protection is active on both branches
- Fly CLI:
  - binary: `D:\My Playground\tools\flyctl\flyctl.exe`
  - current state: token works, but Fly app creation is blocked by billing
  - helper: `scripts/dev/fly-first-deploy.ps1`
- Supabase bootstrap:
  - env helper: `scripts/dev/bootstrap-supabase-env.ps1`
  - bucket helper: `backend/scripts/supabase-bootstrap.cjs`
- Cloud-ready runbook:
  - `docs/management/day1_cloud_bootstrap_runbook.md`

## Latest unblock notes

- `D1-02` is now closed end-to-end without Windows admin rights because the machine already had working GitHub credentials through Git Credential Manager, even though `gh auth status` stays unauthenticated.
- `D1-16` is still partial because the supplied Supabase URL points to the dashboard, not to the project API host. The supplied secret key also cannot query the Supabase Management API, so the real project URL still has to come from the Supabase project settings page.
- `D1-18` is still partial because the supplied Fly token is valid, but Fly blocks app creation until billing is added to the active organization.

## Important evidence paths

- Board: `docs/management/day1_execution_board.md`
- Blockers: `docs/management/day1_runtime_blockers.md`
- No-admin workaround note: `docs/management/day1_no_admin_workarounds.md`
- Cloud bootstrap runbook: `docs/management/day1_cloud_bootstrap_runbook.md`
- Evidence matrix: `docs/qa/day1_evidence_matrix.md`
- Spatial SQL patch: `backend/prisma/sql/day1_postgis_patch.sql`

## Residual quality risk

- `npm audit --omit=dev` currently reports one high-severity advisory in `fastify@4`, and the suggested fix is a breaking upgrade to Fastify 5. This unblock wave keeps Fastify 4 stable for Day 1 and carries the upgrade as a follow-up task.

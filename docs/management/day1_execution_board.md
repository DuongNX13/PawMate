# PawMate Day 1 Execution Board

Project root: `D:\My Playground\PawMate`
Date: `2026-04-08`

## Current Constraints

- Flutter SDK is installed locally at `tools/flutter`, but not added to global `PATH`
- Android SDK is not installed locally
- `docker` not found in local `PATH`
- portable PostgreSQL 17.9 + PostGIS 3.6.2 are provisioned locally under `D:\My Playground\tools\pgsql` and `D:\My Playground\tools\pgsql-data`
- portable Redis is provisioned locally under `D:\My Playground\tools\redis-portable`
- portable GitHub CLI is provisioned locally under `D:\My Playground\tools\gh`
- portable Fly CLI is provisioned locally under `D:\My Playground\tools\flyctl`
- no GitHub remote is configured yet for this repository
- local Docker is still absent, but compose verification now has a hosted-runner fallback via `.github/workflows/compose-smoke.yml`

## Load Strategy

- Oracle owns coordination and load balancing only, no heavy authoring tasks beyond board and checkpoint synthesis.
- Architect stays on contract/schema/governance artifacts.
- Morpheus stays on stories and DoD.
- Trinity stays on design system, wireframes, and UI states.
- Neo has completed backend bootstrap, mobile scaffold, and portable local database/cache runtime setup; local Android build remains blocked by missing Android SDK.
- Cypher focuses on CI/infrastructure scaffolds and verification notes; runtime verification that needs Docker is blocked.

## Day 1 Tasks

| Task | Owner | Support | Status | Notes |
|---|---|---|---|---|
| D1-01 Kick-off & Tracking Board | Oracle | - | DONE | Board and load plan created in `docs/management/` |
| D1-02 GitHub Repo + Branch Strategy | Architect | Neo | BLOCKED | Repo and `CONTRIBUTING.md` are ready, and `scripts/dev/bootstrap-github-no-admin.ps1` now prepares remote/push flow; the remaining gap is GitHub login plus the first real commit and remote repo ownership |
| D1-03 OpenAPI Contract - Auth Module | Architect | Morpheus | DONE | Auth contract included in `docs/architecture/openapi.phase1.yaml` |
| D1-04 OpenAPI Contract - Pet/Vet/Review/Health | Architect | Morpheus | DONE | Phase 1 contract added for pets, vets, reviews, health, reminders, notifications |
| D1-05 Database ERD | Architect | Neo | DONE | ERD captured in `docs/architecture/erd.md` |
| D1-06 Architecture Decision Records | Architect | Oracle | DONE | ADRs captured in `docs/architecture/adr.md` |
| D1-07 User Stories - Phase 1 | Morpheus | Trinity | DONE | User stories created in `docs/product/day1_user_stories_and_dod.md` |
| D1-08 Definition of Done - Phase 1 | Morpheus | Cypher | DONE | DoD captured in `docs/product/day1_user_stories_and_dod.md` |
| D1-09 Design System - Colors & Typography | Trinity | Morpheus | DONE | Design tokens documented in `docs/design/day1_design_system.md` |
| D1-10 Design System - Spacing & Components | Trinity | Morpheus | DONE | Component basics documented in `docs/design/day1_design_system.md` |
| D1-11 Wireframe - Phase 1 Flows | Trinity | Morpheus | DONE | Lo-fi flow structure documented in `docs/design/day1_wireframes_and_states.md` |
| D1-12 Define 5 UI States Standard | Trinity | Cypher | DONE | Shared state rules documented in `docs/design/day1_wireframes_and_states.md` |
| D1-13 Init Backend - Fastify + TypeScript | Neo | Architect | DONE | Fastify 4 + TypeScript scaffold created; `build`, `test`, `lint`, and live `/health` verified |
| D1-14 Init Flutter Project | Neo | Trinity | DONE | Flutter 3.41.6 installed locally, mobile scaffold created, feature-first folders added, `flutter analyze` and `flutter test` verified via no-space drive alias |
| D1-15 Setup PostgreSQL + PostGIS + Prisma | Neo | Architect | DONE | Portable PostgreSQL 17.9 + PostGIS 3.6.2 verified locally; `prisma db push` plus spatial SQL patch proved `vets.location` and GIST index setup |
| D1-16 Setup Redis + Supabase | Neo | Architect | PARTIAL | Portable Redis is done, and Supabase now has env/bootstrap helpers in-repo; the remaining gap is a real Supabase project plus provider credentials |
| D1-17 Setup GitHub Actions CI | Cypher | Neo | DONE | `.github/workflows/ci.yml` now covers backend lint/test/prisma and mobile analyze/test/build when pushed |
| D1-18 Setup Docker Compose + Fly.io Staging | Cypher | Architect | PARTIAL | `docker-compose.yml`, `backend/Dockerfile`, hosted compose smoke workflow, Fly template, and Fly deploy workflow are ready; local Docker is no longer critical, but Fly login, app name, and remote push are still needed |

## Checkpoints

- Local project root created
- Git repository initialized
- Day 1 artifact wave completed for product, design, architecture, CI, backend bootstrap, and mobile scaffold
- Verified locally:
  - `npm run build`
  - `npm test`
  - `npm run lint`
  - `npm run prisma:validate`
  - `npx prisma db push --skip-generate` against local portable PostgreSQL/PostGIS
  - `SELECT postgis_full_version();`
  - `SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'vets';`
  - `scripts/dev/start-portable-postgres.ps1`
  - `scripts/dev/stop-portable-postgres.ps1`
  - `flutter analyze`
  - `flutter test` via `subst` no-space drive alias
  - portable Redis `PONG`
  - `scripts/dev/start-portable-redis.ps1`
  - `scripts/dev/stop-portable-redis.ps1`
  - portable `gh` -> `gh --version`
  - `scripts/dev/bootstrap-github-no-admin.ps1` reaches the expected auth boundary when `gh` is not logged in
  - `scripts/dev/bootstrap-supabase-env.ps1` generates a working `.env.local` template
  - `scripts/dev/fly-first-deploy.ps1 -GenerateOnly` renders Fly config without Docker local
  - portable `flyctl` -> `flyctl version`
  - `GET /health` -> `{"status":"ok"}`
- Remaining Day 1 blockers are now mostly login/account related, not planning related; local Docker is off the staging critical path

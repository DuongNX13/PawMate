# Day 1 Runtime Blockers

## Scope note

Neo ownership has moved beyond D1-13. D1-14 and D1-15 are now locally verified for Day 1, while D1-16 and D1-18 still carry external-runtime or account-bound blockers.

See also: `docs/management/day1_no_admin_workarounds.md` for paths that avoid Windows administrator privileges.
See also: `docs/management/day1_cloud_bootstrap_runbook.md` for the exact commands now prepared in-repo.

## D1-02 - GitHub repo + branch strategy

Status: Blocked by GitHub login and missing first commit, but no-admin publish path is ready

What is now done:
- Portable GitHub CLI is provisioned locally under `D:\My Playground\tools\gh`.
- `scripts/dev/bootstrap-github-no-admin.ps1` now prepares the remote, optional repo creation, optional push, and branch settings URL in one path.
- Branch model remains documented in `CONTRIBUTING.md`.

What is still blocked:
- `gh auth status` still reports no authenticated GitHub host.
- The repo does not have a first commit yet.
- Repo-local git author identity is not configured yet.
- Actual branch protection still needs a real remote repo and account permissions.

What is needed to unblock:
- Run `D:\My Playground\tools\gh\bin\gh.exe auth login --web`.
- Set repo-local git author identity.
- Create the first commit.
- Run `scripts/dev/bootstrap-github-no-admin.ps1` with the real owner/repo.

## D1-14 - Flutter project init

Status: Closed for Day 1 scaffold, with one carried environment note

What is now done:
- Flutter 3.41.6 is installed locally under `tools/flutter`.
- `mobile/` was created with a real Flutter project.
- Feature-first folders and starter screens exist for auth, pets, vets, health, community, and rescue.
- `flutter analyze` passes locally.
- `flutter test` passes locally when the workspace is accessed through a no-space drive alias.

Carried environment note:
- Local `flutter build apk --debug` is still blocked because Android SDK is not installed on this machine.
- Flutter native-asset commands on Windows are sensitive to spaces in the workspace path; local testing currently uses a temporary `subst` drive alias as a workaround.

## D1-15 - PostgreSQL + PostGIS + Prisma

Status: Closed for Day 1 local runtime bootstrap

What is now done:
- Prisma is installed.
- `backend/prisma/schema.prisma` now materializes the Phase 1 domain.
- `npm run prisma:validate` passes with a safe local placeholder connection string.
- Official PostgreSQL 17.9 Windows binaries are provisioned locally under `D:\My Playground\tools\pgsql`.
- Local cluster data exists under `D:\My Playground\tools\pgsql-data`.
- PostGIS 3.6.2 bundle is applied locally.
- `prisma db push --skip-generate` succeeds against the local `pawmate` database.
- `postgis_full_version()` succeeds.
- `backend/prisma/sql/day1_postgis_patch.sql` creates the local GIST index needed for `vets.location`.

What is carried forward:
- The local runtime is portable and not added to global `PATH`.
- The spatial GIST index still depends on the raw SQL patch because Prisma does not model that index directly on the unsupported geography field.

## D1-16 - Redis + Supabase

Status: Partially blocked

What is now done:
- Backend env loader exists in `backend/src/config/env.ts`.
- `.env.example` now defines Redis and Supabase placeholders.
- Storage bucket naming contract is documented.
- Portable Redis runtime is provisioned locally under `D:\My Playground\tools\redis-portable`.
- Local `redis-cli ping` returns `PONG`.
- Start/stop helpers now exist in `scripts/dev/start-portable-redis.ps1` and `scripts/dev/stop-portable-redis.ps1` and were re-verified in this pass.
- `scripts/dev/bootstrap-supabase-env.ps1` now writes a ready-to-run backend env file without requiring admin rights.
- `backend/scripts/supabase-bootstrap.cjs` now bootstraps the required buckets once a real key is available.
- Backend env loader now accepts both publishable/secret and legacy anon/service-role key names.

What is still blocked:
- Supabase project, keys, and auth providers are not available in local environment.
- OAuth provider setup still needs Google and Apple credentials.
- Storage integration cannot be validated end-to-end until a real project is attached.

What is needed to unblock:
- Create or attach the Supabase project and provide publishable/secret configuration safely through env files.
- Run `scripts/dev/bootstrap-supabase-env.ps1`.
- Run `npm run supabase:bootstrap` from `backend`.
- Verify Google and Apple auth provider setup plus storage bucket policy requirements before integration.

## D1-18 - Docker Compose + Fly.io Staging

Status: Partially blocked, but local Docker is no longer on the critical path

What is now done:
- `docker-compose.yml`, `backend/Dockerfile`, and `backend/.dockerignore` already exist in the repo.
- Portable Fly CLI is provisioned locally under `D:\My Playground\tools\flyctl`.
- `flyctl version` succeeds locally.
- `deploy/fly.staging.template.toml` now provides a reusable Fly config template.
- `scripts/dev/fly-first-deploy.ps1` can render Fly config and deploy with `--remote-only`.
- `.github/workflows/compose-smoke.yml` now provides compose verification on a hosted runner.
- `.github/workflows/fly-staging.yml` now provides a Fly-first deployment path through GitHub Actions.

What is still blocked:
- Fly.io account login or token is not available in the local environment.
- Real Fly app name and secrets are still missing.
- GitHub Actions cannot run until the repo is pushed to a real remote.

What is needed to unblock:
- Log into Fly.io with `D:\My Playground\tools\flyctl\flyctl.exe auth login` or set `FLY_ACCESS_TOKEN`.
- Generate config with `scripts/dev/fly-first-deploy.ps1 -GenerateOnly`.
- Push the repo so hosted workflows can run.
- Add `FLY_API_TOKEN`, `FLY_APP_NAME`, and `FLY_PRIMARY_REGION` to GitHub.

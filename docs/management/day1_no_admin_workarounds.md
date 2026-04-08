# PawMate Day 1 No-Admin Workarounds

Snapshot updated: `2026-04-08`

This note captures which Day 1 blockers can be worked around without Windows administrator privileges on the local machine.

Detailed commands now live in `docs/management/day1_cloud_bootstrap_runbook.md`.

## Quick verdict

- `D1-02 GitHub Repo + Branch Strategy`: bypassable without local admin rights
- `D1-16 Redis + Supabase`: mostly bypassable without local admin rights
- `D1-18 Docker Compose + Fly.io Staging`: partially bypassable without local admin rights

## D1-02 - GitHub Repo + Branch Strategy

### Why this can be bypassed

This blocker does not actually depend on Windows admin rights. The remaining requirement is GitHub access, not machine-level installation.

### No-admin path

1. Create the repository in the GitHub web UI.
2. Add the remote locally with plain Git:
   - `git remote add origin https://github.com/<owner>/<repo>.git`
3. Authenticate with one of these methods:
   - browser login through portable `gh`
   - HTTPS + personal access token
   - SSH key
4. Push the current branch.
5. Configure branch protection in the GitHub web UI.

### Local tools already prepared

- Portable GitHub CLI: `D:\My Playground\tools\gh\bin\gh.exe`
- Repo helper: `scripts/dev/bootstrap-github-no-admin.ps1`

### What still cannot be bypassed

- You still need a GitHub account with permission to create the repo or manage branch protection.

## D1-16 - Redis + Supabase

### Why this is mostly bypassable

Redis is already solved locally through a portable runtime. Supabase configuration can be done in the cloud dashboard or Management API, so it does not require local admin rights either.

### No-admin path

1. Create a Supabase project in the dashboard or through the Management API.
2. Copy the project URL and API keys from the project's Connect dialog or API Keys settings page.
3. Create the required storage bucket in the Supabase dashboard.
4. Configure Auth providers in the Supabase dashboard.
5. Place the resulting values into the repo env file and continue backend integration.

### Local tools already prepared

- Portable Redis runtime and helper scripts:
  - `scripts/dev/start-portable-redis.ps1`
  - `scripts/dev/stop-portable-redis.ps1`
- Supabase env writer: `scripts/dev/bootstrap-supabase-env.ps1`
- Storage bootstrap: `backend/scripts/supabase-bootstrap.cjs`

### What still cannot be bypassed

- You still need a Supabase account and a real project.
- Social auth setup still depends on credentials from the external identity providers such as Google or Apple.

## D1-18 - Docker Compose + Fly.io Staging

### What can be bypassed

The Fly.io part can be bypassed locally because `fly deploy` uses a remote builder by default. That means local Docker is not required for the deploy itself.

### No-admin path for Fly staging

1. Log in with portable `flyctl`.
2. Run `fly launch --no-deploy` from the project directory.
3. Review `fly.toml`.
4. Run `fly deploy`.

### Local tools already prepared

- Portable Fly CLI: `D:\My Playground\tools\flyctl\flyctl.exe`
- Fly template: `deploy/fly.staging.template.toml`
- Fly helper: `scripts/dev/fly-first-deploy.ps1`
- Hosted compose smoke workflow: `.github/workflows/compose-smoke.yml`
- Hosted Fly deploy workflow: `.github/workflows/fly-staging.yml`

### What is only partially bypassable

Local Docker Compose execution is not realistically verified without some working container runtime. If Docker Desktop cannot be installed:

- treat compose as authored but not locally executed
- move runtime verification to CI or another machine that has Docker
- use Fly staging as the first real environment instead of local containers

### What still cannot be bypassed

- You still need a Fly.io account and login token.
- Full local compose bring-up remains blocked until a container runtime exists somewhere.

## Practical recommendation

If the goal is to keep Day 1 moving without waiting on IT, the fastest path is:

1. Finish `D1-02` via GitHub web + portable `gh`
2. Finish the Supabase half of `D1-16` via dashboard plus the repo bootstrap scripts
3. Treat `D1-18` as `Fly-first, Docker-local-later`

That path avoids local admin rights for almost everything except true local container testing.

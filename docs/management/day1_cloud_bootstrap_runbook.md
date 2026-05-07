# PawMate Day 1 Cloud Bootstrap Runbook

Snapshot updated: `2026-04-08`

This runbook turns the remaining Day 1 blockers into no-admin workflows wherever possible.

## 1. GitHub web + portable gh

### What is already ready

- Portable GitHub CLI exists at `D:\My Playground\tools\gh\bin\gh.exe`.
- Repo helper exists at `scripts/dev/bootstrap-github-no-admin.ps1`.
- Branch strategy is already documented in `CONTRIBUTING.md`.
- If the repo already exists and Git Credential Manager can push to GitHub, the helper can now push branches without requiring `gh auth`.

### What still needs your account

- GitHub login
- repository owner/name confirmation
- first local commit

### Fastest path

1. Log in:

```powershell
D:\My Playground\tools\gh\bin\gh.exe auth login --web
```

2. Set repo-local author if this machine does not already have one:

```powershell
git -C D:\My Playground\PawMate config user.name "Your Name"
git -C D:\My Playground\PawMate config user.email "your-email@example.com"
```

3. Create the first commit when you are ready to publish:

```powershell
git -C D:\My Playground\PawMate add .
git -C D:\My Playground\PawMate commit -m "chore: bootstrap PawMate day 1"
```

4. Create the GitHub repo, wire `origin`, push branches, and open the branch settings page:

```powershell
powershell -File scripts/dev/bootstrap-github-no-admin.ps1 `
  -Owner "<github-owner>" `
  -Repo "PawMate" `
  -CreateRepo `
  -PushBranches `
  -OpenRepoPages
```

5. In GitHub web UI, enable branch protection for `main` and `develop`.

## 2. Supabase bootstrap without local admin

### What is already ready

- Backend env loader now supports both new Supabase key names and legacy aliases.
- Env writer exists at `scripts/dev/bootstrap-supabase-env.ps1`.
- Storage bootstrap exists at `backend/scripts/supabase-bootstrap.cjs`.
- `npm run supabase:bootstrap` will create the required buckets if the service key works.

### What still needs your account

- Supabase project
- Supabase URL and keys
- provider credentials for Google and Apple

### Fastest path

1. Create or open the Supabase project in the dashboard.
2. Copy:
   - project URL
   - publishable key
   - secret key or legacy service role key

3. Generate `backend/.env.local`:

```powershell
powershell -File scripts/dev/bootstrap-supabase-env.ps1 `
  -SupabaseUrl "https://<project-ref>.supabase.co" `
  -PublishableKey "<publishable-or-anon-key>" `
  -SecretKey "<secret-or-service-role-key>"
```

4. Bootstrap storage buckets:

```powershell
cd backend
npm run supabase:bootstrap
```

5. In Supabase dashboard, enable Google and Apple providers using:
   - `SUPABASE_AUTH_REDIRECT_URL`
   - `SUPABASE_AUTH_MOBILE_REDIRECT_URL`

## 3. Fly-first instead of Docker-local-first

### What is already ready

- Portable Fly CLI exists at `D:\My Playground\tools\flyctl\flyctl.exe`.
- Fly config template exists at `deploy/fly.staging.template.toml`.
- Local helper exists at `scripts/dev/fly-first-deploy.ps1`.
- CI deploy workflow exists at `.github/workflows/fly-staging.yml`.
- Hosted compose smoke workflow exists at `.github/workflows/compose-smoke.yml`.

### What still needs your account

- Fly login or access token
- real app name
- runtime secrets
- GitHub repo push so Actions can run

### Fastest path

1. Log in to Fly:

```powershell
D:\My Playground\tools\flyctl\flyctl.exe auth login
```

2. Generate a staging config without needing Docker local:

```powershell
powershell -File scripts/dev/fly-first-deploy.ps1 `
  -AppName "<fly-app-name>" `
  -PrimaryRegion "sin" `
  -GenerateOnly
```

3. Set runtime secrets in Fly from real project values in `deploy/fly.secrets.example.env`.

4. Deploy through one of these paths:
   - local portable CLI: `powershell -File scripts/dev/fly-first-deploy.ps1 -AppName "<fly-app-name>" -PrimaryRegion "sin"`
   - GitHub Actions workflow: `.github/workflows/fly-staging.yml`

5. Use `.github/workflows/compose-smoke.yml` to prove compose on a hosted runner instead of waiting for Docker on this laptop.

## Practical outcome

- `D1-02` is now auth-ready and repo-publish-ready.
- `D1-16` is now project-ready and bucket-bootstrap-ready.
- `D1-18` is now Fly-first and hosted-runner-ready, so local Docker is no longer on the critical path.

# PawMate Day 7 Blocker Resolution Plan

Date: 2026-05-05

## Current Blockers

Day 7 now has two remaining external/runtime blockers:

- `D7-05 Scheduler production enablement`: workflow exists, but GitHub Actions needs a database secret before the scheduled worker can process real reminders.
- `D7-04 iOS real-device smoke`: local Windows path is blocked, BrowserStack is logged in, but Codemagic is still at auth wall and a signed IPA still requires Apple signing.

Resolved:

- `D7-03 Supabase cloud SQL proof`: completed through Supabase SQL Editor without resetting the database password. Evidence is recorded in `docs/qa/day7_cloud_supabase_proof_report.md`.

## Best Path

Use one Supabase Session Pooler Postgres URL as the unblock path for `D7-05`.

Recommended secret value shape:

```text
postgres://postgres.<project-ref>:<database-password>@aws-0-<region>.pooler.supabase.com:5432/postgres?connection_limit=1
```

Why this is the best fit:

- It avoids local admin rights and local Docker.
- It works from GitHub-hosted runners without depending on direct IPv6 support.
- It keeps the database password in GitHub Secrets instead of chat or repository files.
- It is safer than Supabase Transaction Pooler for the current Prisma-based proof because transaction mode has prepared-statement constraints.
- It can be reused by the scheduled reminder worker and the manual cloud proof workflow.

Use Supabase Direct connection only when the runner/environment supports IPv6 or the project has the IPv4 add-on.

Avoid Transaction Pooler on port `6543` for Day 7 unless it is explicitly tested with Prisma pooler settings. It is a fallback, not the preferred unblock path.

## User Steps

1. Open Supabase project `qeoowayxfqyhfcgnrfnv`.
2. Click `Connect`.
3. Copy `Session pooler` connection string, port `5432`.
4. If the database password is unknown, reset the database password only after confirming that breaking existing database connections is acceptable.
5. Add `?connection_limit=1` to the URL if it has no query string. If it already has query parameters, append `&connection_limit=1`.
6. In GitHub repo `DuongNX13/Pawmate`, open `Settings -> Secrets and variables -> Actions`.
7. Add repository secret `PAWMATE_REMINDER_DATABASE_URL` with the Session Pooler URL.
8. Run GitHub Action `Reminder Worker` manually with `limit=100`.

## Codex Verification After Secrets Exist

If the Postgres URL is available locally, run:

```powershell
cd 'D:\My Playground\PawMate\backend'
$env:PAWMATE_DB_MIGRATION_URL = '<redacted-session-pooler-url>'
npm run db:day6:cloud-proof
npm run db:day6:cloud-proof -- --verify-only
```

If secrets are configured only on GitHub, use the workflow evidence instead:

- `Day 7 Cloud Schema Proof`: must pass `apply-and-verify`, then `verify-only`.
- `Reminder Worker`: must pass and print a safe JSON summary with `processedCount`, `reminderIds`, `ranAt`, and `limit`.

## Sign-Off Rule

Day 7 can be signed off when:

- local backend/mobile gates remain green;
- cloud schema proof passes against Supabase;
- scheduled reminder worker has a valid GitHub secret and passes at least one manual run;
- iOS smoke either completes through `codemagic.yaml` plus BrowserStack real iPhone evidence, or is explicitly carried as a release-parity gap, not a Day 7 backend blocker.

Current sign-off state:

- Local backend/mobile gates are green.
- Supabase cloud schema proof is green.
- Scheduled reminder worker cloud run is still blocked by missing Postgres secret.
- iOS real-device smoke is still blocked by Codemagic login plus Apple signing.

## iOS Cloud Real-Device Path

Local Windows cannot provide a trustworthy iOS real-device proof. The best no-local-Xcode route is now prepared in:

- `codemagic.yaml`
- `docs/qa/day7_ios_real_device_cloud_runbook.md`

Required external setup:

1. Connect `DuongNX13/PawMate` to Codemagic.
2. Configure iOS signing for bundle id `com.pawmate.pawmateMobile`.
3. Add Codemagic variable group `pawmate_browserstack` with `BROWSERSTACK_USERNAME` and `BROWSERSTACK_ACCESS_KEY`.
4. Add `PAWMATE_API_BASE_URL` when a public backend is available.
5. Run Codemagic workflow `ios-real-device-smoke`.
6. Open the uploaded `bs://...` app on BrowserStack real iPhone and capture smoke evidence.

## References

- Supabase database connection strings: https://supabase.com/docs/guides/database/connecting-to-postgres
- Prisma with Supabase: https://www.prisma.io/docs/v6/orm/overview/databases/supabase
- GitHub Actions repository secrets: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets

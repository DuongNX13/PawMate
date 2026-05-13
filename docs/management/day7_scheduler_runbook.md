# PawMate Day 7 Scheduler And Cloud Schema Runbook

Date: 2026-05-05

## Purpose

This runbook describes the Day 7 productionization path for reminder due processing and Supabase cloud schema proof.

Day 6 remains an Android-local MVP. Day 7 adds repeatable operational paths without storing real secrets in the repository.

## Reminder Worker

### Local smoke

From `backend`:

```powershell
npm run reminders:process-due -- --limit 100 --now 1970-01-01T00:00:00.000Z
```

Expected safe output:

```json
{"data":{"processedCount":0,"reminderIds":[],"ranAt":"1970-01-01T00:00:00.000Z","limit":100}}
```

Use a current `--now` or omit `--now` only when you intentionally want to process real due reminders in the configured database.

### GitHub Actions manual worker

Workflow: `.github/workflows/reminder-worker.yml`

Current Day 11 state: manual `workflow_dispatch` only.

The old 15-minute schedule is intentionally disabled. Do not add a `schedule`
or `cron` trigger back until production reminder scheduling is explicitly
re-approved. This prevents repeated Reminder Worker failure emails while still
allowing manual worker proof runs.

Required secret:

- `PAWMATE_REMINDER_DATABASE_URL`: preferred secret for the scheduler database connection.

Fallback secret:

- `DATABASE_URL`: accepted if `PAWMATE_REMINDER_DATABASE_URL` is not set.

The workflow validates the secret exists, installs backend dependencies, validates Prisma schema, generates Prisma client, then runs:

```bash
npm run reminders:process-due -- --limit "$REMINDER_PROCESS_LIMIT"
```

Recommended value for Day 7:

```text
postgres://postgres.<project-ref>:<database-password>@aws-0-<region>.pooler.supabase.com:5432/postgres?connection_limit=1
```

Use Supabase Session Pooler on port `5432` first. It avoids local admin work and direct IPv6 dependency while staying safer for Prisma than Transaction Pooler.

## Supabase Cloud Schema Proof

Script:

```powershell
npm run db:day6:cloud-proof
```

Connection string precedence:

1. `PAWMATE_DB_MIGRATION_URL`
2. `DATABASE_DIRECT_URL`
3. `SUPABASE_DATABASE_URL`
4. `SUPABASE_DB_URL`
5. `DATABASE_URL`

Recommended cloud usage:

```powershell
$env:PAWMATE_DB_MIGRATION_URL = "<direct-or-session-pooler-postgres-url>"
npm run db:day6:cloud-proof
```

Manual GitHub proof workflow:

- Workflow: `.github/workflows/day7-cloud-schema-proof.yml`
- Required secret: `PAWMATE_DB_MIGRATION_URL`
- First run: `apply-and-verify`
- Second run: `verify-only`

Verify only, without applying SQL:

```powershell
npm run db:day6:cloud-proof -- --verify-only
```

The script redacts DB passwords in output, verifies Day 6 columns/indexes/enum, creates a temporary user/pet/reminder/notification smoke record, marks reminder done, dismisses notification, then cleans up.

## Current State

- Supabase cloud proof was completed during Day 7/8 hardening.
- Reminder Worker manual dispatch remains available, but production schedule is disabled by design.
- iOS real-device/TestFlight parity remains blocked on Apple Developer/App Store Connect signing assets, not on the scheduler path.

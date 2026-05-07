# Day 5 DB Blocker Resolution

## Problem

`backend/.env.local` points `DATABASE_URL` to local PostgreSQL on `localhost:5432`. When the local DB is stopped, Day 5 health-record schema proof and runtime smoke fail even though the code and route tests pass.

## Decision

Use the local portable PostgreSQL/PostGIS runtime as the default development unblock path, then keep Supabase cloud migration as a separate staging/production proof.

This is the best fit for the current machine because:

- it does not require admin rights;
- it does not require Docker;
- it matches the existing `DATABASE_URL` target;
- it uses the already-provisioned PostgreSQL binaries under `D:\My Playground\tools\pgsql`;
- it still verifies real database behavior instead of relying on in-memory route tests.

## Official Documentation Findings

- Supabase direct connections are ideal for persistent servers and long-running containers, while session pooler mode is the fallback when IPv4 is needed.
- Supabase transaction pooler mode is intended for serverless/edge-style workloads and does not support prepared statements.
- Supabase's Prisma guide recommends the session-pooler string ending with port `5432` for Prisma server deployments and notes direct connection can be used in IPv6 or with IPv4 add-on.
- Prisma requires a PostgreSQL connection URL for Prisma Client and schema-changing operations. Passwords with special characters must be percent-encoded.
- If Prisma Accelerate is used later, Prisma's guide keeps a direct database URL for migrations.

## Implemented Local Unblock

Run from `D:\My Playground\PawMate\backend`:

```powershell
npm run db:day5:unblock
```

What the script does:

1. Loads `.env` and `.env.local`.
2. Chooses DB URL in this priority:
   - `PAWMATE_DB_MIGRATION_URL`
   - `DATABASE_DIRECT_URL`
   - `SUPABASE_DATABASE_URL`
   - `SUPABASE_DB_URL`
   - `DATABASE_URL`
3. If the URL host is `localhost`/`127.0.0.1` and port `5432` is not reachable, starts `scripts/dev/start-portable-postgres.ps1`.
4. Applies `backend/prisma/sql/day5_health_records_patch.sql` through real `psql`.
5. Verifies Day 5 schema:
   - columns: `title`, `vet_id`, `deleted_at`
   - enum values: `deworming`, `grooming`
   - indexes: `health_records_pet_deleted_record_date_idx`, `health_records_vet_id_idx`
   - foreign key: `health_records_vet_id_fkey`
6. Runs a Prisma CRUD smoke:
   - create user
   - create pet
   - create `deworming` health record with `title`
   - soft-delete record
   - verify soft-deleted record is hidden
   - cleanup smoke rows

The script redacts DB password from output.

## Supabase Cloud Path

When staging/production migration proof is needed, do not use `SUPABASE_URL`, publishable key, or service role key for SQL DDL. Configure a real Postgres connection string instead.

Recommended env variable:

```powershell
$env:PAWMATE_DB_MIGRATION_URL='postgres://<db-user>.<project-ref>:<password>@<region>.pooler.supabase.com:5432/postgres'
npm run db:day5:unblock
```

Use either:

- Supabase Session pooler string on port `5432` for Prisma server-style deployments; or
- Supabase Direct connection string when the environment supports IPv6 or the project has IPv4 add-on.

Avoid transaction pooler for this migration path unless the Prisma connection is specifically configured for transaction-pooler constraints.

## Verification Commands

```powershell
cd D:\My Playground\PawMate\backend
npm run db:day5:unblock
npm run prisma:validate
npm run build
npm run lint -- --quiet
npm test -- --runTestsByPath tests/pet.routes.test.ts
npm run test:coverage
npm audit --omit=dev
```

## Status

Local DB blocker is resolved and repeatable. Supabase cloud proof remains intentionally separate until a direct Supabase Postgres connection string is configured.

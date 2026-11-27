# PawMate Backend

Fastify/TypeScript API for PawMate Phase 1 and Phase 2.

## What is in place

- Fastify 5 + TypeScript 5 bootstrap
- `GET /health` liveness and `GET /ready` dependency readiness routes
- Jest smoke tests
- ESLint + Prettier
- Dockerfile scaffold
- Prisma schema scaffold for the Phase 1 domain

## Local commands

```bash
npm ci
npm run lint
npm test
npm run build
npm run prisma:validate
npm run dev
```

## Environment contract

Copy `.env.example` to `.env` and adjust values as the runtime becomes available.

Minimum local bootstrap:

- `HOST`
- `PORT`

Production is fail-closed and also requires:

- `DATABASE_URL`
- `REDIS_URL`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` (legacy `SUPABASE_ANON_KEY` is accepted)
- `SUPABASE_SECRET_KEY` (legacy `SUPABASE_SERVICE_ROLE_KEY` is accepted)
- independent access/refresh secrets of at least 32 UTF-8 bytes
- explicit JWT issuer, audience and distinct key IDs

PawMate application tokens are issued with `HS256`, issuer `pawmate-api`,
audience `pawmate-mobile`, a 15-minute access lifetime and a refresh lifetime
of at most 30 days. Rotation supports one optional previous verify-only key per
token class. See `docs/qa/security/day131/DAY131_DEC03_CONFIG_TOKEN_CONTRACT.md`
for the rollout and rollback contract.

`TRUSTED_PROXY_CIDRS` is empty by default. Set it only to the exact proxy IPs or
bounded CIDRs used by the deployment; wildcard trust is rejected.

## Runtime notes

- Database and Redis are intended to run through `docker-compose.yml` first.
- Supabase remains an external dependency and should be wired via env values once the project exists.
- PostGIS support is scaffolded in Prisma as an unsupported spatial column and will need a raw SQL migration when Docker/Postgres is available.

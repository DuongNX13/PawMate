# PawMate Backend

Day 1 backend scaffold for PawMate Phase 1.

## What is in place

- Fastify 4 + TypeScript 5 bootstrap
- `GET /health` route
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

Next-step integration placeholders:

- `DATABASE_URL`
- `REDIS_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Runtime notes

- Database and Redis are intended to run through `docker-compose.yml` first.
- Supabase remains an external dependency and should be wired via env values once the project exists.
- PostGIS support is scaffolded in Prisma as an unsupported spatial column and will need a raw SQL migration when Docker/Postgres is available.

# PawMate Day 1 Architect Review

Date: 2026-04-07  
Role: Architect  
Mission: Review Day 1 architecture consistency and propose practical unblock steps for D1-02, D1-15, D1-16, D1-18 without editing other artifacts.

## Review scope
- Contract handoff: `docs/architecture/openapi.phase1.yaml`
- Data model handoff: `docs/architecture/erd.md`
- Decision log: `docs/architecture/adr.md`
- Backend scaffold: `backend/package.json`, `backend/src/index.ts`, TS/Jest config
- Infra handoff: `.github/workflows/ci.yml`, `docker-compose.yml`, `backend/Dockerfile`
- Execution state: `docs/management/day1_execution_board.md`, `docs/management/day1_load_plan.md`

## Executive verdict
Day 1 is directionally sound. The main architecture spine exists: branch strategy guidance, Phase 1 API contract, ERD, ADR set, backend scaffold, CI scaffold, and infra scaffold. The remaining risk is not missing architecture intent; it is incomplete environment convergence between what the documents assume and what Neo/Cypher can execute locally.

## What is consistent

### 1) Contract-to-scope consistency is mostly good
- `openapi.phase1.yaml` stays inside Phase 1 scope: auth, pets, vets, reviews, health records, reminders, notifications.
- The contract matches the Day 1 brief well enough to unblock Neo route scaffolding.
- `erd.md` covers the same domain objects and defers out-of-scope systems correctly.
- `adr.md` aligns with the intended stack: Flutter, Fastify+TS, Supabase, PostGIS, Redis-backed jobs.

### 2) ERD-to-contract consistency is mostly good
- Core resource mapping is coherent:
  - `users` / `sessions` support auth flows
  - `pets` supports `/pets`
  - `vets` + `vet_services` support nearby/search/detail
  - `reviews` supports review endpoints
  - `health_records`, `reminders`, `notifications` support Phase 1 health/reminder work
- Spatial dependency is explicit in ERD and implied in contract, which is enough for D1 handoff.

### 3) Backend scaffold is aligned with ADR-002
- Backend uses Fastify + TypeScript as decided.
- Build/test/lint scripts exist.
- Entry point is clean and minimal.
- CI references the backend scaffold sanely.

## Inconsistencies and gaps

### A. D1-02 is only partially complete
**Finding**
- `CONTRIBUTING.md` documents the branch model correctly.
- Execution board marks D1-02 as blocked because branch protection requires a real remote GitHub repo.

**Why it matters**
- The doc-level branch strategy exists, but enforcement is not yet real.
- Without remote branch protection, `main`/`develop` safety is social only, not technical.

**Architect call**
- Treat D1-02 as `document complete, enforcement pending`.
- Do not represent branch protection as done until GitHub remote + protection rules are actually applied.

### B. Auth ownership is split between Supabase and app sessions, but the contract is still too implicit
**Finding**
- ADR-003 says Supabase handles auth flows and storage.
- ERD includes `sessions.refresh_token_hash`, meaning the app backend also owns refresh lifecycle.
- OpenAPI exposes `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/oauth`, `/auth/logout` as if PawMate backend is the main auth API.

**Why it matters**
- Neo can implement this in more than one way:
  1. backend as auth facade over Supabase
  2. backend issues app tokens after Supabase identity verification
  3. Supabase session model and app session model both coexist
- If this stays implicit, D2 auth work will drift into inconsistent token ownership.

**Architect call**
- Freeze the intended contract as: **Supabase is the identity provider and storage provider; PawMate backend is the domain API and app-session boundary.**
- Practical meaning:
  - register/login/oauth may delegate credential verification to Supabase
  - PawMate backend still issues or tracks its own app session/refresh artifacts for domain access control
  - Neo should not mix raw Supabase client sessions directly into all domain authorization paths without a backend-owned translation rule

### C. Contract error handling is present but not normalized enough for implementation handoff
**Finding**
- The OpenAPI file already uses a shared Error response, but Day 2 plan expects a stricter global error format and code families.

**Why it matters**
- Cypher will need deterministic assertions.
- Neo needs one stable envelope before route implementation multiplies.

**Architect call**
- Freeze one backend-wide error envelope before D2 endpoint implementation:
  - `success`
  - `error.code`
  - `error.message`
  - `error.field` optional
  - `requestId`
- This is already directionally implied; it just needs to be treated as mandatory, not optional.

### D. ERD is good enough for Phase 1 but a few implementation details need explicit convention
**Finding**
- `pets.microchip_number` is unique when provided.
- `reviews` mentions one active review per user per vet only in notes.
- `vets.location` mentions geography support but not an exact Prisma mapping or migration convention.
- `opening_hours` is JSONB but no format convention is specified.

**Why it matters**
- Neo and Cypher can still move, but migration/test details may diverge.

**Architect call**
- For D1/D2 execution, freeze these conventions operationally:
  - `reviews`: unique composite index `(user_id, vet_id)` if one-review-per-vet is a real Phase 1 invariant
  - `pets.microchip_number`: nullable unique partial constraint if DB supports it; otherwise application validation plus DB uniqueness strategy
  - `vets.location`: PostGIS `geography(Point, 4326)` as source of truth
  - `opening_hours`: structured JSON object keyed by weekday, not free-form text

### E. Redis/Bull decision and current scaffold are not fully aligned yet
**Finding**
- ADR-005 says Redis-backed queue/scheduler patterns are accepted.
- Day 1 task text names Redis Bull specifically.
- Current scaffold has Redis infra only; no worker/process boundary is described yet.

**Why it matters**
- Reminder delivery and token/session async work can become tangled inside the API process if worker boundaries are not declared early.

**Architect call**
- Freeze a minimal process split now:
  - API process: HTTP routes, sync validation, enqueue only
  - Worker process: reminders and scheduled/background jobs
  - Redis: queue transport/shared job state
- Neo does not need to implement the worker fully on Day 1, but folder/process separation should assume this split.

### F. D1-18 scaffold exists, but execution-board wording should be read carefully
**Finding**
- `docker-compose.yml` and backend Dockerfile exist.
- Execution board correctly says D1-18 is blocked on runtime/credentials, not on missing files.

**Why it matters**
- This is a real unblock candidate, not a planning gap.
- Cypher and Neo can continue on scaffold quality even before local Docker/Fly execution is possible.

**Architect call**
- Treat D1-18 as `scaffold complete, runtime verification pending`.

## Practical unblock plan

## D1-02 — GitHub repo + branch strategy
### Current state
- Local git repo exists.
- Branch model is documented.
- Missing: remote repo + actual protection rules.

### Practical steps
1. Create/connect GitHub remote repository.
2. Push `main` and `develop`.
3. Configure branch protection:
   - require PR for `main`
   - require PR for `develop`
   - require at least 1 review
   - require CI checks once workflow is live
4. Keep feature naming convention from `CONTRIBUTING.md`.

### Exit condition
- D1-02 is done only when protection is enforceable remotely, not just documented.

## D1-15 — PostgreSQL + PostGIS + Prisma
### Current state
- ERD is ready.
- Docker compose defines a valid PostGIS container.
- Local `psql`/Postgres runtime is missing.

### Practical steps
1. Use Dockerized PostGIS as the primary local dev DB path instead of waiting for host Postgres installation.
2. Neo creates Prisma schema from `erd.md` with these first-class priorities:
   - `users`
   - `sessions`
   - `pets`
   - `vets`
   - `vet_services`
   - `reviews`
   - `health_records`
   - `reminders`
   - `notifications`
3. For PostGIS support, do not block the whole schema on perfect ORM abstraction:
   - keep Prisma for the relational model
   - apply raw SQL migration for PostGIS extension, location column, and GIST index if needed
4. Seed only enough vet data to validate geo query shape later.
5. Cypher should verify migration reproducibility before broader feature tests.

### Exit condition
- `docker compose up postgres`
- migration runs successfully
- `vets.location` exists with spatial index
- schema is committed and reproducible

## D1-16 — Redis + Supabase
### Current state
- Redis runtime missing locally on host, but Docker compose already defines Redis.
- Supabase is an external setup task, not a local runtime requirement.

### Practical steps
1. Use Docker Redis as the default local path; do not wait for host `redis-server` installation.
2. Neo should add config placeholders early:
   - `REDIS_URL`
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - bucket names for avatars and pet photos
3. Freeze auth responsibility split before code:
   - Supabase verifies identity / handles provider integrations
   - backend maps identity to local user/session/domain access
4. Draft storage conventions now:
   - bucket `avatars`
   - bucket `pet-photos`
   - deterministic object path strategy by user/pet IDs
5. Keep rate-limiting and queue concerns separate:
   - rate limiting belongs in API boundary/plugin layer
   - reminder/session jobs belong in Redis-backed worker path

### Exit condition
- Redis reachable from app container or local process
- Supabase env contract documented and injectable
- ownership split for auth/session/storage is understood by Neo before D2 auth coding

## D1-18 — Docker Compose + Fly.io staging
### Current state
- Compose file exists and is structurally reasonable.
- Backend Dockerfile exists.
- Missing: executable Docker runtime locally and Fly credentials/verification.

### Practical steps
1. Validate compose as the canonical Day 1 local runtime path for Postgres + Redis + backend.
2. Keep pgAdmin optional; do not treat it as critical path.
3. Separate D1-18 into two sub-checks operationally:
   - local compose viability
   - Fly staging deployment viability
4. Neo/Cypher should first prove container boot order and env contract locally.
5. Fly deployment should happen only after backend env list is explicit and health route is stable.

### Exit condition
- local compose can boot database + redis + backend
- backend `/health` returns 200 inside the compose path
- Fly secrets/app mapping prepared, even if full deploy trails behind by a checkpoint

## Support lane: Neo environment strategy

## Recommended strategy
Use **container-first infrastructure, host-light tooling**.

### Why
- Current blockers are almost entirely missing host runtimes.
- Docker artifacts already exist.
- Installing and stabilizing Flutter/Postgres/Redis directly on host is slower and less reproducible than pushing DB/cache/backend into containers.

### Recommended sequencing for Neo
1. Continue backend code on host Node runtime.
2. Move Postgres and Redis to Docker as soon as Docker becomes available.
3. Keep Flutter as a separate toolchain track; do not let it block backend/schema progress.
4. Use raw SQL where Prisma/PostGIS friction appears instead of stalling for perfect abstraction.
5. Treat Supabase as an external integration boundary with env contract first, code second.

## Highest-priority architecture decisions to keep stable tomorrow
1. Backend owns the app session boundary even if Supabase owns identity.
2. PostGIS geography with spatial index is non-negotiable for Vet Finder.
3. One-review-per-user-per-vet should be enforced as a real invariant, not just a note.
4. Reminder/background work must assume API/worker separation.
5. Branch protection is not complete until enforced in the remote.

## Suggested owner handoff notes
- **Neo:** proceed with backend/domain/session scaffolding, Docker-first for DB/Redis, raw SQL allowed for PostGIS support.
- **Cypher:** verify reproducibility and health checks, not just file presence.
- **Oracle:** track D1-02 and D1-18 as partially complete with external execution dependencies.

## Final assessment
Architecture direction is solid enough to continue. The remaining Day 1 risk is executional consistency at the environment boundary, not missing system design. If the squad freezes token ownership, worker boundaries, and Docker-first local infra, D1-15, D1-16, and D1-18 can be unblocked with practical engineering steps rather than more planning.

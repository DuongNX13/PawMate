# Day 1 - Cypher CI / Infra Notes

## Scope owned

- D1-17: Setup GitHub Actions CI scaffold
- D1-18: Setup Docker Compose scaffold and backend Dockerfile scaffold

## Artifacts in place now

- `.github/workflows/ci.yml`
- `docker-compose.yml`
- `backend/Dockerfile`
- `backend/.dockerignore`

## What is covered now

- CI triggers on push and pull request for `develop` and `main`.
- Backend lane now runs:
  - `npm ci`
  - `npm run lint`
  - `npm test`
  - `npm run prisma:validate`
- Mobile lane now has a real Flutter project and can run:
  - `flutter pub get`
  - `dart analyze`
  - `flutter test`
  - `flutter build apk --debug`
- Local service compose still describes Postgres + PostGIS, Redis, pgAdmin, and backend container wiring.
- Backend Dockerfile now builds TypeScript output and starts from `dist/index.js`.

## What was verified locally

- Backend lint passes.
- Backend tests pass.
- Backend build passes.
- Prisma schema validation passes.
- Flutter analyze passes.
- Flutter test passes through a temporary no-space drive alias.

## Current blockers / assumptions

- Docker runtime is still not available on this machine, so `docker compose up` remains unverified locally.
- Fly.io staging deployment was not executed because no Fly credentials or app configuration were provided.
- Local `flutter build apk --debug` is still blocked by missing Android SDK.
- Remote GitHub Actions have not been executed yet because the repo has not been pushed.

## QA interpretation

- D1-17 is now meaningfully stronger than a placeholder scaffold because both backend and mobile manifests exist.
- D1-18 remains scaffold-only until Docker runtime and Fly credentials are available.
- CI should still be described as `enforceable when pushed`, not `proven by remote traffic`.

## Recommended next checks

1. Push the repo and watch the first GitHub Actions run.
2. Install Docker runtime and verify `docker compose up --build`.
3. Install Android SDK if local APK build proof is required on this machine.
4. Attach Fly credentials only when backend env values are finalized.

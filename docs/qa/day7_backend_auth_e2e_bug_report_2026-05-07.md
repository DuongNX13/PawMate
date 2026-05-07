# Day 7 Backend Auth E2E Bug Report - 2026-05-07

## Symptom

After submitting Register in the Appetize iOS simulator build, the app can show a backend/connectivity error instead of completing backend-backed register/login evidence.

## Confirmed Evidence

- Appetize simulator artifact: `temp/qa/day7-ios-cloud-proof/PawMate-appetize-simulator.zip`.
- The built artifact contains `https://pawmate-api-placeholder.invalid` in `Runner.app/Frameworks/App.framework/flutter_assets/kernel_blob.bin`.
- The same artifact also contains `PAWMATE_API_BASE_URL` and the iOS fallback `127.0.0.1:3000`, confirming the backend URL is compile-time mobile configuration.
- `https://pawmate-api-placeholder.invalid/auth/register` is not resolvable, so Register cannot reach a real backend from Appetize.
- Candidate Fly URLs `https://pawmate.fly.dev/health` and `https://pawmate-api.fly.dev/health` were not resolvable during this check.
- Existing project note still records Fly app creation as blocked by Fly billing, so no confirmed public backend URL is available yet.

## Root Cause

The Appetize and BrowserStack iOS workflows were building mobile artifacts with a placeholder backend URL:

```text
PAWMATE_API_BASE_URL=https://pawmate-api-placeholder.invalid
```

Because Flutter reads `PAWMATE_API_BASE_URL` through `String.fromEnvironment`, the value is compiled into the iOS artifact. It cannot be fixed from the Appetize page after upload; the app must be rebuilt with a real public backend URL.

## Fix Implemented

- Added `scripts/ci/validate-mobile-backend-url.mjs`.
- Removed placeholder `PAWMATE_API_BASE_URL` values from Codemagic iOS workflows.
- Added Codemagic preflight validation before mobile builds:
  - rejects empty URL,
  - rejects placeholder/local/private hosts,
  - requires HTTPS unless explicitly allowed for local-only testing,
  - verifies `GET /health` before building the artifact.

## Optimal Resolution Path

1. Provision a public PawMate backend URL.
2. Verify `GET /health` returns `{"status":"ok"}`.
3. Set `PAWMATE_API_BASE_URL` in Codemagic.
4. Rebuild the Appetize simulator artifact.
5. Re-upload to Appetize.
6. Run Register/Login with Network Logs enabled.
7. Capture `/auth/register`, OTP/verification, and `/auth/login` evidence before marking D7-04 backend-backed E2E done.

## Current Status

Not ready for backend-backed auth sign-off until a public backend URL is available and a new mobile artifact is rebuilt with that URL.

# Day 7 Free Backend Replacement Status - 2026-05-08

## Objective

Replace the Fly durable-backend path with a free/no-credit path that can produce a public HTTPS backend URL for Appetize and Codemagic mobile builds.

## Decision

Use Render Free Web Service as the Fly replacement for the MVP backend proof.

Render is the closest fit because it runs a normal Node web service, supports monorepo root directories, exposes a public `onrender.com` HTTPS URL, supports Blueprint IaC through `render.yaml`, and the official first-deploy guide says the free tutorial requires no payment.

## Current Repo Changes

- Added root `render.yaml` for a free Render web service named `pawmate-api`.
- Configured Render to build from `backend`, run `npm ci && npx prisma generate && npm run build`, start with `npm start`, and health check `/health`.
- Required Render dashboard secret prompt: `DATABASE_URL`.
- Generated Render secrets: `AUTH_ACCESS_TOKEN_SECRET`, `AUTH_REFRESH_TOKEN_SECRET`.
- Updated mobile backend URL validation to retry until `PAWMATE_BACKEND_HEALTH_TIMEOUT_MS`, which makes Render Free cold starts less likely to fail Codemagic/Appetize builds.
- Updated Codemagic so BrowserStack is no longer the default QA path; Appetize simulator builds now default to proxy-aware Network Logs and a 70 second backend health timeout.

## Option Comparison

| Option | Fit | Why |
| --- | --- | --- |
| Render Free Web Service | Recommended | Minimal backend change, public HTTPS, Node runtime, Blueprint config, free instance path without payment for first deploy. |
| Railway Free Trial | Not first choice | Trial credits exist, but full network behavior depends on account verification and the trial is credit/time based. |
| Koyeb free instance | Not acceptable for no-credit constraint | Official pricing FAQ says Koyeb requires a credit card for fraud prevention. |
| Vercel Hobby | Possible rewrite path only | Free serverless/function platform, but PawMate backend is a long-running Fastify service and would need adapter/rewrite work. |
| Cloudflare Workers | Possible rewrite path only | Strong free edge tier, but requires moving the API to Worker/edge runtime instead of deploying the current Node server directly. |
| Supabase Edge Functions | Possible rewrite path only | Good for TypeScript edge functions near existing Supabase data, but it is a Deno edge-function model and not a direct Fastify deployment. |

## Render Setup Steps

1. Open Render Dashboard and choose New > Blueprint or New > Web Service for `DuongNX13/PawMate`.
2. Use branch `main`.
3. If using Blueprint, Render reads root `render.yaml`.
4. Enter `DATABASE_URL` in the Render prompt using the existing Supabase Session Pooler value. Do not put this value in git or chat.
5. Deploy the free web service.
6. Verify `GET https://<render-service-subdomain>.onrender.com/health` returns status `200`.
7. Set Codemagic variable `PAWMATE_API_BASE_URL` to the Render HTTPS base URL.
8. Run `ios-appetize-simulator-smoke`, upload the simulator zip to Appetize, and capture `/auth/register` plus `/auth/login` Network Logs against the durable Render URL.

## Remaining Blockers

- Render dashboard creation may still require user login/GitHub connection, but it should not require Fly payment or prepaid credit for the MVP free service path.
- Apple Developer/App Store Connect API remains required for signed IPA/TestFlight parity.
- Appetize replaces BrowserStack for simulator QA and network proof. It does not replace a physical iPhone or TestFlight for final real-device signing parity.

## Official References

- Render First Deploy: `https://render.com/docs/your-first-deploy`
- Render Free Instances: `https://render.com/docs/free`
- Render Web Services: `https://render.com/docs/web-services`
- Render Blueprint Reference: `https://render.com/docs/blueprint-spec`
- Railway Free Trial: `https://docs.railway.com/pricing/free-trial`
- Koyeb Pricing FAQ: `https://www.koyeb.com/docs/faqs/pricing`
- Vercel Hobby Plan: `https://vercel.com/docs/plans/hobby`
- Cloudflare Workers Pricing: `https://developers.cloudflare.com/workers/platform/pricing/`
- Supabase Edge Functions: `https://supabase.com/docs/guides/functions`

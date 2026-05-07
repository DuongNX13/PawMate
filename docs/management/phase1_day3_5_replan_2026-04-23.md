# PawMate Phase 1 Replan

Date: `2026-04-23`  
Project root: `D:\My Playground\PawMate`

## Objective

Re-evaluate the original Day 3-5 and MVP plan against the current Day 2 live state so the team keeps moving on a real critical path instead of an optimistic one.

## Inputs reviewed

- `C:\Users\duongnx\Downloads\phase1_tasks_day3_5.md`
- `C:\Users\duongnx\Downloads\MVP_pawmate_agent_schedule.md`
- `docs/management/day2_execution_board.md`
- `docs/management/day2_status_summary.md`
- `backend/prisma/data/day2_vet_seed_candidates.json`

## Bottom line

Yes, a targeted replan is needed.

The current plan does not need a full rewrite, but it does need three concrete corrections:

1. Social login must stay out of the current critical path.
2. Day 3 cannot start with nearby-map delivery as originally written because the current vet seed file does not yet contain geo coordinates, open hours, or service tags.
3. Day 5 should keep TestFlight as a conditional milestone, not as an unconditional promise, until core data inputs and visual QA are stable.

## What is still good and does not need replanning

- Day 2 backend auth and pet thin-slice remains a valid foundation.
- Day 2 mobile auth and pet screens remain usable as the implementation base, and auth is now wired to the real register -> OTP verify -> login path.
- Day 4 review-system work is still feasible after vet list/detail is connected, even if map delivery moves later.
- Day 5 health-records and reminder center work can still proceed in parallel with remaining visual QA.

## What changed in the live state

### 1. Auth scope changed

- `D2-13` and `D2-20` are no longer active MVP-critical tasks because social login is intentionally disabled through `AUTH_SOCIAL_LOGIN_ENABLED=false`.
- The Day 2 goal should now be read as `email-first auth`, not `email + Google + Apple`.

### 2. Runtime blocker changed

- Portable PostgreSQL and Redis are restored.
- `npm run smoke:runtime` is green again.
- The resumed Supabase project is reachable again.
- `D2-11` live proof is now green for:
  - register
  - verify email
  - login after verify

### 3. Vet data is not map-ready yet

The current `80`-clinic seed file is useful, but only for curated directory/list work.

Current strengths:

- clinic name
- city
- district
- address
- phone
- source traceability

Current missing fields for Day 3 nearby-map/filter work:

- `latitude`
- `longitude`
- `openHours`
- `services`
- `photoUrls`
- reliable `is24h`

Because of that, the original Day 3 sequence is too optimistic.

## Replan proposal

## Stabilization wave before Day 3

Add a short prep wave before the original Day 3 critical path:

1. Run a manual Stitch-vs-Flutter review for Day 2 auth and pet screens.
2. Freeze the current email-first auth path as the stable MVP auth baseline.
   - for now, treat in-app OTP verification as the stable user flow instead of raw email-link confirmation

Exit criteria:

- Day 2 UI is signed off as `implementation-ready`, even if final polish still carries forward
- email-first auth remains the stable baseline while social login stays deferred

## Day 3 should be split into two sub-waves

### Day 3A: Vet Directory foundation

Start these first:

- D3-02 Content Spec - Vet Data Format
- D3-05 Figma - Vet List Screen
- D3-06 Figma - Vet Detail Screen
- D3-10 Vet Detail Response Schema
- D3-11 Directions Deep Link Spec
- D3-13 API - GET /vets/search
- D3-14 API - GET /vets/:id
- D3-18 Flutter - Vet List Tab + Filter Bar
- D3-19 Flutter - Vet Detail Screen

Reason:

- these tasks can move forward with curated list/detail data
- they do not require finished geo coordinates for every clinic

### Day 3B: Vet Nearby + Map delivery

Only start after enrichment is done:

- D3-01 AC Vet Finder - Nearby & Filter
- D3-03 Figma - Map Screen
- D3-04 Figma - Bottom Sheet Preview
- D3-07 Figma - Map Error States
- D3-08 PostGIS Geo Query Design
- D3-09 Filter Query Param Schema
- D3-12 API - GET /vets/nearby
- D3-15 API - Filter Validation Middleware
- D3-16 Flutter - Map Tab
- D3-17 Flutter - Bottom Sheet Preview
- D3-20 Tests - Geo Query 10 Vi Tri
- D3-21 Tests - Performance 1000+ Vets
- D3-22 Tests - Filter & Map States

New prerequisite for this sub-wave:

- enrich the current vet seed with geo coordinates, open hours, service tags, and basic map-safe readiness checks

## Day 4 impact

Day 4 can remain mostly intact, but one rule should be explicit:

- review-system work should attach first to vet detail/list flows
- map completeness is not a blocker for review CRUD, helpful votes, report flow, or rating aggregates

## Day 5 impact

Day 5 should keep the feature scope, but the milestone wording needs to change:

- keep health records, reminders, notification center, and profile work
- keep E2E and accessibility planning
- treat `TestFlight RC1` as conditional, not guaranteed by calendar alone

Day 5 should only claim `RC-ready` if all of these are true:

1. vet list/detail runs on real backend data, not demo-only state
2. key Day 2 and Day 3 screens pass manual visual QA
3. no unresolved critical blocker remains in environment or data inputs

## MVP critical path after replanning

Recommended MVP critical path now:

1. Email auth stable and externally verified
2. Pet profile stable
3. Vet directory list/detail on real seeded backend data
4. Review system core
5. Health records + reminder center
6. Only then: map/nearby polish, real push, and TestFlight packaging

## Recommendation to the team

Use the replan, but keep it small and pragmatic:

- do not restart Phase 1
- do not wait for social login
- do not block all of Day 3 on map delivery
- do not promise TestFlight on date alone if live auth and vet data are still not production-ready

This keeps momentum while aligning the plan to the actual state of the repo and machine.

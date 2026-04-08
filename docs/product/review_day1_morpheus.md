# PawMate — Morpheus Review Day 1

## Review scope
- Primary lane: product + Definition of Done review for Day 1
- Support lane: Cypher acceptance coverage support
- Inputs reviewed:
  - `docs/product/day1_user_stories_and_dod.md`
  - `backend/package.json`
  - `backend/src/app.ts`
  - `backend/src/routes/health.ts`
  - `backend/tests/health.test.ts`
  - `.github/workflows/ci.yml`
- Constraint: no edits outside this review artifact

## Continuity note
- No PawMate knowledge log was found during rehydrate.
- This review is based on current repo state plus the existing Day 1 product artifact, without assuming undocumented prior decisions.

---

## 1) Executive verdict
Day 1 has a usable starting product artifact for stories and a generic DoD, but it is not yet strong enough to govern delivery cleanly. The biggest gap is not missing prose volume; it is missing acceptance precision and mismatch between the Day 1 product definition and the actual repo evidence.

Current Day 1 repo evidence shows only backend scaffold + `/health` route + one health test + CI scaffold. From a Morpheus lens, Day 1 is partially aligned on intent, but not yet aligned on measurable acceptance for the four planned user modules.

---

## 2) What is good already

### Product artifact quality
- The Day 1 stories cover the four planned modules clearly:
  - Auth
  - Pet Profile
  - Vet Finder
  - Health Records
- The stories are written in usable user-value language.
- The DoD includes healthy quality themes:
  - test coverage
  - performance target
  - dark mode
  - loading/empty/error/offline states
  - Vietnamese copy
  - security and release readiness

### Delivery hygiene already visible in repo
- Backend scaffold exists and is runnable in principle.
- CI workflow exists.
- Basic health endpoint + test exist, which is a valid bootstrap milestone.

---

## 3) Product and scope gaps

### Gap A — Stories are still too broad to guide implementation handoff
The current stories are useful for direction, but several are epic-sized and not yet sliced into implementation-safe acceptance units.

Examples:
- `AUTH-03 Login with social account` groups Google and Apple together, but these have different failure modes and device constraints.
- `VET-04 Filter and sort clinic results` is still too broad without a locked first-cut filter set.
- `HEALTH-04 Set reminders for care events` spans reminder creation, scheduling, and notification delivery, which are different delivery slices.

**Impact**
- Architect and Neo can interpret different scopes.
- Cypher cannot derive deterministic acceptance coverage from broad stories alone.

**Improve**
- Split stories into MVP-thin slices with first-pass boundaries.
- Example slices:
  - Auth email/password first; OAuth separate.
  - Vet Finder radius + open-now first; advanced filter combinations later.
  - Health reminder create/view first; push delivery verification later.

### Gap B — Review is present in Phase 1 DoD scope, but absent from the Day 1 story artifact
The DoD scope includes `Review`, but the Day 1 user-story document covers only four modules and does not define review stories.

**Impact**
- Scope accounting is inconsistent.
- Oracle/Cypher may assume Review is Day 1-ready when product definition has not prepared it.

**Improve**
- Either:
  1. explicitly mark Review as excluded from this Day 1 artifact, or
  2. add a small placeholder section with deferred review stories.

### Gap C — User value hierarchy is implied, not explicitly prioritized
The document contains all four modules, but it does not explicitly say what user value comes first if the team must cut scope.

**Impact**
- Delivery may over-invest equally across modules.
- Team may build breadth before proving core value.

**Recommended priority order**
1. Auth
2. Pet Profile
3. Vet Finder core discovery + clinic actionability
4. Health Records basic capture/history
5. Reminder scheduling polish after basic record flow is stable

### Gap D — Missing explicit assumptions for location, clinic data quality, and notification dependencies
Vet Finder and reminders both depend on external realities:
- user grants location permission
- clinic seed data is good enough
- map/directions deep links work on device
- notification channel may not be ready on Day 1

**Impact**
- Stories appear more delivery-ready than they really are.

**Improve**
- Add an assumptions subsection for each dependency-heavy story cluster.

---

## 4) Acceptance gaps
The largest Day 1 weakness is acceptance specificity. The current artifact describes intent and some expectations, but it does not yet provide testable acceptance for each story cluster.

### Missing acceptance for Auth
Still missing explicit acceptance on:
- password strength rule
- duplicate email behavior
- email verification required or optional for MVP
- session expiry expectation
- login error wording baseline
- logout outcome across one vs all sessions

### Missing acceptance for Pet Profile
Still missing explicit acceptance on:
- required vs optional fields
- allowed species list
- photo optional vs mandatory
- pet deletion behavior (hard delete vs soft delete from user perspective)
- empty state after first login with no pets

### Missing acceptance for Vet Finder
Still missing explicit acceptance on:
- MVP radius options
- minimum clinic card fields
- permission denied fallback behavior
- no-result state wording/CTA
- sort precedence
- exact CTA set on detail page
- whether reviews are required in MVP or optional if absent

### Missing acceptance for Health Records
Still missing explicit acceptance on:
- allowed record types in MVP
- required fields by record type
- timeline sort order
- edit/delete restrictions
- reminder recurrence support vs one-time only
- in-app reminder visibility if push is unavailable

### Cypher support note
For Cypher coverage, the current Day 1 artifact is not enough by itself to derive full negative-path coverage. Cypher will need explicit AC tables or scenario bullets per module, otherwise QA will be forced to infer product behavior.

---

## 5) Definition of Done gaps
The current DoD is directionally good, but several criteria are either too global, too advanced for Day 1, or not yet measurable from current repo state.

### DoD gap A — Too broad to apply fairly to every Day 1 task
The DoD says all deliverables should satisfy items like dark mode, offline states, and API p95 targets. That works for feature slices, but not for all Day 1 artifacts such as stories, ADRs, or ERD.

**Impact**
- Team can falsely mark planning artifacts as incomplete against irrelevant UI/runtime criteria.

**Improve**
- Separate DoD into two layers:
  - **Artifact DoD** for docs/contracts/design outputs
  - **Feature DoD** for implemented backend/mobile slices

### DoD gap B — `unit test coverage >= 80%` is not enough on its own
Coverage is useful but weak without critical-path expectations.

**Impact**
- Team may meet percentage without protecting the riskiest flows.

**Improve**
- Add: critical-path auth, pet ownership, vet search, and health record write/read flows must have explicit automated coverage.

### DoD gap C — `API <300ms p95` is premature without measurement conditions
The threshold is fine aspirationally, but Day 1 has no documented environment, sample load, or exclusions except a general note.

**Impact**
- This is hard to verify honestly on Day 1.

**Improve**
- Reframe for now as: endpoint performance target documented + measurement method defined before claiming pass.

### DoD gap D — `no crash >0.1%` is not yet actionable on Day 1
This is a release-quality metric, not a Day 1 proof gate.

**Impact**
- The metric sounds rigorous but cannot yet be evidenced from current state.

**Improve**
- Replace Day 1 expectation with: no known blocker crash in tested bootstrap flows; crash reporting plan exists before TestFlight.

### DoD gap E — Acceptance sign-off is declared, but AC artifact is not yet produced
The DoD assumes acceptance criteria exist and can be signed off, but the current product artifact does not yet provide story-level AC.

**Impact**
- Sign-off gate is structurally incomplete.

**Improve**
- Make story-level AC a prerequisite for marking Day 1 product work complete.

---

## 6) Tasks that are not yet at Definition of Done from current evidence
This section reviews Day 1 completion realism from visible repo/artifact evidence only.

### D1-07 — User Stories — Phase 1
**Status from Morpheus review:** partially done, not fully DoD-complete

**Why not fully DoD-complete yet**
- Stories exist.
- But acceptance criteria are still too implicit.
- Scope boundary for Review vs four-module artifact is inconsistent.
- Prioritization and cut-line are not explicit enough for an MVP under pressure.

**Needed to close**
- Add concise AC or scenario bullets per module.
- Clarify whether Review is excluded or deferred from this artifact.
- Add explicit MVP-first priority note.

### D1-08 — Definition of Done — Phase 1
**Status from Morpheus review:** partially done, not fully operationalized

**Why not fully DoD-complete yet**
- DoD exists as a quality statement.
- But it mixes artifact-quality criteria and shipped-feature criteria.
- Several gates are not measurable yet from Day 1 repo state.

**Needed to close**
- Split artifact DoD vs feature DoD.
- Convert aspirational metrics into verifiable Day 1 gates.
- Tie AC existence to DoD completion.

### Day 1 overall from product perspective
**Status from Morpheus review:** Day 1 is not yet product-complete

**Reason**
- Current repo evidence does not show product acceptance artifacts beyond the story/DoD document.
- Backend scaffold is much earlier than the declared Day 1 goal set.
- Product handoff precision is not yet strong enough for deterministic QA coverage.

---

## 7) Short improvement proposal

### Must-fix now
1. Add one compact acceptance section under each of the four module groups.
2. Clarify Review scope mismatch in the Day 1 artifact.
3. Split DoD into `artifact DoD` and `feature DoD`.
4. Mark MVP cut-line explicitly: what is required now vs safely deferred.

### Should-fix next
1. Add a module-by-module edge-case checklist for Cypher.
2. Add dependency assumptions for location, clinic seed quality, and notifications.
3. Add “minimum shippable fields” for Pet Profile and clinic cards.

### Nice-to-have
1. Add traceability mapping: story -> AC -> test owner.
2. Add a readiness table per module with `story ready / AC ready / UX ready / QA ready`.

---

## 8) Suggested acceptance coverage handoff to Cypher
Cypher should derive or request explicit tests at least for:

### Auth
- register success
- duplicate email
- weak password
- invalid login
- expired session / forced re-login
- logout success

### Pet Profile
- create with valid required fields
- invalid species or missing required field
- edit owned pet
- delete/remove flow confirmation
- first-time empty state

### Vet Finder
- permission granted vs denied
- nearby results within chosen radius
- no-result state
- filter apply/reset
- clinic detail data completeness
- call/directions fallback on failure

### Health Records
- add valid record
- invalid or incomplete record
- view chronological history
- edit/delete record
- reminder create with fallback if push not available

---

## 9) Bottom line
From a Morpheus lens, Day 1 has a decent product skeleton but not yet a delivery-safe product contract. The next best move is not to write more generic prose; it is to tighten acceptance and make the DoD operational for real handoff across Architect, Neo, and Cypher.

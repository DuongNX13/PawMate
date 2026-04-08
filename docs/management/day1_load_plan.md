# PawMate Day 1 Load Plan

Project root: `D:\My Playground\PawMate`
Date: `2026-04-07`
Owner: `Oracle (PM lane, D1-01 only)`

## Mission focus
- Day 1 goal: repo live, contract published, design system shared, local scaffolds prepared, critical blockers surfaced early.
- Oracle scope: own `D1-01` and coordination only; no technical implementation ownership.

## Day 1 lane allocation

### Oracle
- Primary lane: `D1-01 Kick-off & Tracking Board`
- Support lane: mission tracking, blocker escalation, overload balancing, checkpoint synthesis
- Notes: keep board current, confirm handoffs, guard against serial queueing

### Morpheus
- Primary lane: `D1-07 User Stories - Phase 1`, `D1-08 Definition of Done - Phase 1`
- Support lane: support Architect on `D1-03`, `D1-04`; support Trinity on copy/intent alignment
- Dependencies: needs MVP scope discipline and architecture feasibility feedback

### Trinity
- Primary lane: `D1-09 Design System - Colors & Typography`, `D1-10 Design System - Spacing & Components`, `D1-11 Wireframe - Phase 1 Flows`, `D1-12 Define 5 UI States Standard`
- Support lane: support Morpheus on user intent/copy; support Neo on Flutter-ready UI specs once runtime issue is clear
- Dependencies: needs scope lock for Phase 1 screens and AC clarity

### Architect
- Primary lane: `D1-02 GitHub Repo + Branch Strategy`, `D1-03 OpenAPI Contract - Auth Module`, `D1-04 OpenAPI Contract - Pet/Vet/Review/Health`, `D1-05 Database ERD`, `D1-06 Architecture Decision Records`
- Support lane: support Neo on backend structure and DB/schema decisions; support Cypher on infra assumptions
- Dependencies: none for drafting, but contract/ERD must land early to unblock Neo

### Neo
- Primary lane: `D1-13 Init Backend - Fastify + TypeScript`
- Support lane: support Architect on repo/bootstrap reality checks; prepare non-executable drafts for `D1-14`, `D1-15`, `D1-16` until runtimes are available
- Dependencies: blocked on missing local Flutter/Postgres/Redis runtimes for parts of Day 1

### Cypher
- Primary lane: `D1-17 Setup GitHub Actions CI`
- Support lane: support Morpheus on DoD/testability and Trinity on UI-state verification notes; prepare scaffold/verification notes for `D1-18`
- Dependencies: blocked from full runtime verification where Docker/local services are missing

## Current blockers
- `flutter` not found in local `PATH` -> blocks `D1-14` executable mobile bootstrap
- `docker` not found in local `PATH` -> blocks `D1-18` local container/staging verification
- `psql` not found in local `PATH` -> blocks `D1-15` local Postgres/PostGIS execution
- `redis-server` not found in local `PATH` -> blocks runtime verification for `D1-16`
- Critical path risk: Architect contract/ERD output must land early or Neo backend setup will drift into idle/support-only mode

## Support plan to avoid overload
- Oracle monitors load and keeps work parallel, not queued behind one lane.
- Architect is the highest Day 1 document-load lane; Morpheus supports contract clarity and Neo supports feasibility checks.
- Trinity carries the heaviest design batch; Morpheus supports copy/intent review to avoid rework.
- Neo should not absorb blocked runtime work as hidden overtime; when blocked, switch to backend bootstrap, folder structure, config skeletons, and implementation notes only.
- Cypher should scaffold CI and write verification notes first, then defer hard runtime checks until environment blockers are cleared.
- If Architect slips on contract/ERD, Oracle escalates immediately because this is the main Day 1 unblocker for Neo.

## Coordination checkpoints
- Checkpoint 1: board live and all Day 1 tasks assigned
- Checkpoint 2: Architect publishes first contract + ERD draft
- Checkpoint 3: Trinity publishes initial design system and wireframe draft
- Checkpoint 4: Neo confirms backend bootstrap status and lists environment-blocked items separately
- Checkpoint 5: Cypher confirms CI scaffold status and blocked verification scope

## PM note
- Oracle owns load balance, blocker visibility, handoff timing, and checkpoint synthesis only.
- Oracle does not take over technical drafting from Architect, Neo, Trinity, Morpheus, or Cypher.

# Contributing to PawMate

## Scope
This repository is organized for Phase 1 delivery. Keep changes small, reviewable, and traceable to a task, user story, or architecture decision.

## Branch model
- `main` is the protected release branch.
- `develop` is the integration branch for completed work.
- `feature/*` is for new work tied to a single task or story.
- `fix/*` is for bug fixes and small corrective changes.

## Working rules
- Start from `develop`, not from `main`.
- Keep each branch focused on one concern.
- Rebase or merge from `develop` before opening a PR if the branch has drifted.
- Do not push directly to protected branches.
- Prefer small PRs that can be reviewed in one pass.

## Pull request checklist
- The change is linked to the relevant Day 1 or Day 2 task.
- The scope is limited to the agreed Phase 1 feature set.
- Docs, schema, or contract changes are updated together when the behavior changes.
- Tests or verification notes are added when the change affects behavior.

## Architecture docs ownership
For Day 1 architecture work, keep the contract, ERD, and ADR aligned with Phase 1 only:
- `docs/architecture/openapi.phase1.yaml`
- `docs/architecture/erd.md`
- `docs/architecture/adr.md`

## Review notes
- Flag any dependency, runtime, or environment assumption explicitly.
- If a change is blocked by local tooling, document the blocker instead of faking completion.
- Preserve existing work from other contributors unless the task explicitly asks to replace it.

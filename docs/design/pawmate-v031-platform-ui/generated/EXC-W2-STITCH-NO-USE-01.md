# EXC-W2-STITCH-NO-USE-01 — approved exception

Status: `APPROVED_EXCEPTION_NOT_W2_PASS`

Approval record: [Product Owner approval](../../../management/pawmate_product_owner_approval_2026-07-22.md)
Approval timestamp: `2026-07-22T16:41:12+07:00`
Baseline ID: `UI-CC-2026-07-21-G4B`

## Request

Allow W3 to use the locked native/Figma sources while treating every Stitch
pilot as rejected reference-only material. This exception does not convert W2
to PASS and does not authorize any historical-node mutation.

## Baseline fingerprint

- Baseline ID: `UI-CC-2026-07-21-G4B`.
- W2 manifest: `generated/W2_GENERATION_MANIFEST.md`.
- Private Stitch project: `1138263671097818380`.
- Calls used: `6/9`; calls remaining and intentionally unused: `3`.
- S01: rejected because the required age field was omitted.
- S02: rejected because the required emergency row was omitted; recovered
  artifact SHA-256:
  `FED20F11460FA9F2A51DFCCBEBF806E161AD72D1DF4DC550EB49571E94AFC843`.
- S03-S05: not run under the repeated-IA stop condition.

## Owner and approval

- Requested owner: `User / Product Owner`.
- Technical reviewer: `Codex lead`.
- Approval status: `APPROVED`.
- Approval evidence: [pawmate_product_owner_approval_2026-07-22.md](../../../management/pawmate_product_owner_approval_2026-07-22.md).

No agent may change this status to approved based only on task execution
permission. Product Owner approval must be explicit and recorded with date,
scope and baseline ID.

## Required approval record

The dated approval record contains the required decision, approver, date, scope,
baseline and conditions fields:

```text
Decision: APPROVE | REJECT
Approver: <name or account>
Decision date: <ISO-8601 date>
Scope: W2 Stitch no-use exception; W3 may use locked native/Figma/runtime sources
Baseline ID: UI-CC-2026-07-21-G4B
Conditions: <any additional conditions, or NONE>
```

`APPROVE` changes the exception status to
`APPROVED_EXCEPTION_NOT_W2_PASS`; it does not make W2 a PASS and does not waive
the W3 77-row matrix, font, geometry, or historical-fingerprint gates. `REJECT`,
an incomplete record, or an approval that names another baseline leaves the
exception `DRAFT_NOT_APPROVED` and keeps W3 mutation blocked.

## Impact

- Stitch output is excluded from canonical UI, runtime, test and Figma sources.
- W3 may use only the locked v0.29 source, v0.31 clone, approved design tokens,
  runtime responsive goldens and a Product-Owner-approved proof matrix.
- All W3 count/font/geometry/historical-fingerprint gates remain mandatory.
- W2 stays `NOT_PASS_WITH_APPROVED_EXCEPTION`; W3 mutation may proceed after the
  separately approved 77-row matrix and allowlist are recorded.

## Expiry and reconsideration

This exception expires if any of these occur:

1. the Stitch project or design-system contract changes;
2. a new generative call is made;
3. Product Owner asks Stitch to become a source of truth; or
4. the G4B baseline changes without rebinding this exception.

Reconsider the exception if a future separately approved exploration budget
can produce five inspectable pilots without IA or privacy violations.

## Verification

- Confirm no production/runtime file references a Stitch artifact.
- Confirm no historical Figma node changed.
- Confirm W3 evidence cites native/Figma/runtime sources, never Stitch output.
- Confirm the W2 call count remains `6/9`.
- Confirm the approval record is bound to baseline `UI-CC-2026-07-21-G4B`.

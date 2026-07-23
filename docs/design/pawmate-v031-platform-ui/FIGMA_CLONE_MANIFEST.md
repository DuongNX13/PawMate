# Figma clone manifest — PawMate v0.31/v0.32

Status: `PARTIAL_FAIL_CLOSED`

## Immutable source

- Figma file: `zPyYIN058igxtbj44G30o8` (`Pawmate Desgin`).
- Source v0.29 section: `442:2`, 56 `NativeEditable/` frames.
- Source responsive v0.30 section: `444:3050`, 15 `NativeEditable/`
  frames.
- Historical rollback section: `447:4266`.
- Historical v0.27/v0.28 anchors: `382:87177`, `426:8956`.
- Historical names, parents, positions, metadata, and content were not changed.

## New append-only clones

- v0.31 section: `453:7374`, named
  `PawMate v0.31 - Cross-Platform Chocomint UI - Full Flow + States - TRUE EDITABLE`,
  at page coordinate `(18000, 24880)`.
- v0.32 responsive section: `453:10333`, named
  `PawMate v0.32 - Cross-Platform Chocomint Responsive Proof - TRUE EDITABLE`,
  at page coordinate `(21200, 24880)`.
- Exact source/target frame IDs and dimensions are recorded in
  `FIGMA_CLONE_MAP.csv`.

## Verification result

- v0.31: `56/56 MATCH` by exact frame name and size.
- v0.32: `15/77 MATCH`; the clone faithfully preserves all 15 responsive
  frames that exist in source v0.30, but 62 required proof frames do not exist.
- The read-only live audit on `2026-07-22` found 88 unsupported font nodes and
  eight direct geometry violations across the two new sections.
- No approved 77-row screen/state/viewport proof matrix exists, so the missing
  62 frames cannot be generated or resized safely from a numeric target alone.
- Therefore W3 is `NOT_PASS`; the new sections remain valid append-only
  rollback-safe artifacts, but must not be presented as fully approved UI.
- Exact nodes, screenshots, hashes, and the remediation contract are recorded in
  `docs/qa/ui-v031/W3_FIGMA_LIVE_AUDIT_2026-07-22.md`.

## Approved P1-01 delta — 2026-07-22

- Change control: `UI031-CHANGE-W8-P1-01-NO-RAILS-02`.
- Editable target: v0.31 frame `453:7378` only.
- Active clean hero: `459:11570`; photo picker circle/icon: `459:11571` and
  `459:11572`.
- Rollback image node `453:7383` is retained with visibility disabled.
- The three progress rails are absent; hero, photo picker, rounded content panel,
  and form content remain visible.
- No matching P1-01 frame exists in v0.32, so the responsive count remains
  `15/77`.
- Post-edit screenshot and live-audit data are recorded in
  `W3_FIGMA_LIVE_AUDIT_2026-07-22_P1-01_NO_RAILS.md`.

## Rollback and approval

Rollback affects only new section IDs `453:7374` and `453:10333`. No deletion
or mutation is authorized without explicit Product Owner approval. W3 needs
Product Owner approval only after 77/77 responsive frames, font audit, overflow
audit, and historical-node comparison all pass.

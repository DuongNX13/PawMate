# W8 Traceability Status

Baseline: `UI-CC-2026-07-21-G4B`
Current verdict: `EXECUTION_PASS / IOS_GATE_PASS / G4B_SIGNOFF_PENDING`

Opening checkpoint (superseded): `STRUCTURE_PASS / EXECUTION_STATUS_BLOCKED`

The traceability validator passes referential integrity and the frozen
denominators: 56 screen rows, 44 route/navigation rows, 84 CTA rows, 24 state
references, seven accessibility journeys, and 191 total unique trace rows. Its
eleven validator tests also pass.

The P1-01 screen row retains its frozen trace identity and `PLANNED` status but
now records approved change control `UI031-CHANGE-W8-P1-01-NO-RAILS-02`: the
screen must keep its clean hero and photo picker and must not display progress
rails. This is an objective expectation update, not a synthetic PASS transition.

The current CTA matrix now contains zero enabled `NO_OP` actions. The deferred
reminder action is backed by its snooze handler/test, and Rescue's staged post
action is correctly hidden while creation is disabled. Those corrections remove
stale matrix defects; they do not justify changing any of the 191 trace rows to
PASS without portable row-level evidence.

This is not execution completion. Every trace row still has status `PLANNED`,
with no portable test/golden/device evidence attached row by row. Therefore the
W8 rule that every required trace row must pass is not met.

| Check | Result | Evidence |
|---|---|---|
| Schema, references and denominators | PASS | `W8/traceability/codex-rtk-safe-20260721-204443-7234e1d7.raw.txt` |
| Validator unit tests | PASS, 11/11 | Latest W8 traceability validation evidence |
| Execution status | BLOCKED | `191 PLANNED`, `0 PASS` |

The W1 matrix remains frozen. W8 must create evidence-backed status transitions;
it must not turn rows to PASS from aggregate suite success alone.

## G4C split and post-W3 revalidation — 2026-07-22 17:24 ICT

The Product Owner's `VOICEOVER=G4C` decision is applied in the trace generator
and regenerated CSV. The seven `UI031-TRACE-A11Y-*` rows now declare
`platform=ANDROID`, retain `PLANNED` status for the missing row-level TalkBack
proof, and explicitly link their real-device VoiceOver proof to G4C. This keeps
the frozen denominator at 191 rows without claiming a false PASS.

| Check | Result | Evidence |
|---|---|---|
| Traceability structure | `PASS`, 191 rows / 11 tests | `node scripts/ci/ui-v031/validate_traceability.mjs` |
| G4C split | `PASS`, 7 rows updated, VoiceOver excluded from G4B | `scripts/ci/ui-v031/generate_traceability.mjs` |
| Current CSV SHA-256 | `0B220D56E1330FF9D25A6B2512327ADB528C8E5D1D8DD8871B3442D4FB5A7752` | `ui_v031_traceability.csv` |
| Execution status | `BLOCKED`, 191 `PLANNED`, 0 `PASS` | row-level device evidence still required |

## Successor current-state overlay — 2026-07-22 18:28 ICT

The earlier `0 PASS / 191 PLANNED` execution summary is superseded by a
fail-closed, row-bound evidence overlay. Current trace status is:

| Status | Rows | Composition / proof |
|---|---:|---|
| `PASS` | 102 | Evidence-bound screen, route and state rows |
| `PLANNED` | 89 | `82` CTA rows plus `7` Android TalkBack journeys |
| Total | 191 | Frozen denominator retained |

The transition was revalidated after tightening the validator against stale
goldens, unbound test logs, path traversal and synthetic accessibility proof:

- validator tests: `16/16 PASS`;
- fresh runtime-golden selection: `73/73 PASS`;
- fresh route selection: `108/108 PASS`;
- fresh Rescue CTA/golden selection: `6/6 PASS`.

VoiceOver remains explicitly outside G4B and is tracked in G4C. The remaining
seven accessibility rows above are Android TalkBack journeys, not VoiceOver
rows. W8 remains `PARTIAL_PASS / FAIL_CLOSED`; neither the 102 transitioned
rows nor the aggregate suite results constitute W8 or G4B sign-off.

## Terminal revalidation overlay — 2026-07-22 19:05 ICT

This append-only overlay supersedes the `16/16` validator count above. The
terminal deterministic checks pass with `17/17` validator tests and preserve
the frozen execution result at `102 PASS / 89 PLANNED`.

The additional validator rejects a TalkBack manifest when focus labels or
bounds repeat. A real HOME attempt using six Alt+Right inputs was assessed as
`NOT_PROVEN`: all six hierarchy XML files are byte-identical and the visible
focus target does not move. The negative evidence is retained at
`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/talkback-row-evidence-20260722/A11Y-HOME-TALKBACK-KEY/assessment.json`.
It does not transition `UI031-TRACE-A11Y-HOME` to PASS.

Current denominator remains exactly:

- `102 PASS`;
- `89 PLANNED` = `82` CTA rows + `7` Android TalkBack journeys;
- `191` total rows.

Protected-path reconciliation now passes separately with the approved exact
owner delta (`50` changes: `38` added, `12` modified, `0` removed). This closes
the protected-path subcheck but does not close W8 or G4B.

## Row-level closure overlay — 2026-07-23 11:59 ICT

This overlay supersedes the `102 PASS / 89 PLANNED` execution count. The frozen
191-row denominator now has portable, row-bound evidence for every row:

| Status | Rows | Composition / proof |
|---|---:|---|
| `PASS` | 191 | `56` screen + `44` route + `84` CTA + `7` Android TalkBack |
| `PLANNED` | 0 | none |
| Total | 191 | frozen denominator retained |

The previously missing proof is bound as follows:

- `82` CTA manifests:
  `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/cta-row-proof-20260723/cta-row-proof-index.json`;
- `7` TalkBack journey manifests:
  `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/talkback-journeys-20260723/talkback-journey-index.json`.

Fresh deterministic validation is `PASS`:

- trace execution overlay: `191 PASS / 0 PLANNED`;
- generated traceability: `191` records;
- validator tests: `19/19 PASS`;
- traceability validator: `PASS`, status counts `{PASS: 191}`;
- focused CTA suite: `148/148 PASS`;
- full Flutter suite: `411 PASS + 1 intentional skip`;
- current runtime-golden suite: `73/73 PASS`.

VoiceOver remains outside this denominator under the approved
`VOICEOVER=G4C` decision. W8 trace execution is complete; the post-change iOS
compile/render gate is now PASS; joint G4B sign-off remains the only downstream
approval gate.

## Post-change iOS gate closure addendum — 2026-07-23 15:08 ICT

The trace denominator remains frozen at `191 PASS / 0 PLANNED`. The separate
iOS gate is now bound to Codemagic build `6a61c58e95159f0929dd483e` on commit
`9afdb53`, with compile, launch, screenshot/hash and Runner fatal-scan evidence
under:

`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/ios-post-change-20260723/codemagic-build-6a61c58e95159f0929dd483e`.

The terminal W8 manifest validator returns `PASS`; the trace contract is
therefore execution-complete and waits only for Product Owner `G4B=APPROVE`.

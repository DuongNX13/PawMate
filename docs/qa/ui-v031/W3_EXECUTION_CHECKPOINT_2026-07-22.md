# W3 execution checkpoint — 2026-07-22

Verdict: `NOT_PASS / NO_MUTATION`
Baseline: `UI-CC-2026-07-21-G4B`
Figma file: `zPyYIN058igxtbj44G30o8`

## Read-only preflight completed

The live Figma source was inspected through read-only MCP operations. No Figma
write was issued in this checkpoint.

| Check | Result | Evidence |
|---|---|---|
| v0.31 editable section | `56` `NativeEditable` frames | `453:7374`; source-to-clone map and live search |
| v0.32 responsive section | `15` `NativeEditable` frames | `453:10333`; inherited v0.30 frames |
| Historical sections | not targeted | source lock `FIGMA_SOURCE_LOCK.json` |
| W3 matrix | `77` rows generated, not approved | `W3_RESPONSIVE_PROOF_MATRIX_PROPOSAL.csv` |
| Font audit | `88` unsupported families remain | parent live audit `W3_FIGMA_LIVE_AUDIT_2026-07-22.md` |
| Geometry audit | `8` direct violations remain | parent live audit, nodes listed below |
| Figma writes | `0` | MCP call log for this checkpoint |

The reproducible static validator is recorded in
`W3_MATRIX_VALIDATION_2026-07-22.txt`. Its output SHA-256 is
`ec6566a553f1b4c896effeb4b5e648c26e4b14e0910050710b4f3fd35761ed9e`; it proves
`77` rows, `56+21` partitioning, `15` existing candidates, `62` missing rows,
zero bad source/target IDs, zero duplicate IDs, zero historical targets, and
`figma_write_calls=0`. The matrix file SHA-256 is
`044FBF20B404AF84866FC62B1D08227177196638CD81CD363EB6001E136EB62F`.

Exact validation command (read-only):

```powershell
$m=Import-Csv docs/qa/ui-v031/W3_RESPONSIVE_PROOF_MATRIX_PROPOSAL.csv
$map=Import-Csv docs/design/pawmate-v031-platform-ui/FIGMA_CLONE_MAP.csv
$v31=@($map|? kind -eq screen|% target_node_id)
$v32=@($map|? kind -eq responsive|% target_node_id)
$sourceBad=@($m|? {$_.source_v031_frame_id -notin $v31})
$targetBad=@($m|? {$_.target_v032_frame_id -and $_.target_v032_frame_id -notin $v32})
$historical=@($m|? {$_.target_v032_frame_id -match '^(382:|426:|442:|444:)'})
$dupeProof=@($m|group proof_id|? Count -gt 1)
$dupeTarget=@($m|? target_v032_frame_id|group target_v032_frame_id|? Count -gt 1)
```

The command's final JSON projection is the exact payload whose SHA-256 is recorded
above; it also appends `figma_write_calls=0` and `w2_generation_calls=6/9` as
execution facts.

The parent audit records the stable baseline typography count as 1,977 text nodes
and 88 unsupported-family nodes (86 Inter, one Plus Jakarta Sans, one mixed-family
node). A later P1-01 no-rails scan reported a different total while retaining the
same 88 unsupported nodes; that denominator drift is intentionally not normalized
or promoted to a new baseline.

## Geometry blockers still open

| Frame | Node | Failure |
|---|---|---|
| v0.32 P1-08 `453:10600` | `453:10648` | “Đánh giá 4.5+” exceeds right bound by 121 px |
| v0.32 P1-08 `453:10699` | `453:10748` | same label exceeds right bound by 69 px |
| v0.32 P1-08 `453:10797` | `453:10846` | same label exceeds right bound by 51 px |
| v0.32 P1-16 `453:11218` | `453:11229` | rectangle crosses bottom by 1 px |
| v0.31 P2-06 `453:8638` | `453:8643` | child crosses bottom by 1 px |
| v0.31 P2-06 `453:8638` | `453:8653` | child crosses bottom by 1 px |
| v0.31 P2-06 `453:8638` | `453:8678` | child crosses bottom by 4 px |
| v0.31 P2-14 `453:9121` | `453:9158` | text crosses bottom by 1 px |

## W2 dependency

W2 was stopped fail-closed after two consecutive Stitch IA/content misses. The
second pilot was recovered without a new generation call, but still rejected:

- session `7441708477120337878`;
- stable screen `08af8045ba774488af5709761f62a30a`;
- recovered screenshot asset `db110720620e4c2fa0eed569cad5407b`;
- screenshot SHA-256
  `FED20F11460FA9F2A51DFCCBEBF806E161AD72D1DF4DC550EB49571E94AFC843`;
- missing prompt-mandated full-width emergency row and wrong reported viewport.

The generation manifest remains `STOPPED_FAIL_CLOSED` at `6/9` model-like calls.
`EXC-W2-STITCH-NO-USE-01.md` is only a draft; no Product Owner approval exists.

## Re-entry gates

W3 may not mutate until all of these are evidenced:

1. Product Owner approval of the 77-row matrix and its seven-screen selection.
2. Product Owner approval of the W2 no-use exception, or a formally accepted
   alternative that preserves the fail-closed status.
3. Explicit allowlist confirmation for new v0.31/v0.32 sections only.
4. A post-write audit proving 77/77 rows, zero unsupported fonts, zero overflow,
   and unchanged historical fingerprints.

This checkpoint was originally closed read-only. The Product Owner has since
approved the no-use exception, the exact 77-row/seven-screen matrix and the
v0.31/v0.32 allowlist. The Stitch call count remains `6/9`; no new generation
call is authorized. W3 is now permitted to mutate only the two new sections and
must produce the post-write proof below.

## Approval update — 2026-07-22 16:41 ICT

- W2 exception: `APPROVED_EXCEPTION_NOT_W2_PASS`.
- W3 matrix: exact proposal `77` rows (`56` canonical + `21` responsive-extra),
  seven-screen selection approved.
- Mutation allowlist: only new sections `453:7374` (v0.31) and `453:10333`
  (v0.32), plus append-only evidence and governance artifacts.
- VoiceOver disposition: seven real-device journeys are moved to optional G4C;
  they are not part of the G4B denominator.
- Approval evidence: [Product Owner approval record](../../management/pawmate_product_owner_approval_2026-07-22.md).

## W3 execution entry

W3 may now execute in this order:

1. Capture the approved-section rollback snapshot.
2. Normalize all 88 unsupported text nodes to approved Be Vietnam Pro styles.
3. Repair the eight listed geometry/overflow violations.
4. Clone the 62 missing responsive proof frames into `453:10333` using the
   approved matrix; preserve the 15 existing frames and historical nodes.
5. Re-run recursive font/geometry/overflow/fingerprint validation and export
   evidence for all 77 rows.

W3 remains `IN PROGRESS` until all five steps pass; W8/W9/G4B remain fail-closed
until their downstream gates are rerun.

## Post-write execution result — 2026-07-22 17:20 ICT

W3 is now `PASS` for the approved design mutation scope. The Product Owner
approval is recorded in
`../../management/pawmate_product_owner_approval_2026-07-22.md`.

| Gate | Result | Evidence |
|---|---|---|
| Approved matrix | `PASS` — 77/77 rows resolved (56 canonical + 21 responsive extra) | `W3_MATRIX_VALIDATION_POST_WRITE_2026-07-22.txt` |
| NativeEditable target frames | `PASS` — v0.31 56, v0.32 77 | `W3_POST_WRITE_AUDIT_2026-07-22.json` |
| Typography | `PASS` — 0 unsupported font families in both sections | same audit |
| Geometry/overflow | `PASS` — 0 recursive violations; 360px P1-01 and P2-12 reflowed | same audit + approved-seven screenshots |
| Historical sections | `PASS` — names, bounds and child-ID counts unchanged for all 5 protected roots | same audit + pre-snapshot fingerprint |
| Snapshot/screenshots | `PASS` — post-write section and seven-screen evidence saved | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/` |

The mutation allowlist used only sections `453:7374` and `453:10333`; Stitch
remained reference-only under the approved W2 exception. W3 is not a G4B
sign-off: W7 post-change iOS, W8 traceability and G4C, and W9 remain required
downstream gates. Day 39 stays closed until G4B passes.

## Successor current-state overlay — 2026-07-22 18:28 ICT

This overlay supersedes only the downstream-gate wording above; it does not
rewrite the historical execution record. VoiceOver is explicitly outside the
G4B denominator and is tracked separately in G4C. Android TalkBack remains in
the G4B traceability scope.

The W3 approval-to-execution byte chain has now been recovered and reconciled:

| Item | Current verified value |
|---|---|
| Approved input SHA-256 | `044FBF20B404AF84866FC62B1D08227177196638CD81CD363EB6001E136EB62F` |
| Executed matrix SHA-256 | `D9F295525E261D797823F06E872472C0CAB2C2F599F57AB8A74126F1B8D3468A` |
| Matrix accounting | `77` rows: `62` created, `15` inherited, `0` unexpected |
| Reconciliation artifact | `W3_APPROVAL_HASH_RECONCILIATION_2026-07-22.json` |
| Immutable recovered input | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/pre-write-approved-matrix/W3_RESPONSIVE_PROOF_MATRIX_APPROVED_INPUT.csv` |

Current W3 verdict remains `PASS`. This does not imply W8, W9 or G4B PASS.

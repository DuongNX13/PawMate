# W3 Figma Live Audit — 2026-07-22

Baseline: `UI-CC-2026-07-21-G4B`
Figma file: `zPyYIN058igxtbj44G30o8`
Verdict: `FAIL / NO_MUTATION`

## Scope and method

The audit used read-only Figma MCP calls against the two append-only sections:

- v0.31: `453:7374`
- v0.32 responsive proof: `453:10333`

It counted text families, compared existing frame geometry against direct child
bounds, and exported the four v0.32 frames that contain a visible or boundary
violation. Historical v0.27/v0.28/v0.29/v0.30 nodes were not renamed, moved,
reparented, or edited. No node in v0.31/v0.32 was mutated during this audit.

## Findings

### Responsive denominator

- v0.31 preserves `56/56` source frames by exact name and size.
- v0.32 contains only the `15` responsive frames inherited from source v0.30.
- The contract requires `77`, but there is no approved row-level proof matrix
  identifying the missing 62 screen/state/viewport targets.
- Therefore neither blind cloning nor resizing is authorized: doing so could
  create the wrong states while still reaching a misleading numeric count.

### Typography

| Section | Text nodes | Be Vietnam Pro | Material Icons (allowed) | Unsupported |
|---|---:|---:|---:|---:|
| v0.31 | 1,377 | 844 | 457 | 76 |
| v0.32 | 600 | 371 | 217 | 12 |
| Total | 1,977 | 1,215 | 674 | 88 |

The 88 unsupported nodes comprise 86 Inter nodes, one Plus Jakarta Sans node,
and one mixed-family node. They violate the current Be Vietnam Pro design-system
contract.

### Direct geometry violations

| Section/frame | Node | Violation |
|---|---|---|
| v0.32 P1-08 360x800 `453:10600` | `453:10648` | “Đánh giá 4.5+” exceeds the right bound by 121 px |
| v0.32 P1-08 412x915 `453:10699` | `453:10748` | Same label exceeds the right bound by 69 px |
| v0.32 P1-08 430x932 `453:10797` | `453:10846` | Same label exceeds the right bound by 51 px |
| v0.32 P1-16 412x915 `453:11218` | `453:11229` | Rectangle crosses the bottom bound by 1 px |
| v0.31 P2-06 `453:8638` | `453:8643` | Direct child crosses the bottom bound by 1 px |
| v0.31 P2-06 `453:8638` | `453:8653` | Direct child crosses the bottom bound by 1 px |
| v0.31 P2-06 `453:8638` | `453:8678` | Direct child crosses the bottom bound by 4 px |
| v0.31 P2-14 `453:9121` | `453:9158` | Text crosses the bottom bound by 1 px |

The P1-08 clipping is visually confirmed in all three exported screenshots.
The one-pixel cases remain objective geometry failures even when they are hard to
see at screenshot scale.

## Portable evidence

Evidence directory:
`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W3/live-audit-2026-07-22/`

| Artifact | SHA-256 |
|---|---|
| `p1-08-360x800-overflow.png` | `61FD210894235CF4E09AB1D325D059ED53E0F6204C102F4BA89E51C0D5069185` |
| `p1-08-412x915-overflow.png` | `3186B37865F94D0A0F8A96F4E27E174147514B7411EF367663FECCDAA39312E7` |
| `p1-08-430x932-overflow.png` | `13C1AD43A48E8F4FA13E8646081941AE2E736CB653A7F6BEA6D8A08F96A3F0EC` |
| `p1-16-412x915-boundary.png` | `F3881C217AAC4887EAD0A09BCD021529D4F8B4CDE71903869D864AC3D407393A` |
| `figma-live-audit-summary.json` | Bound by the W8 source snapshot manifest |

## Required remediation contract

W3 can be re-entered only after all of the following inputs exist:

1. Product Owner approves a 77-row proof matrix with screen ID, state, viewport,
   source frame, target section, safe-area policy, and expected evidence.
2. Edits are restricted to the new section IDs `453:7374` and `453:10333`.
3. All 88 unsupported font nodes are migrated to approved Be Vietnam Pro styles.
4. All eight direct geometry violations are fixed, followed by recursive overflow
   and text-wrap validation at the approved viewports and accessibility scales.
5. A post-fix audit proves `77/77`, zero unsupported families, zero overflow, and
   unchanged historical-node fingerprints.
6. Product Owner records explicit approval. Until then W3 remains `NOT_PASS` and
   W8/W9 remain fail-closed.

# PawMate Product Owner G4B approval record — 2026-07-23

- Approval timestamp: `2026-07-23T15:47:52+07:00`
- Approver: `User / Product Owner (explicit Codex-thread confirmation)`
- Exact decision: `G4B=APPROVE`
- Baseline: `UI-CC-2026-07-21-G4B`
- Evidence source: the user's explicit approval message in the active Codex task.

## Approved immutable evidence baseline

| Artifact | Approved value |
|---|---|
| Evidence branch | `evidence/g4b-ios-postchange-20260723` |
| Evidence commit | `9b6501991bd56a865ae5a1cac9defd7b31ecad22` |
| W8 manifest | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json` |
| W8 manifest SHA-256 | `3832C950AFCED7ADDFE8B7D828DFE7CD8E40A566F4B9147778203F1C35FCD7A1` |
| W8 source snapshot SHA-256 | `9D1E17293EF7532DAC0FC1ED286FDBCDF1027B200A00826C8AEEB6F836D52245` |
| W8 artifacts | `779`; redaction `PASS`; validator errors `0` |
| Post-change iOS proof | Codemagic build `6a61c58e95159f0929dd483e`; compile, launch, render/hash and Runner fatal scan `PASS` |
| Android/TalkBack | normal APK provenance `PASS`; seven TalkBack journeys `PASS` |
| Traceability | `191/191 PASS`; CTA evidence `82/82` |
| VoiceOver disposition | `G4C`, outside the approved G4B denominator |

## Decision effect

- Product Owner and Codex lead now jointly approve the same immutable G4B
  evidence baseline.
- G4B may transition from `PENDING_PRODUCT_OWNER` to `PASS`.
- W9 handoff may transition to `PASS`.
- `D39-ENTRY` may be evaluated. Day 39 is not opened by this record alone; a
  machine-verifiable entry manifest must still prove SRS v1.1 adoption, G5A
  PASS, G4B PASS, protected baseline/owner delta and feature flags
  `false/false`.

## Immutability rule

This approval binds the exact W8 manifest hash above. The approval and
successor status documents are not retroactively inserted into that signed
manifest, because doing so would change the evidence baseline after approval.
Any later UI, contract or proof change requires a new successor manifest and a
new approval decision.

# W2 generation manifest

Status: `STOPPED_FAIL_CLOSED`

This manifest records the bounded Stitch and Image Gen exploration for PawMate
v0.31. Generated UI is reference-only. It is not a canonical source for the
runtime or for historical Figma nodes.

## Generation budget

- Approved cap: 9 generative/model calls.
- Used: 6 model-like calls: one DESIGN.md design-system attempt, one fallback
  design-system creation, two Stitch pilots, and two Image Gen fixtures.
- The remaining three calls were deliberately not used after the second Stitch
  pilot initially appeared uninspectable. A later zero-call recovery found the
  stable output ID in the exact prior MCP result, but visual review then proved
  a second IA/content miss. The W2 repeated-IA stop condition therefore still
  applies and the three calls remain unused.
- Read/list/get/export/conversion/hash calls are evidence operations and do not
  consume the generative budget.

## Private Stitch scope

- New project: `projects/1138263671097818380`.
- Project title: `PawMate v0.31 Cross-Platform Chocomint Lab — 2026-07-21`.
- Visibility verified: `PRIVATE`.
- Uploaded DESIGN.md instance: `15917604135703988036`.
- Design-system asset: `assets/2426112189390792966`, version `2`.
- Historical projects `7831209429172632844` and `2375517817629542727`
  were not edited.

## Pilot results

| Pilot | Prompt source | Result | Review decision |
|---|---|---|---|
| `S01_P1-01_Onboarding_SafeArea` | `stitch/prompts/S01_P1-01_Onboarding_SafeArea.md`; SHA-256 `CD36DD05AA1E211147C1D2AA57D5A208DEAC8A8A55D688DD3BFBA7181BF2E15C` | Session `2879713888517171693`; screen `48290502ec914e78bf6922e941087d6f`; screenshot `stitch/pilots/S01_P1-01_Onboarding_SafeArea.png` | `REJECTED`: the required `Tuổi (năm)` field was omitted, so the IA contract failed. |
| `S02_P1-07_Home_Hierarchy` | `stitch/prompts/S02_P1-07_Home_Hierarchy.md`; SHA-256 `C4C183846766A26F95D582B238501A1A051077AEE77A940E5ADDFF6057794963` | Session `7441708477120337878`; recovered screen `08af8045ba774488af5709761f62a30a`; screenshot `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W2/stitch/pilots/S02_P1-07_Home_Hierarchy-recovered.png` | `REJECTED`: the required full-width emergency message row is absent. The returned `780x2306` artifact also does not prove the requested `390x844` viewport. This is the second IA/content miss, so the W2 stop condition applies. |
| `S03_P1-08_VetMap_Permission` | frozen name in `DESIGN.md` | Not generated | `NOT_RUN`: stop-loss after S02. |
| `S04_P2-01_RescueHome_FinalContract` | frozen name in `DESIGN.md` | Not generated | `NOT_RUN`: stop-loss after S02. |
| `S05_P2-12_ShelterChat_Overflow` | frozen name in `DESIGN.md` | Not generated | `NOT_RUN`: stop-loss after S02. |

The project API still exposes only the uploaded DESIGN.md instance through
`get_project`; `list_screens` and direct `get_screen` calls return an invalid
argument for the recovered S02 ID. The immutable prior MCP result nevertheless
contains the screen ID and downloadable screenshot/HTML assets, so S02 is now
inspectable without a new generation call. Its review is a rejection, not an
acceptance. This is not enough evidence for the required five-pilot denominator;
W2 remains not PASS and later design/runtime work must use the locked native
source and Figma clone, not Stitch output.

## Zero-call S02 recovery addendum — 2026-07-22

- New generation/model calls: `0`; cumulative usage remains `6/9`.
- Prior Stitch session: `7441708477120337878`.
- Stable screen ID: `08af8045ba774488af5709761f62a30a`.
- Screenshot asset ID: `db110720620e4c2fa0eed569cad5407b`.
- HTML asset ID: `e29376a0ab4149bb909ced046fc8e939`.
- Recovered screenshot: `67,184` bytes, SHA-256
  `FED20F11460FA9F2A51DFCCBEBF806E161AD72D1DF4DC550EB49571E94AFC843`.
- Recovered HTML: `17,280` bytes, SHA-256
  `14157AFC61AF6939AD006A2D355261F1F25B5A93E811185B5B47474DE88F61FB`.
- S02 does preserve the five-tab shell, Chocomint palette, Home hierarchy,
  compact actions and the complete `Tìm nhà cho Golden` card.
- S02 omits the prompt-mandated emergency message row. Its artifact is reported
  as `780x2306`, not the requested `390x844`. It is therefore `REJECTED`.
- `S03` through `S05` were not generated because W2 explicitly stops after a
  repeated IA violation. There was no retry and no hidden use of the reserve.
- Proposed exception `EXC-W2-STITCH-NO-USE-01` is a separate draft. It cannot
  unlock W3 until the Product Owner approves it.

## Synthetic Rescue fixtures

| Fixture | Design copy | Dimensions | Size | SHA-256 | Review |
|---|---|---:|---:|---|---|
| `synthetic/lulu-rescue-test-fixture.webp` | Dữ liệu minh họa — Lulu | 1024×768 | 187,612 bytes | `44FCE6A6CCA269F758EEA8E2DB0A2CA8674BBBF8D150242B1EDD648D4D4F960C` | PASS |
| `synthetic/muc-rescue-test-fixture.webp` | Dữ liệu minh họa — Mực | 1024×768 | 143,202 bytes | `639AD776E49E4A761EAEFE7D2D73CA320353D89A3B819AFB9AB0FBA1653DCCCF` | PASS |

Both fixtures contain one animal, no people, no readable text, no identifiable
address/property/location, no embedded metadata, and are test/design-only.
Their exact prompts and conversion contract are recorded in
`synthetic/README.md`. Test copies may live under `mobile/test/fixtures/rescue/`
but must never be listed in `mobile/pubspec.yaml` production assets.

## W2 verdict

- Image Gen subgate: `PASS`.
- Stitch subgate: `FAIL_CLOSED`.
- Wave W2: `NOT_PASS`.
- Rollback point: abandon only project `1138263671097818380` and the generated
  references; historical work remains immutable.

# W4 foundation report — UI-CC-2026-07-21-G4B

Verdict: `IMPLEMENTATION_PASS_CONTRACT_BLOCKED_BY_W3`.

The W4 implementation itself passes its source, component, accessibility,
golden, analysis, and bundle checks. It is not promoted to an unconditional
wave exit because W3 remains fail-closed at `56/56` editable clones but only
`15/77` responsive variants.

## Approved implementation

- Light-only Chocomint theme with Deep Green `#2D6A4F`, Brown `#5C3C25`, Mint
  `#95D5B2`, Light Beige `#E9F5DB`, and White `#FFFFFF` through semantic
  tokens.
- Be Vietnam Pro is the production font family. Only weights 400, 500, 600,
  and 700 are bundled. The historical Inter file remains in the repository but
  is no longer a production asset.
- A compact CTA may render at 36dp only for a one-line label at text scale
  `<= 1.3`; its hit target remains at least 48dp. Longer labels and larger text
  use content-driven height, and multi-action groups change to a vertical,
  full-width layout when needed.
- Safe-area, keyboard inset, focus, disabled/loading semantics, bottom
  navigation, and Android/iOS adaptive back, dialog, date picker, time picker,
  and action-sheet primitives are implemented.
- `FittedBox` and `BoxFit.scaleDown` are absent from the W4 foundation scope.

## Independent root verification

| Gate | Result | Evidence |
|---|---|---|
| Focused theme/widget/platform suite | PASS, `54/54` | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W4/root-verification/approved-focused-tests-post-clean.raw.txt` |
| Platform primitive goldens | PASS, 12 images | `mobile/test/visual/goldens/ui-v031-platform-primitives/` |
| Contact-sheet visual inspection | PASS | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W4/platform-primitives-contact-sheet.png` |
| `flutter analyze --no-pub` | PASS, no issues | `W4/root-verification/approved-analyze.raw.txt` |
| `flutter build bundle --no-pub` | PASS | `W4/root-verification/approved-bundle.meta.json` |
| Scoped `git diff --check` | PASS | Exit code 0; CRLF conversion warnings are informational |
| Forbidden layout scan | PASS | `rg` exit code 1 with zero matches |
| Toolchain preflight after owner hash refresh | PASS_WITH_KNOWN_GAPS, `33/33` checks | `W4/root-verification/toolchain-preflight-after-W4.raw.json` |

The approved launcher is `D:/flutter/bin/flutter.bat`. An initial verification
mistakenly used the same Flutter revision from a path containing a space, which
exposed an `objective_c` native-hook quoting defect. A temporary `P:` alias then
left one generated cache reference after removal. The cache was cleaned and
rebuilt with the approved launcher; the first failure and the final PASS are
both retained under `W4/root-verification/`.

`flutter pub get` resolved and wrote package metadata but returned non-zero on
the optional Windows desktop plugin-symlink step because Windows Developer Mode
is disabled. The Android/iOS-oriented analysis, focused tests, and Flutter
bundle all pass afterward. No system setting was changed and no retry hides the
first failure.

## Exit constraint

W4 source is approved for downstream reversible development. Formal W4/G4B
sign-off remains coupled to W3 remediation or an explicit approved exception.
W5 must still implement active-tab reselect, branch restoration, and the Vet
root change from `/vets/list` to `/vets/map`; those are router responsibilities,
not W4 foundation defects.

## Post-W3 revalidation addendum — 2026-07-22 17:18 ICT

The approved W3 contract is now `PASS` (77/77 rows, zero unsupported text
families, zero geometry violations, unchanged historical fingerprints). The
exact W4 revalidation was rerun with the approved local launcher
`D:/flutter/bin/flutter.bat`:

| Gate | Result | Evidence |
|---|---|---|
| Focused foundation/widget/platform suite | `PASS`, 57 tests | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W4/post-w3-revalidation-20260722/codex-rtk-safe-20260722-171808-642ef453.raw.txt` |
| `flutter analyze --no-pub` | `PASS`, exit 0 | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W4/post-w3-revalidation-20260722/codex-rtk-safe-20260722-171630-e4b423d9.raw.txt` |
| `flutter build bundle --no-pub` | `PASS`, exit 0 | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W4/post-w3-revalidation-20260722/codex-rtk-safe-20260722-171649-0bd728b1.raw.txt` |

Formal W4 status is promoted to `PASS`. This is a local Flutter 3.41.6 proof;
the Codemagic-pinned iOS toolchain remains a separate W7 gate.

# W0 baseline report — UI-CC-2026-07-21-G4B

Verdict: `PASS` — the local source, rollback, Flutter, Android,
backend-regression, protected-path, and current-commit iOS simulator baseline
gates pass. Codemagic workflow `ios-appetize-simulator-smoke` completed on
baseline commit `4910aa0e9b811b05361650c8d3ea193ca70a0b7d` with every recorded step
successful and a downloadable simulator artifact.

## Identity and rollback

- Change-control ID: `UI-CC-2026-07-21-G4B`.
- Baseline commit: `4910aa0e9b811b05361650c8d3ea193ca70a0b7d`.
- Scoped backup:
  `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/baseline-scoped-backup/`.
- Backup manifest: 188 files, 6,336,665 bytes, SHA-256
  `31D0A31B7241AC43DED6B33EBAC600BAC271719BD38AEB45E73C42614F779487`.
- Full restore verification: `188/188` files match recorded size and SHA-256;
  mismatches `0`.
- Cache/build/temp directories and unrelated historical untracked artifacts
  were deliberately excluded.

## Dirty-file classification

The 188 scoped baseline files have no unclassified rows:

| Classification | Count | Handling |
|---|---:|---|
| Design governance | 1 | W0/W1 owned |
| Native deferred/protected until W7 | 2 | read-only before W7 and iOS baseline |
| UI assets | 20 | UI lane owned |
| Integration tests | 6 | UI/QA lane owned |
| Flutter production source | 64 | W4–W6 owned by wave allowlist |
| Flutter config | 1 | W4 owned |
| Flutter tests | 50 | W4–W8 owned by wave allowlist |
| Generated visual evidence/goldens | 44 | never treated as production source |

## Authoritative design inventory

- `SCREEN_INVENTORY.csv`: 56 unique live Figma source rows.
- Denominator: 16 Phase 1, 16 Phase 2, 24 state/reference rows.
- Source section: `442:2` in Figma file `zPyYIN058igxtbj44G30o8`.
- Inventory SHA-256:
  `AA429BA515C1F0C7B7212053B356C745A92247A9C0A9363776D17ADA40693077`.
- `node scripts/ci/ui-v031/validate_inventory.mjs`: PASS, 56/56.

## Local Flutter and Android baseline

| Gate | Result | Evidence/fingerprint |
|---|---|---|
| `flutter analyze --no-pub` | PASS, 0 issues | W0 mobile analyze log |
| `flutter test --no-pub --coverage` | PASS, 276 tests plus 1 intentional skip | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/mobile/full-test-coverage/codex-rtk-safe-20260721-161333-c847ecf5.raw.txt` |
| Flutter LCOV | Captured | SHA-256 `F3AA61F74AAD69944E4A1ADCD1BC6050F020F8D746D1A6C904972216E136BFDF` |
| Fresh visual failure directory | PASS, 0 files | 148 stale pre-baseline diff files were moved into `visual-failures-prebaseline/`, never deleted |
| `flutter build apk --debug` | PASS | `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/mobile/android-debug-build/codex-rtk-safe-20260721-161437-15ca5b8d.raw.txt` |
| Codemagic `ios-appetize-simulator-smoke` | PASS, build `6a5f426f3432213ac398e71a` | Build overview: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/6a5f426f3432213ac398e71a`; successful-finish screenshot SHA-256 `E6D52630888591CF17B7C4A3D01894A8CE928057D3BBD2A823C00B81F3B92154` |
| iOS simulator artifact | PASS, `PawMate-appetize-simulator.zip`, 56.33 MB | Artifact-open screenshot SHA-256 `8C0BDDB0313239956B55C0E2DE773A1A4796DD7CCC43725CF3FA47C35D0E34A3`; evidence in `W0/ios-codemagic/` |

## Backend regression baseline

These commands are regression evidence only; W0 did not change backend source.

| Gate | Result | Evidence |
|---|---|---|
| `npm run lint` | PASS | `W0/backend/lint/` |
| `npm test` | PASS: 28 suites, 212 tests; 3 suites/8 tests intentionally skipped | `W0/backend/test/` |
| `npm run build` | PASS | `W0/backend/build/` |
| `npm run test:coverage` | PASS; all-files statements 80.78%, branches 63.95%, functions 85.46%, lines 80.75% | `W0/backend/coverage/`; LCOV SHA-256 `C7607A0B7275DB0112BE8441440028FF85BB919A8749B86FCB723DF4A270BB9F` |
| `npm audit --omit=dev` | PASS, 0 vulnerabilities | `W0/backend/audit-production/` |

## Protected Day 37/38 baseline

- Manifest:
  `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W0/protected/protected-baseline.json`.
- Policy: `ui-v031-day37-day38-protected-v1`.
- Baseline ID:
  `170B536B40DC73DC269515ABE335DA1CFC7B088F7A4D68ACA2D2D5F355BE8E4B`.
- Protected files: 182.
- Manifest SHA-256:
  `EB0930E33E825BE057AEFDED7549330562D3095A99C57BE2E66364DC20F42DE7`.
- Verification after backend baseline commands: PASS; added 0, removed 0,
  modified 0, no owner exception.

## Known blockers and exceptions

- `W0-IOS-001` is closed by successful Codemagic build
  `6a5f426f3432213ac398e71a`. This is the pre-rework iOS baseline; later waves
  still require their own post-change iOS verification before final G4B.
- `TC-GAP-001..005` are recorded in the toolchain evidence manifest. In
  particular, moving cloud aliases and the absent Podfile/Podfile.lock require
  a real Codemagic run before iOS sign-off.
- No production source was modified by W0 governance work. Subsequent W3/W4
  writes are separately scoped and must not be back-attributed to W0.

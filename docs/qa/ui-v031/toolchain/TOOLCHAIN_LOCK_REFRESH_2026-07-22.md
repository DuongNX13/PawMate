# Toolchain Lock Refresh — 2026-07-22

Baseline: `ui-v031-20260721-4910aa0e`
Verdict: `PASS_WITH_KNOWN_GAPS`

## Reason and authority

W7 intentionally changed two files that are covered by the W0 source-hash
preflight: the Xcode project for iPhone-only configuration and `codemagic.yaml`
for exact cloud tool versions. W7's allowlist explicitly permits these files and
names the Codex lead as approver. The refresh changes only the two expected
hashes and records the before/after values in `TOOLCHAIN_LOCK.json`; it does not
rewrite unrelated W0 fingerprints or hide an unexpected delta.

| Path | Previous SHA-256 | Approved current SHA-256 |
|---|---|---|
| `mobile/ios/Runner.xcodeproj/project.pbxproj` | `372F2403A70B22DD7BCA2306244F07531084DFF30BA7EB3E4670717F5FCB264B` | `BA5886148237D94D70A4B78B708EA2B14537EA06C86CEFE3F1FF0EAA611FE503` |
| `codemagic.yaml` | `42CA44BCA22C4DC8EED6D09C8A8BD226F1BA3B76B064B07B978155CF2E409C64` | `C9EA8093B62D215E505077990B266FA22594BB846F0E74DB4BD5D35F27568513` |

The lock metadata now records iPhone-only `TARGETED_DEVICE_FAMILY=1` and the
Codemagic selectors Flutter `3.44.7`, Xcode `26.4`, CocoaPods `1.16.2`, and Java
`17`.

## Verification

Command:

`powershell -NoProfile -File scripts/ci/ui-v031/toolchain/verify-toolchain-preflight.ps1`

Result at `2026-07-22T09:05:07+07:00`:

- `PASS_WITH_KNOWN_GAPS`
- all required checks passed
- expected and actual Git HEAD both
  `4910aa0e9b811b05361650c8d3ea193ca70a0b7d`
- approved Flutter launcher remains `D:/flutter/bin/flutter.bat`
- no repository mutation was performed by the verifier

Known gaps remain explicit rather than being converted to PASS: GitHub Actions
still follows Flutter `stable`, the current dirty tree lacks a post-change iOS
cloud run, the iOS dependency-manager gap remains, Gradle lacks a distribution
SHA pin, and generation tools do not expose version identifiers.

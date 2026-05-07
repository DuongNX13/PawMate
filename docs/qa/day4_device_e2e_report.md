# Day 4 Device E2E Report

Snapshot: `2026-05-04`

## Scope

- Review Day 4 review-core closure after real review image upload was added.
- Run available device proof on the current Windows host.
- Identify blockers before continuing Day 5.

## Device Availability

| Target | Status | Evidence |
|---|---|---|
| Android emulator | AVAILABLE | `flutter devices` detected `emulator-5554`, Android 14 API 34 |
| Android demo app | PASS | Debug APK built from `lib/main.dart`, installed, launched, screenshot saved |
| Android integration smoke | PASS | `integration_test/app_smoke_test.dart` passed `1/1` on `emulator-5554` |
| iOS simulator/device | BLOCKED | Current host is Windows and Flutter did not detect any iOS target |

## Evidence

- Android demo screenshot: `temp/evidence/day4_android_demo_app_main.png`
- Android integration command:

```powershell
$env:JAVA_HOME='D:\Java\jdk-17-portable\jdk-17.0.19+10'
flutter test --no-pub integration_test\app_smoke_test.dart -d emulator-5554 -r expanded
```

## Notes

- Android E2E initially failed because Gradle used JDK 8. Fixed without admin by adding portable JDK 17 under `D:\Java\jdk-17-portable`.
- Integration test initially failed because Google Fonts were not bundled as app assets. Fixed by bundling BeVietnamPro and Inter font files under `mobile/assets/fonts`.
- iOS remains an environment blocker, not a Day 4 implementation blocker.

## Day 4 Blocker Decision

- `review image upload`: unblocked and verified.
- `Android device smoke`: unblocked and verified.
- `iOS device smoke`: blocked by host/toolchain availability; move to a Mac/Xcode or real iOS CI lane.
- `sentiment worker` and `moderator queue`: non-blocking for Day 4 MVP review core; track as later moderation/quality lanes.

## OpenClaw Review

- Oracle standing agent reviewed the checkpoint via OpenClaw run `f0806ea9-0595-4c59-9de7-e479bb7cc0f6`.
- Recommendation: Day 4 can be signed off conditionally for MVP review core and Day 5 can proceed.
- Conditions: iOS proof, sentiment worker, moderator queue, and full-list per-item review actions remain deferred items, not completed scope.

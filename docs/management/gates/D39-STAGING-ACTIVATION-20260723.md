# D39 staging activation — 2026-07-23

## Kết quả

`PASS`: Day 39 Rescue browse đã có profile staging versioned và artifact Android
được build bằng chính profile đó.

## Hợp đồng kích hoạt

| Capability | Default/fallback | Day 39 staging | Ghi chú |
|---|---:|---:|---|
| Rescue browse | `false` | `true` | Đủ gate sau Day 39 PASS |
| Rescue create/update | `false` | `false` | Chờ Day 40 PASS |

Profile:
`mobile/config/day39-rescue-browse-staging.json`.

Codemagic workflow `ios-appetize-simulator-smoke`:

1. chạy riêng test hợp đồng bằng profile staging;
2. build iOS simulator bằng cùng profile;
3. không thay đổi workflow real-device/production.

## Kiểm thử cục bộ

| Gate | Command | Kết quả |
|---|---|---|
| Default profile | `flutter test --no-pub test/app/router/app_route_registry_test.dart` | `PASS 48/48`; `false/false` |
| Day 39 staging profile | `flutter test --no-pub --dart-define-from-file=config/day39-rescue-browse-staging.json test/app/router/app_route_registry_test.dart` | `PASS 48/48`; `true/false` |
| Rescue focused | `flutter test --no-pub --dart-define-from-file=config/day39-rescue-browse-staging.json test/features/rescue/rescue_home_screen_test.dart test/features/rescue/rescue_home_live_screen_test.dart` | `PASS 7/7` |
| Analyze | `flutter analyze --no-pub` | `PASS`; 0 issue |
| Android build | `flutter build apk --debug --no-pub --dart-define-from-file=config/day39-rescue-browse-staging.json` | `PASS` |
| Codemagic YAML parse | `python -c "import yaml; ..."` | `PASS` |

Preserved Android artifact:

- path:
  `output-evidence/day39-staging-activation/pawmate-day39-rescue-browse-staging-debug.apk`;
- bytes: `194877079`;
- SHA-256:
  `0255B212ADB224575CAECEBB469EE9078D20FE58BAC305C12B30B0F202CA0192`;
- source/copy hash match: `true`.

Đây là compile/build proof, không claim Android device install/cold-launch hoặc
iOS execution mới. iOS staging workflow đã được cấu hình để dùng profile; lần
chạy hosted tiếp theo sẽ cung cấp runtime artifact riêng.

## Rollback

Build/redeploy không truyền profile staging, hoặc truyền:

```text
PAWMATE_RESCUE_BROWSE_ENABLED=false
PAWMATE_RESCUE_CREATE_ENABLED=false
```

Missing/invalid define tiếp tục fail closed trong
`AppFeatureAvailability.fromEnvironment()`.

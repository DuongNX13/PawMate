# Day 40 — P2-02 Create Lost Alert và P2-03 Lost Info Form

Ngày thực hiện: 2026-07-23
Branch: `feature/day40-rescue-create-20260723`
Baseline: `f67f1a0d77eb64bc1aacd68329fcda78d2cb67f7`

## Scope đã hoàn thành

- Thêm P2-02 `/rescue/create`: upload ảnh/video theo giới hạn contract, tên/loài/giống-màu, khu vực thất lạc, thời gian `hh:mm dd/mm/yyyy`, fixed CTA.
- Thêm P2-03 `/rescue/create/details`: đặc điểm nhận dạng, tính cách/cách gọi, contact preference `in_app|phone_with_consent`, privacy copy và publish CTA.
- Router chỉ render màn thật khi `rescueCreate == true`; mặc định production vẫn `false/false`.
- Draft giữ trong Riverpod memory và được đồng bộ server bằng `POST /rescue/case-drafts`, `PATCH .../:draftId`, publish với idempotency + `expectedVersion`.
- Media dùng ticket → PUT upload → complete; MIME/size contract: JPEG/PNG/WebP ≤10 MiB, MP4 ≤50 MiB, tối đa 5 tệp.
- Exact location chỉ tồn tại trong draft write payload; không đưa sang Rescue Home/public map.

## Verification

| Gate | Command | Kết quả |
|---|---|---|
| Mobile analyze | `flutter analyze` | PASS, 0 issue |
| Day40 provider/widget | `pawmate-flutter.ps1 test test/features/rescue/rescue_create_provider_test.dart test/features/rescue/rescue_create_screen_test.dart` | PASS 7/7 |
| Day40 goldens | `pawmate-flutter.ps1 test --no-pub test/visual/ui_v031_rescue_create_golden_test.dart` | PASS 4/4 |
| Rescue regression | `pawmate-flutter.ps1 test --no-pub test/features/rescue test/app/router/app_feature_availability_day40_test.dart` | PASS 21/21 |
| Feature profile default | same test, no defines | PASS `false/false` |
| Feature profile staging | `--dart-define-from-file=config/day40-rescue-create-staging.json` | PASS `true/true` |
| Backend write contract | `npm test -- --runTestsByPath tests/rescue.write.routes.test.ts tests/rescue.write.service.test.ts` | PASS 37/37 |
| Backend media contract | `npm test -- --runTestsByPath tests/rescue.media.service.test.ts tests/rescue-media-sanitizer.test.ts` | PASS 21/21 |
| Android staging build | `pawmate-flutter.ps1 build apk --debug --no-pub --dart-define-from-file=config/day40-rescue-create-staging.json` | PASS |

APK evidence: `output-evidence/day40/day40-android-build.json` and
`output-evidence/day40/pawmate-day40-rescue-create-staging-debug.apk`
(194,925,619 bytes, SHA-256
`052F4C62959C630FD395C3F964CD6591A1F9D19F0E5728A6FB8BAE2CB33637DE`).

## Exit decision

**PARTIAL.** Day40 implementation and focused gates pass. The repository-wide
mobile run remains non-green only because three pre-existing Day39 live Rescue
goldens compare relative-time text (`1 giờ trước` vs `2 giờ trước`) at 360/390/430;
the Day40 code does not modify `rescue_home_screen.dart` or those goldens. This is
tracked as a baseline/date-determinism note and does not activate production flags.

The protected-path verifier is also blocked by the already-dirty Day 34–38
backend/evidence tree: 38 protected files are added and 12 are modified versus
the W0 baseline. Day40 did not touch those paths; no rebaseline or owner-delta
approval was invented. The ledger itself is protected and needs the existing
G5A owner-delta process before this exit can be upgraded to PASS.

Create activation remains staging-only until product owner accepts the Day40 write
gate. Production/default compile flags are still:

```text
PAWMATE_RESCUE_BROWSE_ENABLED=false
PAWMATE_RESCUE_CREATE_ENABLED=false
```

No iOS hosted compile/render proof was run in this Windows lane; it remains a
separate G4C/platform gate and is not claimed here.

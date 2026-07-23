# Day 39 — P2-01 Rescue Home status

## Kết luận

`PASS`.

Day 39 đã hoàn thiện Rescue Home theo đúng scope entry/list/map preview, dùng
production source `GET /rescue/cases` khi browse flag được bật. Hai compile-time
flag vẫn giữ mặc định fail-closed:

- `PAWMATE_RESCUE_BROWSE_ENABLED=false`;
- `PAWMATE_RESCUE_CREATE_ENABLED=false`.

Việc Day 39 PASS không tự bật staging/production và không mở create/update.

## Phạm vi đã hoàn tất

| Requirement | Kết quả |
|---|---|
| 5 ca gần nhất | Query `sort=recent`, `limit=5`; có pagination bằng opaque cursor và dedupe `caseId` |
| Status | Chip `Chưa thấy` / `Đã thấy`, căn cùng hàng với card |
| Filter | Tất cả, chưa thấy, đã thấy, chó, mèo; đổi filter reset cursor |
| Refresh | Pull-to-refresh; lỗi refresh giữ dữ liệu cũ và hiển thị stale banner |
| Map preview | Bản đồ deterministic, chỉ hiển thị vùng/vòng tròn vị trí ước tính từ public location |
| States | Loading, empty, error/retry, ready, stale, loading-more |
| Navigation | Bottom nav 5 nhánh; detail và full map giữ fail-closed theo Day 41/44 |
| Privacy | Parser allowlist chỉ nhận public fields; không cache/persist dữ liệu Rescue |
| Accessibility | Semantic labels, tap targets, text scale 1.3 tại 360px, không overflow |
| Responsive | Golden live và fail-closed tại 360x844, 390x844, 430x932 |

Copy “quanh bạn” đã được đổi thành “gần đây” vì Day 39 sắp xếp theo thời gian,
không được phép ngụ ý ứng dụng đã dùng vị trí hiện tại của người dùng.

## API và rollout contract

- Production source: `GET /rescue/cases`.
- Request dùng `Cache-Control: no-store`; không có persistent cache.
- Filter hợp lệ: `status`, `species`; sort mặc định `recent`.
- Pagination dùng opaque cursor từ backend, không tự suy diễn cursor.
- Private/exact-location fields không được parse, log hoặc persist.
- Flag off gọi zero Rescue API.
- Flag on nhưng API lỗi hiển thị error/retry; không dùng fixture production.
- `Báo thấy` không xuất hiện trên P2-01.

## Bằng chứng khách quan

| Gate | Kết quả | Evidence |
|---|---|---|
| D39 entry | `32/32 PASS` | `docs/management/gates/D39-ENTRY-20260723-g4b-approved.json` |
| Analyze | `PASS`, 0 issue | `output-evidence/day39/flutter-analyze-20260723.log` |
| Rescue focused | `13/13 PASS` | `output-evidence/day39/flutter-test-rescue-focused-20260723.log` |
| Responsive goldens | `6/6 PASS` | `output-evidence/day39/flutter-test-rescue-goldens-20260723.log` |
| Full mobile | `427 PASS`, `1` intentional skip, `0` fail | `output-evidence/day39/flutter-test-full-20260723.log` |
| Full coverage run | `427 PASS`, `1` intentional skip, `0` fail | `output-evidence/day39/flutter-test-coverage-20260723.log` |
| Rescue line coverage | `503/616 = 81.66%` | `output-evidence/day39/lcov.info` |
| Android debug build | `PASS` | `output-evidence/day39/flutter-build-apk-debug-20260723.log` |
| Dependency inventory | `PASS`, read-only; lockfile không đổi bởi Day 39 | `output-evidence/day39/flutter-pub-outdated-20260723.log` |
| Exit manifest | `11/11 PASS` | `output-evidence/day39/D39-EXIT-20260723.json` |

APK debug được bảo toàn tại
`output-evidence/day39/app-debug-day39.apk`, `167030216` bytes, SHA-256
`BAD9A3BBC7A8C0018521D7C6941BC87F0B1B8E001A1B62BFF1554BE80C1255B8`.

Exit manifest:

- source commit:
  `137c83c33e45dd5c035a47676979423d799f0594`;
- source snapshot SHA-256:
  `1DCA7173601AFC722ADC378E03E87AC65CF949D03025F741ED6A1DDCE38958C2`;
- evidence snapshot SHA-256:
  `B85089C88B360AAD0892DBFEB025576392254A84A510F5B4EF93A20C84B1E7F2`;
- manifest SHA-256:
  `C049533E44E488A7E54EDAB7064C06358E0282FC347715F42DB4C4E81B6961E8`;
- immediate validator: exit `0`, errors `0`, manifest hash ổn định trước/sau
  validation.

## Ngoại lệ và ranh giới

- Một integration test logout cần local backend và seeded mobile E2E account
  vẫn skip có chủ đích; đây là baseline đã biết, không thuộc Rescue Day 39.
- Flutter/Dart hiện không có dedicated vulnerability-audit command trong repo.
  Day 39 không thêm dependency và không sửa `pubspec.lock`; dependency inventory
  đã chạy, nhưng không được diễn giải thành security audit độc lập.
- G4C VoiceOver real-device vẫn `PENDING` và không nằm trong mẫu số G4B.
- P2-02/P2-03 create form thuộc Day 40; case detail thuộc Day 41; full Rescue
  Map thuộc Day 44.

## Chuyển tiếp

Day 39 chuyển `IN PROGRESS -> PASS`. Day 40 đủ dependency để mở nhưng tiếp tục
giữ `NOT STARTED` cho tới khi entry của Day 40 được ghi nhận; không tự bật
Rescue create flag.

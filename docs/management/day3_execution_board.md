# PawMate Day 3 Execution Board

Project root: `D:\My Playground\PawMate`  
Snapshot updated: `2026-04-29`

## Day 3 Goal

- Hoàn tất `Day 3A` theo hướng quality-first:
  - vet list/detail/search chạy bằng backend thật
  - có nearby runtime lane và dữ liệu geo pilot
  - map tab có controller, state machine, marker flow và preview sheet
  - benchmark và matrix test không chỉ dừng ở mức phân tích
- Chưa coi Day 3 release-hardening xong nếu:
  - chưa có physical-device parity pass cho external intents và permission flows

## Source Of Truth

- Replan: `docs/management/phase1_day3_5_replan_2026-04-23.md`
- Quality-first plan: `docs/management/phase1_quality_first_plan_2026-04-23.md`
- Pending-resolution plan: `docs/management/day3_pending_resolution_plan_2026-04-24.md`
- Acceptance criteria: `docs/product/day3_vet_finder_acceptance_criteria.md`
- Contracts: `docs/architecture/day3_vet_finder_contracts.md`
- Seed gốc: `backend/prisma/data/day2_vet_seed_candidates.json`
- Overlay geo pilot: `backend/prisma/data/day3_vet_geo_pilot.json`

## Current Status

| Task | Status | Notes |
|---|---|---|
| `D3-01` AC Vet Finder - Nearby & Filter | DONE | Acceptance criteria covers list/detail/search plus deferred map/runtime boundaries |
| `D3-02` Content Spec - Vet Data Format | DONE | Shared backend/mobile display contract is defined |
| `D3-09` Filter Query Param Schema | DONE | `GET /vets/search` and `GET /vets/nearby` have query validation |
| `D3-10` Vet Detail Response Schema | DONE | Detail response includes `source`, `openHours`, `photoUrls`, and `readyForMap` |
| `D3-11` Directions Deep Link Spec | DONE | Detail screen has call/directions fallback chain |
| `D3-13` API - `GET /vets/search` | DONE | Route and accent-insensitive search are covered by tests |
| `D3-14` API - `GET /vets/:id` | DONE | Detail route renders backend data |
| `D3-15` API - Filter Validation Middleware | DONE | Invalid query values return `400` with field-level errors |
| `D3-16` Flutter - Map Tab | DONE | TomTom tile runtime proof passed on Android emulator with real backend `/vets/nearby`, public markers, radius state, reload, and bottom navigation visible |
| `D3-17` Flutter - Bottom Sheet Preview | DONE | Marker tap opens preview on-device; `Xem chi tiết` opens `/vets/:id` detail for map-ready directory records; directions/call callbacks remain covered by widget tests |
| `D3-18` Flutter - Vet List Tab + Filter Bar | DONE | List/filter/sort/load-more/error/empty are covered by widget tests |
| `D3-19` Flutter - Vet Detail Screen | DONE | Detail screen has Figma-aligned structure and keeps review slot for Day 4 |
| `D3-20` Geo Query 10 Positions | DONE | Runtime matrix covers 10 nearby scenarios with radius/sort/filter assertions |
| `D3-21` Performance 1000+ Vets | DONE (local benchmark) | Synthetic 1000-vet benchmark uses PostGIS GIST index |
| `D3-22` Filter & Map States | DONE | Backend filter/nearby matrix, route tests, mobile map-state tests, and Android emulator map parity proof pass |

## Implemented In This Wave

### Backend

- Giữ `GET /vets/search` và `GET /vets/:id` chạy trên curated seed + overlay.
- Thêm `GET /vets/nearby` với:
  - validation `lat/lng/radius`
  - in-memory fallback cho test
  - PostGIS store thật qua `prisma-vet-nearby-store.ts`
- Thêm schema support cho geo lane:
  - `external_id`
  - `source_rank`
  - `ready_for_map`
- Thêm overlay geo pilot tại `backend/prisma/data/day3_vet_geo_pilot.json`
- Thêm helper dùng chung cho sync/seed:
  - `backend/scripts/lib/day3-vet-geo-utils.mjs`
- Thêm scripts:
  - `seed:vets:validate-geo-pilot`
  - `seed:vets:sync-geo-pilot`
  - `seed:vets:perf`
  - `benchmark:vets:nearby`
  - `test:vets:nearby-matrix`

### Mobile

- Thêm model/contract cho nearby:
  - `VetNearbyRequest`
  - `VetNearbyResult`
  - `distanceMeters`, `latitude`, `longitude` trên `VetSummary`
- Thêm `VetLocationService` dùng `geolocator`
- Thêm `VetMapNotifier` và `VetMapState`
- Thêm `VetGoogleMapCanvas` + canvas builder override cho test
- Thêm `VetPreviewSheet`
- Rebuild `vet_map_screen.dart` thành screen thật với:
  - permission denied state
  - location disabled state
  - empty state
  - error state
  - radius selector
  - map type toggle
  - marker tap -> bottom sheet
  - nearby list fallback dưới map
- Bổ sung Android/iOS location permissions và Android manifest placeholder cho Maps API key

### Tests

- Backend route tests mở rộng tại `backend/tests/vet.routes.test.ts`
- Thêm runtime matrix test:
  - `backend/scripts/day3-vet-nearby-matrix.ts`
- Thêm mobile tests:
  - `mobile/test/features/vets/vet_map_provider_test.dart`
  - `mobile/test/features/vets/vet_map_screen_test.dart`
  - mở rộng `mobile/test/features/vets/vet_screens_test.dart`

## Verified In This Wave

### Backend quality gates

- `npm run build`
- `npm run lint -- --quiet`
- `npm test`
- `npm run test:coverage`
- `npm audit --omit=dev`

### Backend runtime/data proof

- `npm run seed:vets:validate-geo-pilot`
  - `overlayCount=12`
  - `errorCount=0`
  - `warningCount=0` after pilot overlay enrichment
- `npx prisma generate`
- `npm run seed:vets:sync-geo-pilot`
  - `syncedCount=12`
- `npm run seed:vets:perf`
  - `inserted=1000`
- DB count proof:
  - `ready_count=1012`
  - `pilot_count=12`
  - `perf_count=1000`
- `npm run test:vets:nearby-matrix`
  - checked `10` scenarios
  - có case `no-result-small-radius`
  - assert sort theo khoảng cách, item không vượt radius, filter `is24h/minRating`
- `npm run benchmark:vets:nearby`
  - local benchmark sau warm-up:
    - `p50=1.01ms`
    - `p95=1.26ms`
    - `p99=1.34ms`
  - `EXPLAIN ANALYZE` xác nhận dùng `vets_location_gist_idx`
- app inject runtime proof:
  - `GET /vets/nearby?lat=10.7769&lng=106.7009&radius=3000&limit=3` -> `200`

### Mobile quality gates

- `flutter analyze --no-pub`
- `flutter test --no-pub`
- Focused vet tests pass:
  - provider tests
  - map screen tests
  - list/detail tests

## Verification Refresh - 2026-04-28

### Backend

- Started portable PostgreSQL from `D:\My Playground\tools\pgsql` with data dir `D:\My Playground\tools\pgsql-data`.
- Verified local DB `pawmate` is reachable and PostGIS extension exists.
- `npm test -- --runTestsByPath tests/vet.routes.test.ts`
  - `4/4` tests passed.
- `npm run test:vets:nearby-matrix`
  - `10/10` scenarios checked.
  - Includes radius, distance sort, `is24h`, `minRating`, and no-result case.
- `npm run benchmark:vets:nearby`
  - `p50=0.93ms`
  - `p95=1.32ms`
  - `p99=15.34ms` due one cold-ish outlier in `mixed-open-24h`
  - `EXPLAIN ANALYZE` confirms `vets_location_gist_idx` is used.

### Mobile

- Regenerated Flutter native-assets hooks with `flutter pub get --offline` on `P:` subst path.
- `P:\tools\flutter\bin\flutter.bat analyze --no-pub`
  - pass, no issues found.
- `P:\tools\flutter\bin\flutter.bat test --no-pub test\features\vets`
  - `16/16` tests passed.
- `P:\tools\flutter\bin\flutter.bat test --no-pub`
  - `17/17` tests passed.
- Added/confirmed coverage for:
  - permission denied
  - location services disabled
  - empty nearby state
  - API error state
  - radius update
  - map type toggle
  - marker tap to preview sheet
  - preview detail/directions/call callbacks

## Verification Refresh - 2026-04-29

### Backend

- Switched Day 3 map runtime proof from Google Maps key blocker to `flutter_map` + TomTom tiles.
- Patched public nearby store to exclude benchmark-only `perf-*` records from app-facing `/vets/nearby`.
- Added `/vets/:id` fallback for map-ready directory records returned by the nearby store, so a public marker can open detail even when the record is DB-only.
- Enriched all 12 pilot geo records with `services`, `openHours`, `averageRating`, and `reviewCount`, then synced the overlay to local PostgreSQL.
- Added cross-day integration coverage in `backend/tests/phase1.integration.test.ts`.
- Verified runtime API:
  - `GET /vets/nearby?lat=10.7769&lng=106.7009&radius=3000&limit=5` -> `200`, `0` `perf-*` records.
  - `GET /vets/hcm-039` -> `200` with non-empty `services`, `openHours`, `averageRating`, and non-fallback summary after backend restart.
  - `GET /vets/perf-hcm-0244` -> `404`.
- Integration/data checks:
  - `npm run seed:vets:validate-geo-pilot` -> `overlayCount=12`, `errorCount=0`, `warningCount=0`.
  - `npm run seed:vets:sync-geo-pilot` -> `syncedCount=12`.
  - `npm run test:vets:nearby-matrix` -> `10` scenarios checked on public pilot coordinates.
  - `npm test -- --runTestsByPath tests/phase1.integration.test.ts tests/vet.routes.test.ts` -> `6/6` focused tests pass.
- Quality gates:
  - `npm run build` -> pass.
  - `npm test` -> `11/11` suites, `52/52` tests pass.
  - `npm run lint -- --quiet` -> pass.
  - `npm run test:coverage` -> pass, overall statements `83.73%`.
  - `npm audit --omit=dev` -> `0` vulnerabilities.

### Mobile

- Verified Android emulator runtime with TomTom tiles:
  - map tiles render with TomTom attribution.
  - public vet markers render from real backend nearby data.
  - marker tap opens bottom sheet preview.
  - `Xem chi tiết` opens the vet detail screen instead of the earlier 404 state.
- Evidence screenshots:
  - `mobile/build/day3-vet-map-after-backend-fix-later.png`
  - `mobile/build/day3-vet-map-preview-after-backend-fix.png`
  - `mobile/build/day3-vet-map-detail-after-backend-fix-2.png`
- Quality gates:
  - `flutter analyze --no-pub` on `P:` subst path -> pass.
  - `flutter test --no-pub` -> `17/17` tests pass.
  - `flutter build apk --debug --no-pub --dart-define=PAWMATE_MAP_TILES_PROVIDER=tomtom` -> pass.

## Known Gaps

- Running Flutter tests directly under `D:\My Playground` can fail native-assets hook generation because the path contains a space. The current no-admin bypass is to use `P:` subst (`P:\ => D:\My Playground`) for `flutter pub get --offline`, analyze, and tests.
- Manual proof covered Android emulator only. iOS/real device parity is still a later release-hardening lane, not a blocker for Day 3 Android-first sign-off.
- `Chỉ đường` and `Gọi ngay` are covered by widget callback tests; external intent UX should still be rechecked on a physical device before production release.

## Next Critical Path

1. Chạy physical-device QA cho external intents:
   - directions app / browser fallback
   - phone dialer fallback
   - location permission denied/granted
2. Bắt đầu Day 4 sau khi chốt mức chấp nhận Android emulator proof cho Day 3.

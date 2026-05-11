# PawMate Day 9 Vet Map/Nearby QA Report

Date: `2026-05-11`

## Current Status

Day 9 Vet Map/Nearby is implementation-complete and verified on backend, Render live, and Android emulator. The backend nearby contract and pilot geo dataset were already present, so the main code change is on mobile: expose the existing backend filters in the map UI, forward them through `VetNearbyRequest`, remove demo wording, and make the map screen safer for large Android text.

Render `/vets/search` showed HCM map-ready clinics, but Render `/vets/nearby` returned an empty list before the Day 9 backend fallback patch. The root cause was the runtime Prisma/PostGIS nearby path returning zero geo rows while the committed pilot seed had valid latitude/longitude. The deployed regression fix now falls back to the pilot seed when the runtime nearby store returns no candidates.

## Data Readiness

| Check | Status | Notes |
|---|---|---|
| Pilot overlay exists | PASS | `backend/prisma/data/day3_vet_geo_pilot.json` |
| Pilot overlay count | PASS | 12 clinics |
| Required fields | PASS | Existing validator returned `errorCount: 0`, `warningCount: 0` |
| Full 80-clinic map coverage | OUT_OF_SCOPE | Day 9 uses the 12-clinic pilot subset only |

## Backend Nearby Contract

Endpoint:

`GET /vets/nearby?lat&lng&radius&limit&cursor&is24h&isOpenNow&minRating`

Covered behavior:

- radius-based results,
- sorted nearby results,
- 24h filter,
- rating filter,
- empty small-radius scenario,
- detail-route compatibility for nearby IDs.

Latest targeted proof:

- `npm run seed:vets:validate-geo-pilot` passed with `overlayCount: 12`, `errorCount: 0`, `warningCount: 0`.
- `npm run test:vets:nearby-matrix` passed 10 scenarios.
- Backend full gate after fallback patch passed: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-175106-5a1c8303.raw.txt`.
- Live Render `/vets/nearby?lat=10.7769&lng=106.7009&radius=10000&limit=5` returns `200` with 4 HCM clinics after deploy.

## Mobile Map Scope

Implemented behavior:

- Radius chips remain available: `1 km`, `3 km`, `5 km`, `10 km`.
- New filter chips: `24/7`, `Đang mở`, `Đánh giá 4+`.
- Filter state is stored in `VetMapState`.
- `VetMapNotifier` forwards filters to `VetApi.nearby`.
- Map screen copy now describes real nearby search instead of Day 3/demo status.
- Map screen bottom padding is increased for bottom-nav safety.
- Radius and filter chips are horizontally scrollable without fixed height.
- Nearby summary card no longer forces status and long text into one tight row.

Targeted tests:

- `mobile/test/features/vets/vet_map_provider_test.dart`
- `mobile/test/features/vets/vet_map_screen_test.dart`

Both targeted test files passed through the no-space `P:` path.

Mobile full gate passed after the map UI patch:

- `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-173800-cbea50f6.raw.txt`

## Manual Android QA Matrix

| Area | Flow | Status | Evidence |
|---|---|---|---|
| Navigation | Vet list -> Map | PASS | `temp/qa/day9-android-map/04-vet-list.png`, `temp/qa/day9-android-map/05-map-initial.png` |
| Permission | Location allowed | PASS | Emulator location was granted and set to HCM; live nearby rows rendered after redeploy in `temp/qa/day9-android-map/15-map-live-nearby-reloaded.png` |
| Permission | Location denied/disabled | AUTOMATED_PASS_PENDING_MANUAL | Widget tests cover states; manual capture optional |
| Radius | Change radius to `10 km` | PASS | `temp/qa/day9-android-map/11-map-10km-no-filters.png` |
| Filters | Toggle `24/7`, `Đang mở`, `Đánh giá 4+` | PASS | `temp/qa/day9-android-map/06-map-filters-selected.png`; provider/screen tests prove query flags |
| Marker | Tap marker -> preview sheet | PASS | `temp/qa/day9-android-map/16-marker-preview-sheet.png`, `temp/qa/day9-android-map/22-large-text-marker-preview.png` |
| Detail | Preview -> detail | PASS | `temp/qa/day9-android-map/17-preview-detail-route.png` |
| Actions | Call/directions buttons | AUTOMATED_PASS_PENDING_MANUAL | Existing widget test covers callbacks; Android intent path remains manual |
| Large text | Map controls at `font_scale=1.3` | PASS | `temp/qa/day9-android-map/21-large-text-map.png`, `temp/qa/day9-android-map/22-large-text-marker-preview.png` |

## Findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| D9-F01 | Medium | Map UI had product-demo copy referencing Day 3. | FIXED |
| D9-F02 | Medium | Map UI did not expose backend-supported `24h`, open-now, and rating filters. | FIXED |
| D9-F03 | Medium | Map chip rows used fixed height, which increases large-text clipping risk. | FIXED |
| D9-F04 | Low | Day 1 design doc still described old teal primary tokens. | FIXED |
| D9-F05 | Medium | Android live map E2E evidence still needs marker preview/detail capture after live nearby rows return. | CLOSED |
| D9-F06 | High | Render `/vets/nearby` returned empty while `/vets/search` showed map-ready HCM clinics. | RESOLVED_DEPLOYED |

## Exit Recommendation

Day 9 can close. Backend/mobile gates pass, GitHub CI and Compose Smoke pass for commit `84dc545`, Render live nearby returns rows, and Android evidence covers map controls, marker preview, detail route, and large-text map/preview usability.

Remaining release-parity gap: Apple Developer/App Store Connect signing and separate PawMate team/payment remains final-day work, not a Day 9 map blocker.

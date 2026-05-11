# PawMate Day 9 Execution Board

Date: `2026-05-11`

## Scope

Day 9 owns Vet Nearby/Map production readiness. The goal is to ship the map as a real MVP feature backed by the pilot geo dataset, not as a demo shell.

Out of scope for Day 9:

- Apple Developer/App Store Connect signing and separate PawMate team payment. This remains final-day release parity work.
- Expanding all 80 Day 2 vet seed candidates into map-ready clinics. Day 9 uses the validated 12-clinic pilot overlay.
- Adding paid Google Maps. The app keeps the existing `flutter_map` path with TomTom when configured and OSM fallback.

## Task Status

| ID | Task | Status | Evidence |
|---|---|---|---|
| D9-01 | Day 8 closeout and Day 9 board setup | DONE | `docs/management/day9_execution_board.md`, `docs/qa/day9_vet_map_nearby_report.md` |
| D9-02 | Resolve UIX-D8-01 color-token conflict | DONE | `docs/design/day1_design_system.md`, `docs/qa/day8_android_uiux_figma_audit.md` |
| D9-03 | Validate pilot nearby dataset | DONE | `npm run seed:vets:validate-geo-pilot` returned `overlayCount: 12`, `errorCount: 0`, `warningCount: 0` |
| D9-04 | Prove backend nearby radius/filter matrix | DONE | `npm run test:vets:nearby-matrix` checked 10 scenarios including radius, 24h, rating, empty radius |
| D9-05 | Promote mobile map from demo copy to product UI | DONE | `mobile/lib/features/vets/presentation/vet_map_screen.dart` |
| D9-06 | Add map filters to mobile nearby request | DONE | `mobile/lib/features/vets/domain/vet_map_models.dart`, `mobile/lib/features/vets/application/vet_map_provider.dart` |
| D9-07 | Automated mobile map regression tests | DONE | `flutter test --no-pub --no-test-assets test/features/vets/vet_map_provider_test.dart`; `flutter test --no-pub --no-test-assets test/features/vets/vet_map_screen_test.dart` |
| D9-08 | Full backend/mobile quality gates | DONE | Backend gate: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-175106-5a1c8303.raw.txt`; Mobile gate: `C:\Users\duongnx\.codex\output-evidence\codex-rtk-safe-20260511-173800-cbea50f6.raw.txt` |
| D9-09 | Android map E2E evidence | PARTIAL_PASS | Build/install passed; Vet list -> Map, radius/filter controls, tile render, empty state captured under `temp/qa/day9-android-map/` |
| D9-10 | Render live nearby smoke | CODE_FIXED_PENDING_DEPLOY | Pre-fix live Render `/vets/nearby?lat=10.7769&lng=106.7009&radius=10000` returned empty while `/vets/search` showed map-ready HCM clinics |
| D9-11 | Backend fallback when runtime directory has no geo rows | DONE | `backend/src/services/vets/vet-service.ts`, `backend/tests/vet.routes.test.ts`; regression test added |

## Implementation Notes

- The accepted Day 9 data basis is `backend/prisma/data/day3_vet_geo_pilot.json`.
- The pilot overlay has 12 map-ready clinics and is validated through the existing backend script.
- The API contract stays unchanged: `GET /vets/nearby?lat&lng&radius&limit&cursor&is24h&isOpenNow&minRating`.
- Mobile map now forwards `only24h`, `openNow`, and `minRating` into the existing API contract.
- The map screen no longer references Day 3/demo wording. User-facing copy now describes the real nearby search behavior.
- Radius and filter chips use horizontal scrolling without fixed height so large Android text has less clipping risk.
- Bottom content padding on map is increased to match the Day 8 large-text fix pattern for bottom navigation.
- Warm orange `#FF8A5B` is accepted as the PawMate primary token because it matches the current Figma intake page and Flutter app.
- Render exposed a backend edge case: when `DATABASE_URL` is present, `/vets/nearby` used the Prisma/PostGIS nearby store and did not fallback to the committed pilot seed if the runtime directory returned zero geo rows. Day 9 adds a fallback so pilot nearby data still serves while DB geo sync catches up.

## Verification Checklist

- [x] Day 9 board exists.
- [x] Day 9 QA report exists.
- [x] Warm orange token conflict is closed in docs.
- [x] Pilot geo overlay validates with zero errors and warnings.
- [x] Nearby matrix covers radius, 24h, rating, and empty-radius scenarios.
- [x] Mobile provider forwards map filters to API requests.
- [x] Mobile map screen exposes filter chips and removes demo copy.
- [x] Map provider widget tests pass through no-space `P:` drive path.
- [x] Map screen widget tests pass through no-space `P:` drive path.
- [x] Backend full gates pass.
- [x] Mobile full gates pass.
- [x] Android latest APK builds and installs.
- [x] Android manual map E2E captures Vet list -> Map -> radius/filter controls and empty-state behavior.
- [ ] Android manual map E2E captures marker preview -> detail after Render redeploy returns live nearby rows.
- [ ] Render live nearby smoke passes after deploy.

## Risk Register

| Risk | Severity | Status | Mitigation |
|---|---|---|---|
| Full 80-clinic seed is not map-ready | Medium | MITIGATED | Day 9 uses validated 12-clinic pilot overlay only |
| Tile provider key missing or external tiles fail | Low | MITIGATED | Existing map canvas has OSM fallback path |
| Location permission denied on Android | Medium | COVERED | Existing map state and widget tests cover permission denied and location disabled states |
| Large text clips horizontal chips or map summary | Medium | MITIGATED | Chip rows are horizontally scrollable without fixed height; summary card no longer forces a tight row |
| Render `/vets/nearby` returns empty because runtime PostGIS store has no geo rows | High | CODE_FIXED_PENDING_DEPLOY | Service now falls back to committed pilot seed when runtime directory returns zero nearby candidates |
| Apple signing unavailable | Release parity | DEFERRED | Keep as final-day work, not Day 9 map blocker |

## Exit Gate

Day 9 can close when:

- pilot nearby data remains valid,
- `/vets/nearby` passes radius/filter/detail expectations,
- Android map screen shows real product copy and has usable radius/filter controls,
- marker -> preview sheet -> detail flow works,
- no P0/P1 visual or interaction issue remains on the map path,
- backend/mobile quality gates pass,
- Apple signing remains tracked as final-day release parity only.

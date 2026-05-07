# PawMate Day 3 Pending Resolution Plan

Updated: `2026-04-24`

## Current Ground Truth

- `D3-22` is still `PARTIAL`.
- `D3-16`, `D3-17`, `D3-20`, `D3-21` are still deferred or todo because the map lane is not technically ready yet.
- Current mobile app has no real map SDK dependency and no location permission dependency in `mobile/pubspec.yaml`.
- Current map screen is still a placeholder in `mobile/lib/features/vets/presentation/vet_map_screen.dart`.
- Current seed file `backend/prisma/data/day2_vet_seed_candidates.json` contains `80` clinics, but:
  - `0/80` have `latitude` + `longitude`
  - `0/80` have `openHours`
  - `0/80` have `services`
  - `0/80` have `photoUrls`
  - `0/80` are `readyForMap=true`
- Prisma schema already has a `Vet.location` geography field and the repo already contains a PostGIS patch for the GIST index in `backend/prisma/sql/day1_postgis_patch.sql`.

## Key Decision

Do not treat these pending tasks as one problem.

There are actually two separate lanes:

1. `D3-22` can be advanced now, at least partially, without waiting for the real map lane.
2. `D3-16`, `D3-17`, `D3-20`, `D3-21` all depend on a missing geo-enrichment wave and should be re-sequenced behind that prerequisite.

## Task-By-Task Resolution

### D3-22 — Tests: Filter & Map States

#### What is blocked

- Only the map-specific part is blocked.
- The backend filter matrix and Vietnamese search cases are not blocked.

#### What can be closed now

- Add backend tests for:
  - `24h + openNow`
  - `minRating + city`
  - Vietnamese diacritic search
  - empty-result behavior when filter data is missing
- Add mobile widget tests for:
  - empty result state on vet list
  - load error state on vet list
  - placeholder map state copy until real map is live

#### What should stay open

- location permission denied flow on the real map widget
- empty results on real geo query
- marker interaction states

#### Recommended status

- Keep `D3-22` as `PARTIAL`, but split it internally into:
  - `D3-22A` backend + current mobile states
  - `D3-22B` real map states after geo lane is live

### D3-16 — Flutter Map Tab

#### Why it is blocked

- No map SDK is installed in mobile.
- No location plugin is installed in mobile.
- No map-ready dataset exists yet.
- No `/vets/nearby` API exists yet.

#### Correct resolution

1. Add a real map dependency and platform setup.
2. Add location permission and current-position flow.
3. Introduce a `map-ready` data contract that only serves clinics with:
   - valid `lat/lng`
   - enough fields to render a marker and preview
4. Keep the first implementation intentionally narrow:
   - current location
   - markers
   - camera animate
   - map type toggle
   - no clustering in the first slice unless marker count justifies it

#### Recommended implementation order

1. `google_maps_flutter`
2. `geolocator`
3. map screen with current location + markers from fake geo-ready subset
4. wire to real `/vets/nearby` only after backend exists

### D3-17 — Flutter Bottom Sheet Preview

#### Why it should not wait completely

- It depends on the map lane for the final hook-up.
- But the preview UI itself does not need real geo or map rendering to be built.

#### Correct resolution

- Build the bottom sheet as an isolated reusable widget first:
  - input: `VetSummary`
  - output actions:
    - `Xem chi tiết`
    - `Gọi ngay`
- Test the sheet independently.
- Later, map marker tap only needs to open this ready-made sheet.

#### Recommendation

- Re-scope `D3-17` into:
  - UI component now
  - marker integration later

### D3-20 — Geo Query 10 Positions

#### Why it is fully blocked

- There is no `/vets/nearby` route yet.
- There are no coordinates in the seed file.
- There is no truthful distance computation to verify.

#### Correct resolution

1. Create a geo-enrichment wave for a small verified subset first.
2. Do not wait for all `80` clinics.
3. Build a `pilot set` of `10-20` clinics with:
   - verified `lat/lng`
   - basic `openHours`
   - basic `services`
   - `readyForMap=true`
4. Implement `/vets/nearby` against PostGIS using `ST_DWithin`.
5. Only then write the `10 positions` test matrix.

#### Recommended pilot coverage

- HCM: `4`
- Hà Nội: `4`
- Đà Nẵng: `1`
- no-result edge case: `1`

That is enough to verify:

- radius filter
- distance sorting
- no-result state
- city spread

### D3-21 — Performance 1000+ Vets

#### Why it is not honest to do now

- The current live search service is still a curated JSON service, not the final scalable geo query path.
- Performance on the JSON foundation says nothing useful about the future nearby query.

#### Correct resolution

1. Move the source of truth for nearby from JSON to PostgreSQL/PostGIS.
2. Apply the existing GIST index patch on `vets.location`.
3. Create an import script from enriched JSON to DB.
4. Seed an extra synthetic dataset around city centroids.
5. Benchmark the real `ST_DWithin` query path with `EXPLAIN ANALYZE`.

#### Recommendation

- Keep `D3-21` deferred until the nearby backend is real.
- Do not burn time benchmarking the current JSON layer.

## Recommended Sequence

### Phase A — Close what is closeable now

- Finish `D3-22A`
- Keep map-state tests out of scope until the real map lane exists

### Phase B — Build geo-enrichment foundation

- Create one new script or workflow to enrich a pilot subset of clinics with:
  - coordinates
  - open hours
  - service tags
  - `readyForMap`

### Phase C — Open backend nearby lane

- Implement `GET /vets/nearby`
- Use PostGIS `ST_DWithin`
- Return `distance`, `isOpen`, and `readyForMap`

### Phase D — Open mobile map lane

- Add map SDK
- Add location permission flow
- Render map markers from the pilot subset
- Hook the reusable bottom sheet to marker tap

### Phase E — Only then run geo and perf tests

- `D3-20`
- `D3-21`
- `D3-22B`

## Recommended Replan

If the team wants truthful execution instead of optimistic status inflation, the defensible replan is:

- `D3-22`:
  - continue now on backend/current-mobile states
- `D3-16` and `D3-17`:
  - move behind pilot geo enrichment
- `D3-20` and `D3-21`:
  - move behind real `/vets/nearby` and PostGIS-backed data

## External References

- Google Maps Flutter package: <https://pub.dev/packages/google_maps_flutter>
- Geolocator package: <https://pub.dev/packages/geolocator>
- PostGIS `ST_DWithin`: <https://postgis.net/docs/ST_DWithin.html>

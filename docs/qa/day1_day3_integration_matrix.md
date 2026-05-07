# PawMate Day 1-3 Integration Matrix

Snapshot: `2026-04-29`

## Objective

Verify that the completed Day 1, Day 2, and Day 3 work links together through executable checks, not only isolated unit/widget tests.

## Optimal Block Resolution

The remaining Day 3 blocker was not the map tile provider anymore. `D3-16`, `D3-17`, and `D3-22` had already passed Android emulator proof with TomTom tiles. The real residual quality gap was data completeness: the Day 3 pilot geo overlay still had map-ready clinics without `services`, `openHours`, and ratings, which made preview/detail UX fall back to generic copy.

Chosen resolution:

- Keep TomTom as the MVP map runtime path because it avoids Google billing/admin blockers.
- Enrich all 12 Day 3 pilot geo records with `services`, `openHours`, `averageRating`, and `reviewCount`.
- Keep `perf-*` benchmark records out of public `/vets/nearby` responses.
- Re-point the nearby matrix to real pilot coordinates instead of relying on synthetic benchmark density.
- Add one cross-day route integration test that exercises health, auth, pets, vet search, nearby, detail, and MVP-disabled OAuth in the same app instance.

## Executable Coverage

| Coverage Area | Day | Test / Command | What It Proves | Result |
|---|---:|---|---|---|
| Backend app boots and health route works | Day 1 | `backend/tests/phase1.integration.test.ts` -> `GET /health` | Day 1 Fastify app shell still serves baseline runtime health | PASS |
| Auth email flow | Day 2 | `backend/tests/phase1.integration.test.ts` -> register, login-before-verify, verify-email, login | Email verification gate still blocks login until verification and then unlocks login | PASS |
| MVP social login deferral | Day 2 | `backend/tests/phase1.integration.test.ts` -> `POST /auth/oauth` | Google/Apple sign-in remains intentionally disabled in MVP config | PASS |
| Pet profile protected flow | Day 2 | `backend/tests/phase1.integration.test.ts` -> create/list/delete pet with bearer token | Auth token and pet ownership route wiring work together | PASS |
| Vet search from curated seed | Day 3 | `backend/tests/phase1.integration.test.ts` -> `GET /vets/search` | Day 2 seed + Day 3 overlay merge still supports user-facing vet search | PASS |
| Nearby map contract | Day 3 | `backend/tests/phase1.integration.test.ts` -> `GET /vets/nearby` | Map-ready vet is returned with non-empty services and no `perf-*` records | PASS |
| Marker detail compatibility | Day 3 | `backend/tests/phase1.integration.test.ts` -> `GET /vets/:id` from nearby result | Every public marker id used in the scenario can open detail | PASS |
| 10-position geo matrix | Day 3 | `npm run test:vets:nearby-matrix` | Radius, sorting, 24h, rating, empty-result, and city coverage work on public pilot data | PASS |
| Pilot overlay quality | Day 3 | `npm run seed:vets:validate-geo-pilot` | All 12 pilot records are valid and no longer have services/openHours warnings | PASS |
| Existing backend regression suite | Day 1-3 | `npm test` | Existing auth, pet, infrastructure, and vet route tests remain green after integration patch | PASS |
| Mobile widget/app shell regression | Day 2-3 | `flutter analyze --no-pub`, `flutter test --no-pub`, debug APK build | Flutter app remains analyzable, tested, and buildable after backend/data hardening | PASS |

## Latest Verified Commands

```powershell
npm run seed:vets:validate-geo-pilot
npm run seed:vets:sync-geo-pilot
npm run test:vets:nearby-matrix
npm test -- --runTestsByPath tests/phase1.integration.test.ts tests/vet.routes.test.ts
npm run build
npm run lint -- --quiet
npm test
npm run test:coverage
npm audit --omit=dev
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub --dart-define=PAWMATE_MAP_TILES_PROVIDER=tomtom
```

## Verified Results

- `seed:vets:validate-geo-pilot`: `overlayCount=12`, `errorCount=0`, `warningCount=0`.
- `seed:vets:sync-geo-pilot`: `syncedCount=12`.
- `test:vets:nearby-matrix`: `10` scenarios checked.
- `phase1.integration.test.ts` + `vet.routes.test.ts`: `6/6` focused tests passed.
- Full backend `npm test`: `11/11` suites, `52/52` tests passed.
- Backend coverage: overall statements `83.73%`.
- Backend audit: `0` vulnerabilities.
- Mobile tests: `17/17` tests passed.
- Runtime API after backend restart:
  - `GET /vets/hcm-039` returns `services`, `openHours`, `averageRating`, and non-fallback summary.

## Remaining Non-Automated Checks

- Physical-device test for `Chỉ đường` external intent.
- Physical-device test for `Gọi ngay` dialer intent.
- Final manual visual comparison against Stitch/Figma for Day 2 UI screens.

These are release-hardening checks, not current Day 3 implementation blockers.

# PawMate Day 10 RC Gate Report

Date: `2026-05-13`

## Summary

Day 10 RC gate has passed local backend/mobile gates, Render API smoke, and Android emulator smoke after one Day 10 map fix. The remaining required external check is GitHub `CI` and `Compose Smoke` on the pushed candidate commit.

Recommendation before GitHub verification: `GO_WITH_KNOWN_ISSUES`.

## Candidate Scope

- Target: internal Android/Render RC candidate.
- Backend: Render API base `https://pawmate-api-yteu.onrender.com`.
- Mobile gate path: `P:\mobile`.
- Appetize: skipped to save quota.
- Apple signing: final-day external dependency, not a Day 10 blocker.

## Local Backend Gates

| Command | Result |
|---|---|
| `npm run prisma:validate` | PASS, Prisma schema valid |
| `npm run lint` | PASS |
| `npm run build` | PASS |
| `npm test` | PASS, 15 suites / 70 tests |

## Local Mobile Gates

| Command | Result |
|---|---|
| `flutter analyze --no-pub` | PASS, no issues found |
| `flutter test --no-pub --no-test-assets -r expanded` | PASS, 44 tests |
| `flutter build apk --debug --no-pub --dart-define=PAWMATE_API_BASE_URL=https://pawmate-api-yteu.onrender.com` | PASS, built `P:\mobile\build\app\outputs\flutter-apk\app-debug.apk` |

## Render API Smoke

| Probe | Result |
|---|---|
| `GET /health` | PASS `200`, `{"status":"ok"}` |
| `GET /vets/search?limit=1` | PASS `200`, returns real vet `hn-001` / `Bệnh viện thú cưng Longkhanhpets.com` |
| `GET /vets/nearby?lat=10.7769&lng=106.7009&radius=10000&limit=5` | PASS `200`, returns nearby clinics |
| `POST /auth/login` with verified QA account | PASS `200`, access and refresh tokens returned; secrets not logged |

## Android RC Smoke

Evidence folder: `temp/qa/day10_android_rc/`.

| Flow | Result | Evidence |
|---|---|---|
| Verified QA login | PASS | `01-after-qa-login.png` |
| Pets list | PASS | `07-pets-list-with-data.png` |
| Pet detail | PASS | `08-pet-detail.png` |
| Pet create route | PASS | `06-pet-create.png` |
| Vet list | PASS | `02-vets-list.png` |
| Vet detail | PASS | `03-vet-detail.png`, `18-vet-detail-from-map.png` |
| Vet map | PASS_AFTER_FIX | `16-vet-map-after-fallback-fix.png` |
| Vet map preview | PASS | `17-vet-map-preview.png` |
| Vet review sheet | PASS | `19-vet-review-sheet.png` |
| Health timeline/add-event data | PASS | `09-health.png` |
| Reminder list/create data | PASS | `10-reminders.png` |
| Notifications list/read | PASS | `11-notifications.png` |

## Day 10 Fix

During Android smoke, `/vets/map` reproduced an ANR after location grant/reload. Evidence:

- Before fix: `14-vet-map-hanoi-reload.png` shows Android `pawmate_mobile isn't responding`.
- Log: `temp/qa/day10_android_rc/vet-map-anr-logcat.txt`.

Fix:

- `mobile/lib/features/vets/application/vet_map_provider.dart` now wraps location lookup with an app-level timeout.
- If emulator/device location lookup times out or returns unknown, the map falls back to Hanoi center instead of staying in loading forever.
- Permission denied and service disabled still surface explicit state cards.

Post-fix proof:

- `flutter analyze --no-pub`: PASS.
- `flutter test --no-pub --no-test-assets -r expanded`: PASS, 44 tests.
- `/vets/map` renders OSM tiles and marker: `16-vet-map-after-fallback-fix.png`.
- Marker preview opens: `17-vet-map-preview.png`.

## GitHub Verification

Pending candidate push:

- `CI`: pending.
- `Compose Smoke`: pending.

This section must be updated after the candidate commit reaches GitHub and Actions complete.

## Known Issues

| Issue | Severity | Decision |
|---|---|---|
| Apple Developer/App Store Connect signing not ready | External release parity dependency | Move to final day |
| Appetize deep login not rerun on Day 10 | P2 / optional parity | Save quota; use Appetize only when final iOS parity is needed |
| Map uses Hanoi fallback if live location lookup times out | P2 handled behavior | Accept for RC; broaden real-device location QA later |
| Some map seed vet details may have limited recent-review data | P2 backlog | Not blocking; list/detail/map/review sheet still open |

## Recommendation

`GO_WITH_KNOWN_ISSUES` for internal Android/Render RC after GitHub `CI` and `Compose Smoke` pass on the candidate commit.

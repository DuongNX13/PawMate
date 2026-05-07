# PawMate Day 4 Execution Board

Project root: `D:\My Playground\PawMate`  
Snapshot updated: `2026-05-04`

## Day 4 Goal

- Gan review core vao vet detail backend contract.
- Enforce duplicate-review rule: 1 user chi duoc review 1 vet 1 lan.
- Co helpful/report flow va rating aggregate co test, khong chi dung spec.

## Current Status

| Task | Status | Notes |
|---|---|---|
| `D4-01` AC Review - Core Rules | DONE (backend enforceable) | Rating 1-5, optional text min 10 chars, max 3 photo URL refs, duplicate review returns `409 REVIEW_001` |
| `D4-02` AC Verified Badge & Report | PARTIAL | `isVerifiedVisit` flag and report auto-hide foundation exist; moderator approve/reject UI/queue remains later |
| `D4-07` DB - Review Uniqueness Constraint | DONE | Prisma schema uses `@@unique([userId, vetId])`; SQL patch adds `reviews_user_id_vet_id_uidx` |
| `D4-08` DB - Rating Aggregate Design | DONE | Aggregate rule counts visible reviews and stores `average_rating`, `review_count` |
| `D4-10` DB - Report Queue Schema | DONE | `review_reports` schema added with reason/status and one reporter per review constraint |
| `D4-11` API - `POST /vets/:id/reviews` | DONE | Endpoint creates review and returns public review object; review photo URLs can now come from the authenticated binary upload endpoint |
| `D4-12` API - `PUT /reviews/:id/helpful` | DONE | Toggle helpful vote with one vote per user/review |
| `D4-13` API - `POST /reviews/:id/report` | DONE | Report count increments; 5th unique report hides review |
| `D4-14` DB - Rating Aggregate Trigger | DONE | `day4_review_core_patch.sql` creates `reviews_rating_aggregate_trigger` |
| `D4-16` Flutter - Review List + Rating Chart | DONE (MVP) | Vet detail reads `GET /vets/:vetId/reviews`, displays latest review/empty/error/loading state, renders rating distribution, and opens a cursor-based review list sheet with load-more |
| `D4-17` Flutter - Write Review Form | DONE | Bottom-sheet form validates rating/body, can select up to 3 photos, uploads selected binaries before submit, refreshes vet/review providers, and keeps duplicate-review errors visible |
| `D4-18` Flutter - Report Dialog & Helpful Action | DONE (latest card) | Latest review card can toggle helpful and submit report with auth token; actions for a future full review list will reuse the same API methods |
| `D4-19` Test - Duplicate Review | DONE | Route test covers unauthorized, invalid, duplicate, second user allowed, and concurrent duplicate attempt |
| `D4-20` Test - Rating Aggregate | DONE (route/store level) | Summary distribution and hidden-review aggregate behavior covered |
| `D4-21` Test - Photo Upload in Review | DONE | Backend route test covers auth, invalid content type, binary upload, local asset URL, and attaching returned URL to review; Supabase live smoke uploaded to `review-photos` and cleaned up |
| `D4-22` Test - Sentiment Flag & Report Flow | PARTIAL | Sentiment defaults to `UNPROCESSED`; report threshold auto-hide covered; GPT/sentiment async lane remains pending |

## Implemented In This Wave

- Added review service contract and in-memory store for test/runtime fallback:
  - `backend/src/services/reviews/review-service.ts`
- Added Prisma-backed persistence adapter:
  - `backend/src/repositories/prisma-review-store.ts`
- Wired review service into app and vet routes:
  - `backend/src/app.ts`
  - `backend/src/routes/vets.ts`
- Updated Prisma schema and additive SQL patch:
  - `backend/prisma/schema.prisma`
  - `backend/prisma/sql/day4_review_core_patch.sql`
- Added tests:
  - `backend/tests/review.routes.test.ts`
  - `backend/tests/prisma-review-store.test.ts`
- Added mobile read/action path for review summary/latest review:
  - `mobile/lib/features/vets/domain/vet_models.dart`
  - `mobile/lib/features/vets/data/vet_api.dart`
  - `mobile/lib/features/vets/application/vet_providers.dart`
  - `mobile/lib/features/vets/presentation/vet_detail_screen.dart`
  - `mobile/test/features/vets/vet_screens_test.dart`
- Added review image upload path:
  - `backend/src/infrastructure/review-photo-storage.ts`
  - `backend/scripts/supabase-bootstrap.cjs`
  - `mobile/assets/fonts/`
  - `mobile/integration_test/app_smoke_test.dart`

## API Surface

- `GET /vets/:vetId/reviews`
- `POST /vets/:vetId/reviews`
- `POST /vets/:vetId/reviews/photos`
- `PUT /reviews/:reviewId/helpful`
- `POST /reviews/:reviewId/report`
- `GET /assets/review-photos/:vetId/:userId/:fileName` for local fallback assets

## Verified Commands

```powershell
npm run prisma:validate
npm run build
npm run lint -- --quiet
npm test -- --runTestsByPath tests/prisma-review-store.test.ts tests/review.routes.test.ts
npm test
npm run test:coverage
npm audit --omit=dev
flutter analyze --no-pub
flutter test --no-pub test
flutter test --no-pub integration_test\app_smoke_test.dart -d emulator-5554 -r expanded
flutter build apk --debug --no-pub -t lib\main.dart
npm run supabase:bootstrap
```

## Verified Results

- Prisma schema: valid.
- Focused review tests: `2/2` suites, `10/10` tests passed.
- Full backend regression: `13/13` suites, `61/61` tests passed.
- Backend coverage: statements `84.02%`, lines `83.85%`.
- Security audit: `0` vulnerabilities.
- Local DB patch applied successfully through `psql`.
- Supabase storage bootstrap: `review-photos` bucket created.
- Supabase live smoke: uploaded 68-byte PNG to `review-photos`, then removed it.
- Mobile analyze: no issues.
- Mobile tests: `22/22` tests passed.
- Android emulator E2E smoke: `1/1` test passed on `emulator-5554`.
- Android demo APK: built, installed, launched, and screenshot saved at `temp/evidence/day4_android_demo_app_main.png`.

## Remaining Day 4 Critical Path

1. Decide whether Day 4 sentiment stays deferred as `UNPROCESSED` or opens a separate async worker lane.
2. Define moderator queue approve/reject scope if report moderation must go beyond auto-hide threshold.
3. Run iOS physical-device demo when a Mac/Xcode or supported iOS runner is available.

## Known Gaps

- iOS demo/E2E was not executed on this Windows host; Flutter sees Android emulator, Windows, Chrome, and Edge only.
- Sentiment analysis is explicitly non-blocking and still defaults to `UNPROCESSED`.
- Moderator queue UI/actions are not implemented yet.
- Current mobile app supports submit/helpful/report on the vet detail latest-review card and cursor pagination in the review list sheet; per-item helpful/report actions inside the full list are not implemented yet.

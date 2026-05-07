# Day 4 Review Core Test Matrix

Snapshot: `2026-05-04`

## Scope

This matrix maps Day 4 review-core behavior to executable tests. It covers backend routes, persistence adapter behavior, and remaining gaps before Day 4 sign-off.

## Coverage Matrix

| Behavior | Test / Command | Coverage Type | Result |
|---|---|---|---|
| Auth required to submit a review | `backend/tests/review.routes.test.ts` | Negative route test | PASS |
| Rating must be integer 1-5 | `backend/tests/review.routes.test.ts` | Negative route test | PASS |
| Optional body must be at least 10 chars if present | `backend/tests/review.routes.test.ts` | Negative route test | PASS |
| One user cannot review same vet twice | `backend/tests/review.routes.test.ts` | Regression/negative route test | PASS |
| Different users can review same vet | `backend/tests/review.routes.test.ts` | Happy path route test | PASS |
| Concurrent duplicate submissions keep only one review | `backend/tests/review.routes.test.ts` | Race-condition regression test | PASS |
| Review list returns rating summary and distribution | `backend/tests/review.routes.test.ts` | Integration route test | PASS |
| Helpful vote toggles on/off | `backend/tests/review.routes.test.ts` | State-transition route test | PASS |
| Duplicate report from same user is rejected | `backend/tests/review.routes.test.ts` | Negative route test | PASS |
| Five unique reports hide a review | `backend/tests/review.routes.test.ts` | Moderation-lite route test | PASS |
| Hidden review drops out of aggregate/list | `backend/tests/review.routes.test.ts` | Regression route test | PASS |
| Auth required to upload a review photo | `backend/tests/review.routes.test.ts` | Negative route test | PASS |
| Review photo upload rejects unsupported MIME type | `backend/tests/review.routes.test.ts` | Negative route test | PASS |
| Review photo binary upload returns a public asset URL | `backend/tests/review.routes.test.ts` | Happy path route test | PASS |
| Uploaded review photo URL can be attached to a created review | `backend/tests/review.routes.test.ts` | Integration route test | PASS |
| Supabase `review-photos` bucket exists and accepts upload | `npm run supabase:bootstrap` plus live smoke upload/cleanup | Live storage smoke | PASS |
| Prisma create path refreshes vet aggregate | `backend/tests/prisma-review-store.test.ts` | Persistence adapter unit test | PASS |
| Prisma unique violation maps to `REVIEW_001` | `backend/tests/prisma-review-store.test.ts` | Persistence adapter negative test | PASS |
| Prisma list path returns summary/distribution/cursor | `backend/tests/prisma-review-store.test.ts` | Persistence adapter unit test | PASS |
| Prisma helpful and report paths update counters | `backend/tests/prisma-review-store.test.ts` | Persistence adapter unit test | PASS |
| Mobile vet detail consumes review list API | `mobile/test/features/vets/vet_screens_test.dart` | Widget regression test | PASS |
| Mobile review models parse summary/latest review | `mobile/test/features/vets/vet_screens_test.dart` via fake API fixture | Widget/model integration test | PASS |
| Mobile write-review form requires rating before submit | `mobile/test/features/vets/vet_screens_test.dart` | Widget validation test | PASS |
| Mobile write-review form sends auth token and review payload | `mobile/test/features/vets/vet_screens_test.dart` | Widget/API contract test | PASS |
| Mobile review photo upload payload/result contract serializes correctly | `mobile/test/features/vets/vet_screens_test.dart` | Model/API contract test | PASS |
| Mobile duplicate-review error keeps submit sheet open | `mobile/test/features/vets/vet_screens_test.dart` | Regression/negative widget test | PASS |
| Mobile helpful action sends review id and auth token | `mobile/test/features/vets/vet_screens_test.dart` | Widget/API contract test | PASS |
| Mobile report dialog sends reason, description, and auth token | `mobile/test/features/vets/vet_screens_test.dart` | Widget/API contract test | PASS |
| Mobile rating chart and review list sheet load next cursor page | `mobile/test/features/vets/vet_screens_test.dart` | Widget pagination regression test | PASS |
| Android app boots on emulator with bundled production fonts | `flutter test --no-pub integration_test\app_smoke_test.dart -d emulator-5554 -r expanded` | Device E2E smoke | PASS |
| Android debug APK builds, installs, and launches | `flutter build apk --debug --no-pub -t lib\main.dart` plus `adb install`/`monkey` | Device demo smoke | PASS |

## Quality Gates

```powershell
npm run prisma:validate
npm run build
npm run lint -- --quiet
npm test
npm run test:coverage
npm audit --omit=dev
flutter analyze --no-pub
flutter test --no-pub test
flutter test --no-pub integration_test\app_smoke_test.dart -d emulator-5554 -r expanded
flutter build apk --debug --no-pub -t lib\main.dart
npm run supabase:bootstrap
```

Latest result:

- Build: PASS.
- Lint: PASS.
- Tests: `13/13` suites, `61/61` tests PASS.
- Coverage: statements `84.02%`, lines `83.85%`.
- Audit: `0` vulnerabilities.
- Mobile analyze: PASS.
- Mobile tests: `22/22` PASS.
- Android device E2E smoke: `1/1` PASS on `emulator-5554`.
- Android demo screenshot: `temp/evidence/day4_android_demo_app_main.png`.
- Supabase live storage smoke: PASS, temporary object removed.

## Gaps Before Full Day 4 Sign-Off

- Mobile public review read path plus latest-card submit/helpful/report actions are implemented and covered by widget tests.
- MVP rating chart and cursor-based review list sheet are implemented and covered by widget tests.
- Per-item helpful/report actions inside the full review list are still pending.
- Real image upload is implemented and covered at route/local-fallback/live-Supabase smoke level.
- Sentiment analysis worker is pending; current review sentiment is stored as `UNPROCESSED`.
- Moderator approve/reject flow is pending.
- iOS physical-device proof is pending because the current Windows host cannot build/run iOS and Flutter does not detect an iOS target.

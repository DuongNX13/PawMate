
# PawMate Execution Ledger v1.1

## Mục đích

Ledger này ngăn việc một nhãn Day bị dùng cho nhiều scope. Mỗi Day chỉ được đổi trạng thái khi evidence và Definition of Done đã được kiểm tra.

## Trạng thái hiện tại

| Planned slice | Scope gốc | Scope thực tế đã làm | Status | Evidence chính | Khoản còn thiếu | Quyết định |
|---|---|---|---|---|---|---|
| Day 1 | Source lock/audit | QA/infra baseline; phần source lock còn thiếu đã được đóng tại Day 6 | PASS (CLOSED BY DAY 6) | `docs/qa/day1_evidence_matrix.md`, [source lock](../engineering/pawmate_source_lock_v1.md), [worktree audit](../engineering/pawmate_dirty_worktree_audit_v1.md), [repo inventory](../engineering/pawmate_repo_inventory_v1.md) | Figma live metadata được tách sang visual gate Day 9 | Đóng; không mở lại nếu nguồn SRS/roadmap không đổi |
| Day 2 | Phase 1 reuse audit | Đúng scope | PASS WITH NOTES | [Reuse audit](../engineering/phase1_reuse_audit.md), [test impact](../engineering/phase1_test_impact.md), [blockers](../engineering/day2_blockers.md) | Cập nhật nếu Day 6 phát hiện source mới | Giữ kết quả |
| Day 3 | Contract/navigation/state | Route/API/test docs được hợp nhất thành API/data contract Day 7 và navigation/state/permission/traceability contract Day 8 | PASS (CLOSED BY DAY 7-8) | [Route/API](../engineering/day3_route_api_test_contract.md), [API contract](../architecture/pawmate_api_contract_v1.md), [Day 8 contract](../architecture/pawmate_state_navigation_permission_v1.md), [Day 8 status](../engineering/day8_navigation_state_permission_status.md) | Không còn nợ contract; implementation drift có owner/Day cụ thể | Đóng; thay đổi phải đi qua change control và validator G1 |
| Day 4 | Design system/app shell | Foundation + nhiều feature Phase 1 được sửa sớm | PARTIAL | [Phase 1 regression status](../engineering/day4_phase1_regression_status.md), Flutter tests | Token/primitive/golden diff, `/community`, visual fidelity | Đóng ở Day 9-12 |
| Day 5A | Auth/Onboarding P1-01..P1-04 | Đã thực hiện một phần trong Day 4 | PARTIAL | Auth tests, runtime screenshots | OTP resend/expiry, real secure-storage adapter, Figma diff | Đóng ở Day 13-16 |
| Day 5B deviation | Không thuộc scope gốc | Phase 2 Rescue/Adoption artifact đã được nâng thành implementation contract tại Day 7 | CONTRACT LOCKED; IMPLEMENTATION NOT STARTED | [Day 5 artifact](../engineering/day5_phase2_rescue_adoption_contract.md), [route/data contract](../engineering/phase2_route_data_contract.json), [API contract](../architecture/pawmate_api_contract_v1.md), contract tests | Schema, migration, service, route và persistence | Production implementation bắt đầu Day 34+ |

## UI baseline change-control ngày 20-07-2026

- Baseline thiết kế mới: [v0.29/v0.30 Chocomint Compact](../design/pawmate-devmode-v029-v030-chocomint-compact-status.md). v0.27/v0.28 được giữ nguyên làm lịch sử/rollback reference.
- Historical `PASS` không bị ghi đè. Phạm vi mới được quản lý bằng [impact report Day 1-34](pawmate_v029_chocomint_ui_rework_impact_2026-07-20.md).
- `MUST REWORK`: Day `9, 10, 13, 14, 18, 19, 23, 24, 27, 28`.
- `MUST REVALIDATE`: Day `6, 11, 12, 15, 16, 20, 21, 25, 26, 29, 30, 31, 32, 33`.
- `UNAFFECTED`: Day `1, 2, 3, 4, 5, 7, 8, 17, 22, 34`.
- Tại thời điểm lập change-control, Day 34 là row `IN PROGRESS` duy nhất vì đây là backend persistence/migration. Không mở Day 39 UI trước khi addendum visual Day 33/G4 được ký trên implementation Chocomint mới.
- `UI-CC-2026-07-20` đã hoàn tất ngày 21-07-2026: [wave gate report](../qa/ui-rework-2026-07-20/ui_rework_wave_gate_report.md), [evidence manifest](../qa/ui-rework-2026-07-20/ui_rework_evidence_manifest.md), [responsive review](../qa/ui-rework-2026-07-20/responsive_visual_review.md) và [Day 33/G4 addendum](../engineering/day33_ui_rework_g4_addendum_2026-07-20.md) đều `PASS`; P0/P1 UI = `0/0`.
- Addendum chỉ ký baseline UI mới; Day 34 vẫn phải đạt migration/repository/cloud gate trước Day 35. Điều kiện này đã PASS ngày 21-07-2026 và được phản ánh tại row Day 34 bên dưới.

## Baseline test evidence ngày 13-07-2026

| Gate | Kết quả | Evidence |
|---|---|---|
| Flutter analyze | PASS | [Day 9 log](../../temp/proof/day9_20260713/mobile_analyze.log) |
| Flutter tests | PASS - 90 tests | [Day 9 log](../../temp/proof/day9_20260713/mobile_full_test.log) |
| Backend tests | PASS - 16 suites / 79 tests | [Day 8 log](../../temp/proof/day8_20260713/backend_full_test.log) |
| Backend build | PASS | [Log](../../temp/proof/review_20260713_backend_build.log) |
| Backend lint | PASS | [Log](../../temp/proof/review_20260713_backend_lint.log) |

Test xanh không đồng nghĩa với visual fidelity hoặc Phase 2 implementation đã hoàn thành.

## Future execution ledger

| Day | Scope cố định | Gate | Status | Evidence/notes |
|---:|---|---|---|---|
| 6 | Rebaseline, source lock và worktree classification | G0 | PASS | [Source lock](../engineering/pawmate_source_lock_v1.md), [worktree audit](../engineering/pawmate_dirty_worktree_audit_v1.md), [repo inventory](../engineering/pawmate_repo_inventory_v1.md). Manifest phân loại đủ 33.892/33.892 entry; chưa sửa code feature. Figma live metadata chuyển sang Day 9 do plugin chưa kết nối. |
| 7 | API/data contract lock | - | PASS | [Status](../engineering/day7_api_data_contract_status.md), [API contract](../architecture/pawmate_api_contract_v1.md), [machine contract](../architecture/pawmate_api_contract_v1.json), [compatibility report](../architecture/pawmate_api_contract_change_report_v1.md). Contract QA 11/11; backend 16 suites/79 tests, build/lint pass; production dependency audit 0 vulnerability. Không sửa production feature/schema. |
| 8 | Navigation, state, permission và traceability lock | G1 | PASS | [Status](../engineering/day8_navigation_state_permission_status.md), [contract](../architecture/pawmate_state_navigation_permission_v1.md), [Impact traceability](../qa/pawmate_traceability_matrix_v1.csv), [screen-state traceability](../qa/pawmate_screen_state_traceability_v1.csv), [G1 QA](../../temp/proof/day8_20260713/day8_g1_qa.json). Validator 20/20; mobile 82/82; backend 79/79; build/lint/analyze/audit pass. |
| 9 | Token, typography và primitive contract | - | PASS | [Status](../engineering/day9_design_system_status.md), [machine contract](../architecture/pawmate_design_tokens_primitives_v1.json), [component contract](../architecture/pawmate_design_tokens_primitives_v1.md), [migration audit](../qa/pawmate_design_token_usage_audit_v1.csv), [QA manifest](../../temp/proof/day9_20260713/day9_qa.json). Validator 17/17; contract/a11y 13/13; focused regression 27/27; full mobile 90/90; analyze 0 issue; visual auth 390x844 7 PNG dùng font thật. |
| 10 | Shared primitives, app shell và visual harness implementation | - | PASS | [Status](../engineering/day10_shared_primitives_visual_harness_status.md), [implementation map](../architecture/pawmate_shared_primitive_implementation_v1.md), [QA manifest](../../temp/proof/day10_20260713/day10_qa.json), [visual proof](../../temp/proof/day10_20260713/day10_foundation_contact_sheet.png). Shared primitives/app shell hoàn tất; validator 16/16, focused 27/27, full mobile 113/113, analyze 0 issue, 12 golden tại 360/390/412/430 và intentional-drift guard pass. Không còn blocker active; chuyển Day 11 để kiểm thử foundation độc lập. |
| 11 | Foundation Feature Test | - | PASS | [Status](../engineering/day11_foundation_feature_test_status.md), [test matrix](../qa/day11_foundation_test_matrix.md), [defect ledger](../qa/day11_foundation_defect_ledger.md), [QA manifest](../../temp/proof/day11_20260714/day11_qa.json). Snapshot Day 11 giữ nguyên kết quả focused 45 pass/1 skip và full mobile 122 pass/1 skip; P1 `D11-FND-001` được chuyển sang Day 12 để sửa, không bị xoá khỏi lịch sử. |
| 12 | Foundation Fix, Verify và Integration | G2 | PASS | [Day 12 status](../engineering/day12_foundation_fix_verify_integration_status.md), [QA manifest](../../temp/proof/day12_20260714/day12_qa.json), [defect ledger](../qa/day11_foundation_defect_ledger.md), [Android smoke](../../temp/proof/day12_20260714/day12_android_smoke.json). `D11-FND-001` đã RESOLVED; pilot 108/108, full mobile 123/123, golden 13/13, validator 16/16, analyze 0 issue, backend 16 suites/79 tests + build/lint pass. Gradle Windows immutable-workspace blocker được xử lý bằng wrapper 9.1.0; `flutter build apk` pass, APK 164,073,638 bytes, cài/chạy trên Pixel 7 API 34 và logcat có 0 fatal. Gate G2 PASS; Day 13 là scope tiếp theo. |
| 13 | P1-01 Onboarding và P1-02 Login | - | PASS | [Day 13 status](../engineering/day13_p1_01_p1_02_status.md), [QA manifest](../../temp/proof/day13_20260714/day13_qa.json). Focused 15/15, router 3/3, golden 2/2, full mobile 134/134, coverage 73.15%, analyze 0 issue và Android debug build pass. Draft/session/validation/loading/error/route đã có test; Figma live và emulator smoke được ghi là note không chặn, không có claim giả. |
| 14 | P1-03 Register và P1-04 OTP Verification | - | PASS | [Day 14 status](../engineering/day14_p1_03_p1_04_status.md), [QA manifest](../../temp/proof/day14_20260714/day14_qa.json). Mobile focused 20/20, backend focused 23/23, golden 3/3, full mobile 149/149, backend 16 suites/81 tests, analyze/build/lint pass. Android emulator gọi PostgreSQL-backed local API, `POST /auth/register` trả 201 và mở đúng OTP với cooldown thật. Supabase public DNS là note môi trường ngoài, không được che bằng production fallback. |
| 15 | Auth Feature Test | - | COMPLETE - GATE FAIL (2 P0 OPEN) | [Test report](../qa/auth/day15_auth_test_report.md), [test matrix](../qa/auth/day15_auth_test_matrix.csv), [defect ledger](../qa/auth/day15_auth_defects.md), [QA manifest](../../temp/proof/day15_20260714/day15_qa.json). Đã chạy 42/42 testcase P0/P1: 39 PASS, 3 FAIL; ba failure quy về `D15-AUTH-001` và `D15-AUTH-002`. Baseline vẫn xanh: mobile 156/156, backend 16 suites/81 tests, analyze/build/lint pass. Day 16 phải đóng hai P0; chưa được mở Day 17/Pet. |
| 16 | Auth Fix, Verify và Integration | G3 | PASS WITH NOTES | [Day 16 status](../engineering/day16_auth_fix_verify_integration_status.md), [QA manifest](../../temp/proof/day16_20260715/day16_qa.json), [defect ledger](../qa/auth/day15_auth_defects.md). `D15-AUTH-001` và `D15-AUTH-002` CLOSED; Sol xhigh không còn P0/P1 và khuyến nghị G3 PASS. Mobile focused 68/68, full 194 pass/1 intentional skip, analyze 0 issue; backend 16 suites/85 tests, build/lint/audit pass; Redis atomic/concurrency proof và client/server logout integration pass; Android API34 cold restore/logout restart có 0 fatal/ANR. P2: theo dõi Redis session-index growth và review cross-slot nếu chuyển Redis Cluster. |
| 17 | Pet domain/API/provider contract | - | PASS | [Day 17 status](../engineering/day17_pet_domain_api_provider_status.md), [Pet contract](../architecture/pet_profile_data_contract.md), [machine contract](../architecture/pawmate_pet_domain_api_provider_contract_v1.json), [change report](../architecture/pawmate_pet_contract_change_report_v1.md), [QA manifest](../../temp/proof/day17_20260715/day17_qa.json). Backend focused 2 suites/10 tests và full 17 suites/92 tests pass; build/lint/audit pass. Mobile Pet contract 9 tests, navigation 13 tests, full 201 tests/1 intentional skip và analyze 0 issue. Runtime HTTP smoke 11/11 pass. Không còn P0/P1; mở Day 18. |
| 18 | P1-05 Pet List và P1-06 Pet Form | - | PASS | [Day 18 status](../engineering/day18_p1_05_p1_06_status.md), [QA manifest](../../temp/proof/day18_20260715/day18_qa.json), [source manifest](../../temp/proof/day18_20260715/day18_source_manifest.json), [golden proof](../../mobile/test/visual/goldens/day18/). Pet focused 42/42, state/widget/viewport 15/15, golden 5/5, full mobile 221 pass/1 intentional skip, analyze 0 issue, coverage 76.16%; backend 17 suites/92 tests + build/lint/audit pass; Android debug build/install/launch pass và 0 fatal/ANR. Không còn P0/P1; feature-level Android E2E được giao cho Day 20. |
| 19 | P1-07 Home Screen và P1-16 Profile | - | PASS | [Day 19 status](../engineering/day19_p1_07_p1_16_status.md), [QA manifest](../../temp/proof/day19_20260716/day19_qa.json), [source manifest](../../temp/proof/day19_20260716/day19_source_manifest.json), [golden proof](../../mobile/test/visual/goldens/day19/). Home/Profile dùng auth/pet/reminder providers thật; selected-pet và route impact có test. Focused 34/34, golden 2/2, full mobile 226 pass/1 intentional skip, analyze 0 issue, coverage 76.41%; backend 17 suites/92 tests + build/lint/audit pass; Android debug APK build pass. P0=0, P1=0; mở Day 20 independent feature test. |
| 20 | Pet/Home/Profile Feature Test | - | PASS | [Day 20 test plan](../qa/pet-home-profile/day20_pet_home_profile_test_plan.md), [traceable test matrix](../qa/pet-home-profile/day20_pet_home_profile_test_matrix.md), [defect ledger](../qa/pet-home-profile/day20_pet_home_profile_defects.md), [QA manifest](../../temp/proof/day20_20260716/day20_qa.json). Focused/module/API/Android journey passed; no P0/P1 product defect; feature scope remained frozen. |
| 21 | Pet/Home/Profile Fix, Verify và Integration | G3A | PASS | [Day 21 status](../engineering/day21_pet_home_profile_fix_verify_integration_status.md), [G3A gate matrix](../qa/pet-home-profile/day21_g3a_gate_matrix.md), [QA manifest](../../temp/proof/day21_20260716/day21_qa.json), [source manifest](../../temp/proof/day21_20260716/day21_source_manifest.json). Day 20 có P0=0/P1=0 nên không tạo defect giả hoặc thay đổi feature source; bổ sung regression E2E test-only cho Auth -> Home -> Pet Detail/List -> Profile. Focused 113 pass/1 intentional skip, golden 12/12, full mobile 226 pass/1 intentional skip, analyze 0 issue, coverage 76.41%; backend 17 suites/92 tests + build/lint/prod-audit pass; Android API34 E2E 1/1 và logcat sạch. G3A PASS; selected-pet/data/navigation ổn định; mở Day 22. |
| 22 | Vet contract, location và map foundation | - | PASS | [Day 22 status](../engineering/day22_vet_contract_location_map_foundation_status.md), [Vet contract](../architecture/day22_vet_contract_foundation.md), [QA matrix](../qa/vet/day22_vet_contract_test_matrix.md), [QA manifest](../../temp/proof/day22_20260716/day22_qa.json), [source manifest](../../temp/proof/day22_20260716/day22_source_manifest.json). Canonical `vetId`/`pageInfo` được dual-emit và parser fallback với legacy `id`/`pagination`; location permission fallback và map/list state foundation đã khóa. Backend focused 23/23, full 18 suites/95 tests; mobile focused 33/33, full 228 pass/1 intentional skip; analyze/build/lint/audit/OpenAPI refs pass. G22 scope PASS; không làm trước feature Day 23. |
| 23 | P1-08 Vet Finder Map và P1-09 Vet List | - | PASS | [Day 23 status](../engineering/day23_vet_finder_map_list_status.md). Map/List share `VetFinderSessionState` for query/filter/dataset/selection/scroll; permission/API/map-unavailable fallbacks remain usable; focused Vet 37/37, Day 23 golden 5/5, combined focused+golden 43/43, full mobile 238 pass/1 intentional skip, analyze 0 issue. Android 14 emulator proof captured map and clean list screenshots; Day 24 Vet Detail/Write Review remains excluded. Workbook direct-cell read and live tile/API availability are recorded as evidence limits. |
| 24 | P1-10 Vet Detail và P1-11 Write Review | - | PASS | [Day 24 status](../engineering/day24_vet_detail_write_review_status.md). Detail/review source-of-truth, auth/validation/duplicate/photo-upload flow, review invalidation and safe call/directions fallbacks are covered; source-aware Map/List back path added. Vet focused 43/43, Day 24 goldens 2/2, combined 45/45, full mobile 245 pass/1 intentional skip, analyze 0 issue, backend Vet/review routes 11/11. Day 25 feature-test scope is next; Health remains untouched. |
| 25 | Vet Feature Test | - | PASS | [Day 25 test report](../engineering/day25_vet_feature_test_report.md). Deterministic journey/fallback 2/2, Vet focused plus Day 24 visuals 47/47, full mobile 247 pass/1 intentional skip, analyze 0 issue, backend 18 suites/95, build/lint and production audit PASS; no P0/P1 product defect. Day 26 G3B Vet integration is unblocked. |
| 26 | Vet Fix, Verify và Integration | G3B | PASS | [Day 26 G3B status](../engineering/day26_vet_fix_verify_integration_status.md). No Day 25 product fix required; G3B matrix PASS, Vet 47/47, cross-module 69/69, Android Map/List 2/2 on emulator API34, full mobile 247 pass/1 intentional skip, backend 18 suites/95, analyze/build/lint/audit PASS; P0=0, P1=0. Day 27 Health is unblocked. |
| 27 | P1-12 Health Timeline và P1-13 Add Health Event | - | PASS | [Day 27 Health status](../engineering/day27_health_timeline_add_event_status.md), [Supabase cloud evidence](../../output-evidence/day27/cloud/day27-supabase-cloud-migration-20260717.md). Fixed and retested timeline grouping/order, selected event time persistence, 390px form clipping and network-failure draft retention; Health focused+golden 11/11, full mobile 252 pass/1 intentional skip, analyze 0 issue, backend 18 suites/95, Prisma/schema/local DB proof, native Prisma generate, build/lint/audit PASS. Production Supabase backup/apply/postflight/REST proof also PASS; P0=0, P1=0 and no remaining Day 27 release blocker. Day 28 product work is unblocked. |
| 28 | P1-14 Reminder Calendar và P1-15 Notification Center | - | PASS | [Day 28 status](../engineering/day28_reminder_notification_status.md), [Day 28 test plan](../qa/reminders-notifications/day28_reminder_notification_test_plan.md), [Day 28 defects](../qa/reminders-notifications/day28_reminder_notification_defects.md). Reminder filter/overdue/snooze/done/delete, notification unread badge/read/read-all/dismiss, deep-link and offline-safe navigation complete; focused mobile+golden 16 pass, backend 18 suites/95, coverage 84.73% statements/84.58% lines, analyze/build/lint/Prisma pass. Full mobile retains two pre-existing date-sensitive golden failures (Day 19/27) and npm audit has 1 high dependency finding; both are explicit follow-up, outside Day 28 product scope. |
| 29 | Health/Reminder/Notification Feature Test | - | PASS | [Day 29 test report](../engineering/day29_health_reminder_notification_feature_test_report.md), [test matrix](../qa/health/day29_health_reminder_notification_feature_test_matrix.md), [defects](../qa/health/day29_health_reminder_notification_defects.md). Selected-pet và cross-screen impact được kiểm thử từ focused/module đến API thật và Android E2E; Health persistence 1/1, Reminder -> Notification persistence 1/1, mobile full 259 pass/1 intentional skip, backend 95/95, analyze/build/lint/prod-audit pass. P0=0, P1=0; Day 30 G3C được mở. |
| 30 | Health Fix, Verify và Integration | G3C | PASS | [Day 30 G3C status](../engineering/day30_health_fix_verify_integration_status.md), [G3C matrix](../qa/health/day30_g3c_gate_matrix.md), [defects](../qa/health/day30_health_fix_verify_integration_defects.md). No production feature fix needed; selected-pet integration harness regression was reproduced and closed. Cross-module Android: Home/Pet/Profile 1/1, Vet Map 2/2 + List 1/1, Health 1/1, Reminder -> Notification 1/1; full mobile 259 pass/1 intentional skip, backend 18 suites/95, analyze/build/lint/Prisma/audit PASS. P0=0, P1=0; Day 31 opened. |
| 31 | Phase 1 Visual, Responsive và Accessibility Test | - | PASS | [Day 31 status](../engineering/day31_phase1_visual_responsive_accessibility_status.md), [screen matrix](../qa/phase1/day31_phase1_visual_responsive_accessibility_matrix.md), [defects](../qa/phase1/day31_phase1_visual_accessibility_defects.md). All P1-01..P1-16 have canonical 390x844 evidence; visual 39/39, accessibility 8/8, responsive/state 110/110, focus/semantics 15/15 and analyze 0 issue. Manual 16-screen + representative-width review found P0=0/P1=0; Day 32 opened. |
| 32 | Phase 1 Full Regression và Integration Test | - | PASS | [Day 32 status](../engineering/day32_phase1_full_regression_status.md), [22-impact matrix](../qa/phase1/day32_phase1_full_regression_matrix.md), [consolidated defects](../qa/phase1/day32_phase1_consolidated_defects.md). Full mobile 259 pass/1 intentional skip, backend 18 suites/95, coverage mobile 79.55% lines/backend 84.59% lines, analyze/build/lint/Prisma/audit PASS; Android Pet/Home/Profile 1/1, Vet Map/List 2/2, Health 1/1, Reminder -> Notification 1/1. All 22 impacts executed/triaged; product P0/P1=0, two P1 harness/tooling findings assigned to Day 33, so G4 remains unsigned. |
| 33 | Phase 1 Fix, Full Retest và Sign-off | G4 | PASS | [G4 sign-off](../engineering/day33_phase1_g4_signoff.md), [gate matrix](../qa/phase1/day33_g4_gate_matrix.md), [known issues](../qa/phase1/day33_phase1_known_issues.md). Closed Day 21 session-provider harness, Windows whitespace-safe Flutter launcher/Android clean restore and warm-sequential Reminder IME harness. Focused 36/36 + 16/16, full mobile 259 pass/1 intentional skip with 79.55% line coverage, analyze 0, backend 18 suites/95 + build/lint/Prisma/audit PASS, Android critical batch 6/6 and final APK build PASS. P0=0, P1=0; 16 screens/22 impacts have code-test-evidence; G4 signed and Day 34 opened. |
| 34 | Rescue schema và migration foundation | - | PASS | [Status](../engineering/day34_rescue_persistence_status.md), [migration review](../qa/phase2/day34_rescue_migration_review.md), [repository matrix](../qa/phase2/day34_rescue_repository_test_matrix.md), [cloud schema proof](../../output-evidence/day34/day34-cloud-schema-proof-20260721.json). Local Prisma/migration/seed/repository/real-DB gates PASS. Supabase production ref `qeoowayxfqyhfcgnrfnv`: clean preflight, transactional patch không seed, shared postflight 12/12 metrics và REST 6/6 không còn `PGRST205` đều PASS; P0=0/P1=0. Day 35 được phép mở. |
| 35 | Rescue read API | - | PASS | [Status](../engineering/day35_rescue_read_api_status.md), [test matrix](../qa/phase2/day35_rescue_read_api_test_matrix.md), [machine proof](../../output-evidence/day35/day35-read-api-proof-20260721.json). Public list/detail/geo, filter/sort/opaque cursor, privacy allowlist and optional bearer are wired. Full backend 22 suites/131 tests, real local Rescue DB 4 suites/14 tests, lint/build/Prisma generate+validate/coverage/audit PASS. Repeatable-read hydration, typed enum predicates, tuple keyset, local query-plan and Supabase 4/4 partial indexes PASS; P0=0/P1=0. Day 36 được phép mở. |
| 36 | Rescue write/media/comment/status API | - | PASS | [Status](../engineering/day36_rescue_write_api_status.md), [test matrix](../qa/phase2/day36_rescue_write_api_test_matrix.md), [machine proof](../../output-evidence/day36/day36-write-api-proof-20260721.json). Eight mutation/media endpoints, owner permissions, exact-location privacy, idempotency, optimistic version, transaction/outbox and sanitized media lifecycle are wired. Full backend 28 suites/212 tests, real local Rescue DB 3 suites/8 tests, lint/build/Prisma generate+validate/coverage/audit PASS. Local/cloud SQL constraints and Supabase buckets are aligned at 50 MiB; live metadata removal/hash/cleanup proof PASS via `browser-use`, no Chrome Extension. P0=0/P1=0 known; Day 37 opened. |
| 37 | Rescue Backend Feature Test | - | PASS | [Canonical Day 37 status](../engineering/day37_rescue_backend_feature_test_status.md) và [clean-chain checkpoint](../../output-evidence/day37/final-20260722-1510/manifest.json) đã freeze một P1 dependency đúng owner; Day 38 sau đó resolve `fast-uri` và current clean-chain [PASS không defect](../../output-evidence/day37/20260722t085001z/manifest.json). Migration/rollback/idempotency/full regression an toàn; Day 37 đóng, không reopen Day 34-36. |
| 38 | Rescue Backend Fix, Verify và Integration | G5A | PASS | [Day 38 status](../engineering/day38_rescue_backend_fix_verify_g5a_status.md), [G5A matrix](../qa/rescue-backend/day38_g5a_gate_matrix.md), [machine manifest](../../output-evidence/day38/final-20260722-1533/manifest.json), [approval](./pawmate_product_owner_approval_2026-07-22.md). Technical gate PASS: 32 suite/247 test, changed-source coverage 100%, audit 0, P0/P1 mở 0/0; Product/BA đã approve bốn decision AUTH/PRIVACY/CONTACT/OUTBOX. G4B vẫn chưa PASS nên Day 39 chưa mở. |
| 39 | P2-01 Rescue Home | - | PASS | [Day 39 status](../qa/phase2/day39_rescue_home_status_2026-07-23.md), [D39 exit manifest](../../output-evidence/day39/D39-EXIT-20260723.json). Real `GET /rescue/cases` source, recent list/filter/refresh/opaque pagination, privacy-safe map preview, loading/empty/error/stale states and bottom nav are wired. Rescue focused 13/13, responsive goldens 6/6, full mobile 427 pass/1 intentional skip, analyze 0, Android debug build PASS, Rescue line coverage 81.66%, exit checks 11/11. No visible `Báo thấy`; browse/create defaults remain `false/false`. |
| 40 | P2-02 Create Lost Alert và P2-03 Lost Info Form | - | NOT STARTED | |
| 41 | P2-04 Case Detail | - | NOT STARTED | |
| 42 | Rescue Core Feature Test | - | NOT STARTED | |
| 43 | Rescue Core Fix, Verify và Integration | G5B | NOT STARTED | |
| 44 | P2-05 Rescue Map | - | NOT STARTED | |
| 45 | P2-06 Case Comment | - | NOT STARTED | |
| 46 | P2-07 Case Status Update và P2-08 Case Discussion | - | NOT STARTED | |
| 47 | Rescue Interaction Feature Test | - | NOT STARTED | |
| 48 | Rescue Interaction Fix, Verify và Full Integration | - | NOT STARTED | |
| 49 | Rescue Full Regression và Sign-off | G5 | NOT STARTED | |
| 50 | Adoption listing/request schema và API | - | NOT STARTED | |
| 51 | Shelter chat backend | - | NOT STARTED | |
| 52 | Adoption Backend Feature Test | - | NOT STARTED | |
| 53 | Adoption Backend Fix, Verify và Integration | G6A | NOT STARTED | |
| 54 | P2-09 Adoption Swipe Deck và P2-10 Adoption Profile | - | NOT STARTED | |
| 55 | P2-11 Adoption Request Form và P2-12 Shelter Chat | - | NOT STARTED | |
| 56 | Adoption UI Feature Test | - | NOT STARTED | |
| 57 | Adoption Fix, Verify và Integration | - | NOT STARTED | |
| 58 | Adoption Full Regression và Sign-off | G6 | NOT STARTED | |
| 59 | Preferences/privacy backend và cross-impact | - | NOT STARTED | |
| 60 | P2-13 Health Hub và P2-14 Notification Preferences | - | NOT STARTED | |
| 61 | P2-15 Privacy Defaults và P2-16 Profile Controls | - | NOT STARTED | |
| 62 | Health/Preferences/Privacy Feature Test | - | NOT STARTED | |
| 63 | Health/Preferences/Privacy Fix, Verify và Integration | G7A | NOT STARTED | |
| 64 | Phase 2 Full Regression, Fix Gate và Sign-off | G7 | NOT STARTED | |
| 65 | Detailed Testcase Design và Test-data Freeze | - | NOT STARTED | |
| 66 | Android Toolchain, APK Build/Install và Emulator Smoke | - | NOT STARTED | |
| 67 | Android Emulator Regression Phase 1 | - | NOT STARTED | |
| 68 | Android Phase 1 Fix và Retest | - | NOT STARTED | |
| 69 | Android Emulator Regression Phase 2 | - | NOT STARTED | |
| 70 | Android Phase 2 Fix và Retest | - | NOT STARTED | |
| 71 | Android Edge và Lifecycle Feature Test | - | NOT STARTED | |
| 72 | Android Edge Fix, Verify và Integration | - | NOT STARTED | |
| 73 | Cross-phase Integration Regression | - | NOT STARTED | |
| 74 | Cross-phase Fix, Verify và Retest | - | NOT STARTED | |
| 75 | Accessibility, Viewport, Performance và Security Test | - | NOT STARTED | |
| 76 | Non-functional Fix và Retest | - | NOT STARTED | |
| 77 | Final Stabilization và Full Automated Retest | - | NOT STARTED | |
| 78 | Android Release Build và Release Candidate Sign-off | G8 | NOT STARTED | |

## Quy tắc cập nhật

- Chỉ có một row `IN PROGRESS`.
- `PASS` phải kèm test/evidence path và DoD conclusion.
- `PARTIAL` phải ghi việc còn thiếu và Day xử lý tiếp.
- `BLOCKED` phải ghi nguyên nhân, ba lần xử lý nếu có, và input cần thêm.
- Scope thay đổi phải thêm row `<Day>-deviation`; không ghi đè scope gốc.
- Buffer C1-C8 chỉ thêm khi có evidence blocker và ETA thay đổi.
- Row `TEST` không triển khai feature mới; chỉ thực thi testcase, ghi defect và evidence.
- Row `FIX/INTEGRATION` không mở scope mới; phải retest defect, thêm regression test và chạy integration gate.
- Nếu gate chưa đạt, giữ cùng Day hoặc ghi deviation; không tự động chuyển sang cụm feature kế tiếp.

## Roadmap v1.2/addendum change-control ngày 22-07-2026

Phần này là append-only overlay. Nó không đổi scope hoặc verdict lịch sử Day 1-36 và không tạo thêm Day row `IN PROGRESS`.

| Change-control | Scope | Status | Evidence/contract | Tác động lên execution |
|---|---|---|---|---|
| `ROADMAP-CC-2026-07-22-V1.2` | Source precedence, Day rework policy, Day 37/38 contracts, W2-W9 convergence, G4B/G4C và D39-ENTRY | `LOCKED_FOR_EXECUTION` | [Roadmap v1.2 addendum](./pawmate_v1_roadmap_v1_2_addendum_2026-07-22.md) | Giữ Day 37 là Day `IN PROGRESS` duy nhất; không renumber Day 39-78 |
| `SRS-CC-2026-07-22` | Hai workbook SRS Phase 1/2 v1.1 | `APPROVED / ADOPTED_V1.1` | [SRS contract](../product/srs_v031_day37_38_update_2026-07-22/SRS_UPDATE_CONTRACT.md), [independent QA](../../output-evidence/srs-update-20260722/qa-independent.md), [approval](./pawmate_product_owner_approval_2026-07-22.md) | Hash workbook giữ nguyên; Day 39 vẫn chờ G5A + G4B |
| `UI-CC-2026-07-21-G4B` | UI v0.31/v0.32 cross-platform acceptance | `W3_REENTRY_APPROVED / FAIL_CLOSED_DOWNSTREAM` | [W3 checkpoint](../qa/ui-v031/W3_EXECUTION_CHECKPOINT_2026-07-22.md), [W8 report](../qa/ui-v031/W8_CROSS_PLATFORM_QA_REPORT.md), [W9 status](../qa/ui-v031/W9_HANDOFF_BLOCKED_REPORT.md), [approval](./pawmate_product_owner_approval_2026-07-22.md) | W3 được phép mutation; vẫn phải đóng W3, W7 iOS, W8 trace/accessibility và W9 trước G4B |
| `DAY37-EXEC-2026-07-22-1510` | Canonical Day 37 clean-chain/test execution checkpoint | `COMPLETE_WITH_DEFECTS / DAY38_ENTRY_READY / LEDGER_ROW_PENDING` | [Day 37 manifest](../../output-evidence/day37/final-20260722-1510/manifest.json), [result](../../output-evidence/day37/final-20260722-1510/day37-clean-chain-result.json); manifest SHA-256 `810F388BEDC8AEEFCB5C235A775BA104149C44A98BEC24FA0453EB4459BA0BAC`, result SHA-256 `C7D539E13080EA3D5F21849414B04B37B0F57C3F2B7216110E775097A06F9832` | Non-security gates pass, coverage 85.34%, source unchanged/DB dropped/redaction pass; one P1 `D37-DEPENDENCY_AUDIT_HIGH-01` goes to Day 38; historical Day 37 row remains `IN PROGRESS` until final sign-off |
| `DAY38-EXEC-2026-07-22-1533` | Day 37 defect closure, Day 38 remediation và G5A technical proof | `PASS / G5A_APPROVED` | [Day 38 status](../engineering/day38_rescue_backend_fix_verify_g5a_status.md), [gate matrix](../qa/rescue-backend/day38_g5a_gate_matrix.md), [machine manifest](../../output-evidence/day38/final-20260722-1533/manifest.json), [decision record](../architecture/day38_g5a_decision_record.md), [approval](./pawmate_product_owner_approval_2026-07-22.md) | Day 37/38 đóng; W3 là wave `IN PROGRESS`; không mở Day 39 cho đến khi G4B PASS |
| `D39-ENTRY` | Gate hội tụ trước P2-01 Rescue Home | `CLOSED` | Điều kiện trong roadmap v1.2 addendum | SRS và G5A đã PASS; vẫn chờ G4B PASS |

### UI wave approval overlay — 2026-07-22 16:41 ICT

| Wave | Status | Evidence / next gate |
|---|---|---|
| W2 | `NOT_PASS_WITH_APPROVED_EXCEPTION` | [Approved exception](../design/pawmate-v031-platform-ui/generated/EXC-W2-STITCH-NO-USE-01.md); Stitch remains reference-only |
| W3 | `IN PROGRESS` | Exact 77-row matrix, seven-screen selection and v0.31/v0.32 allowlist approved; post-write proof required |
| W7 | `POST_CHANGE_IOS_PENDING` | Must run isolated post-change iOS compile/render |
| W8 | `FAIL_CLOSED_DOWNSTREAM` | Re-enter after W3/W7; VoiceOver journeys moved to G4C |
| W9/G4B | `NOT_READY / CLOSED` | Requires W8 PASS, traceability/protected reconciliation and joint sign-off |

## Post-W3 convergence checkpoint — 2026-07-22 17:30 ICT

Append-only status reconciliation after the Product Owner approvals and W3
post-write proof:

| Surface | Status | Evidence / boundary |
|---|---|---|
| Day 37 | `PASS` | `output-evidence/day37/20260722t085001z/manifest.json`; no reopen. |
| Day 38 / G5A | `PASS` | `docs/architecture/day38_g5a_decision_record.md`; all four decisions approved. |
| SRS v1.1 | `ADOPTED` | `docs/product/srs_v031_day37_38_update_2026-07-22/SRS_UPDATE_CONTRACT.md`. |
| W2 | `NOT_PASS_WITH_APPROVED_EXCEPTION` | `EXC-W2-STITCH-NO-USE-01`; no Stitch generation. |
| W3 | `PASS` | 77/77 matrix, 0 font/geometry violations, protected Figma fingerprints unchanged. |
| W4 | `PASS` | 57 focused tests; analyze/bundle exit 0. |
| W5 | `PASS` | 82/82 router/auth/navigation checks; legacy visual mismatch cleared by W6 rebaseline. |
| W6 | `PASS` | 411 tests + one intentional skip; 85 visual checks; Rescue flags off. |
| W7 | `PARTIAL_PASS / POST_CHANGE_IOS_CI_PENDING` | Android/static native proof pass; iOS post-change run unavailable on Windows. |
| W8 | `PARTIAL_PASS / FAIL_CLOSED` | Validators/goldens/coverage/manifest pass; 191 trace rows still planned; VoiceOver moved G4C. |
| W9 / G4B | `NOT_READY / FAIL_CLOSED` | Waiting on iOS proof, row-level evidence and fresh protected reconciliation. |
| G4C | `PENDING` | Seven real-device VoiceOver journeys. |
| Day 39 | `NOT_STARTED / CLOSED` | Entry contract not met because G4B is not PASS. |

The authoritative detail is in
`docs/management/pawmate_v1_roadmap_v1_2_addendum_2026-07-22.md` section 16.
No historical Day verdict was overwritten and no protected backend path was
rebaselined.

## Approval reconciliation overlay — 2026-07-22

Overlay append-only này là trạng thái mới hơn checkpoint Post-W3 ở trên:

| Approval / gate | Giá trị được duyệt | Trạng thái và bằng chứng |
|---|---|---|
| G5A | `APPROVE_ALL_4` | `PASS`; [machine reconciliation](../../output-evidence/day38/final-20260722-1533/g5a-product-approval-reconciliation-20260722.json), SHA-256 `58F4D77F8D38940A08B0ABEAD13520D64624DBE045C1C086413AF3538F1BED2A`, verdict `G5A_PASS`. |
| W2 | `APPROVE_NO_USE_EXCEPTION` | Ngoại lệ no-use được duyệt; wave giữ `NOT_PASS_WITH_APPROVED_EXCEPTION`. |
| W3 | `APPROVE_77_ROWS_AND_7_SCREENS` | 77 dòng và 7 màn được duyệt; W3 giữ `PASS`. |
| v0.31/v0.32 | `ALLOWLIST=APPROVE` | Chỉ mutation trong allowlist được duyệt. |
| SRS | `ADOPT_V1.1` | Product/BA adopt hai workbook v1.1 mà không đổi byte/hash. |
| VoiceOver | `G4C` | Tách khỏi G4B và theo dõi riêng ở G4C. |

Parent technical manifest của G5A có SHA-256
`25B66518BB423898614582DA177BC581DD03AE704F7CA870CE4F45257ADEB9D6`.
W8 hiện có `102 PASS / 89 PLANNED`, trong đó 89 dòng còn lại là 82 CTA và
7 Android TalkBack journey. W9/G4B tiếp tục `NOT_READY / FAIL_CLOSED` cho đến
khi đóng hai nhóm này, có post-change iOS proof và joint sign-off.

`D39-ENTRY` vẫn `CLOSED`; không mở Day 39 trước khi G4B thực sự PASS.

## Terminal reconciliation overlay — 2026-07-22 19:05 ICT

Protected-path reconciliation đã chuyển sang
`PASS_WITH_APPROVED_OWNER_DELTA`: 50 exact changes (`38` added, `12` modified,
`0` removed), không rebaseline. Full Flutter suite PASS `411 + 1 intentional
skip`; analyze PASS; trace validator PASS `17/17`; trace execution giữ nguyên
`102 PASS / 89 PLANNED`.

Một thử nghiệm TalkBack HOME sáu bước đã bị loại đúng theo fail-closed vì XML
không đổi và không chứng minh focus chuyển target. Do đó 89 dòng còn thiếu vẫn
là `82` CTA + `7` Android TalkBack. W7 còn thiếu post-change iOS proof; W9/G4B
vẫn `NOT_READY / FAIL_CLOSED`; VoiceOver ở G4C; Day 39 tiếp tục đóng.

## Pre-Day-39 G4B convergence overlay — 2026-07-23 12:12 ICT

Số liệu `102 PASS / 89 PLANNED` ở checkpoint trước đã được thay thế bằng
`191 PASS / 0 PLANNED`. `82/82` CTA manifests và `7/7` Android TalkBack journey
manifests đã được bind vào traceability; validator tests `19/19 PASS`.

Android normal APK sau instrumentation đã được rebuild, bảo toàn và cài đúng
SHA-256 `C5153B1775B65B1678122E9B6FD3612861C5527F68B2F147792E25CC1F09A540`;
clear-data cold launch PASS. Analyze, full Flutter, goldens, coverage, native
branding, protected paths, redaction và W8 manifest validation đều PASS.

W7/W8/W9/G4B vẫn fail-closed ở hai điều kiện cuối:

1. chạy post-change iOS compile/render trên một revision CI-visible được ủy quyền;
2. Product Owner ký joint G4B sau khi proof iOS và manifest cuối được bind.

Sign-off contract: [G4B joint sign-off](../qa/ui-v031/G4B_JOINT_SIGNOFF.md).
VoiceOver tiếp tục ở G4C. `D39-ENTRY` và Day 39 vẫn `CLOSED / NOT_STARTED`.

## G4B joint approval closure — 2026-07-23 15:47 ICT

Product Owner đã xác nhận chính xác `G4B=APPROVE` cho immutable W8 manifest
SHA-256
`3832C950AFCED7ADDFE8B7D828DFE7CD8E40A566F4B9147778203F1C35FCD7A1`.
Post-change iOS proof dùng Codemagic build `6a61c58e95159f0929dd483e`; traceability
giữ `191/191 PASS`; CTA `82/82`; Android TalkBack `7/7`; redaction và terminal
manifest validation đều PASS.

| Surface | Current status | Evidence / next transition |
|---|---|---|
| W7 iOS | `PASS` | Codemagic post-change compile/render proof |
| W8 | `PASS` | Immutable terminal manifest approved |
| W9 / G4B | `PASS` | [Product Owner approval](./pawmate_product_owner_g4b_approval_2026-07-23.md) |
| G4C | `PENDING / NON_BLOCKING_FOR_G4B` | VoiceOver real-device follow-up |
| D39-ENTRY | `READY_FOR_MACHINE_EVALUATION` | Must still emit and validate `D39-ENTRY-<run-id>.json` |
| Day 39 | `NOT_STARTED / CLOSED_PENDING_ENTRY_MANIFEST` | Do not change row 39 until D39 manifest passes |

Không recapture W8 sau approval vì việc đưa successor sign-off metadata trở lại
source snapshot sẽ thay đổi chính baseline vừa được ký. Mọi Day 39 source change
phải bắt đầu từ một successor branch sau khi `D39-ENTRY` pass.

## D39 entry opened — 2026-07-23 15:55 ICT

`D39-ENTRY-20260723-g4b-approved.json` đã validate `PASS` với `32/32` checks,
source commit `4046b4c70e2892985a54725a998e43b8f93784c4`, source snapshot SHA-256
`4ED7D12A19AACE517D9708DE0D75093F83F2778BB78320F1288E17EA7EEB3429`
và manifest SHA-256
`1B558EFC8B27C2A0B2C24001A60941B548144D782C04818B367F6E02F7CA6B83`.

Day 39 là row `IN PROGRESS` duy nhất. Scope bất biến:

- P2-01 Rescue Home entry/list/map preview;
- 5 ca gần nhất, status, filter, refresh, pagination;
- empty/loading/error, bottom nav, long text và accessibility;
- data thật qua Rescue read API;
- không visible `Báo thấy`;
- `PAWMATE_RESCUE_BROWSE_ENABLED=false` và
  `PAWMATE_RESCUE_CREATE_ENABLED=false` cho tới khi Day 39 behavior/evidence
  gate PASS.

## Day 39 exit closure — 2026-07-23 16:31 ICT

Day 39 P2-01 đã PASS trên source commit
`137c83c33e45dd5c035a47676979423d799f0594`.

| Gate | Status | Evidence |
|---|---|---|
| D39 exit manifest | `PASS 11/11` | `output-evidence/day39/D39-EXIT-20260723.json` |
| Analyze | `PASS`, 0 issue | `output-evidence/day39/flutter-analyze-20260723.log` |
| Rescue focused | `PASS 13/13` | `output-evidence/day39/flutter-test-rescue-focused-20260723.log` |
| Responsive golden | `PASS 6/6` | Live + fail-closed tại 360/390/430 |
| Full mobile | `PASS 427 + 1 intentional skip` | `output-evidence/day39/flutter-test-full-20260723.log` |
| Rescue coverage | `PASS 81.66% lines` | `output-evidence/day39/lcov.info` |
| Android debug build | `PASS` | APK SHA-256 `BAD9A3BBC7A8C0018521D7C6941BC87F0B1B8E001A1B62BFF1554BE80C1255B8` |

Source snapshot SHA-256:
`1DCA7173601AFC722ADC378E03E87AC65CF949D03025F741ED6A1DDCE38958C2`.
Evidence snapshot SHA-256:
`B85089C88B360AAD0892DBFEB025576392254A84A510F5B4EF93A20C84B1E7F2`.
Manifest SHA-256:
`C049533E44E488A7E54EDAB7064C06358E0282FC347715F42DB4C4E81B6961E8`.

Day 40 đủ dependency nhưng vẫn `NOT STARTED`; không có Day row `IN PROGRESS`.
Browse/create flags giữ `false/false`, vì Day 39 PASS không tự kích hoạt
staging/production.

# PawMate v1 Roadmap v1.2 Addendum

**Change-control ID:** `ROADMAP-CC-2026-07-22-V1.2`

**Ngày khóa:** 22-07-2026

**Trạng thái:** `LOCKED_FOR_EXECUTION / DAY_37_IN_PROGRESS`
**Phạm vi áp dụng:** phủ lên roadmap và master plan v1.1; không thay thế hoặc viết lại lịch sử

Tài liệu gốc được giữ nguyên:

- [Master plan v1.1](./pawmate_v1_master_plan_v1_1_2026-07-13.md);
- [Roadmap Day 1-78 v1.1](./pawmate_v1_day_by_day_roadmap_v1_1_2026-07-13.md);
- [Execution ledger v1.1](./pawmate_execution_ledger_v1_1_2026-07-13.md).

Addendum này khóa công việc từ trạng thái hiện tại đến điểm hội tụ trước Day 39:

1. hoàn tất Day 37;
2. thực hiện Day 38 và ký G5A;
3. song song đóng W2/W3, hội tụ W4-W7, hoàn tất W8/W9 và ký G4B;
4. chỉ mở Day 39 khi SRS v1.1 được phê duyệt áp dụng, G5A `PASS` và G4B `PASS`.

## 1. Mục tiêu, độc giả và phạm vi

### 1.1 Mục tiêu

Addendum giúp Codex lead, backend owner, UI/QA owner và Product Owner thực thi phần còn lại mà không phải suy đoán:

- nguồn nào quyết định requirement, visual, runtime và trạng thái thực thi;
- Day lịch sử nào được giữ nguyên, Day nào chỉ cần revalidate và điều kiện nào mới cho phép reopen;
- đầu vào, file được phép sửa, file bị cấm sửa, output, lệnh, điều kiện PASS/FAIL, rollback và approver của Day 37, Day 38 và các wave UI còn mở;
- bằng chứng nào bắt buộc trước khi mở Day 39.

### 1.2 Ngoài phạm vi

- Không renumber hoặc đổi scope Day 1-78.
- Không ghi đè verdict lịch sử Day 1-36 hoặc báo cáo wave đã phát hành.
- Không triển khai feature mới trong Day 37 hoặc Day 38.
- Không bật Rescue trên production chỉ vì G5A/G4B đạt; rollout và monitoring có gate riêng ở giai đoạn sau.
- Không coi SRS v1.1 QA `PASS` là Product/BA adoption nếu chưa có bản ghi phê duyệt.

## 2. Source precedence và khóa đầu vào

Không dùng một thứ tự chung cho mọi loại claim. Nguồn quyết định theo bề mặt sau:

| Bề mặt | Nguồn ưu tiên | Quy tắc khi xung đột |
|---|---|---|
| Product requirement và business behavior | Hai workbook SRS v1.1 sau khi `SRS-CC-2026-07-22` được Product/BA phê duyệt; sau đó là change-control được duyệt có ngày mới hơn | Dừng phần phụ thuộc và tạo decision record; không lấy code hiện tại để tự đổi requirement |
| Trạng thái triển khai | Repo hiện tại, schema, config và test/evidence chạy thật | Phân biệt `configured`, `implemented` và `proven`; test xanh không tự chứng minh visual hoặc product acceptance |
| Visual mục tiêu | Figma v0.31/v0.32 sau W3 `PASS` và Product Owner duyệt | Trước W3 PASS, Flutter đang chạy là baseline runtime; v0.31/v0.32 chỉ là target chưa đạt gate toàn cục |
| Route/API/data contract | Contract được duyệt mới nhất, sau đó đối chiếu route/mapper/schema chạy thật | Drift phải có owner và được giải quyết tại Day 38/G5A; không tự mở rộng public DTO |
| Trạng thái Day/gate | Execution ledger và evidence manifest hash-valid | Chỉ ledger được đổi trạng thái Day; report hoặc test đơn lẻ không tự đổi ledger |
| Trạng thái wave UI | `WAVE_CONTRACTS.md`, report wave và manifest tương ứng | Report cũ được giữ nguyên; kết quả hội tụ được ghi bằng addendum kế nhiệm |

### 2.1 SRS v1.1

| Artifact | SHA-256 | Trạng thái |
|---|---|---|
| `PawMate_SRS_Phase1_22-07-2026_v1.1.xlsx` | `0941F3BD4BDA4228AB137AC5A172919D5A7A1329C17D92FCBF09F8FDB8E78248` | Independent workbook QA `PASS`; Product/BA adoption chưa được ghi nhận |
| `PawMate_SRS_Phase2_22-07-2026_v1.1.xlsx` | `8B53E336AB1B4042335C786648083D275A96D0E5DDB3101437D0A97AD0C418ED` | Independent workbook QA `PASS`; Product/BA adoption chưa được ghi nhận |

Nguồn kiểm chứng: [SRS update contract](../product/srs_v031_day37_38_update_2026-07-22/SRS_UPDATE_CONTRACT.md) và [independent QA](../../output-evidence/srs-update-20260722/qa-independent.md). QA workbook không làm Day 37, Day 38 hoặc G5A thành `PASS`.

### 2.2 Visual và UI change-control

- Baseline/runtime change-control đã ký: `UI-CC-2026-07-20`.
- Baseline wave đang hội tụ: `UI-CC-2026-07-21-G4B`.
- Historical Figma v0.27/v0.28/v0.29/v0.30 giữ nguyên tên, parent, metadata và node fingerprint.
- Figma v0.31 section `453:7374` có 56/56 frame; v0.32 section `453:10333` hiện chưa đạt 77 responsive proof.
- Stitch/Image Gen là tham khảo hoặc fixture test/design; không thay thế SRS, Figma đã duyệt hoặc runtime.

### 2.3 Rescue backend source hashes phải ghi lại ở mỗi run

Hash quan sát tại lúc khóa addendum:

| File | SHA-256 |
|---|---|
| `backend/prisma/schema.prisma` | `45B3C3D2DB8B1EF852C29CF426BDEB26BACABDC83386C923DA6D203D4D4F7EFA` |
| `day34_rescue_foundation_patch.sql` | `EF35A9F249B5E2D584659C373DD32088D8600A1A9F8D5471A86FAB70EED5C113` |
| `day35_rescue_read_indexes_patch.sql` | `D1E78F7B2E84B630FF3434C058EB5AD51411456478E1EC93F0E90C089673D0D1` |
| `day36_rescue_write_patch.sql` | `9C8719330617540D43A803F278B27EEEA898E5729887B427EB3F8071316D25D3` |

Day 34 cloud proof cũ không chứng minh current Day 34 patch vì hash nguồn đã thay đổi. Khoảng trống này thuộc Day 37 clean-chain proof; nó không tự động reopen Day 34.

## 3. Kết luận về phạm vi rework Day

### 3.1 Verdict

Tại thời điểm khóa addendum, **không có Day 1-36 nào phải rework toàn bộ**.

| Day | Xử lý theo v1.2 | Owner/gate kế nhiệm |
|---|---|---|
| 1-5 | Giữ lịch sử; không reopen | Các khoản nợ đã có Day kế nhiệm trong ledger |
| 6 | Thêm source-lock delta cho SRS v1.1 và UI v0.31/v0.32 | Addendum này và `SRS-CC-2026-07-22` |
| 7-8 | Revalidate có mục tiêu: P2-01 auth, canonical mobile routes, `contactChannel` | Day 38/G5A và W5/W8 traceability |
| 9-33 | Không reopen; đóng acceptance mới bằng wave/addendum kế nhiệm | W3/W8/W9/G4B |
| 34 | Giữ `PASS`; chứng minh current clean migration chain | Day 37 |
| 35-36 | Giữ `PASS`; revalidate auth/privacy/contact/outbox | Day 37 rồi Day 38/G5A |

### 3.2 Điều kiện duy nhất cho phép reopen Day cũ

Chỉ reopen đúng Day lịch sử khi đồng thời thỏa cả ba điều kiện:

1. Product/BA đã phê duyệt một contract mới, có change-control ID và ngày hiệu lực.
2. Production artifact thuộc chính Day đó vi phạm Definition of Done mới.
3. Vi phạm không thể xử lý đúng scope trong Day 38 hoặc owning wave W4-W8.

Nếu chỉ có Figma geometry/font/proof thiếu nhưng Flutter runtime vẫn đạt gate, xử lý trong W3 và revalidate ở W8; không mở lại Day feature. Nếu phải đổi scope của một Day, ghi `<Day>-deviation` vào ledger trước khi sửa code.

## 4. Luồng thực thi và điểm hội tụ

```text
ROADMAP-CC-2026-07-22-V1.2
  |-- Backend: Day 37 TEST -> Day 38 FIX/INTEGRATION -> G5A
  |-- UI: W2 close/exception -> W3 -> W4-W7 convergence -> W8 -> W9/G4B
  `-- Product: SRS-CC-2026-07-22 approved

D39-ENTRY = SRS v1.1 approved AND G5A PASS AND G4B PASS
```

- Day 37 là Day `IN PROGRESS` duy nhất.
- Wave UI được chạy song song vì không tạo thêm Day row, nhưng phải tuân thủ protected paths.
- W8 không được đóng trước W3 và W7; W9 không được mở final sign-off trước W8 `PASS`.
- Day 39 không được mở chỉ vì một lane hoàn tất sớm.

## 5. Hợp đồng thực thi chung

### 5.1 Wave/Day contract bắt buộc

Mỗi Day hoặc wave còn mở phải có đủ:

| Trường | Yêu cầu |
|---|---|
| Input/Definition of Ready | Gate, source hashes, matrix và quyết định bắt buộc đã tồn tại |
| Allowlist | File/path được phép sửa, ghi trong manifest trước khi làm |
| Denylist | Historical, protected, secret-bearing và scope của lane khác |
| Output | Code/test/doc/evidence cụ thể |
| Commands | Command, working directory, thời gian bắt đầu/kết thúc và exit code |
| PASS | Điều kiện khách quan, denominator và threshold |
| FAIL | Stop condition và defect/exception ID |
| Rollback | Snapshot/baseline và cách chứng minh phục hồi |
| Approver | Vai trò có quyền ký, không tự tạo tên người |
| Known exception | ID, owner, phạm vi, expiry/reconsideration trigger và evidence |

P0/P1 không được waiver để ký gate cuối. Một infrastructure retry không xóa lần fail đầu.

### 5.2 Evidence và manifest

Evidence portable dùng đường dẫn repo-relative:

- backend: `output-evidence/day37/<run-id>/`, `output-evidence/day38/<run-id>/`;
- UI: `output-evidence/ui-v031/<baseline-id>/<wave>/`.

Mỗi `manifest.json` hoặc `wave-manifest.json` phải chứa tối thiểu:

- schema version, run/wave ID, baseline ID và roadmap change-control ID;
- commit SHA, dirty-worktree fingerprint và allowlist/denylist;
- toolchain versions và lockfile/source hashes;
- platform, device/runtime, database safety metadata nếu có;
- command, working directory, start/end time, exit code và raw-log path;
- artifact path, byte count và SHA-256;
- executor, reviewer, approver;
- `contains_test_data_only`, `redaction_status` và secret-scan result;
- defect/exception IDs và parent manifest khi là addendum.

Không bịa timestamp, command hoặc evidence còn thiếu. Trường chưa chứng minh ghi `NOT_PROVEN` và giữ gate fail-closed.

### 5.3 Retry và test determinism

- Không retry analyze, compile, migration, deterministic unit/contract/widget/golden test để đổi verdict.
- Device/CI infrastructure được retry tối đa một lần sau khi lưu lần fail đầu và tạo `FLAKE-*` exception.
- Không dùng `--update-goldens` trong W8/W9.
- Freeze clock/timezone, locale, font, DPR, text scale, network, location, permission, map placeholder, seed và animation cho golden/integration.
- Dùng test account, pet/location giả lập; không ghi token, email/điện thoại thật, địa chỉ thật hoặc exact Rescue location vào log/evidence.

### 5.4 Coverage contract

| Gate | Phương pháp | PASS |
|---|---|---:|
| Backend global | Jest/Istanbul line coverage từ `coverage-summary.json` và `lcov.info` | `>=80%` production lines |
| Rescue Day 37 | Cùng run có ba opt-in PostgreSQL suites; báo aggregate Rescue line coverage | `>=85%` |
| Day 38 changed production | Explicit changed-file allowlist so với Day 37 source snapshot; Istanbul LCOV | `>=90%` changed production lines |
| Flutter global | Checked-in mobile coverage validator | `>=80%` production lines |
| Flutter changed source | Checked-in mobile coverage validator | `>=90%` changed production lines |

Generated l10n, `*.g.dart`, `*.freezed.dart` và plugin registrants được loại theo validator đã khóa. Branch coverage chỉ báo cáo tham khảo; không claim threshold branch trong addendum này.

### 5.5 Toolchain lock

Giá trị sau là reference đã quan sát, không thay thế manifest của run:

| Surface | Giá trị khóa/tham chiếu |
|---|---|
| Backend local | Node `24.14.0`, npm `11.9.0`, Prisma CLI/Client resolved `6.19.3`, TypeScript `5.9.3` |
| Backend lockfile | `backend/package-lock.json` SHA-256 `6A30E18707A635B1CD932033E78C8C19542E1DDF79DED4DEF92F3748CDA62C0D` |
| PostgreSQL local | server `17.9`, PostGIS `3.6.2`; portable `psql`/`pg_dump` `17.9` |
| Flutter local W0 reference | Flutter `3.41.6` stable, Dart `3.11.4`, Java `17.0.19`, AGP `8.11.1`, Gradle `9.1.0`, Kotlin `2.2.20` |
| Flutter lockfile reference | `mobile/pubspec.lock` SHA-256 `98FCD39FCC334F491ED9212B8738B60001B92E8B6D586509C325CB6F22F8B6B7` |
| Codemagic iOS pin | Flutter `3.44.7`, Xcode `26.4`, CocoaPods `1.16.2`, Java `17`; vẫn cần post-change run |
| Font bundle | Be Vietnam Pro 400/500/600/700 |

Nếu live version lệch, dừng trước quota-consuming hoặc mutation step, ghi toolchain delta và reverify compatibility. Figma/Stitch/MCP không lộ version thì ghi `not_exposed` cùng file/project ID, timestamp, prompt hash và output ID.

### 5.6 Protected paths và concurrency

UI lane không được ghi vào:

- `backend/**`;
- canonical API/Phase 2 route-data contracts;
- Day 34-38 engineering/QA/evidence;
- execution ledger hoặc roadmap ngoài append-only W9 artifact được cho phép;
- historical Figma sections/nodes.

Trình tự bắt buộc:

```powershell
$script = '.\scripts\ci\ui-v031\protected\verify-protected-paths.ps1'

& $script `
  -Mode Verify `
  -BaselineManifest '<artifact-root>\ui-v031-protected-baseline.json'

# Khi Day 38 tạo approved owner delta:
& $script `
  -Mode Verify `
  -BaselineManifest '<artifact-root>\ui-v031-protected-baseline.json' `
  -OwnerDeltaManifest '<artifact-root>\approved-owner-delta.json'
```

Đây là command contract đầy đủ; lệnh W9 viết tắt thiếu `-BaselineManifest` không được dùng nguyên văn. Owner delta phải khớp chính xác path, change type, before/after hash, baseline ID, approver và thời hạn; owner delta không phải rebaseline.

## 6. Day 37 — Rescue Backend Feature Test

**Loại ngày:** `TEST`

**Ledger status tại lúc khóa:** `IN PROGRESS`
**Mục tiêu:** chứng minh current Day 34-36 chain trên PostgreSQL disposable sạch, chạy độc lập backend test/coverage/static gates và tạo defect ledger; không sửa production.

### 6.1 Definition of Ready

- Day 36 trong ledger là `PASS` và source hashes tại mục 2.3 được ghi vào manifest mới.
- Addendum v1.2 đã tồn tại; Day 37 test matrix, output paths và defect schema đã khóa.
- Nguồn schema chỉ là local database `127.0.0.1|localhost|::1` có tên chính xác `pawmate` và bị ép read-only trong proof.
- Disposable DB có prefix `pawmate_day37_`; harness hard-fail remote host hoặc tên ngoài prefix.
- Portable `psql` và `pg_dump` được kiểm chứng trước khi mutation disposable DB.
- Không có cloud/Supabase write trong Day 37.

### 6.2 Allowlist

- `backend/tests/**` cho test/fixture Day 37;
- `backend/scripts/day37-rescue-clean-chain-proof.cjs` và test-only helper do nó sở hữu;
- `docs/qa/rescue-backend/day37*`;
- `output-evidence/day37/**`;
- append-only Day 37 evidence/status vào ledger sau khi có verdict.

### 6.3 Denylist

- `backend/src/**`;
- `backend/prisma/schema.prisma`;
- Day 34-36 patch/preflight/postflight/rollback SQL;
- dependency/lockfile và runtime config;
- mobile/Figma/UI wave artifacts;
- remote database, Supabase schema/storage hoặc production data.

Nếu test harness không thể hoàn tất mà không sửa production, giữ Day 37 `IN PROGRESS`, ghi `Day 37-deviation`; không tự mở rộng allowlist.

### 6.4 Command contract

| Gate | Working directory | Command | PASS artifact |
|---|---|---|---|
| Clean-chain proof | `backend/` | `node scripts/day37-rescue-clean-chain-proof.cjs --evidence-dir=output-evidence/day37/<run-id>` | `day37-clean-chain-result.json`, `manifest.json`, raw logs; exit `0` |
| Prisma validate | `backend/` | `npm run prisma:validate` | raw log, exit `0` |
| Prisma generate | `backend/` | `npm run prisma:generate` | raw log, exit `0` |
| Lint | `backend/` | `npm run lint` | raw log, exit `0` |
| Build | `backend/` | `npm run build` | raw log, exit `0` |
| Full test/coverage | `backend/` | `npm run test:coverage` trong same disposable-DB environment của harness | Jest JSON/LCOV/summary, exit `0` |
| Dependency audit | `backend/` | `npm audit --omit=dev --audit-level=high` | raw log, exit `0` |

Harness bắt buộc thực hiện theo thứ tự:

1. ghi Git/toolchain/source hashes và fingerprint nguồn;
2. dump schema-only từ local `pawmate` dưới read-only enforcement;
3. tạo DB disposable từ `template0` và restore schema;
4. rollback Day 36 -> 35 -> 34, xác minh target object trở về zero/Phase 1 baseline;
5. apply/preflight/postflight/idempotency Day 34 -> 35 -> 36;
6. chạy ba PostgreSQL integration suites cho foundation/read/write;
7. rollback lần hai, reapply current chain, chạy full backend coverage và static gates;
8. xác minh final schema metrics, drop disposable DB trong `finally` và so fingerprint nguồn trước/sau;
9. secret scan, hash artifact và phát hành manifest.

### 6.5 Output

- `docs/qa/rescue-backend/day37_rescue_backend_feature_test_report.md`;
- `docs/qa/rescue-backend/day37_rescue_traceability.csv`;
- `docs/qa/rescue-backend/day37_rescue_defect_ledger.csv`;
- `output-evidence/day37/<run-id>/manifest.json` và raw evidence;
- append-only ledger verdict và Day 38 opening recommendation.

### 6.6 PASS, FAIL và chuyển Day

Machine verdict:

- `PASS_TEST_EXECUTION`: chain, tests, coverage, static/audit và cleanup đều pass; không có defect.
- `COMPLETE_WITH_DEFECTS`: test execution hoàn tất nhưng có defect có severity, repro, evidence và owner.
- `FAILED_INFRA_OR_MIGRATION`: thiếu proof, cleanup/fingerprint fail, remote/unsafe target hoặc deterministic gate fail.

Ledger Day 37 chỉ được đổi sang `PASS` khi:

- toàn bộ testcase denominator đã chạy;
- migration apply/idempotency/rollback/reapply và source-read-only proof đạt;
- global/Rescue coverage gate đạt;
- lint/build/Prisma/audit đạt hoặc failure đã được chứng minh là overlapping concurrent-run artifact bằng một run cô lập mới;
- P0/P1/P2/P3 đều có repro, severity, owner và Day 38 disposition;
- disposable DB đã bị xóa, source fingerprint không đổi, evidence redaction/hash pass.

Day 37 có thể `PASS` với defect vì Day 38 là owning fix day, nhưng Day 39 vẫn bị chặn. Missing/invalid evidence giữ Day 37 `IN PROGRESS` hoặc `BLOCKED`; không được dùng một run xanh đơn lẻ để bỏ qua run canonical fail.

**Rollback:** drop đúng disposable DB, không rollback local source; giữ raw failed evidence.

**Approver:** Codex lead/QA owner cho test execution; backend owner nhận defect.

**Known exception:** không có retry deterministic. Concurrent-run artifact chỉ được loại sau một run cô lập có fingerprint tương ứng.

### 6.7 Checkpoint thực thi hiện tại và điều kiện mở Day 38

Evidence canonical mới nhất đang được ghi nhận tại `output-evidence/day37/final-20260722-1510/` có machine status **`COMPLETE_WITH_DEFECTS`**.

- clean-chain migration/rollback/reapply và focused PostgreSQL tests: exit `0`;
- full backend coverage: line `85.34%`;
- static lint, static build, Prisma validate và focused/full test đều exit `0`; chỉ còn một defect security `P1` `D37-DEPENDENCY_AUDIT_HIGH-01` do `fast-uri` high vulnerability, có raw-log path và owner disposition trong result artifact;
- machine status này **chưa tự đổi ledger Day 37** và **chưa phải G5A**.

Canonical evidence hashes:

| Artifact | SHA-256 |
|---|---|
| `output-evidence/day37/final-20260722-1510/manifest.json` | `810F388BEDC8AEEFCB5C235A775BA104149C44A98BEC24FA0453EB4459BA0BAC` |
| `output-evidence/day37/final-20260722-1510/day37-clean-chain-result.json` | `C7D539E13080EA3D5F21849414B04B37B0F57C3F2B7216110E775097A06F9832` |

Manifest xác nhận source fingerprint không đổi, disposable DB đã drop, redaction `PASS` và coverage line `85.34%`.

Vì vậy Day 38 được xem là **đủ điều kiện entry về mặt test execution**, nhưng ledger Day 37 vẫn giữ `IN PROGRESS` cho tới khi Codex lead/backend owner freeze Day 37 report và defect ledger. Row Day 38 vẫn `NOT STARTED` cho tới khi entry action được ghi nhận. Khi mở Day 38, input bắt buộc là:

1. Day 37 report, result/manifest và defect ledger hash-valid;
2. defect `D37-DEPENDENCY_AUDIT_HIGH-01` có root cause/repro/owner và exact changed-file allowlist;
3. bốn Product/BA decision IDs ở mục 7.1 hoặc decision record thay thế;
4. protected baseline và owner-delta contract;
5. snapshot source Day 37 để đo changed-source coverage.

Day 38 được phép sửa đúng defect đã frozen và chạy regression/integration; không được coi `COMPLETE_WITH_DEFECTS` là G5A hoặc dùng nó để mở Day 39.

## 7. Day 38 — Rescue Backend Fix, Verify và Integration / G5A

**Loại ngày:** `FIX/INTEGRATION/GATE`

**Entry:** Day 37 ledger `PASS`, hoặc machine verdict `COMPLETE_WITH_DEFECTS` khi defect ledger đã frozen. Các non-security gate gồm clean-chain, focused/full test, coverage, lint, build và Prisma validate đều phải `PASS`; từng defect phải có owner, repro, evidence và Day 38 exact allowlist. Product/BA decisions bắt buộc phải có ID.

`COMPLETE_WITH_DEFECTS` chỉ mở Day 38 để xử lý defect; nó không phải G5A.

### 7.1 Quyết định phải khóa trước production fix

| Decision ID | Hiện trạng được chứng minh | Quyết định cần phê duyệt trước G5A |
|---|---|---|
| `G5A-DEC-AUTH-01` | `GET /rescue/cases` và detail đang public, bearer tùy chọn | Chấp thuận runtime này hoặc yêu cầu auth; cập nhật SRS/traceability tương ứng |
| `G5A-DEC-PRIVACY-01` | Rounding ba chữ số không chứng minh displacement 500 m | Định nghĩa threat model và ý nghĩa `privacyRadiusMeters`; test đúng nghĩa đã chọn |
| `G5A-DEC-CONTACT-01` | Public mapper không trả `contactChannel`, `canViewPrivateContact=false` | Khuyến nghị giữ không có private-contact read/CTA trong scope hiện tại, hoặc phê duyệt contract khác |
| `G5A-DEC-OUTBOX-01` | Durable atomic producer/dedupe có bằng chứng; chưa có consumer/delivery | Khuyến nghị G5A chỉ claim producer; delivery consumer để scope riêng, không claim notification delivery |

Tạo addendum không đồng nghĩa bốn quyết định trên đã được Product/BA phê duyệt.

### 7.2 Allowlist

- File production/backend chính xác được nêu trong defect ledger và Day 38 source manifest;
- `backend/tests/**` và regression test liên quan;
- additive `backend/prisma/sql/day38_*` chỉ khi schema change được duyệt;
- canonical API/route-data/SRS traceability file nằm trong decision record;
- `docs/engineering/day38*`, `docs/qa/rescue-backend/day38*`, `output-evidence/day38/**`;
- owner-delta manifest cho UI protected-path reconciliation.

### 7.3 Denylist

- Sửa ngược Day 34-36 SQL lịch sử;
- feature mới ngoài defect/decision Day 37;
- mobile/Figma/W3-W9 implementation;
- cloud seed, destructive rollback hoặc blind full-patch reapply;
- mở rộng public DTO mà không có contract/permission/privacy test.

### 7.4 Thứ tự thực thi

1. Freeze defect ledger và exact changed-file allowlist.
2. Chốt bốn decision records tại mục 7.1.
3. Sửa P0 rồi P1; mỗi defect có regression test.
4. Nếu cần schema change, tạo additive/idempotent Day 38 preflight/patch/postflight; không sửa Day 34-36 patch.
5. Chạy focused retest rồi clean-chain harness đầy đủ trên disposable DB.
6. Chạy full DB/API/route/contract test, coverage, lint, build, Prisma và dependency audit.
7. Nếu không đổi SQL: cloud chỉ chạy read-only postflight/parity check.
8. Nếu đổi SQL: chỉ apply additive Day 38 patch sau approval, backup/preflight và fail-closed review; không seed/rollback production.
9. Tạo G5A machine proof, API readiness report và exact UI owner-delta manifest.
10. Independent review rồi mới cập nhật ledger/gate.

### 7.5 G5A PASS

- P0 = 0, P1 = 0.
- Current migration chain apply/idempotency/rollback/reapply pass trên DB disposable sạch.
- Auth, privacy, contact và outbox decision đã được phản ánh nhất quán trong SRS/contract/code/test.
- Public DTO/log/evidence không lộ owner ID, exact location, private contact, storage/hash metadata hoặc token.
- Permission, concurrency, version, idempotency, media cleanup, comment/status và outbox atomicity pass.
- Backend coverage và Day 38 changed-source coverage đạt mục 5.4.
- Cloud parity pass khi Day 38 có schema/storage change; nếu không đổi, read-only postflight pass.
- Owner delta khớp exact protected changes; secret/PII scan và artifact hashes pass.
- G5A report có backend owner, Codex lead/QA reviewer và Product/BA decision references.

**FAIL:** defect P0/P1, contract drift, missing clean-chain/cloud parity, coverage fail hoặc evidence mismatch.

**Rollback:** source snapshot Day 37; additive Day 38 rollback chỉ dùng ở local/staging theo approved runbook. Production failure kích hoạt stop/escalation, không tự chạy destructive rollback.

**Approver:** backend owner và Codex lead cho technical gate; Product/BA cho bốn product decisions.

## 8. UI convergence W2-W9 và G4B

### 8.1 Trạng thái đầu vào

| Wave | Trạng thái live | Khoản phải đóng |
|---|---|---|
| W2 | `NOT_PASS / STOPPED_FAIL_CLOSED` | S02 chưa inspectable; S03-S05 chưa chạy |
| W3 | `NOT_PASS` | 15/77 proof, 88 unsupported font nodes, 8 geometry violations, thiếu Product-approved 77-row matrix |
| W4-W6 | Implementation/runtime checks đã có kết quả xanh nhưng phụ thuộc W3 | Rerun hội tụ và phát hành append-only unconditional exit addenda |
| W7 | `IMPLEMENTATION_PASS / POST_CHANGE_IOS_CI_PENDING` | Post-change iOS simulator compile/render |
| W8 | `PARTIAL_PASS / FAIL_CLOSED` | W3/W7, 191 evidence-backed trace rows và 7 accessibility journeys |
| W9 | `NOT_READY / FAIL_CLOSED` | W8 PASS, manifests, protected reconciliation và joint G4B sign-off |

Nguồn trạng thái W2/W3/W7/W8/W9:

- [W2 manifest](../design/pawmate-v031-platform-ui/generated/W2_GENERATION_MANIFEST.md);
- [W3 audit](../qa/ui-v031/W3_FIGMA_LIVE_AUDIT_2026-07-22.md);
- [W7 report](../qa/ui-v031/W7_NATIVE_REPORT.md);
- [W8 report](../qa/ui-v031/W8_CROSS_PLATFORM_QA_REPORT.md);
- [W9 report](../qa/ui-v031/W9_HANDOFF_BLOCKED_REPORT.md).

### 8.2 W2 close hoặc approved no-use exception

1. Thử khôi phục S02 stable screen ID bằng read/list/get/export; không dùng model call.
2. Nếu S02 inspectable và đạt review, dùng tối đa ba call còn lại cho S03-S05; không retry.
3. Nếu không inspect được hoặc một call fail, dừng và xin Product Owner duyệt `EXC-W2-STITCH-NO-USE-01`.
4. Exception phải ghi Stitch output không là canonical source; W3 dùng locked native/Figma source.
5. W3 Definition of Ready trở thành `W2 PASS OR approved EXC-W2-STITCH-NO-USE-01`; không fake W2 PASS.

### 8.3 W3 contract

**Entry:** W2 PASS/approved exception; Product Owner duyệt matrix đúng 77 row gồm screen/state/viewport/source/target/safe-area/evidence.

#### W3 responsive denominator draft (chưa phải approval)

`W3-DENOM-DRAFT-2026-07-22` khóa cách đếm, không tự bịa các row còn thiếu:

| Denominator | Đã có bằng chứng | Mục tiêu contract | Cách hoàn tất |
|---|---:|---:|---|
| Responsive proof frames v0.32 | 15 | 77 | Bổ sung 62 row sau khi Product Owner duyệt matrix; mỗi row phải có source frame và target node |
| Row identity | 15 có thể truy hồi | 77 unique | `screen_id`, `state_id`, viewport, text scale, source/target section, safe-area và expected result |
| Evidence | 15 live-audit artifacts | 77 portable artifacts | Mỗi row có design node ID, screenshot/hash và manifest path; không dùng tên file để suy node ID |
| Quality checks | 8 geometry findings + 88 font findings đang mở | 0 geometry + 0 unsupported font | Recursive overflow, text-wrap và font validator chạy lại sau batch |

Viewport/state split cụ thể là **open input** của Product Owner; không được suy ra bằng cách nhân 56 screen với viewport hoặc clone hàng loạt cho đủ 77. Matrix được duyệt phải là artifact riêng, có denominator, owner, evidence ID và expected result trước khi W3 write.

**PASS:**

- 56/56 one-to-one v0.31 clones;
- 77/77 v0.32 responsive proof frames;
- unsupported font family = 0;
- direct/recursive overflow = 0 ở viewport/text scale đã duyệt;
- historical node fingerprint unchanged;
- Product Owner phê duyệt visual.

Chỉ sửa section `453:7374` và `453:10333`. Không rename/move/reparent historical nodes. Mọi Figma batch phải có metadata reread, screenshot, node-map/count/font/overflow validation và output-node evidence.

### 8.4 W4-W7 convergence

- Không rewrite báo cáo W4-W6 cũ. Sau W3 PASS, rerun exact foundation/router/module suites và phát hành append-only exit addendum.
- W4: 12/12 primitive goldens, token/contrast/focus/semantics/reduced-motion và CTA overflow pass.
- W5: toàn bộ route rows, auth redirect/`returnTo`, deep link, branch restore, tab reselect, Android root-back và iOS pushed-route behavior pass.
- W6: A-E pass, 71/71 runtime responsive goldens, enabled no-op CTA = 0; Rescue browse/create vẫn off.
- W7: publish source revision bằng isolated worktree/allowlist; post-change Codemagic iOS simulator compile/render pass. Commit/push/CI trigger cần user authorization riêng; không commit dirty main tree.

### 8.5 W8 contract

W8 chỉ re-enter khi W7 PASS, W3 PASS, trace contract frozen và manifests W0-W7 hợp lệ.

PASS bắt buộc:

- 56 screen rows, 44 route rows, 84 CTA rows và 7 accessibility rows có status/evidence hợp lệ; tổng 191 row không còn `PLANNED`;
- từng `PASS` row có test/assertion ID, repo-relative evidence path và artifact hash;
- 7/7 TalkBack journeys cho AUTH, HOME, VET, HEALTH, NOTIFICATIONS, PROFILE và RESCUE;
- post-change iOS simulator compile/render;
- 83/83 goldens, Flutter coverage threshold, Android API 34/35/36 và backend smoke pass;
- P0/P1 = 0; protected-path verification và redaction pass.

Trace row `BOTH` không được đánh `PASS` chỉ bằng Android proof. Chọn một trong hai trước W8:

1. chạy đủ VoiceOver journey trên iOS và giữ contract hiện tại; hoặc
2. Product Owner duyệt versioned trace change: G4B bắt buộc Android TalkBack + iOS automated semantics, bảy real-VoiceOver journeys chuyển sang G4C backlog riêng.

Nếu chưa có phê duyệt split, VoiceOver vẫn thuộc denominator hiện tại và chặn W8/G4B.

### 8.6 Wave manifests

Retrofit `wave-manifest.json` cho W0-W8 từ evidence thật. Không suy ra command/timestamp chưa tồn tại. Với field thiếu:

- rerun deterministic command trong đúng source snapshot; hoặc
- ghi `NOT_PROVEN`, tạo blocker và giữ wave chưa PASS.

Mỗi manifest phải validate schema, artifact-set equality, byte count, SHA-256, redaction và parent relationship. W9 tạo manifest kế nhiệm, không thay manifest lịch sử.

### 8.7 W9/G4B

**Definition of Ready:** W8 PASS; Day 38 owner delta/G5A đã reconcile; W0-W8 manifests hợp lệ; redaction scan pass.

**G4B PASS:**

- final analyze/test/golden/build smoke pass;
- manifest/hash/protected-path check pass;
- no secret/PII/sensitive Rescue location trong evidence;
- historical sources unchanged;
- known gaps ghi đúng, không claim G4C/production rollout;
- Product Owner và Codex lead cùng ký G4B.

G4C là optional real-device acceptance gate, không tự động chặn G4B chỉ khi versioned trace change đã được Product Owner duyệt. Compile/test failure hoặc thiếu post-change iOS simulator vẫn chặn W7/W8/G4B; signing-only real-device failure mới có thể chuyển G4C.

## 9. Feature flags và Day 39/40 behavior

| Capability | Dart define | Default/fallback | Activation dependency |
|---|---|---|---|
| Rescue browse | `PAWMATE_RESCUE_BROWSE_ENABLED` | `false` | D39-ENTRY pass; Day 39 behavior/evidence pass trước staging activation |
| Rescue create/update | `PAWMATE_RESCUE_CREATE_ENABLED` | `false`; forced false nếu browse false | Day 40 build/test gate; auth/owner/write contract pass |

Quy tắc:

- Compile-time, build-global; không remote config, không TTL/cache và không account targeting trong scope này.
- Missing/invalid value fail closed.
- Disabled root/deep link hiển thị honest unavailable state và gọi zero Rescue API/location/map/upload/persistence.
- Flag bật nhưng handler/API thiếu không được dùng fixture thay data thật; hiển thị unavailable/error/retry đúng contract.
- Current kill switch là rebuild/redeploy với hai flag `false`; không được mô tả là instant remote kill switch.
- Day 39 không bật create; Day 40 không mở nếu Day 39 chưa đạt gate.

Canonical mobile routes dùng contract UI hiện hành:

`/rescue`, `/rescue/create`, `/rescue/create/details`, `/rescue/map`, `/rescue/:caseId`, `/rescue/:caseId/comment`, `/rescue/:caseId/status`, `/rescue/:caseId/discussion`.

API routes vẫn là `/rescue/cases...`; không trộn mobile route với HTTP endpoint trong traceability.

## 10. D39-ENTRY convergence gate

Day 39 chỉ được đổi từ `NOT STARTED` sang `IN PROGRESS` khi một manifest `D39-ENTRY-<run-id>.json` chứng minh:

```text
SRS-CC-2026-07-22 = APPROVED
AND G5A = PASS
AND G4B = PASS
```

Manifest phải chứa:

- hash hai workbook SRS v1.1 và Product/BA approval reference;
- G5A report/manifest hash và bốn decision IDs;
- G4B report/manifest hash, W3/W8/W9 verdict và G4C disposition;
- protected baseline/owner-delta IDs;
- feature-flag defaults `false/false`;
- commit/source snapshot và reviewer/approver.

Nếu một điều kiện fail hoặc `NOT_PROVEN`, giữ Day 39 `NOT STARTED`. Design-only work có thể tiếp tục trong allowlist nhưng không được claim live Rescue integration.

## 11. Execution order và sign-off checklist

| Thứ tự | Backend lane | UI lane | Điều kiện hội tụ |
|---:|---|---|---|
| 0 | Khóa Day 37 source/test matrix | Khóa W2 decision và 77-row W3 matrix | Roadmap v1.2 tồn tại; SRS adoption pending được ghi rõ |
| 1 | Chạy clean-chain proof và Day 37 report | Đóng W2/exception rồi W3 | Không protected-path drift ngoài owner |
| 2 | Đóng Day 37, freeze defects | Rerun W4-W6, hoàn tất W7 iOS | Day 37 `PASS`, W3/W7 `PASS` |
| 3 | Day 38 fixes/decisions, full retest | Chuẩn bị W8 trace/device/a11y | Exact Day 38 owner delta |
| 4 | Ký G5A | Rerun W8, retrofit manifests | G5A owner delta được W8 reconcile |
| 5 | Giữ Rescue flags off | W9, joint G4B sign-off | G4B `PASS` |
| 6 | D39 entry review | D39 entry review | SRS approved + G5A + G4B |

### Approver matrix

| Quyết định/gate | Approver |
|---|---|
| SRS v1.1 adoption | Product/BA |
| W2 no-use exception và W3 77-row/visual | Product Owner |
| Day 37 test execution | Codex lead/QA owner |
| G5A technical | Backend owner + Codex lead |
| Auth/privacy/contact/outbox semantics | Product/BA, với backend owner xác nhận khả năng thực thi |
| W4-W8 technical gates | Codex lead/QA owner |
| G4C trace split/defer | Product Owner |
| G4B | Product Owner + Codex lead |
| Isolated CI branch push | User authorization riêng trước external mutation |

## 12. FAIL, rollback và amendment policy

- Addendum này không cho phép hạ gate để hợp thức hóa evidence thiếu.
- Nếu một contract sai, tạo v1.2.x successor addendum; không sửa lịch sử quyết định đã dùng để chạy.
- Nếu Day 37/38 scope phải đổi, ghi `<Day>-deviation` trước production/test mutation ngoài allowlist.
- Nếu W2/W3/W7/W8 fail, rollback đúng artifact/section/worktree của owning wave; không reset dirty main tree hoặc historical Figma.
- Nếu protected-path check fail, dừng UI lane; không rebaseline để che delta.
- Nếu D39-ENTRY fail, giữ Day 39 `NOT STARTED`; không mượn thời gian sang Day 39 feature.

## 13. Current open decisions

Các mục sau vẫn là input cần phê duyệt, không phải quyết định đã có:

1. `SRS-CC-2026-07-22`: Product/BA adoption hai workbook v1.1.
2. W2: dùng ba Stitch calls còn lại sau khi recover S02, hoặc duyệt `EXC-W2-STITCH-NO-USE-01`.
3. W3: matrix chính xác 77 responsive rows và final visual approval.
4. W8/G4C: chạy VoiceOver trong G4B hay tách bảy real-device journeys sang G4C.
5. W7: quyền tạo/push isolated source revision để chạy Codemagic.
6. G5A: auth, privacy 500 m, `contactChannel` và outbox producer-only scope.

Cho đến khi có decision record, các lane liên quan giữ fail-closed.

## 14. Execution checkpoint 2026-07-22 15:33 ICT

Checkpoint này cập nhật trạng thái thực thi, không sửa wave/day contract ở trên:

| Lane | Trạng thái hiện tại | Evidence / bước tiếp theo |
|---|---|---|
| Day 37 | `PASS` sau defect transfer | Canonical run ban đầu freeze một P1 dependency; Day 38 đã remediate và current clean-chain `PASS_TEST_EXECUTION` với defect count 0 |
| Day 38 technical | `PASS` | 32 suite/247 test; PostgreSQL focused 3/8; changed-source coverage 100%; lint/build/Prisma/audit/redaction PASS |
| G5A | `PENDING_PRODUCT_BA_APPROVAL` | Phải duyệt `G5A-DEC-AUTH-01`, `G5A-DEC-PRIVACY-01`, `G5A-DEC-CONTACT-01`, `G5A-DEC-OUTBOX-01` |
| W2/W3 | `FAIL_CLOSED` | Chờ Product Owner duyệt no-use exception và exact 77-row responsive matrix trước khi W4-W9/G4B tiếp tục |
| SRS v1.1 | `QA_PASS / PRODUCT_ADOPTION_PENDING` | Không suy diễn workbook QA pass thành Product/BA approval |
| D39-ENTRY | `CLOSED` | Day 39 giữ `NOT STARTED` cho đến khi `SRS APPROVED AND G5A PASS AND G4B PASS` |

Không phát sinh yêu cầu reopen Day 34-36: schema/storage không đổi, cloud parity Day 38 được chứng minh bằng chuỗi hash bất biến từ Day 36 và clean-chain current. Tài liệu trạng thái: [Day 38 status](../engineering/day38_rescue_backend_fix_verify_g5a_status.md), [G5A matrix](../qa/rescue-backend/day38_g5a_gate_matrix.md), [decision record](../architecture/day38_g5a_decision_record.md).

## 15. Approval checkpoint 2026-07-22 16:41 ICT

Product Owner/BA đã xác nhận các quyết định cần để re-enter UI lane:

- G5A: `APPROVE_ALL_4`; Day 38/G5A được phép chuyển `PASS` sau khi hash/evidence reconciliation.
- W2: `APPROVE_NO_USE_EXCEPTION`; W2 giữ `NOT_PASS_WITH_APPROVED_EXCEPTION`, Stitch reference-only.
- W3: exact `77` rows và seven-screen selection được approve.
- Allowlist: approve mutation chỉ trên v0.31/v0.32 new sections.
- SRS: `ADOPT_V1.1` với hash workbook hiện hành.
- VoiceOver: tách bảy real-device journeys sang G4C; không nằm trong G4B denominator.

Approval evidence: [Product Owner approval record](./pawmate_product_owner_approval_2026-07-22.md).

W3 được mở lại theo contract và đang `IN PROGRESS`; W4-W9 chưa được coi là PASS.
W8/W9/G4B chỉ được revalidate sau khi W3 post-write proof đạt 77/77 và W7 iOS
evidence/traceability gates được chạy lại.

## 16. Post-W3 convergence checkpoint — 2026-07-22 17:30 ICT

This append-only checkpoint supersedes the provisional statuses in section 14
and records the approved execution result without rewriting historical entries.

| Lane | Current status | Objective evidence / remaining condition |
|---|---|---|
| Day 37 | `PASS` | Canonical clean-chain remains hash-valid; no new Day 37 work was opened. |
| Day 38 / G5A | `PASS` | Four decision IDs approved; technical and product reconciliation recorded in the approval and G5A decision documents. |
| SRS v1.1 | `ADOPTED` | Product Owner approved `ADOPT_V1.1`; workbook hashes remain the adopted baseline. |
| W2 | `NOT_PASS_WITH_APPROVED_EXCEPTION` | `EXC-W2-STITCH-NO-USE-01`; Stitch remains reference-only. |
| W3 | `PASS` | 77/77 rows, v0.31 56 + v0.32 77 NativeEditable frames, zero unsupported fonts, zero geometry violations, historical fingerprints unchanged. |
| W4 | `PASS` | Post-W3 focused suite 57, analyze and bundle exit 0. |
| W5 | `PASS` | Post-W3 router/auth/navigation suite 82/82; historical golden blocker cleared by W6 full-suite rebaseline. |
| W6 | `PASS` | Full Flutter suite 411 + one intentional skip; visual subset 85/85; flags remain fail-closed. |
| W7 | `PARTIAL_PASS / POST_CHANGE_IOS_CI_PENDING` | Native/static and Android evidence pass; post-change iOS compile/render is not runnable on this Windows worktree without an authorized CI-visible revision or macOS runner. |
| W8 | `PARTIAL_PASS / FAIL_CLOSED` | Deterministic validators, 83/83 goldens, coverage, manifest and redaction pass. 191 trace rows remain planned; seven TalkBack journeys need row evidence. VoiceOver is moved to G4C. |
| W9 / G4B | `NOT_READY / FAIL_CLOSED` | Requires W7 iOS proof, W8 row-level transitions, fresh protected-path reconciliation and joint sign-off. |
| G4C | `PENDING` | Seven real-device VoiceOver journeys are intentionally outside G4B. |
| Day 39 | `NOT_STARTED / CLOSED` | Entry remains `SRS ADOPTED AND G5A PASS AND G4B PASS`; not met because G4B is closed. |

### Evidence anchors for this checkpoint

- W3: `docs/qa/ui-v031/W3_POST_WRITE_AUDIT_2026-07-22.json` and
  `docs/qa/ui-v031/W3_MATRIX_VALIDATION_POST_WRITE_2026-07-22.txt`.
- W4-W6: `docs/qa/ui-v031/W4_W5_W6_POST_W3_REVALIDATION_2026-07-22.json`;
  its protected-path subcheck is explicitly `FAIL_CLOSED_STALE_BASELINE` and
  is not presented as a fresh Day 37/38 PASS.
- W7-W9: `docs/qa/ui-v031/W7_NATIVE_REPORT.md`,
  `docs/qa/ui-v031/W8_CROSS_PLATFORM_QA_REPORT.md`,
  `docs/qa/ui-v031/W9_HANDOFF_BLOCKED_REPORT.md`.
- G4C backlog: `docs/qa/ui-v031/G4C_VOICEOVER_BACKLOG_2026-07-22.md`.
- Portable W8 manifest: `output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json`;
  validator PASS, status remains BLOCKED by the two explicit exceptions.

No Day feature is reopened by this checkpoint. The next authorized action is to
obtain a CI-visible post-change iOS run and complete evidence-backed W8 row
transitions, then rerun protected reconciliation before requesting G4B sign-off.

## 17. Approval and traceability successor checkpoint — 2026-07-22

Checkpoint append-only này thay thế số liệu W8 và trạng thái approval ở các
checkpoint trước; nội dung lịch sử không bị viết lại.

| Contract | Quyết định đã khóa | Trạng thái hiện hành |
|---|---|---|
| G5A | `G5A=APPROVE_ALL_4` | `PASS`; cả bốn Decision ID đã được Product/BA chấp thuận. |
| W2 | `W2=APPROVE_NO_USE_EXCEPTION` | `NOT_PASS_WITH_APPROVED_EXCEPTION`; `EXC-W2-STITCH-NO-USE-01` là ngoại lệ được duyệt, không biến Stitch thành bằng chứng thực thi. |
| W3 | `W3=APPROVE_77_ROWS_AND_7_SCREENS` | `PASS`; ma trận đúng 77 dòng và tập 7 màn đã được duyệt. |
| v0.31/v0.32 | `ALLOWLIST=APPROVE` | Allowlist mutation được duyệt; ngoài allowlist và các node lịch sử vẫn được bảo vệ. |
| SRS | `SRS=ADOPT_V1.1` | Hai workbook v1.1 được adopt nguyên byte/hash; không tái xuất workbook. |
| VoiceOver | `VOICEOVER=G4C` | VoiceOver thuộc G4C, nằm ngoài mẫu số G4B. |

G5A machine reconciliation:

- Artifact: [`g5a-product-approval-reconciliation-20260722.json`](../../output-evidence/day38/final-20260722-1533/g5a-product-approval-reconciliation-20260722.json).
- SHA-256: `58F4D77F8D38940A08B0ABEAD13520D64624DBE045C1C086413AF3538F1BED2A`.
- Verdict: `G5A_PASS`.
- Parent technical manifest SHA-256: `25B66518BB423898614582DA177BC581DD03AE704F7CA870CE4F45257ADEB9D6`.

W8 traceability hiện là `102 PASS / 89 PLANNED`. Chính xác 89 dòng còn thiếu
bằng chứng gồm 82 CTA và 7 Android TalkBack journey. Vì vậy G4B vẫn
`NOT_READY / FAIL_CLOSED` cho đến khi đồng thời có đủ 82 CTA, 7 Android
TalkBack, post-change iOS proof và joint sign-off. VoiceOver không còn là
blocker của G4B nhưng vẫn phải đóng riêng ở G4C.

Day 39 tiếp tục `NOT_STARTED / CLOSED`; việc G5A và SRS đã PASS không thay thế
điều kiện bắt buộc `G4B PASS` trong `D39-ENTRY`.

## 18. Terminal gate reconciliation — 2026-07-22 19:05 ICT

Checkpoint append-only này cập nhật trạng thái sau revalidation cuối, không sửa
lại các số liệu lịch sử ở các mục trước.

| Gate | Trạng thái hiện hành | Kết luận |
|---|---|---|
| Day 37 | `PASS` | Không reopen. |
| Day 38 / G5A | `PASS` | Cả bốn Decision ID đã được duyệt. |
| W2 | `NOT_PASS_WITH_APPROVED_EXCEPTION` | Ngoại lệ no-use hợp lệ, không claim đã dùng Stitch. |
| W3 | `PASS` | 77 dòng = 62 created + 15 inherited + 0 unexpected. |
| W4-W6 | `PASS` | Full Flutter 411 + 1 intentional skip; analyze PASS; golden/coverage PASS. |
| Protected paths | `PASS_WITH_APPROVED_OWNER_DELTA` | 50 exact changes: 38 added, 12 modified, 0 removed; không rebaseline. |
| W7 | `PARTIAL_PASS / POST_CHANGE_IOS_CI_PENDING` | Chưa có macOS/Xcode hoặc CI-visible revision được ủy quyền. |
| W8 | `PARTIAL_PASS / FAIL_CLOSED` | 102 PASS / 89 PLANNED; validator 17/17. |
| W9 / G4B | `NOT_READY / FAIL_CLOSED` | Còn 82 CTA, 7 Android TalkBack, post-change iOS proof và joint sign-off. |
| G4C | `PENDING` | VoiceOver theo dõi riêng, không nằm trong mẫu số G4B. |
| Day 39 | `NOT_STARTED / CLOSED` | `D39-ENTRY` chưa đạt vì G4B chưa PASS. |

Thử nghiệm TalkBack HOME bằng sáu lần Alt+Right không được tính PASS: sáu XML
giống hệt từng byte và không chứng minh focus chuyển target. Evidence âm được
lưu để ngăn việc tái sử dụng nhầm một run không hợp lệ làm bằng chứng nghiệm
thu. Protected-path gate đã đóng; nó không còn nằm trong danh sách blocker.

## 19. Pre-Day-39 G4B convergence — 2026-07-23 12:12 ICT

Checkpoint append-only này thay thế các số liệu `102 PASS / 89 PLANNED` ở trên.

| Gate | Trạng thái hiện hành | Kết luận |
|---|---|---|
| W3 | `PASS` | Giữ 77/77, không reopen. |
| CTA | `PASS` | 82/82 row manifests; CTA matrix 84/84 PASS. |
| Android TalkBack | `PASS` | 7/7 named journeys trên API 36, TalkBack 16, font scale 2.0. |
| Traceability | `PASS` | 191/191 PASS, 0 PLANNED; validator tests 19/19. |
| Flutter | `PASS` | Analyze sạch; 411 test PASS + 1 intentional skip; runtime golden 73/73. |
| Android post-instrumentation | `PASS` | APK thường được rebuild, bảo toàn, cài đúng hash và cold-launch sau clear data. |
| Coverage/native/protected paths | `PASS` | Coverage gate PASS; native 50/50; owner delta 38 added + 12 modified + 0 removed. |
| W7 iOS | `PARTIAL_PASS / POST_CHANGE_IOS_CI_PENDING` | Workflow đã có compile + boot/install/launch/screenshot/hash/log scan; chưa có revision CI-visible được ủy quyền. |
| W8 manifest | `VALID / WAVE_BLOCKED_BY_IOS` | 764 artifacts, redaction PASS, validator errors 0. |
| W9 / G4B | `NOT_READY / FAIL_CLOSED` | Chỉ còn post-change iOS proof và Product Owner joint sign-off. |
| G4C | `PENDING` | VoiceOver theo dõi riêng, ngoài mẫu số G4B. |
| Day 39 | `NOT_STARTED / CLOSED` | `D39-ENTRY` chưa đạt vì G4B chưa PASS. |

G4B joint-signoff contract:
`docs/qa/ui-v031/G4B_JOINT_SIGNOFF.md`. Portable W8 manifest hiện hành:
`output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/evidence-manifest.json`.
Không dùng Codemagic build trước rework để thay thế proof iOS post-change.

## 20. G4B approval closure — 2026-07-23 15:47 ICT

Product Owner đã xác nhận `G4B=APPROVE` cho immutable W8 manifest SHA-256
`3832C950AFCED7ADDFE8B7D828DFE7CD8E40A566F4B9147778203F1C35FCD7A1`
và source snapshot
`9D1E17293EF7532DAC0FC1ED286FDBCDF1027B200A00826C8AEEB6F836D52245`.
W7, W8, W9 và G4B chuyển `PASS`; VoiceOver giữ nguyên ở G4C.

Approval record:
`docs/management/pawmate_product_owner_g4b_approval_2026-07-23.md`.

`D39-ENTRY` chuyển từ `CLOSED` sang `READY_FOR_MACHINE_EVALUATION`, chưa tự
chuyển `PASS`. Day 39 chỉ được đổi thành `IN PROGRESS` sau khi manifest theo
mục 10 xác minh đồng thời SRS v1.1 adoption, G5A, G4B, protected baseline/owner
delta, feature flag defaults `false/false`, commit/source snapshot và
reviewer/approver.

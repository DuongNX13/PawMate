# PawMate Day 8 Android Functional E2E Test Cases

Ngày tạo: 11-05-2026
Owner: Functional QA agent
Phạm vi: Android E2E thủ công cho core MVP Day 1 -> Day 8
Artifact sở hữu: `docs/qa/day8_android_functional_testcases.md`

## 1. Scope Summary

Mục tiêu là cung cấp bộ testcase để main agent chạy trên Android emulator/device, tập trung functional flow cốt lõi thay vì visual audit riêng. Bộ testcase bám theo:

- Day 1: design system và accessibility baseline cho readable mobile UI, Vietnamese-first copy, tap target, text scale, contrast.
- Day 2: auth register/login/logout policy và vet finder acceptance criteria.
- Day 3: vet list/search/detail dùng backend data thật.
- Day 4: review trên vet detail, chống duplicate review, submit/list/helpful/report.
- Day 5: pet health timeline, add event, list/filter, empty/loading/error states.
- Day 6: reminder calendar, create/list/process, notification center list/read/read-all.
- Day 7: pet/profile cohesion, logout/session behavior.
- Day 8: full manual QA, accessibility pass, Appetize/Render verified auth proof, regression matrix.

Out of scope:

- Không điều khiển Android simulator trong artifact này.
- Không sửa source code.
- Không sửa `docs/qa/day8_android_uiux_figma_audit.md`.
- Không claim 100% coverage cho OAuth, OTP expiry, lockout 15 phút, concurrent device limit, Apple signing, push notification thật, hoặc map/nearby Day 9 nếu app/build hiện tại chưa expose deterministic UI path.

## 2. Preconditions

| ID | Precondition |
|---|---|
| PRE-01 | Android emulator/device đã cài PawMate Day 8 build trỏ về Render backend `https://pawmate-api-yteu.onrender.com` hoặc môi trường tương đương do main agent xác nhận. |
| PRE-02 | Có verified QA account đã seed trên cloud DB. Không ghi password thật vào evidence/chat; dùng secret từ cấu hình an toàn của main agent. |
| PRE-03 | Có thể tạo fresh email dạng `qa.day8.android+<timestamp>@example.com` để kiểm tra register/unverified policy. |
| PRE-04 | Device có mạng ổn định; nếu dùng proxy/network capture, bật trước khi chạy để lưu status code endpoint. |
| PRE-05 | Trước mỗi run, ghi lại build id/commit, backend base URL, device model, Android version, font scale, theme mode, thời gian chạy. |
| PRE-06 | Nếu cần data sạch, dùng account mới hoặc account QA riêng cho run để tránh duplicate review/reminder/pet làm nhiễu expected result. |

## 3. Test Data

| Data ID | Giá trị đề xuất | Dùng cho |
|---|---|---|
| TD-AUTH-VERIFIED | Verified QA email/password từ secret/config build | Login thành công, protected flows |
| TD-AUTH-FRESH | `qa.day8.android+<yyyyMMddHHmmss>@example.com` / password theo auth policy | Register mới và unverified login |
| TD-AUTH-BAD | Verified QA email / `WrongPass!234` | Login sai password |
| TD-PET-01 | Name `Milo E2E`, species `dog`, gender `male`, breed `Poodle`, weight `7.4`, color `Nâu`, health `healthy`, microchip `E2E-<timestamp>` | Pet create/detail/edit |
| TD-PET-EDIT | Name `Milo E2E Updated`, weight `7.8`, health `monitoring`, neutered `true` | Pet edit/update |
| TD-HEALTH-01 | Type `Vaccine`, date hôm nay, note `Tiêm nhắc E2E Android <timestamp>`, clinic `PawCare QA` | Health record create/list |
| TD-REM-01 | Title/note `Nhắc uống thuốc E2E <timestamp>`, pet `Milo E2E`, due date hôm nay hoặc ngày gần nhất có thể chọn, repeat rule `none` hoặc default | Reminder create/list/process |
| TD-VET-QUERY | `pet`, `quan`, hoặc tên clinic xuất hiện trong seed; filter city/service nếu UI có | Vet search/list/detail |
| TD-REVIEW-01 | Rating `5`, content `Review E2E Android <timestamp>` | Vet review submit/list |

## 4. Requirement Inventory

| REQ_ID | Day/Feature | Acceptance Criteria / Rule | Priority | Evidence required |
|---|---|---|---|---|
| REQ-001 | Day 2 Auth Register | Valid email/password can register; malformed and duplicate email rejected clearly. | P0 | Screenshot + network status `/auth/register` |
| REQ-002 | Day 2/8 Auth Policy | Fresh unverified login is rejected with clear policy; `403 AUTH_006` is accepted behavior. | P0 | Screenshot + network status `/auth/login` |
| REQ-003 | Day 2/8 Verified Login | Verified QA account logs in and reaches authenticated pet list; session saved. | P0 | Screenshot + network status `/auth/login` 200 and `/pets` 200 |
| REQ-004 | Day 2/7 Logout/Session | Logout clears active session; protected screen is not accessible as signed-in user after logout/restart. | P0 | Before/after screenshots + network/auth state |
| REQ-005 | Day 2 Pet Contract | Pet list loads current user's pets and empty state has CTA. | P0 | Screenshot pet list/empty state |
| REQ-006 | Day 2/7 Pet Create | Create requires name/species/gender and successful pet appears in detail/list. | P0 | Screenshot form, detail/list, network `/pets` 201 |
| REQ-007 | Day 2/7 Pet Edit | Editable pet fields persist after save and reload. | P1 | Screenshot before/after + network `/pets/{id}` 200 |
| REQ-008 | Day 5 Health | Create health record and see it on timeline; optional clinic/note/date hierarchy is clear. | P0 | Screenshot form and timeline + network 201/200 |
| REQ-009 | Day 5 Health States | Empty/filter/error/loading states do not break layout. | P1 | Screenshots per state where reproducible |
| REQ-010 | Day 6 Reminder | Create reminder and see it in selected day/upcoming list. | P0 | Screenshot + network `/reminders` 201/200 |
| REQ-011 | Day 6 Reminder Process | Due reminder processing creates visible notification or process result without duplicate spam. | P1 | Screenshot notification/list + network process endpoint |
| REQ-012 | Day 6 Notifications | Notification list/read/read-all update unread state correctly. | P0 | Screenshot unread/read states + network read endpoint |
| REQ-013 | Day 3 Vet Search | Vet list/search renders backend data; filters/search show result or clear empty state. | P0 | Screenshot + network `/vets/search` 200 |
| REQ-014 | Day 3 Vet Detail | Vet detail renders backend clinic data and CTAs are usable/non-crashing. | P0 | Screenshot detail + CTA behavior |
| REQ-015 | Day 4 Reviews | Submit one review, list it on detail, aggregate/review count updates where visible. | P0 | Screenshot submit + list + network 201 |
| REQ-016 | Day 4 Review Policy | Same user cannot review same vet twice; duplicate is blocked clearly. | P1 | Screenshot duplicate message + network 409 if captured |
| REQ-017 | Day 4 Review Actions | Helpful/report actions work or fail with clear feedback. | P2 | Screenshot/snackbar + network status |
| REQ-018 | Day 1/8 Accessibility | Core flows have no severe tap target, text scale, contrast, clipping, or unreadable Vietnamese copy issues. | P1 | Screenshot at normal and large text where possible |
| REQ-019 | Day 8 Regression | E2E flow can move Auth -> Pet -> Health -> Reminder -> Notification -> Vet/Review without app crash. | P0 | Continuous run notes + screenshots |

## 5. Coverage Matrix

| Scenario_ID | TC_ID | Priority | Requirements |
|---|---|---|---|
| SCN-AUTH-REGISTER-POLICY | TC-P0-001, TC-P0-002, TC-P1-003 | P0/P1 | REQ-001, REQ-002 |
| SCN-AUTH-VERIFIED-SESSION | TC-P0-004, TC-P0-005 | P0 | REQ-003, REQ-004 |
| SCN-PET-MVP | TC-P0-006, TC-P0-007, TC-P1-008 | P0/P1 | REQ-005, REQ-006, REQ-007 |
| SCN-HEALTH-MVP | TC-P0-009, TC-P1-010 | P0/P1 | REQ-008, REQ-009 |
| SCN-REMINDER-NOTIFICATION | TC-P0-011, TC-P1-012, TC-P0-013 | P0/P1 | REQ-010, REQ-011, REQ-012 |
| SCN-VET-REVIEW | TC-P0-014, TC-P0-015, TC-P0-016, TC-P1-017, TC-P2-018 | P0/P1/P2 | REQ-013, REQ-014, REQ-015, REQ-016, REQ-017 |
| SCN-A11Y-REGRESSION | TC-P1-019, TC-P0-020 | P0/P1 | REQ-018, REQ-019 |

## 6. Executable Test Cases

### TC-P0-001 - Register fresh account returns created and explains verification policy

Traceability: Day 2 Auth Register, Day 8 Appetize policy, REQ-001
Type: Functional, Regression
Precondition: PRE-01, PRE-03

Steps:
1. Launch app from a clean/signed-out state.
2. Navigate to Register.
3. Enter `TD-AUTH-FRESH` email and a valid password.
4. Submit registration.
5. Capture network/status if available.

Expected:
5.1 App shows success/next-step message telling user to verify/check email, or navigates to OTP/verification surface.
5.2 Backend response is `201` for `/auth/register`.
5.3 App does not auto-login this unverified account.

Evidence: register screen before submit, success/verification screen, network line for `/auth/register`.

### TC-P0-002 - Fresh unverified user cannot login before email verification

Traceability: Day 2 Unverified Email, Day 8 accepted policy, REQ-002
Type: Functional, Negative, Regression
Precondition: TC-P0-001 completed with same fresh email.

Steps:
1. Navigate to Login.
2. Enter the fresh unverified email from TC-P0-001.
3. Enter the same password.
4. Submit login.
5. Capture UI error and network/status.

Expected:
5.1 Login is rejected.
5.2 UI message clearly tells user verification is required or login is not yet allowed.
5.3 Network shows `/auth/login` rejected with expected unverified policy, known as `403 AUTH_006` in Day 8 evidence.
5.4 App remains signed out and does not show pet list.

Evidence: error screen/snackbar, network line `/auth/login` 403/AUTH_006.

### TC-P1-003 - Register validation rejects malformed or duplicate email

Traceability: Day 2 Auth Edge Cases, REQ-001
Type: Functional, Negative
Precondition: PRE-01.

Steps:
1. Open Register.
2. Enter malformed email `bad-email` and valid password.
3. Submit.
4. Replace email with an existing verified QA email.
5. Submit again only if this will not disturb the QA account.

Expected:
5.1 Malformed email is rejected before or during submit with clear message.
5.2 Duplicate email is rejected with clear conflict message if exercised.
5.3 No authenticated session is created.

Evidence: validation/error screenshots; network 400/409 if request is sent.

### TC-P0-004 - Verified QA login reaches authenticated pet list

Traceability: Day 2 Login, Day 8 verified Appetize path, REQ-003
Type: Functional, Regression
Precondition: PRE-01, PRE-02.

Steps:
1. Open Login from a signed-out state.
2. Enter verified QA account email/password from secure config.
3. Submit login.
4. Wait until authenticated landing screen is stable.
5. Capture network/status.

Expected:
5.1 `/auth/login` returns `200`.
5.2 App navigates to pet list, route equivalent to `/pets`.
5.3 `/pets` loads successfully or shows a valid empty state with create CTA.
5.4 No token or password appears in screenshot/log notes.

Evidence: login success transition, pet list screenshot, network `/auth/login` 200 and `/pets` 200.

### TC-P0-005 - Logout clears session and protects authenticated state

Traceability: Day 2 Logout, Day 7 session cohesion, REQ-004
Type: Functional, Security, Regression
Precondition: TC-P0-004 passed.

Steps:
1. From an authenticated screen, navigate to Profile/account area if available.
2. Tap Logout/Đăng xuất if available.
3. Confirm logout if a confirmation appears.
4. Kill and relaunch the app.
5. Try to open an authenticated route through normal navigation.

Expected:
5.1 Logout returns user to Login/onboarding signed-out state.
5.2 Stored session is cleared; relaunch does not silently restore authenticated pet list.
5.3 Protected data is not visible until login again.
5.4 If logout UI is not exposed in current build, record as coverage blocker rather than passing.

Evidence: profile/logout screenshot, post-relaunch screen, note whether logout UI is missing.

### TC-P0-006 - Pet list loads and empty state has usable create CTA

Traceability: Day 2 Pet Profile, Day 7 pet cohesion, REQ-005
Type: Functional, Regression
Precondition: TC-P0-004 passed.

Steps:
1. Navigate to pet list.
2. Wait for loading to finish.
3. If no pet exists, inspect empty state.
4. Tap the add pet CTA/FAB.

Expected:
4.1 Existing pets render as cards with name/species/status.
4.2 Empty state is not blank and includes a clear add pet action.
4.3 Add action opens create pet form.
4.4 No crash or endless loading.

Evidence: pet list/empty state screenshot, create form screenshot.

### TC-P0-007 - Create pet profile persists and opens detail

Traceability: Day 2 Pet Contract, Day 7 Pet Flow, REQ-006
Type: Functional, Regression
Precondition: TC-P0-004 passed.

Steps:
1. Open Create Pet.
2. Enter TD-PET-01 required fields: name, species, gender.
3. Fill optional fields that are visible: breed, weight, color, health status, microchip, neutered.
4. Submit save.
5. Wait for navigation/result.
6. Return to pet list.

Expected:
6.1 `/pets` create returns `201` if network capture is available.
6.2 App opens pet detail or shows saved pet in list.
6.3 Displayed pet values match submitted values, especially name/species/gender/health status.
6.4 Required field validation prevents save if name/species/gender is missing.

Evidence: filled form, saved detail/list, network `/pets` 201.

### TC-P1-008 - Edit pet profile persists after reload

Traceability: Day 2 Pet Update, Day 7 Pet Flow Regression, REQ-007
Type: Functional, Regression
Precondition: TC-P0-007 passed and edit UI exists.

Steps:
1. Open the pet created in TC-P0-007.
2. Open edit action if available.
3. Change values using TD-PET-EDIT.
4. Save.
5. Navigate away and back to pet detail/list.

Expected:
5.1 Updated values persist after navigation/reload.
5.2 Network shows update success for `/pets/{petId}` if captured.
5.3 If edit UI is missing in current Android build, mark as blocked with screenshot of pet detail and available actions.

Evidence: before/after screenshots, blocked evidence if edit action absent.

### TC-P0-009 - Create health record and verify it appears on timeline

Traceability: Day 5 Health Timeline, REQ-008
Type: Functional, Integration, Regression
Precondition: TC-P0-007 passed; one pet exists.

Steps:
1. Navigate to Health tab/screen.
2. Select TD-PET-01 if pet picker exists.
3. Tap add health event/record.
4. Enter TD-HEALTH-01.
5. Save.
6. Return to health timeline and refresh if needed.

Expected:
6.1 Create request succeeds with `/pets/{petId}/health-records` `201` if captured.
6.2 New record appears on timeline/list.
6.3 Date, note, clinic/vet, and type/category are readable.
6.4 Long note and optional empty fields do not break layout.

Evidence: add form, saved timeline, network 201 and list 200.

### TC-P1-010 - Health timeline filter/empty/error states are understandable

Traceability: Day 5 Health States, Day 8 Accessibility, REQ-009
Type: Functional, Negative, Accessibility
Precondition: Authenticated account with at least one pet.

Steps:
1. Open Health timeline.
2. Switch any visible filter tabs/category controls.
3. Select a category/date state likely to have no records.
4. If safe, temporarily disable network and trigger refresh, then restore network.

Expected:
4.1 Filtered list only shows matching records or a clear empty state.
4.2 Empty state has readable guidance and no broken spacing.
4.3 Error state, if triggered, shows retry path and app recovers after network returns.

Evidence: filter state screenshots, empty/error/recovery screenshots.

### TC-P0-011 - Create reminder and see it in calendar/upcoming list

Traceability: Day 6 Reminder Calendar, REQ-010
Type: Functional, Integration, Regression
Precondition: TC-P0-007 passed; one pet exists.

Steps:
1. Navigate to Health then Reminders/Lịch nhắc.
2. Tap add reminder.
3. Select pet TD-PET-01 if picker exists.
4. Enter TD-REM-01 title/note/date/time/repeat rule using visible controls.
5. Save.
6. Check selected day and upcoming list.

Expected:
6.1 Create request succeeds with `/pets/{petId}/reminders` `201` if captured.
6.2 Reminder appears under selected day or upcoming list.
6.3 Reminder card shows pet, due time/date, title/note/status clearly.
6.4 No duplicate card appears after one save.

Evidence: add reminder sheet, saved reminder card, network 201/list 200.

### TC-P1-012 - Process or complete due reminder produces stable state

Traceability: Day 6 Reminder Process, Day 8 board notes that cron is disabled/manual dispatch available, REQ-011
Type: Functional, Integration, Regression
Precondition: TC-P0-011 passed with a due/near-due reminder.

Steps:
1. Open reminder list.
2. Use visible menu/action to mark reminder done if available.
3. If main agent has a safe manual process endpoint/tool, run it outside app and then refresh app.
4. Open notifications.

Expected:
4.1 Reminder done/process action succeeds or shows a clear unsupported state.
4.2 If processing due reminder is available, related notification appears.
4.3 Scheduled cron is not required for this testcase; do not mark failure solely because cron is disabled.
4.4 App does not create repeated duplicate notifications from one manual process run.

Evidence: reminder before/after, process evidence if used, notification result.

### TC-P0-013 - Notification list, mark read, and read-all update unread state

Traceability: Day 6 Notifications, REQ-012
Type: Functional, Regression
Precondition: Authenticated account; at least one notification exists or can be produced from TC-P1-012.

Steps:
1. Navigate to Notifications.
2. Observe unread banner/count and notification cards.
3. Mark one unread notification as read using tap/menu.
4. Refresh or reopen Notifications.
5. Use Read all/Đọc hết if there are unread notifications.

Expected:
5.1 Notification list loads via `/notifications` `200` if captured.
5.2 Mark-read action changes that item from unread to read.
5.3 Read-all clears unread count and updates visible styling.
5.4 Empty/all-read state remains clear and not blank.

Evidence: unread state, after mark-read state, after read-all state, network read/read-all status.

### TC-P0-014 - Vet search/list renders backend clinic data and handles no-result state

Traceability: Day 2 Vet Finder, Day 3 backend vet data, REQ-013
Type: Functional, Regression
Precondition: TC-P0-004 passed.

Steps:
1. Navigate to Vet list.
2. Wait for list load.
3. Search using TD-VET-QUERY.
4. Apply one visible city/service/rating/open-now filter if available.
5. Search with an unlikely string such as `zzzz-no-vet-e2e`.

Expected:
5.1 Vet list/search uses backend data and `/vets/search` returns `200` if captured.
5.2 Result cards show clinic name, city/district/address/service/rating data where available.
5.3 Filters use AND behavior where visible and do not crash.
5.4 No-result search shows clear empty state and a way to recover.

Evidence: default list, searched/filtered list, no-result state, network `/vets/search`.

### TC-P0-015 - Vet detail renders clinic data and CTA behavior is safe

Traceability: Day 3 Vet Detail, REQ-014
Type: Functional, Regression
Precondition: TC-P0-014 has at least one result.

Steps:
1. Tap first vet result.
2. Wait for detail screen.
3. Inspect clinic name, address, phone, services, open hours, rating/review summary.
4. Tap `Gọi ngay` if safe on emulator, then cancel/return.
5. Tap `Chỉ đường` if visible and safe, then cancel/return.

Expected:
5.1 `/vets/{vetId}` returns `200` if captured.
5.2 Detail data matches selected clinic and does not show placeholder-only content.
5.3 CTA opens phone/maps intent or shows clear fallback; no crash/snackbar-only placeholder unless explicitly accepted by current spec.
5.4 Back navigation returns to vet list with state understandable.

Evidence: detail screenshot, CTA result screenshot, network detail 200.

### TC-P0-016 - Submit review and verify it appears on vet detail/list

Traceability: Day 4 Review Core, REQ-015
Type: Functional, Integration, Regression
Precondition: TC-P0-015 passed; use a vet not yet reviewed by this QA account if possible.

Steps:
1. On vet detail, open write review.
2. Select rating `5`.
3. Enter TD-REVIEW-01 content.
4. Submit review.
5. Wait for success message and detail refresh.
6. Open review list/section.

Expected:
6.1 Review submit returns `201` for `/vets/{vetId}/reviews` if captured.
6.2 Success feedback appears.
6.3 Review content/rating appears in review section/list.
6.4 Rating/review count updates where the UI exposes aggregate values.

Evidence: write review sheet, success snackbar, review visible in list/detail, network 201.

### TC-P1-017 - Duplicate review by same user is blocked clearly

Traceability: Day 4 Anti-duplicate Review Rule, REQ-016
Type: Functional, Negative, Regression
Precondition: TC-P0-016 passed using same account/vet.

Steps:
1. Stay on or reopen same vet detail.
2. Attempt to open write review again or submit another review.
3. Capture result.

Expected:
3.1 UI blocks the second review up front, or backend rejects with `409`.
3.2 User sees clear message that this vet has already been reviewed or cannot be reviewed twice.
3.3 Existing review remains unchanged unless edit flow is explicitly provided.

Evidence: blocked UI or network 409, no duplicate in list.

### TC-P2-018 - Review helpful/report actions provide feedback

Traceability: Day 4 Review Actions, REQ-017
Type: Functional, Regression
Precondition: A review is visible on vet detail/list.

Steps:
1. Open review list or review section.
2. Tap Helpful/Hữu ích on one review.
3. Observe count/state.
4. Tap Report/Báo cáo if visible.
5. Confirm report if a dialog/sheet appears.

Expected:
5.1 Helpful action toggles or gives clear feedback; no crash.
5.2 Report action shows confirmation/success or clear error.
5.3 Hidden/moderated behavior does not remove unrelated review content unexpectedly.

Evidence: before/after helpful, report confirmation/success/error.

### TC-P1-019 - Accessibility smoke across core MVP screens

Traceability: Day 1 Design System, Day 8 Accessibility, REQ-018
Type: Accessibility, Regression
Precondition: TC-P0-004 passed.

Steps:
1. Run through Login, Pet list/create/detail, Health, Reminder, Notification, Vet list/detail/review.
2. Repeat key screens with Android font scale increased if main agent can safely change device setting.
3. On each screen, inspect primary buttons, cards, input labels, error text, bottom navigation, and sheet controls.
4. Capture any clipping/overlap/tap target issue.

Expected:
4.1 Text remains readable and not clipped on core screens.
4.2 Primary controls are large enough to tap reliably.
4.3 Error states use readable color/contrast and plain Vietnamese guidance.
4.4 Bottom navigation active state remains clear.
4.5 No P0/P1 accessibility issue remains before Day 8 sign-off.

Evidence: screen set at normal scale and any large-text issue screenshots; note font scale.

### TC-P0-020 - Full Day 1 -> Day 8 core journey regression

Traceability: Day 8 E2E critical flow, REQ-019
Type: End-to-End, Regression
Precondition: PRE-01 through PRE-06.

Steps:
1. Start signed out.
2. Verify fresh register/unverified login policy using TC-P0-001 and TC-P0-002, or reuse already captured Day 8 evidence if quota/time is constrained.
3. Login with verified QA account.
4. Create or confirm one pet.
5. Create one health record for that pet.
6. Create one reminder for that pet.
7. Process/complete reminder where supported.
8. Open notifications and mark notification read/read-all.
9. Search vet, open detail, submit/read review where account/vet allows.
10. Logout or record blocker if logout UI is not exposed.

Expected:
10.1 The app completes the journey without crash, blank screen, or dead-end navigation.
10.2 Each MVP module persists or displays the record created in the same run.
10.3 Auth policy remains correct: unverified login blocked, verified login allowed.
10.4 No P0/P1 functional blocker remains untriaged.

Evidence: one run note with timestamps, screenshots at each module, network snippets for auth/pets/health/reminders/notifications/vets/reviews.

## 7. Expected Evidence Package

Main agent should capture at minimum:

- Device/build metadata: Android device/emulator, Android version, app build id/commit, backend URL, test account class, start/end time.
- Screenshots:
  - Register success/verification message.
  - Unverified login policy error.
  - Verified login reached pet list.
  - Pet create form and saved detail/list.
  - Health record form and timeline after save.
  - Reminder create sheet and upcoming/calendar after save.
  - Notification unread/read/read-all states.
  - Vet search/list, detail, review submit/list.
  - Logout or missing logout blocker.
  - Accessibility large-text issues if any.
- Network evidence where available:
  - `POST /auth/register` -> `201`.
  - `POST /auth/login` unverified -> `403 AUTH_006`.
  - `POST /auth/login` verified -> `200`.
  - `GET /pets` -> `200`, `POST /pets` -> `201`.
  - `POST/GET /pets/{petId}/health-records`.
  - `POST/GET /pets/{petId}/reminders`.
  - Reminder process/read path used by current app/backend if applicable.
  - `GET /notifications`, mark read/read-all endpoint.
  - `GET /vets/search`, `GET /vets/{vetId}`, `POST /vets/{vetId}/reviews`.
- Logs:
  - Android logcat excerpt only around failures.
  - Do not include passwords, tokens, refresh tokens, or full auth headers.

## 8. Residual Coverage Risk

| Risk | Priority | Reason | Mitigation |
|---|---|---|---|
| OAuth conflict, OTP expiry, 5-attempt lockout, and 3-session limit may not be reproducible from current Android UI. | P1 | Day 2 AC includes them, but Day 8 scope and current app surfaces may not expose deterministic controls. | Track as API/contract regression or separate auth hardening suite; do not block this Android MVP run unless UI claims support. |
| Logout flow may be absent or stubbed in current build. | P0 | Day 7 plan mentions logout stub/real local clear; source scan only confirms session store clear capability, not guaranteed UI exposure. | Main agent must capture missing logout UI as blocker if no route/action exists. |
| Pet edit UI may be absent even though API supports update. | P1 | Current route scan shows create/detail/list; edit action must be verified live. | Mark TC-P1-008 blocked if no edit entry point. |
| Reminder process behavior depends on manual dispatch because cron remains disabled. | P1 | Day 8 board says scheduled worker cron remains disabled. | Verify via visible app action or safe manual dispatch; do not expect background cron. |
| Review duplicate test can be polluted by prior QA data. | P1 | Same account/vet may already have a review. | Use a known unreviewed vet or treat existing review as setup and run duplicate-block assertion only. |
| Full accessibility sign-off still requires live Android visual capture. | P1 | This artifact defines testcases; it does not operate simulator. | Main agent captures normal and large text screenshots and files issues separately. |
| Map/nearby full Day 9 behavior is not covered. | P2 | Day 8 focuses vet search/detail/reviews; Day 9 owns map only if data ready. | Keep map/nearby as optional exploratory evidence, not Day 8 exit blocker. |

## 9. Sign-off Guidance

Day 8 functional Android E2E can be signed off only if:

- All P0 testcases pass or have accepted product-policy evidence.
- No P0/P1 crash, blank screen, auth bypass, lost core record, or unreadable blocking UI remains.
- P1 blocked cases are explicitly documented with screenshot and reason.
- Evidence package is saved under the Day 8 QA evidence folder selected by main agent.
- Secrets are redacted from screenshots/logs.

Recommended execution order:

1. TC-P0-001 -> TC-P0-005 for auth/session.
2. TC-P0-006 -> TC-P1-008 for pet list/create/edit.
3. TC-P0-009 -> TC-P1-010 for health.
4. TC-P0-011 -> TC-P0-013 for reminders/notifications.
5. TC-P0-014 -> TC-P2-018 for vet/reviews.
6. TC-P1-019 and TC-P0-020 as final accessibility/regression pass.

# PawMate Phase 1 Quality-First Plan

Date: `2026-04-23`  
Project root: `D:\My Playground\PawMate`

## Summary

- Phase 1 khong tiep tuc theo nhip `Day 3-5 = feature sprint ngan` nua; chuyen sang `quality-first delivery wave` keo tu `Day 3` den `Day 10`.
- Source of truth ve UI/UX la Figma file `Pawmate Desgin`, page `PawMate Stitch Intake`, section `Confirmed Screens`.
- Scope MVP giu nguyen:
  - email-first auth
  - pet profile
  - vet directory
  - review core
  - health timeline
  - reminder
  - notification center
  - profile
- `Google/Apple sign-in` tiep tuc deferred trong toan bo Phase 1.
- `Vet Nearby/Map` khong con la phan phai hoan tat o dau Day 3; chi mo sau khi du lieu vet du `lat/lng/openHours/services/photoUrls/is24h`.
- Milestone cuoi Phase 1 la `RC-ready`, khong phai "den ngay la TestFlight".

## Current Ground Truth

- Day 2 auth da chot that:
  - local user verified
  - remote Supabase user confirmed
  - auth live proof da xanh
- Current Day 2 board:
  - `12/20 DONE`
  - `6/20 PARTIAL`
  - `2/20 DEFERRED`
- Vet mobile hien tai van la thin-slice:
  - `vet_list_screen.dart` dang doc `vet_demo_data.dart`
  - `vet_detail_screen.dart` van la placeholder data + placeholder intents
  - `vet_map_screen.dart` moi la placeholder screen
- Backend hien chua co vet routes:
  - routes moi co `auth.ts`, `pets.ts`, `health.ts`, `web.ts`
- Figma hien co visual language ro nhung chua co local design system:
  - `collections = []`
  - `components = 0`
- Fonts tren current page xac nhan:
  - `Be Vietnam Pro` cho heading/body chinh
  - `Inter` cho label/meta/UI utility

## Design Review Conclusions

- Product dang theo huong visual `editorial mobile utility app`, khong phai generic CRUD app.
- Chat luong se truot nhanh neu tiep tuc lam screen-by-screen ma khong chuan hoa token/component truoc.
- Nhung pattern visual phai duoc productionize:
  - floating bottom nav voi active pill nhat quan
  - translucent top bars
  - rounded card system
  - warm CTA hierarchy
  - chip/tag system
  - form field grammar
  - state card grammar
- `Confirmed Screens` phai duoc uu tien hon cac batch editable/generated neu co conflict.

## Phase 1 Restructure

### Wave 0 - Foundation Freeze

Muc tieu:
- chot visual source of truth
- chot design-to-code rules
- chot data-vs-demo policy

Deliverables:
- screen inventory 1-1 giua Figma va Flutter feature tree
- token inventory
- component inventory
- visual QA checklist
- rule: khong them screen moi neu chua map vao token/component system

Exit criteria:
- khong con doi font/nav/spacing theo tung man
- khong con dung demo state cho nhung flow da vao critical path

### Wave 1 - Core Directory And Review

Muc tieu:
- vet list/detail/search chay bang data that
- review core gan len vet detail
- UI bam Figma o muc production-ready

Deliverables:
- vet APIs
- vet mobile repository-backed flow
- review APIs
- review UI
- manual visual signoff cho vet stack

Exit criteria:
- vet list/detail/search khong con demo-only
- review rule va aggregate da enforce that

### Wave 2 - Health And Reminder

Muc tieu:
- health timeline usable
- reminder/calendar usable
- notification center usable
- profile parity voi Figma

Deliverables:
- health records CRUD
- reminder CRUD + schedule logic
- notification read/list flows
- profile screen productionized

Exit criteria:
- 2 end-to-end Phase 1 flows chay duoc
- key screens qua visual QA

### Wave 3 - Hardening And Release Gate

Muc tieu:
- quality gates xanh
- RC readiness thay vi chi "feature complete"

Deliverables:
- accessibility pass
- manual regression
- E2E critical flows
- release risk register
- RC checklist

Exit criteria:
- khong con blocker critical ve auth, data, UI, runtime, hoac device smoke

## Day-By-Day Plan

### Day 3 - Design System Hardening + Vet Data Foundation

Goal:
- don sach visual drift cua Day 2
- chuan hoa design-to-code
- bat dau vet lane bang du lieu that thay vi demo data

Workstreams:

1. Design system productionization
- Chuan hoa tokens trong Flutter:
  - colors
  - typography
  - spacing
  - radius
  - shadows
  - nav states
- Map Figma patterns thanh reusable UI primitives:
  - top bar
  - bottom nav
  - CTA buttons
  - chips
  - section headers
  - info cards
  - stat pills
  - form groups

2. Screen audit
- Ra manual cac man da co:
  - login
  - register
  - pet form
  - pet list
  - vet list
  - vet detail
- Gan visual bug backlog theo muc:
  - P0 layout break
  - P1 hierarchy mismatch
  - P2 polish inconsistency

3. Vet backend foundation
- Them vet domain/backend lane:
  - repository/store cho vet data
  - seed ingestion strategy tu `backend/prisma/data/day2_vet_seed_candidates.json`
  - `GET /vets/search`
  - `GET /vets/:id`
- Chua mo `GET /vets/nearby`

4. Vet mobile foundation
- Thay `vet_demo_data.dart` khoi critical path
- Them API-backed data layer cho list/detail/search
- Giu `vet_map_screen` la placeholder co chu dich cho den Day 9

Public interfaces:
- `GET /vets/search?q=&city=&district=&limit=&cursor=`
- `GET /vets/:id`
- `VetSummary`
  - `id`
  - `name`
  - `city`
  - `district`
  - `address`
  - `phone`
  - `summary`
  - `services`
  - `seedRank`
- `VetDetail`
  - toan bo `VetSummary`
  - `source`
  - `website?`
  - `openHours?`
  - `photoUrls?`
  - `is24h?`
  - `reviewCount`
  - `averageRating`

Implementation changes:
- Backend:
  - them vet route file
  - them vet service/repository layer
  - map curated seed file thanh queryable source
- Mobile:
  - them vet remote model + repository
  - thay list/detail screen tu static domain sang async data state
  - chuan hoa top bar va bottom nav theo Figma
- Design:
  - cap nhat `app_tokens.dart` va shared widgets de cac man vet/auth/pet dung chung grammar

Acceptance criteria:
- vet list render tu backend data that
- vet detail render tu backend data that
- search theo ten/quan hoat dong
- CTA `Goi ngay` va `Chi duong` khong con la snackbar placeholder trong spec Day 3
- nav active state dung tren list/detail
- khong con font drift giua cac man Phase 1 da co

Tests:
- backend route tests cho `GET /vets/search` va `GET /vets/:id`
- mobile widget/integration tests cho:
  - list load success
  - empty result
  - detail load success
  - missing optional fields
- visual QA checklist cho:
  - typography
  - card spacing
  - nav consistency
  - button hierarchy

Day 3 exit gate:
- vet list/detail/search dung backend data that
- auth/pet/vet co token grammar thong nhat
- visual bug backlog duoc log day du, khong de "known mismatch" an

### Day 4 - Review Core On Vet Detail

Goal:
- gan social proof that vao vet detail
- enforce anti-duplicate review rule tu backend toi UI

Workstreams:
1. Review contract and persistence
- `POST /vets/:id/reviews`
- `PUT /reviews/:id/helpful`
- `POST /reviews/:id/report`
- `@@unique([userId, vetId])` tren review
- rating aggregate update

2. Review UI
- vet detail review summary
- write review screen theo Figma
- helpful/report UI
- block state neu user da review

3. Moderation-lite
- report queue foundation
- sentiment la async side lane, fallback `UNPROCESSED` neu fail

Acceptance criteria:
- 1 user khong the review cung 1 vet 2 lan
- rating aggregate dung sau insert/update/delete
- write review UI khop Figma hierarchy
- review state khong lam hong vet detail rhythm

Tests:
- duplicate review `409`
- helpful toggle
- report threshold
- aggregate correctness
- write-review form validation
- review list render states

Day 4 exit gate:
- review core usable end-to-end
- review data hien thi that tren vet detail
- moderation-lite khong block submit flow

### Day 5 - Health Timeline + Add Event

Goal:
- health lane usable that chu khong chi la static UI

Workstreams:
1. Backend
- `GET /pets/:id/health-records`
- `POST /pets/:id/health-records`
- update/delete support
- ownership checks
- pagination/sort desc

2. Mobile
- health timeline screen theo Figma
- add health event form theo Figma
- empty, loading, error states
- optional vet association

3. Design consistency
- form grammar giong auth/pet form
- timeline cards cung ngon ngu visual voi notifications/reviews

Acceptance criteria:
- add event thanh cong va xuat hien tren timeline
- filter tabs dung loai event
- note/vet/date hierarchy ro
- khong co layout break khi text dai hoac field optional rong

Tests:
- CRUD health record API
- ownership negative tests
- timeline render states
- add-event validation

Day 5 exit gate:
- health timeline usable end-to-end
- add-event form production-ready
- visual consistency giu duoc voi Phase 1 screens

### Day 6 - Reminder Calendar + Notification Center

Goal:
- reminders va notifications tro thanh flow song, khong con la static mock

Workstreams:
1. Reminder backend
- `POST /pets/:id/reminders`
- list/delete reminders
- scheduling abstraction
- store schedule metadata, chua bat buoc push that o ngay nay

2. Notification backend
- `GET /notifications`
- `PUT /notifications/:id/read`
- `PUT /notifications/read-all`

3. Mobile
- reminder calendar theo Figma
- selected-day reminders
- upcoming list
- notification center grouped by time
- unread/read visual states
- swipe interactions

Acceptance criteria:
- reminder tao duoc va thay tren calendar/upcoming list
- notifications list/read state hoat dong
- empty states co UI hoan chinh
- spacing khong va bottom nav

Tests:
- reminder create/list/delete
- read-one/read-all
- empty-state rendering
- grouped notification UI states

Day 6 exit gate:
- reminder + notification usable
- no critical visual/state gaps on those screens

### Day 7 - Profile + Pet Flow Cohesion

Goal:
- hoan thien nhom man account/pet/profile de ca app co cung visual grammar

Workstreams:
- profile screen dung Figma
- pet form/pet list parity pass
- top bar normalization
- bottom nav normalization
- CTA/state polish

Acceptance criteria:
- auth/pet/profile dung cung token/component grammar
- khong con moi man mot kieu nav
- stats/account/settings blocks on dinh ve hierarchy

Tests:
- profile render states
- logout flow stub or real local clear flow
- pet form regressions after shared-component refactor

Day 7 exit gate:
- app cohesion dat muc production-ready cho core screens

### Day 8 - Phase 1 Full Manual QA + Accessibility Pass

Goal:
- khoa visual va interaction debt truoc khi mo map hoac release packaging

Workstreams:
- manual QA toan bo core screens
- accessibility pass:
  - contrast
  - text scale
  - tap targets
  - semantics labels
- device smoke cho auth, pet, vet, review, health, reminder

Acceptance criteria:
- khong con P0/P1 visual bug tren core flow
- screen reader/tap target khong co loi nghiem trong
- 2 flow end-to-end pass tren thiet bi/emulator

Tests:
- E2E critical flows
- a11y checklist
- regression matrix

Day 8 exit gate:
- core MVP visually signed off
- risk register chi con low/known debt

### Day 9 - Vet Nearby/Map Only If Data Ready

Prerequisite:
- vet seed da enrich du:
  - `latitude`
  - `longitude`
  - `openHours`
  - `services`
  - `photoUrls`
  - `is24h`

Goal:
- dua map vao nhu mot feature that, khong phai demo shell

Workstreams:
- `GET /vets/nearby`
- filter validation
- open-now logic
- map screen theo Figma
- marker selection
- bottom sheet
- permission denied / empty / loading states

Acceptance criteria:
- nearby results dung ban kinh
- filter hoat dong
- marker -> bottom sheet -> detail flow muot
- map khong pha visual quality cua app

Tests:
- geo query tests
- filter combos
- permission denied state
- empty-radius state
- bottom-sheet interaction tests

Day 9 exit gate:
- nearby/map production-ready, hoac neu data chua du thi lane nay chinh thuc truot sau RC va khong block release core

### Day 10 - RC Gate

Goal:
- xac dinh app co dat `RC-ready` hay khong

RC checklist:
- auth verified end-to-end
- pet profile stable
- vet list/detail/search dung backend data that
- review core stable
- health timeline usable
- reminder/notification usable
- profile usable
- visual QA signed off
- no unresolved critical runtime blocker
- no unresolved critical accessibility blocker

Release outputs:
- RC checklist
- known issues list
- go/no-go recommendation
- candidate internal build plan

## Day 3 Immediate Execution Spec

### What gets built first

- vet backend lane before map lane
- shared tokens/components before any new vet UI expansion
- replace demo vet data consumption before adding new vet features

### Exact Day 3 order

1. Freeze visual rules from Figma `Confirmed Screens`
2. Create token/component inventory from existing Flutter theme/widgets
3. Add vet backend read routes
4. Add vet mobile repository/models
5. Connect vet list to backend
6. Connect vet detail to backend
7. Replace snackbar placeholders for call/directions with real intent spec
8. Run route tests + mobile tests
9. Run manual visual QA on vet list/detail and auth/pet carry-over screens
10. Log residual bugs for Day 4+

### Files likely touched in execution

- `backend/src/routes/*` for new vet route
- `backend/src/services/*` and repository layer for vet read models
- `mobile/lib/features/vets/*`
- `mobile/lib/app/theme/*`
- `mobile/lib/core/widgets/*`
- `docs/management/*` for Day 3 execution board / status

### Day 3 non-goals

- no real map implementation yet
- no social login
- no review submit UI if vet detail still not on real data
- no release packaging

## Test Plan

### Backend

- `GET /vets/search`
  - keyword match
  - city filter
  - empty result
  - bad query validation
- `GET /vets/:id`
  - success
  - not found
  - missing optional fields fallback

### Mobile

- vet list loading/success/empty/error
- vet detail loading/success/error
- long title/address wrapping
- bottom nav active state
- CTA visibility and hierarchy

### Manual visual QA

- compare against Figma screens:
  - login
  - pet form
  - vet list
  - vet detail
  - review write
  - health timeline
  - reminder calendar
  - notification center
  - profile
- check:
  - typography family/weight
  - spacing rhythm
  - top bar style
  - bottom nav style
  - card radius/shadow
  - chip colors
  - CTA prominence
  - safe-area spacing
  - overflow/truncation behavior

## Assumptions

- Current plan file should live under `docs/management` beside existing day status docs.
- `Confirmed Screens` remains the final visual source of truth for Phase 1.
- Existing generated/editable screens are helper artifacts, not higher priority than confirmed screens.
- Phase 1 quality is more important than date compression.
- If Day 9 data prerequisite is not met, map moves after RC rather than forcing low-quality delivery.
- `TestFlight/Internal build` only starts after RC gate, not before.

## Phase 2+ Direction After Phase 1

- Phase 2 should begin with `Rescue/Lost Pet foundation` before broad social expansion, because it better fits product differentiation and can reuse geo/location groundwork from vet lane.
- Social, adoption, booking, marketplace, payments, subscription, admin, and AI should each open only after the previous lane reaches a stable quality gate, not by calendar alone.
- The same rule from Phase 1 carries forward:
  - component-first
  - state-complete
  - data-realistic
  - manual visual QA before "done"

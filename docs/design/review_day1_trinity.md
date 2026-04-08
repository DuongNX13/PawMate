# PawMate Day 1 Review — Trinity

Date: 2026-04-07  
Role: Trinity (Primary lane: UX review, Support lane: Neo mobile handoff readiness)

## Scope reviewed

- `docs/design/day1_design_system.md`
- `docs/design/day1_wireframes_and_states.md`
- `docs/product/day1_user_stories_and_dod.md`
- `docs/architecture/openapi.phase1.yaml`
- `docs/management/day1_execution_board.md`
- `docs/management/day1_runtime_blockers.md`

## Verdict

Day 1 UX foundation is directionally good and usable as a planning baseline, but it is **not fully handoff-ready for Day 2 implementation yet**. The current artifacts cover the design language, core screen structure, and five standard UI states, but they still miss several implementation-level details that Neo will need to build Flutter screens with low ambiguity.

Overall readiness:
- Design system: **partially ready**
- Wireframes: **partially ready**
- UI state model: **good baseline, needs screen mapping**
- Flutter handoff readiness: **not ready enough without a follow-up clarification pass**

---

## 1) Design system review

### What is solid

- Clear product tone: friendly, calm, trustworthy, mobile-first.
- Token categories exist for color, typography, spacing, radius, and shadows.
- Component basics cover the MVP primitives Neo will need first: buttons, inputs, cards, chips, top bar, FAB.
- Dark mode is acknowledged from Day 1 instead of being deferred.
- Vietnamese-first copy guidance is aligned with product and DoD.

### Gaps

1. **No token naming format for code consumption**
   - Tokens are conceptually defined but not yet expressed in a Flutter-friendly naming structure.
   - Neo still needs a direct mapping such as `AppColors.primary500`, `AppSpacing.s16`, `AppRadius.md`, `AppTextStyles.h1`.

2. **No semantic surface/state token layer**
   - There are base colors, but missing semantic UI aliases for actual screen use:
     - page background
     - card background
     - input border default/focus/error
     - disabled foreground/background
     - success/warning/error container colors
     - map selected marker / default marker / cluster color
   - Without this, Neo may hardcode ad hoc colors during implementation.

3. **Typography lacks usage constraints per screen type**
   - Scale exists, but not enough rules on when to use `H3` vs `H4`, or maximum lines/truncation for cards and list items.
   - Vet cards and pet cards especially need text overflow guidance.

4. **Button and input specs are still behavioral, not structural**
   - Missing minimum heights, horizontal padding, icon placement, loading lock behavior, and full-width vs inline usage.
   - Missing input variants beyond generic field: password, phone, OTP digit field, searchable field.

5. **No asset guidance for icons/illustrations beyond style direction**
   - Good intent exists, but no inventory of required assets for Day 2 flows.
   - Neo can build layouts without final assets, but placeholders must be explicitly listed.

### Trinity recommendation

Add one follow-up pass that converts the current design system into a direct implementation contract for Flutter:
- semantic tokens
- component anatomy
- min sizes
- text overflow rules
- state color aliases
- asset placeholder list

---

## 2) Wireframe review

### What is solid

The Day 1 wireframe document gives a clean first-pass structure for all planned Phase 1 Day 1 screens:
- Onboarding
- Login
- Register
- OTP
- Pet create
- Pet list
- Vet map
- Vet list
- Vet detail
- Health timeline

It captures:
- main content hierarchy
- primary CTA intent
- high-level screen anatomy
- some fallback thinking for empty and permission-denied paths

### Gaps by flow

#### Onboarding
- Good slide structure and CTA stability.
- Missing:
  - back behavior on Android
  - whether `Bỏ qua` appears on all 3 slides or only first 2
  - whether `Bắt đầu ngay` changes to `Tạo tài khoản` / `Đăng nhập` on final slide

#### Login / Register / OTP
- Flow is understandable.
- Missing:
  - password visibility toggle state
  - field-by-field validation timing
  - social login loading/disabled states
  - OTP auto-focus / paste behavior / wrong-code handling
  - lockout or resend-too-early messaging hooks from Auth AC

#### Pet Profile create/list
- Core form is present.
- Missing:
  - required vs optional field split in UI
  - avatar picker source options and failure state
  - breed dropdown behavior for `other`
  - list card action pattern: tap only or quick edit
  - delete/archive path discoverability for Day 2 follow-up

#### Vet Map
- Good first-pass concept.
- Missing:
  - default first-load state before permission grant
  - permission prompt denied-once vs denied-forever recovery
  - cluster tap behavior
  - selected marker persistence when bottom sheet opens/closes
  - switch-to-list affordance placement

#### Vet List
- Good comparison structure.
- Missing:
  - empty-result state after filters
  - sticky vs non-sticky filter bar
  - card hierarchy when address/service tags overflow
  - sort bottom sheet or inline control behavior

#### Vet Detail
- Actionability is strong.
- Missing:
  - image missing fallback
  - no phone / no hours / no review data treatment
  - review preview collapsed vs expanded rule
  - call/directions action persistence on scroll

#### Health Timeline
- Good top-level hierarchy.
- Missing:
  - zero-state structure for first record
  - timeline grouping logic for same-day entries
  - visual distinction between record types
  - empty filter result state

### Trinity recommendation

The wireframes are suitable for alignment and review, but **not yet enough for low-friction Flutter implementation**. Before Neo starts UI work, add a screen-by-screen spec table with:
- entry point
- main sections
- primary CTA
- secondary CTA
- required components
- state coverage
- edge-case notes

---

## 3) UI states review

### What is solid

The five standard states are the right baseline for MVP:
- Loading
- Empty
- Error
- Success
- Offline

The document correctly:
- gives usage conditions
- includes sample Vietnamese copy
- defines priority order
- avoids hiding error/offline behind empty UI

### Gaps

1. **State library exists, but state-to-screen mapping does not**
   - Neo still needs to know which states apply to which screen and what exact layout they replace.

2. **Missing partial-state patterns**
   - Current doc focuses on page-level states.
   - Day 2 will need section-level and action-level states too:
     - submit button loading
     - social login button loading
     - map loading while top bar remains interactive
     - list refresh while old data is visible
     - photo upload progress for pet avatar

3. **No permission state category**
   - Vet Finder depends on location permission.
   - Current docs mention permission denied in prose, but there is no standardized permission-blocked UI state.
   - This is a real Day 2 gap.

4. **No empty-state distinction between first-use and filtered-empty**
   - These need different copy and CTA.
   - Example:
     - no pets yet -> `Thêm thú cưng`
     - no search results -> `Xóa bộ lọc`

5. **Offline fallback is conceptually good, but not bounded**
   - Need explicit statement about which Day 2 screens may show cached read-only content and which should show hard failure.

### Trinity recommendation

Keep the five standard states, but add two practical layers for implementation:
- **permission-blocked state**
- **inline/action state rules**

Also create a state coverage matrix per screen.

---

## 4) Flutter handoff readiness review for Neo

### Current readiness

Neo has enough to understand intended UX direction, but **not enough to implement consistently without extra interpretation**.

### What Neo can already build with acceptable confidence

- overall screen skeletons
- rough information hierarchy
- core CTA layout
- base component families
- general tone and copy direction

### What will likely cause friction or rework

1. **No screen inventory linked to route names / widget breakdown**
   - Neo needs a simple mapping such as:
     - `OnboardingScreen`
     - `LoginScreen`
     - `RegisterScreen`
     - `OtpVerificationScreen`
     - `PetListScreen`
     - `CreatePetScreen`
     - `VetMapScreen`
     - `VetListScreen`
     - `VetDetailScreen`
     - `HealthTimelineScreen`

2. **No component-level acceptance for Flutter widgets**
   - Need explicit reusable blocks:
     - primary button
     - social auth button
     - text field
     - OTP field row
     - pet card
     - vet card
     - filter chip
     - empty state block
     - error state block
     - offline banner

3. **No responsive rules for small vs medium mobile widths**
   - Pet list says grid or stacked cards depending on width, but threshold is unspecified.

4. **No asset readiness list**
   - Need to state clearly what may use placeholders on Day 2:
     - onboarding illustrations
     - empty-state illustrations
     - pet default avatar
     - clinic placeholder image
     - health record icons

5. **No localization-ready copy inventory**
   - Good copy direction exists, but Day 2 implementation would move faster with a starter string list for critical screens and state messages.

6. **No explicit contract-to-screen field mapping**
   - Example gaps:
     - pet fields from schema vs create form grouping
     - vet response fields vs vet card/detail layout
     - auth errors vs inline form messaging

### Trinity recommendation

For Day 2 readiness, the minimum useful handoff package should include:
- route/screen list
- reusable component list
- field mapping by screen
- state coverage matrix
- placeholder asset list
- copy inventory for critical flows

---

## 5) UX gaps that should be added before or alongside Day 2

### High priority gaps

1. **Permission-blocked state for Vet Finder**
   - Title, body copy, CTA to retry, CTA to switch to list/manual search.

2. **Action-level loading and disabled rules**
   - Especially for auth submit, social login, OTP verify, pet save, image upload.

3. **Form validation behavior spec**
   - Real-time vs on blur vs on submit per field.

4. **Field priority and grouping for Create Pet**
   - Split identity fields vs optional health/meta fields.

5. **Map/list switching rule**
   - Must define how user moves between Vet Map and Vet List without losing filters.

6. **Fallback content rules for missing clinic data**
   - No phone, no hours, no photo, no reviews.

7. **Text overflow and truncation rules**
   - For clinic name, address, service tags, pet breed names.

### Medium priority gaps

8. **Placeholder asset inventory**
9. **Sticky action behavior on Vet Detail**
10. **Empty-state variants: first-use vs no-results**
11. **Offline capability boundaries by screen**
12. **Dark mode contrast verification checklist for Day 2 screens**

---

## 6) Suggested immediate additions for Day 2 readiness

If only one small follow-up pass is possible, Trinity should provide these add-ons next:

### A. Screen-state coverage matrix
For each Day 2 screen, list:
- page loading
- inline loading
- empty
- error
- success
- offline
- permission-blocked

### B. Flutter handoff checklist
For each screen, list:
- route name
- widgets/components needed
- API fields shown
- local validation needed
- placeholder assets needed

### C. Copy pack for critical flows
At minimum:
- auth labels/errors
- pet create labels/errors
- vet search empty/error/permission copy
- health timeline empty copy

---

## Final Trinity verdict

Day 1 artifacts are **good enough for alignment, review, and early skeleton building**, but **not yet strong enough to claim fully implementation-ready mobile handoff**. The biggest Day 2 risks are not visual style; they are **state completeness, permission handling, field-level behavior, and missing implementation detail for reusable Flutter components**.

If Neo starts Day 2 with the current docs only, progress is possible, but rework risk is moderate. A short Trinity follow-up pass focused on handoff precision would materially reduce ambiguity.

# PawMate Day 8 Android UI/UX Figma Audit

Owner: UI/UX QA agent
Date: 2026-05-11
Scope: Android E2E visual comparison only. This audit does not operate Android simulator and does not modify app source or functional testcase artifacts.

## 1. Source Evidence

### Figma MCP Go

- Figma MCP Go connected successfully.
- File: `Pawmate Desgin`
- Current page: `PawMate Stitch Intake`
- Current selection: empty
- Page context found these relevant frames/sections:
  - `Login Screen`
  - `Home Screen`
  - `Profile Screen`
  - `Vet Finder Map`
  - `Vet List`
  - `Health Timeline`
  - `Generated Missing Screens - V1 Editable Rebuild`
  - `10 Write Review - editable`
  - `13 Reminder Calendar - editable`
  - `14 Notification Center - editable`
  - `Generated Missing Screens - Editable Batch 2 Auth Pet`
- Figma context confirms design direction text: warm, trusted, friendly pet-care experience; typography direction: `Be Vietnam Pro` for heading/body and `Inter` for labels.
- Figma visible color swatches:
  - Primary `#FF8A5B`
  - Secondary `#2D5A88`
  - Tertiary `#FFD700`
  - Neutral `#F9FAFB`
- Figma variables export returned `{}` and variable definitions returned no collections.
- `get_local_components` timed out after 10 seconds, so component inventory is a blocker.

Fallback evidence used because there was no active Figma selection and no exported variable/component set:

- `docs/design/day1_design_system.md`
- `docs/management/day8_execution_board.md`
- `docs/qa/day8_manual_qa_accessibility_report.md`
- Current Flutter UI under `mobile/lib`

## 2. Day 8 QA Context

Current Day 8 status from repo evidence:

- Appetize deep-login blocker is cleared.
- Render API smoke covers auth, pets, health records, reminders, notifications, and vet search.
- Existing visual/manual QA has follow-up Android evidence beyond auth/pets.
- Full screen-by-screen large-text accessibility has been completed by the main Android E2E runner.

This audit is therefore a readiness checklist and design-drift report for the main Android E2E runner.

## 3. Design Baseline

Use these as Android visual acceptance criteria:

| Area | Expected baseline |
|---|---|
| Typography | User-facing Vietnamese uses `Be Vietnam Pro`; labels may use `Inter`; key scale: Display 32, H1 28, H2 24, H3 20, Body 16, Label 14, Caption 12. |
| Color tokens | Figma page currently shows Primary `#FF8A5B`, Secondary `#2D5A88`, Tertiary `#FFD700`, Neutral `#F9FAFB`. Day 1 doc still defines primary as teal HSL tokens, so this conflict must be resolved by design owner. |
| Spacing | 4/8/12/16/24/32/48/64 px scale; common screen padding should stay around 16-24 px. |
| Shapes | Inputs/chips 8 px, cards/buttons 12 px, bottom sheets/featured cards 16 px, hero/onboarding panels 24 px, pills 999 px. |
| Buttons | Primary action min height 48 px; app theme currently uses 56 px for filled buttons and 48 px for outlined buttons. |
| Inputs | Label above field or visible Material label; min height 48 px; focused/error border must be visible; error text must explain the fix. |
| Cards | 16 px baseline padding; title/meta/action hierarchy must scan quickly. |
| Empty/loading/error states | Must be non-blank, explain the state, and provide retry/create action where useful. |
| Tap target | Interactive controls should be at least 48 x 48 dp or have equivalent padded hit area. |
| Text scale | Android large text should not clip labels, CTA text, bottom nav, cards, bottom sheets, or multiline review text. |
| Navigation hierarchy | Screen title/primary action/secondary navigation should be obvious; bottom nav should not fight local back buttons or repeated CTAs. |

## 4. Key Findings

| ID | Severity | Finding | Evidence | Android E2E check |
|---|---|---|---|---|
| UIX-D8-01 | High | Design token source conflict: Day 1 design doc defines teal primary tokens, while Figma page and current Flutter code use warm orange `#FF8A5B` as primary. This affects color sign-off because both cannot be the source of truth. | Figma swatch Primary `#FF8A5B`; `mobile/lib/app/theme/app_tokens.dart` has `AppColors.primary500 = Color(0xFFFF8A5B)`; Day 1 doc says `primary-500` is HSL teal. | Capture Android screenshots for auth/pets/health/vet/reminder/notification and decide whether orange theme is accepted as latest Figma source or doc must be updated. |
| UIX-D8-02 | Closed in follow-up | Bottom navigation originally used English labels (`Home`, `Vet`, `Health`, `Profile`) while design goal is Vietnamese-first UI copy. Follow-up changed labels to `Thú cưng`, `Thú y`, `Sức khỏe`, `Hồ sơ` with one-line ellipsis. | `mobile/lib/core/widgets/pawmate_bottom_nav.dart`; `temp/qa/day8-android-e2e/35-vietnamese-ui-after-launch.png`. | Re-check when new bottom-nav destinations are added. |
| UIX-D8-03 | Closed in follow-up | Several Android UI strings were Vietnamese without accents. Follow-up normalized major MVP copy on auth, pets, reminders, notifications, vets/reviews, and placeholder routes. | `mobile/lib/features/**/presentation/*.dart`; `temp/qa/day8-android-e2e/35-vietnamese-ui-after-launch.png`. | Re-scan user-visible strings when new screens are added. |
| UIX-D8-04 | Closed in follow-up | Full text-scale proof is captured for dense surfaces: vet review card, review bottom sheet, reminder calendar, notification cards, and bottom nav. | `temp/qa/day8-android-large-text/19-postfix-reminders.png`, `20-postfix-notifications.png`, `18-postfix-health-scroll.png`, `22-postfix-vet-detail-scroll.png`; bottom padding increased in affected screens. | Re-run at large text when new dense cards/forms are added. |
| UIX-D8-05 | Medium | Tap-target semantics should be verified where custom `GestureDetector` or compact icon/text controls are used. | Bottom nav uses `GestureDetector`; pet avatar upload uses `GestureDetector`; many icon-only controls rely on default `IconButton`. | Use Android accessibility/tap pass: bottom nav, avatar upload, map FAB, notification icon, back buttons, review helpful/report/load-more. |
| UIX-D8-06 | Low | Loading/empty/error states are present in code for major Day 8 surfaces, but visual parity is not proven on Android. | Pets, health, reminders, notifications, vet list/detail, and reviews all include loading/error/empty branches. | Capture each state where feasible or simulate backend failure/offline for at least one representative list screen. |

## 5. Screen Mapping For Android E2E

| Screen / flow | Figma/design anchor | Current Flutter evidence | UI/UX checks to run on Android |
|---|---|---|---|
| Auth login/register | Figma `Login Screen`; Day 1 typography/color/input/button rules | Login uses hero gradient, `Be Vietnam Pro`, email/password fields, Vietnamese CTA, loading label. | Typography; input labels and error messages; primary button height; loading state `Đang đăng nhập...`; text scale; keyboard overlap; unverified-login policy error copy. |
| Pets list/create/edit | Figma batch includes Auth/Pet area; Day 1 card/FAB/input rules | Pets list has loading, full-page error, empty state with CTA, grid/list cards, FAB; create pet has form fields, dropdowns, avatar upload, submit error. | Empty state illustration/icon and CTA; FAB size 56; card spacing; form label visibility; avatar tap target; submit loading/error; unaccented copy; create/edit route availability. |
| Health timeline | Figma `Health Timeline`; Day 1 card/FAB/chip rules | Health screen has bottom nav, extended FAB, pet selector, filters, timeline, upcoming reminders, loading/error/empty cards. | Header hierarchy; filter chip tap targets; empty timeline; add-event bottom sheet; loading/error card contrast; bottom nav overlap with FAB; large text in timeline cards. |
| Reminders | Figma `13 Reminder Calendar - editable`; Day 1 state and component rules | Reminder screen has extended FAB, pet selector, month navigation, calendar grid, upcoming list, loading/error/empty status card. | Calendar cell hit area; month nav icons; empty/no-pet states; add reminder sheet; due/process result states; unaccented copy; large text in calendar/list. |
| Notifications | Figma `14 Notification Center - editable`; Day 1 state rules | Notification center has back button, title, mark-all-read action, loading/error/empty states, unread banner, notification cards. | `Đọc hết` disabled/enabled state; empty/loading/error copy; card read/unread contrast; mark-read/dismiss tap targets; bottom nav route highlighting; unaccented copy. |
| Vet list/map/detail | Figma `Vet List`, `Vet Finder Map`; Day 1 vet card/chip/map semantic aliases | Vet list has search, filters, refresh, loading/error/empty, pagination, map FAB; detail has actions Call/Directions/Review and service chips. | Search field layout; filter chip wrapping; error/empty state; card title/address max lines; map FAB; detail action buttons at large text; source attribution readability. |
| Reviews | Figma `10 Write Review - editable`; Day 1 bottom sheet/card/input/button rules | Vet detail has write-review action, review preview, helpful/report, review list bottom sheet, load-more, report sheet. | Write-review form state; star/rating controls; helpful/report buttons; review list sheet height at large text; load-more loading/error; no clipped long review text. |

## 6. Android Visual Checklist

Run these checks for every reachable Day 8 MVP screen:

1. Typography: compare heading/body/label weight and size against design baseline; verify Vietnamese text uses the expected font and does not mix accidental system style.
2. Color tokens: confirm primary, secondary, tertiary, neutral, success/warning/error surfaces; flag any hardcoded color that visibly diverges from Figma or accepted token set.
3. Spacing: check 16/24 px page rhythm, card padding, list gaps, bottom safe-area padding, and whether FAB/bottom nav overlap content.
4. Component shapes: inspect input radius, card radius, chip pills, bottom sheet radius, FAB size, and active bottom-nav pill.
5. Empty/loading/error states: each list/form state must be understandable and provide retry/create action where appropriate.
6. Tap targets: all buttons, icon buttons, chips, bottom nav items, calendar cells, review actions, and avatar upload must be comfortably tappable on Android.
7. Text scale: rerun at larger Android font size; verify no clipped button labels, bottom nav labels, long Vietnamese copy, dynamic vet/review content, or hidden form submit buttons.
8. Navigation hierarchy: verify title, back affordance, primary action, secondary actions, and bottom nav state are unambiguous on each route.

## 7. Acceptance Recommendation

Do not close Day 8 visual/accessibility exit gate until:

- UIX-D8-01 design token conflict is resolved or explicitly accepted.
- Android screenshots prove auth, pets, health, reminders, notifications, vet, and review surfaces at normal text scale.
- Large-text Android pass proves no severe clipping or unreachable CTA on dense screens.
- Bottom nav language and tap-target behavior are either fixed or accepted as MVP debt.
- The manual QA report is updated by the main/QA owner with screenshot evidence from the Android E2E run.

## 8. Out Of Scope For This Agent

- No Android simulator control was performed.
- No source code was changed.
- `docs/qa/day8_android_functional_testcases.md` was not touched.
- `docs/qa/day8_manual_qa_accessibility_report.md` was read only and not modified.

## 9. Main Agent Follow-up

After this audit package was produced, the main Android E2E pass implemented and verified the highest-signal UI/UX findings:

- UIX-D8-02 is closed for the current mobile source: bottom navigation labels now use Vietnamese-first copy (`Thú cưng`, `Thú y`, `Sức khỏe`, `Hồ sơ`) and one-line ellipsis.
- UIX-D8-03 is closed for major MVP surfaces exercised in Day 8: auth, pets, reminders, notifications, vets/reviews, and placeholder routes now use Vietnamese copy with accents.
- A new Android regression test covers the user-reported reminder pet selector overflow: `mobile/test/features/reminders/reminder_calendar_screen_test.dart`.
- Android normal-text screenshots and gates are recorded in `docs/qa/day8_manual_qa_accessibility_report.md`.

Remaining UI/UX debt:

- UIX-D8-01 remains a design-owner decision: the live Flutter/Figma warm orange primary conflicts with the older Day 1 teal-token doc.
- UIX-D8-04 is closed for Day 8: Android `font_scale=1.3` evidence covers dense review/reminder/notification surfaces and the bottom-nav/FAB overlap risk.

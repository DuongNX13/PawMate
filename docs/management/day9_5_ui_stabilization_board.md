# PawMate Day 9.5 UI Stabilization Board

Date: `2026-05-12`

## Scope

Day 9.5 is inserted between the Day 9 map sign-off and the Day 10 RC Gate because current screenshots show full-app visual quality risk:

- typography hierarchy is inconsistent,
- some headings and card labels are too large for their containers,
- long vet names and Vietnamese copy are clipped or hard to scan,
- compact cards/buttons mix oversized title styles with fixed-height layouts.

This is a UI stabilization and retest lane, not a new feature lane.

## Out Of Scope

- Apple Developer/App Store Connect signing.
- New backend features.
- Replacing Render/Appetize/Android QA surfaces.
- Reworking the brand identity from scratch.

## Agent Split

| Agent | Focus | Expected Output |
|---|---|---|
| Turing | Typography/layout system audit | Root causes, files/components to fix first, proposed text scale rules |
| Rawls | Screen-by-screen UI QA audit | Full route matrix with P0/P1/P2 visual and interaction risks |
| Goodall | Accessibility/responsive audit | Large-text, small-screen, tap-target, semantic-label test plan |

## Initial Agent Findings

Turing returned the first audit and confirmed the likely root cause of the screenshots:

- `displaySmall` is used on Vet list/map but is not defined in `AppTheme._textTheme`, so Flutter falls back to a larger Material default.
- Dense cards and fixed containers use `headlineSmall`, `titleLarge`, and local `w800/w700` overrides too aggressively.
- Several containers lock dimensions while holding dynamic text: hero text widths, chip row height, vet thumbnails, fixed-height action buttons, and shared gradient button height.
- Vet list cards are especially squeezed by page padding, card padding, large thumbnail, badge padding, and oversized title style.
- Existing vet tests mostly verify text/function behavior and do not yet enforce small-screen, large-text, overflow-free rendering.

Confirmed first-fix files:

- `mobile/lib/app/theme/app_theme.dart`
- `mobile/lib/features/vets/presentation/vet_list_screen.dart`
- `mobile/lib/features/vets/presentation/vet_detail_screen.dart`
- `mobile/lib/features/vets/presentation/vet_map_screen.dart`
- `mobile/lib/features/vets/presentation/vet_preview_sheet.dart`
- `mobile/lib/core/widgets/primary_gradient_button.dart`

Rawls returned a screen-by-screen QA audit and added these high-priority risks:

- P0: `/pets` and `/profile` are main tabs but may not render `PawMateBottomNav`, so navigation can disappear after tapping from Health/Vets.
- P0: Health and Reminder modal sheets use `showModalBottomSheet(isScrollControlled)` with non-scroll-safe body content; save buttons may be hidden by keyboard or overflow on `320x568`.
- P0: Vet map preview sheet is not scroll-safe for long clinic names/addresses/service pills; action buttons can be pushed off-screen.
- P1: Vet detail hero/quick facts still use fixed widths and oversized styles with long names, addresses, or URLs.
- P1: Vet map control row can overflow at larger text scale because two `OutlinedButton.icon` controls share one row.
- P1: Onboarding/OTP screens are not obviously scroll-safe for small portrait plus keyboard.
- P1: Notification cards lack long-title/body visual coverage.
- P2: Pets/profile coverage needs long pet/breed/name tests and Vietnamese copy cleanup.

Goodall returned the accessibility/responsive audit:

- Local mobile commands should run from `P:\mobile`; direct `D:\My Playground\...` execution can fail native-assets hooks because of the path space.
- Day 9.5 responsive tests should cover `360x800` and `390x844` at text scale `1.3` minimum, with `1.5` as stretch.
- Add guideline checks: `androidTapTargetGuideline`, `labeledTapTargetGuideline`, and `textContrastGuideline` on representative screens.
- Add keyboard visibility tests for login/register/OTP/create pet, health/reminder bottom sheets, write-review/report-review sheets.
- Contrast has real risk: white on `primary500` is about `2.32:1`, white on `primary700` about `4.31:1`, and label on `surfaceMuted` about `3.47:1`.
- Tap target risk: review photo remove button is about `24x24`; icon-only controls need tooltip/semantic coverage.

## Task Status

| ID | Task | Status | Acceptance |
|---|---|---|---|
| D9.5-01 | Insert Day 9.5 plan before Day 10 RC Gate | DONE | Phase plan and board exist |
| D9.5-02 | Agent-based full UI audit | IN_PROGRESS | 2-3 independent agent reports are merged into the QA matrix |
| D9.5-03 | Typography token and usage audit | TODO | Compact surfaces stop using oversized headline styles |
| D9.5-04 | Vet list/detail visual stabilization | TODO | Long clinic names, quick facts, action buttons, chips, review preview do not clip at normal or large text |
| D9.5-05 | Auth/onboarding/pets visual stabilization | TODO | Headings, form labels, CTA states, pet cards/forms are consistent and readable |
| D9.5-06 | Health/reminders/notifications visual stabilization | TODO | Dense timelines, calendars, notification cards, bottom sheets do not overlap bottom nav/FAB or clip labels |
| D9.5-07 | Bottom nav and shared component pass | TODO | Labels, active pill, icon spacing, and tap targets remain stable on small screens |
| D9.5-08 | Automated UI regression tests | TODO | Flutter tests cover small screen + large text + overflow-free rendering |
| D9.5-09 | Manual Android/Appetize visual smoke | TODO | Screenshot evidence covers every core route at normal text and dense routes at large text |
| D9.5-10 | Day 9.5 QA report and go/no-go | TODO | Known issues are classified; P0/P1 must be fixed or Day 10 remains blocked |
| D9.5-11 | Contrast and semantic-label pass | TODO | Primary text/CTA/icon contrast and tap-target labels meet accessibility criteria |

## Priority Fix Order

1. Shared typography rules in `mobile/lib/app/theme/app_theme.dart`.
2. Main tab/bottom-nav consistency in `mobile/lib/app/router/app_router.dart`, `mobile/lib/core/widgets/pawmate_bottom_nav.dart`, `mobile/lib/features/pets/presentation/pet_list_screen.dart`, and profile/placeholder surfaces.
3. Vet list card in `mobile/lib/features/vets/presentation/vet_list_screen.dart`.
4. Vet detail hero, quick facts, action buttons, chips, review preview in `mobile/lib/features/vets/presentation/vet_detail_screen.dart`.
5. Vet map controls and preview sheet in `mobile/lib/features/vets/presentation/vet_map_screen.dart` and `mobile/lib/features/vets/presentation/vet_preview_sheet.dart`.
6. Scroll-safe modal sheets in health/reminders, especially keyboard-open save flows.
7. Dense cards/sheets in notifications, health, reminders.
8. Auth/onboarding/pets once the shared scale and dense surfaces are stable.

## UI Acceptance Rules

- Do not use `headlineSmall` or larger inside compact cards, chips, fixed-height buttons, bottom nav, quick facts, or list metadata.
- Dynamic titles can use at most `titleLarge` in large cards and `titleMedium` in compact cards unless the screen is a true hero.
- Every dynamic text block must define one of: flexible height, `maxLines`, horizontal scroll, or a deliberate wrapping layout.
- Fixed-height action buttons must survive labels at `TextScaler` 1.3; otherwise remove fixed height or lower local text style.
- Long vet names, addresses, services, review labels, and Vietnamese CTA text must remain readable on `360x800` and `390x844`.
- Tap targets must remain at least 48dp or have equivalent padded hit area.
- Bottom nav must not hide the last card/action on any scrollable core screen.

## Evidence Targets

| Evidence | Required |
|---|---|
| Flutter full widget test output from `P:\mobile` | Yes |
| Targeted UI overflow tests | Yes |
| Android normal-text screenshots for auth, pets, vets, map, detail, reviews, health, reminders, notifications | Yes |
| Android large-text screenshots for vet list/detail, health, reminders, notifications, bottom sheets | Yes |
| Appetize smoke | Optional, only if quota allows |
| QA report | Yes |

## Required Test Matrix

| Matrix | Required Values |
|---|---|
| Surface sizes | `360x800`, `390x844`; stretch `320x568` for keyboard/bottom sheets |
| Text scale | `1.0`, `1.3`; stretch `1.5` for dense screens |
| Screens | onboarding, login/register/OTP, pets list/create/detail, vet list/map/detail/reviews, health, reminders, notifications, bottom nav/profile |
| Assertions | `tester.takeException() == null`, submit/CTA visible and tappable, bottom nav visible where expected, no content hidden by bottom nav/FAB |
| Accessibility | Android tap target, labeled tap target, text contrast on representative screens |

## Exit Gate

Day 9.5 can close only when:

- no P0/P1 visual or interaction issue remains,
- full UI QA report is updated with screenshots and test output paths,
- GitHub CI and Compose Smoke pass on the candidate commit,
- Day 10 RC Gate board is updated to show Day 9.5 as complete before RC sign-off.

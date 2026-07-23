# PawMate v0.31 - UI/UX brief

Status: `W1_DRAFT`; implementation is not authorized by this artifact alone.

## Goal

- **User goal:** complete everyday pet-care tasks quickly and understand what
  is available, unavailable, loading, offline, or permission-restricted.
- **Product goal:** make the existing Phase 1 app visually consistent on
  Android and iPhone without inventing routes, data, metrics, or Phase 2
  readiness.
- **Success signal:** the existing five-tab journeys remain intact; every
  enabled action works; layout, text, safe areas, keyboard, states, and
  accessibility pass the v0.31 traceability matrix.

## Audience and use context

- Vietnamese pet owners using a phone in portrait orientation.
- Common contexts include one-handed use, interrupted connectivity, denied
  location/media permission, long Vietnamese names, and enlarged text.
- Target content width is 320-430 logical pixels. Wider layouts may center a
  maximum-width phone content surface; tablet support is not claimed.

## Existing shell and scope

- Existing primary navigation is preserved exactly:
  `Home / Vet / Health / Rescue / Profile`.
- Home does not become a new dashboard. Adoption remains a feature flow rather
  than a primary tab.
- Rescue stays under the Rescue tab. Before Day 39 it is staged/unavailable;
  Day 39 may enable browse/read only after G5A and G4B pass; Day 40 may enable
  Create Lost Alert.

### In scope

- Chocomint light visual system and consistent Be Vietnam Pro typography.
- Compact but accessible CTA/nav treatment.
- Safe area, keyboard, overflow, long-text, localization, and adaptive platform
  primitives.
- Existing Phase 1 runtime screens plus honest Rescue staged state.
- Figma v0.31/v0.32 references for all 56 design screens; future Phase 2 frames
  remain `DESIGN_ONLY`.

### Out of scope

- Dark mode, tablet/desktop UI, new primary navigation, production rollout,
  backend/schema changes, and falsely enabling future Phase 2 features.
- Using generated imagery for logos, app/nav icons, controls, maps, badges, or
  screenshots of UI.

## Primary flows

1. Onboarding/auth leads to the authenticated Home root without losing a pet
   draft or `returnTo` destination.
2. Home/Pet/Profile supports selecting and maintaining a pet, reading current
   care information, and reaching only real destinations.
3. Vet opens map-first, explains location state, and always offers manual/list
   fallback.
4. Health/Reminder/Notification supports creation, status feedback, deep links,
   offline/error recovery, and unsaved-change protection.
5. Rescue displays an honest staged state before Day 39. The Day 39 design
   contract supports real read/list/map data; create remains off until Day 40.

## State matrix

| Area | Required states | Expected recovery/proof |
|---|---|---|
| Auth/Onboarding | draft restore, validation, submitting, API/offline error, OTP expiry/cooldown, media cancel/failure/recovery, keyboard | Widget tests, keyboard screenshot, long-copy/text-scale proof |
| Pet/Home/Profile | loading, empty, error, offline cache, selected pet, reminder dismissed, long names, unavailable future row | Provider/widget tests, responsive goldens, CTA-route trace |
| Vet | not determined, granted, service disabled, denied, denied forever, timeout, unavailable; map loading/empty/error/offline | Permission-service tests, map/list fallback journeys, deterministic map placeholder |
| Health/Reminder | no pet, loading, empty, error, offline, draft, overdue, done, unsaved form | Widget/provider tests, picker proof, responsive goldens |
| Notification | empty, read/unread, deep-link, long text, offline | Widget/deep-link tests and golden evidence |
| Rescue pre-Day 39 | staged/unavailable | Feature-availability and deep-link fail-closed tests |
| Rescue Day 39 contract | loading, empty, error, stale, owner/viewer permissions, status lifecycle | Design-only trace until API/interface freeze and G5A PASS |
| Cross-cutting | text scale 1.0/1.3/2.0, keyboard, reduced motion, disabled/loading, long Vietnamese | Platform-neutral widget tests plus device evidence |

## Primitive choices

| Interaction | Primitive/source | Contract |
|---|---|---|
| Navigation shell | `go_router` stateful indexed shell | Preserve branch state; reselect pops to branch root or scrolls root to top |
| Back navigation | Adaptive wrapper over platform navigation | Android root-back exits; iOS pushed routes preserve swipe-back |
| Dialog | Material/Cupertino adaptive wrapper | Correct semantics, dismissal, focus return, and destructive-action order |
| Date/time input | Adaptive date/time picker wrappers | Vietnamese formatting; cancellation does not mutate draft |
| Action choices | Adaptive action sheet | Safe-area aware; keyboard/focus and cancel behavior tested |
| Toggle/progress | `Switch.adaptive`, adaptive progress indicator | Native semantics; reduced-motion-safe feedback |
| Form | Existing Flutter form/text-field primitives | Linked error text, loading/disabled state, autofill where appropriate |
| Map | Existing `flutter_map`, deterministic test canvas | Never require live tiles in a golden; list/manual fallback always available |
| Media | Existing gallery picker through a project wrapper | Cancel/failure/recovered-lost-data states; no camera permission in this scope |

Custom interaction code is justified only where no platform/project primitive
can satisfy the same behavior. It must have a semantics and test contract before
implementation.

## Component system

### Reuse and normalize

- Existing PawMate Button, TextField, TopBar, BottomNav, FixedCtaBar, Card,
  Chip, StateView, Skeleton, Toast, and UploadTile primitives.
- Existing Rescue shield and approved pet/Golden assets.

### New or extended contracts

- `PawMateStatusColors` theme extension.
- `PawMateSafeAreaPolicy` with `scaffold`, `content`, and `edgeToEdge` policies.
- Adaptive back, dialog, date picker, time picker, and action-sheet wrappers.
- `PawMateContentFrame`, `PawMateActionCluster`, and centralized feature
  availability.

## Visual system

### Core palette

| Role | Value | Approved foreground |
|---|---|---|
| Deep Green | `#2D6A4F` | White |
| Brown | `#5C3C25` | White |
| Mint | `#95D5B2` | Brown/Deep Green only after contrast validation |
| Light Beige | `#E9F5DB` | Brown/Deep Green |
| White | `#FFFFFF` | Brown/Deep Green text |
| Error | `#8A3D2F` | Validated container foreground |
| Error container | `#F4D8CF` | Error/Brown after validation |

Unapproved color pairs are forbidden. In particular, White-on-Mint is not
allowed.

### Required semantic status tokens

- `success`, `successContainer`
- `warning`, `warningContainer`
- `error`, `errorContainer`
- `info`, `infoContainer`
- `offline`, `disabledContent`, `disabledContainer`
- `focusRing`, `scrim`, `divider`, `outline`
- pressed/hover overlays where the platform surface exposes them

Every token requires an approved foreground/background pair and contrast proof.

### Type, spacing, and geometry

- Typeface: Be Vietnam Pro 400/500/600/700; Material Icons only for icon glyphs.
- Type roles: 28/36 page/hero title, reducible to 24/32 on narrow or enlarged-
  text layouts; 18/24 app bar/section, 16/24 card title, 14/20 body/button/input,
  13/18 nav, and 12/16 minimum meta.
- Spacing: 4/8/12/16/20/24/32. Radius: 8/12/16/24.
- Button/input touch target is at least 48dp.
- A compact CTA may have a 36dp one-line visual surface while retaining a 48dp
  hit target. If text wraps or text scale exceeds 1.3, it grows intrinsically,
  changes to full width or vertical ActionCluster as needed, has no 52dp maximum,
  and never truncates an important label.
- Bottom-nav background covers the bottom system inset; content remains inside
  SafeArea. User/action text must not be forced through `FittedBox.scaleDown`.
- Border width, elevation, shadows, system-bar icon brightness, and pressed/focus
  overlays are semantic tokens, not one-off component values.

### Motion

- Motion communicates orientation or feedback only.
- Durations/easing are semantic tokens.
- Reduced-motion mode removes nonessential transitions and keeps tests
  settleable with animations disabled.

## Stitch and Image Gen use

- Stitch is exploratory, not source of truth. Use a new private project and
  only the five locked pilots documented by the wave plan.
- Figma clone v0.31 is the design source; Flutter is the runtime source.
- Image Gen is limited to privacy-safe Rescue fixture photography in design or
  test-only locations. It must not create logos, app/nav icons, controls, maps,
  badges, or UI screenshots.
- Generation budget is nine calls maximum: one design-system call, five Stitch
  screens, two image calls, and one reserve call.

## Deterministic proof plan

- Freeze locale `vi`, timezone/clock fixtures, fonts, device-pixel ratio, text
  scale, network, location, permission service, map canvas, data seed, and
  animation behavior.
- Figma proof: 56 v0.31 screen clones and 77 v0.32 responsive frames.
- Runtime responsive goldens: 71 total. The 390px canonical variant is already
  included for all 16 Phase 1 screens and must not be counted twice.
- Platform primitive goldens: 12 total - Android and iOS variants for back
  button, bottom nav, dialog, date picker, time picker, and action sheet.
- Runtime minimum: 83 goldens, plus any defect-specific regression goldens.
- Android evidence: API 34/35/36, gesture and three-button navigation, with a
  real API 34 device when available.
- iOS evidence: simulator build/render/interaction on small, notched, and Pro
  Max sizes. Real-iPhone/real-VoiceOver proof belongs to G4C if unavailable.
- Accessibility: labels/actions, focus, 4.5:1 normal-text contrast, 3:1 large
  text/non-text contrast, text scales 1.0/1.3/2.0, reduced motion, TalkBack
  journeys, and VoiceOver evidence where available.

## Evidence and privacy

- Use test accounts and synthetic data only.
- No token, real email, exact address, precise Rescue location, or identifiable
  person/property may appear in screenshots or logs.
- Secret-scan and redact logs before upload.
- Each evidence artifact records command, device/runtime, exit code, SHA-256,
  executor/reviewer, test-data-only status, and redaction status.

## Assumptions and open proof gaps

- The 56 live v0.29 source node IDs are captured in authoritative
  `SCREEN_INVENTORY.csv`. W3 must still record new clone IDs separately; no
  clone ID may be guessed from the source inventory or PNG filenames.
- Codemagic's supported exact Flutter/Xcode/CocoaPods combination must be
  discovered and pinned from a successful simulator baseline.
- The local Knowledge Vault checklist paths referenced by global rules were not
  present during this governance pass; this is a process-proof gap, not a UI
  acceptance waiver.
- Production rollout/monitoring remains out of scope unless separately
  authorized.

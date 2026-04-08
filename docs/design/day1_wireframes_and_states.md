# PawMate Day 1 - Wireframes and UI States

Scope: `D1-11 Wireframe - Phase 1 Flows`, `D1-12 Define 5 UI States Standard`

## 1) Wireframe principles

- Mobile-first, thumb-friendly, and low-clutter.
- Prioritize the next action, not decorative content.
- Vietnamese copy should be short and obvious.
- Every screen must have a clear empty path, error path, and recovery path.
- Keep auth, pet, vet, and health flows visually consistent.

## 2) Shared screen layout

- Top area: status bar plus title or logo.
- Main area: content block with one clear reading path.
- Bottom area: primary CTA or persistent actions.
- Support area: helper text, filter chips, or secondary links.

## 3) Phase 1 wireframes

### 3.1 Onboarding

Purpose: introduce the app in 3 slides and move the user into login or register.

Structure:
- Illustration
- Short headline
- One-line explanation
- `Skip` link
- `Get Started` primary button

Notes:
- Use a simple PageView with dots at the bottom.
- Keep CTA placement stable across slides.

### 3.2 Login, Register, OTP

Purpose: let the user sign in quickly and verify ownership.

Login layout:
- Email field
- Password field
- `Login` primary button
- `Continue with Google`
- `Continue with Apple`
- `Forgot password?` text link
- Link to register screen

Register layout:
- Email field
- Phone field
- Password field
- Confirm password field
- Terms checkbox
- `Create account` primary button

OTP layout:
- 6-digit code input
- Countdown resend text
- `Verify` primary button
- `Resend code` secondary link

Notes:
- Keep Google and Apple buttons visually equal.
- Show validation under the field, not as a toast.

### 3.3 Pet Profile: create and list

Purpose: let the user create a pet and switch between pets easily.

Create form layout:
- Avatar picker at top
- Name
- Species
- Breed
- Gender
- Date of birth
- Weight
- Color
- Microchip
- Neutered toggle
- Health status note
- `Save profile` primary button

List layout:
- Grid or stacked cards, depending on screen width
- Each card shows avatar, name, species, and quick status
- `+` FAB for new pet

Notes:
- Use species-specific helper text for breed field.
- Empty state should lead directly to create flow.

### 3.4 Vet Map

Purpose: give fast visual discovery of nearby clinics.

Structure:
- Search bar at top
- Map canvas
- Location control
- Filter chips row
- Bottom sheet preview for selected vet

Bottom sheet preview:
- Clinic name
- Distance
- Rating
- Open status
- `View details` button

Notes:
- Map must keep a fallback list action if location permission is denied.
- Selected marker should be obvious even at small zoom levels.

### 3.5 Vet List

Purpose: compare clinics without relying on the map.

Structure:
- Search bar
- Filter chips
- Sort control
- Result count
- Scrollable list of clinic cards

Clinic card content:
- Name
- Distance
- Rating
- Open status
- Service tags
- Short address

Notes:
- Keep sort and filter actions close to the results count.
- Each card should be tappable and lead to the detail page.

### 3.6 Vet Detail

Purpose: help the user decide and act immediately.

Structure:
- Cover image or map preview
- Clinic name and rating
- Address
- Hours
- Contact row
- Services
- Reviews preview
- CTA area with call and directions

Primary actions:
- `Call now`
- `Directions`

Notes:
- Missing data should be shown explicitly, not hidden.
- Keep contact and direction actions visible near the top or sticky at the bottom.

### 3.7 Health Timeline

Purpose: show health history in time order.

Structure:
- Pet selector at top
- Timeline header
- Record list with date grouping
- Filter by record type if needed
- `+` FAB for new record

Timeline card content:
- Record type icon
- Title
- Date
- Notes summary
- Reminder badge if linked

Notes:
- Most recent records should be easiest to scan.
- Use vertical rhythm to separate dates clearly.

## 4) UI states standard

### 4.1 Loading

When to use:
- Data is being fetched
- Screen is first opening

UI rules:
- Use shimmer skeletons that match the real layout.
- Keep navigation chrome visible if possible.
- Avoid jumping layouts.

### 4.2 Empty

When to use:
- No data exists yet
- Filtered results return nothing

UI rules:
- Illustration or friendly icon
- Short explanation
- One primary CTA

Empty state variants:
- First-use empty: guide the user into creation
- Filtered empty: guide the user into clearing filters

### 4.3 Error

When to use:
- Network failure
- Validation failure at page level
- Data fetch fails

UI rules:
- Error icon
- Short explanation
- Retry button
- If relevant, show a fallback path

### 4.4 Success

When to use:
- Action finished successfully
- Create, update, or save completed

UI rules:
- Use toast or snackbar
- Keep it brief
- Do not block the next step

### 4.5 Offline

When to use:
- Network unavailable
- User loses connection mid-flow

UI rules:
- Persistent banner at top or bottom
- Use cached data if available
- Allow read-only fallback where possible
- Show retry when connection returns

Fallback guidance:
- Vet map can fall back to last known list results.
- Pet profile and health timeline can show cached read-only content when available.

### 4.6 Permission blocked

When to use:
- The feature depends on a device permission such as location or media access.

UI rules:
- Explain why the permission is needed.
- Keep one retry path and one fallback path.
- Do not trap the user on a dead end.

Examples:
- Location denied in Vet Finder
- Photo picker denied in Create Pet

## 5) State priority

If multiple states apply at once, use this order:

1. Error
2. Offline
3. Loading
4. Empty
5. Success

Notes:
- Error and offline should never be hidden by an empty screen.
- Success should be transient and should not replace the screen content.

## 6) Handoff notes

- Wireframes in this file should map directly to the tokens and components in `day1_design_system.md`.
- The next implementation step is to turn these layouts into Figma frames or Flutter screen skeletons without changing the screen structure.
- Screen routing, reusable components, and state coverage are operationalized in `day1_flutter_handoff_matrix.md`.

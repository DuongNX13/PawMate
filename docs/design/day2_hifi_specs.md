# PawMate Day 2 - Hi-Fi Screen Specs

Scope: `D2-08 Onboarding`, `D2-09 Login/Register/OTP`, `D2-10 Pet Profile Form & List`

Goal: hand off hi-fi screen direction for Day 2 implementation while reusing the Day 1 design system without introducing new tokens or component patterns.

## 1) Shared design rules

- Use the Day 1 token set from `day1_design_system.md` only.
- Primary brand action stays `primary-500`; use `primary-100` for selected chips and soft highlights.
- Page background: `neutral-50` in light mode, `neutral-900` in dark mode.
- Surface cards and forms use `neutral-0` / elevated dark surface with `radius-md` or `radius-xl` depending on prominence.
- Typography stays Vietnamese-first with `Be Vietnam Pro` for all user-facing copy.
- Screen titles use `H1`; section labels use `Label`; helper text uses `Caption`.
- Primary CTA height: 48 px minimum. FAB: 56 px.
- Keep one primary action per screen and keep secondary actions visually lighter.
- All screens must support the Day 1 state stack: loading, empty, error, success, offline, and permission blocked where relevant.

## 2) Onboarding: 3 slides

### Screen goal

Introduce the app in three emotional, benefit-led slides and move the user toward auth.

### Layout

- Top area: generous safe-area padding with a small PawMate wordmark or minimal app mark.
- Main area: centered illustration with headline and one-line explanation.
- Bottom area: stable CTA row with `Skip` on the left and `Get Started` on the right.
- Dots sit above the CTA row and remain in a fixed position across slides.

### Visual direction

- Use soft, rounded, low-detail illustrations.
- Keep the illustration dominant, but leave enough breathing room so the headline never competes with it.
- Each slide gets a distinct accent cue while staying in the same brand family.
- Suggested accent pairing:
  - Slide 1: `secondary-500` for map / discovery cues
  - Slide 2: `primary-500` for community warmth
  - Slide 3: `accent-500` for rescue / protection emphasis

### Slide content

1. `Tim phong kham gan ban`
   - Support line: `Xem nhanh ban do va chon noi phu hop nhat cho thu cung.`
   - Illustration cue: map pin, clinic marker, route line.
2. `Cong dong yeu thu cung`
   - Support line: `Ket noi, chia se va hoc hoi tu nguoi nuoi thu cung khac.`
   - Illustration cue: people + paw / chat / community cards.
3. `Bao ve thu cung bi lac`
   - Support line: `Luu thong tin quan trong de tang co hoi tim lai khi can.`
   - Illustration cue: shield, pet profile, rescue alert.

### Interaction notes

- `Skip` jumps directly to login.
- `Get Started` jumps to register.
- Dots animate softly between states, but the layout does not shift.
- Use a single PageView with horizontal paging and no extra chrome.

### States

- Loading: show a simple illustration skeleton or static frame while assets load.
- Empty: not applicable.
- Error: use an inline retry message only if illustration assets fail to load.

## 3) Login, Register, OTP

### 3.1 Login screen

#### Layout

- Top: screen title `Dang nhap`, short support text, then the form.
- Form order: email, password, `Quen mat khau?` link aligned right below password.
- Primary button: `Dang nhap`.
- Social actions: `Tiep tuc voi Google` and `Tiep tuc voi Apple` below the primary button.
- Secondary link at bottom: `Chua co tai khoan? Dang ky`.

#### Visual hierarchy

- Email and password fields use full width with `radius-md`.
- Social buttons are equal width, equal height, and visually balanced.
- Keep the `Quen mat khau?` link understated but easy to hit.
- Use `neutral-0` cards over `neutral-50` background with a soft shadow so the auth stack feels focused.

#### Validation and feedback

- Validate inline under each field.
- Error color uses `error`; helper text uses `neutral-500`.
- Loading state locks the submit button and social buttons independently.
- Success is a brief snackbar after auth handoff, not a blocking modal.

### 3.2 Register screen

#### Layout

- Top: screen title `Tao tai khoan` and one-line help text.
- Form order: email, phone, password, confirm password, terms checkbox.
- Primary button: `Tao tai khoan`.
- Bottom link: `Da co tai khoan? Dang nhap`.

#### Visual hierarchy

- Keep the form in a single vertical flow, no split columns on mobile.
- Terms checkbox sits directly above the primary CTA so the consent action is visible before submit.
- Use compact helper text to explain password rules instead of long paragraphs.

#### Validation and feedback

- Email field checks format and duplicates.
- Phone field accepts a local Vietnamese format.
- Password and confirm password show inline mismatch handling.
- Terms checkbox error appears inline near the checkbox, not at the top of the form.

### 3.3 OTP verification screen

#### Layout

- Top: title `Xac minh ma OTP`, short explanatory text, and the target email/phone shown in a muted caption.
- Main block: six-digit code input centered within the viewport.
- Support row: resend timer on the left, `Gui lai ma` action on the right when available.
- Bottom: primary button `Xac minh`.

#### Visual hierarchy

- The code entry should feel like the main focus of the screen.
- Use a pin-style field with six cells and clear focus states.
- Countdown text remains visible during loading and verification.

#### Interaction notes

- Auto-submit when the 6th digit is entered.
- Paste should distribute digits across all cells.
- Resend is disabled until the timer ends.
- If the code is invalid, keep the user on the same screen and show an inline field error.

#### States

- Loading: keep code field visible and lock submit while verifying.
- Error: show field-level error, plus retry affordance if the verification request fails.
- Success: transition immediately to the next step, no full-screen success panel.

## 4) Pet Profile: create form and list

### 4.1 Create Pet form

#### Layout

- Top: screen title `Them thu cung` and short helper text.
- First block: avatar picker centered at the top, large enough to feel like the entry point.
- Form stack:
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
- Bottom: sticky primary CTA `Luu ho so`.

#### Visual hierarchy

- Avatar picker is the highest-priority visual element after the title.
- Use a card-like form container with `radius-lg` so the screen feels slightly more premium than login.
- Group related fields with vertical rhythm rather than section dividers unless the screen becomes crowded.

#### Conditional field behavior

- Species drives the breed options.
- Breed field shows species-specific helper text when the dropdown is empty.
- Use a compact enum-style dropdown for species and gender.
- Weight field includes `kg` as a unit hint, not as a separate label block.

#### Interaction notes

- Avatar upload shows inline progress near the avatar.
- Date of birth opens a picker; selected value returns in a short locale-friendly format.
- Save button stays pinned at the bottom on small screens.

#### States

- Loading: skeleton for form fields and avatar area.
- Error: inline error under the field that caused the failure.
- Success: snackbar confirmation and return to list or detail flow.
- Permission blocked: if photo access is denied, show a fallback avatar and a `Thu lai` path.

### 4.2 Pet List screen

#### Layout

- Top: title `Thu cung cua toi`.
- Optional secondary text: count or friendly empty prompt.
- Main area: grid cards with avatar, name, species, and quick health status.
- Bottom-right: FAB for adding a new pet.

#### Card spec

- Avatar: circular, prominent, and aligned to the top of each card.
- Name: largest text on the card.
- Species: secondary line with muted text.
- Health status: compact badge or short meta line using semantic color.
- Keep the card tappable as a single target area.

#### Grid behavior

- 1 column below 390 px.
- 2 columns at 390 px and above.
- Use consistent gaps so the grid feels intentional, not crowded.

#### Empty state

- Show a friendly empty illustration or icon.
- Copy should direct the user to add the first pet immediately.
- Primary CTA: `Them thu cung`.

#### Interaction notes

- Tap card to open pet detail later; for Day 2, the card should still look navigable.
- FAB uses `primary-500` fill with a white plus icon.
- When multiple pets exist, keep the first row visually stable so cards do not jump while images load.

## 5) Asset handoff list

- 3 onboarding illustrations:
  - map / discovery
  - community / sharing
  - rescue / protection
- Auth icons for Google and Apple social buttons
- OTP keypad visual treatment
- Default pet avatar
- Pet list empty-state illustration or icon

## 6) Flutter handoff notes

- Reuse the Day 1 route and component conventions from `day1_flutter_handoff_matrix.md`.
- Onboarding maps to `/onboarding`, login to `/auth/login`, register to `/auth/register`, OTP to `/auth/otp`, pet list to `/pets`, and create pet to `/pets/create`.
- Keep auth and pet screens in the same visual family so the transition feels seamless.
- Avoid introducing custom spacing or radius values beyond the Day 1 token scale.
- The implementation should be screen-skeleton friendly: structure first, polish second, with no layout rework expected after handoff.

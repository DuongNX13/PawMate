# PawMate Day 1 Flutter Handoff Matrix

This addendum turns the Day 1 design docs into a lower-ambiguity handoff for Day 2 Flutter work.

## Route inventory

| Route | Screen | Purpose |
|---|---|---|
| `/onboarding` | `OnboardingScreen` | Intro slides with skip/get-started entry |
| `/auth/login` | `LoginScreen` | Email/password and social login |
| `/auth/register` | `RegisterScreen` | Account creation |
| `/auth/otp` | `OtpVerificationScreen` | Ownership verification |
| `/pets` | `PetListScreen` | User pet list |
| `/pets/create` | `CreatePetScreen` | Create a pet profile |
| `/vets/map` | `VetMapScreen` | Nearby clinics on map |
| `/vets/list` | `VetListScreen` | Nearby clinics in list form |
| `/vets/:id` | `VetDetailScreen` | Clinic detail and action |
| `/pets/:id/health` | `HealthTimelineScreen` | Pet health history |

## Reusable component inventory

| Component | Used in | Notes |
|---|---|---|
| `PrimaryButton` | Most screens | Full-width, 48 px min height, loading lock |
| `SocialAuthButton` | Login | Icon leading, equal width between Google and Apple |
| `AppTextField` | Login, Register, Pet Create | Supports helper, error, disabled |
| `OtpCodeField` | OTP | Six digits, auto-advance, paste friendly |
| `PetCard` | Pet List | Avatar, name, species, quick health status |
| `VetCard` | Vet List | Name, distance, rating, open state, services |
| `FilterChipPill` | Vet Map, Vet List | Selected/unselected state |
| `StatePanel` | All screens | Shared empty/error/loading surface |
| `OfflineBanner` | Vet flows, data flows | Persistent non-blocking banner |
| `BottomActionBar` | Vet Detail | Call + directions pair |

## Screen-state coverage matrix

| Screen | Page loading | Inline loading | Empty | Error | Success | Offline | Permission blocked |
|---|---|---|---|---|---|---|---|
| Onboarding | No | No | No | No | No | No | No |
| Login | No | Yes | No | Yes | Yes | No | No |
| Register | No | Yes | No | Yes | Yes | No | No |
| OTP | No | Yes | No | Yes | Yes | No | No |
| Pet List | Yes | Yes | Yes | Yes | Yes | Yes | No |
| Create Pet | No | Yes | No | Yes | Yes | No | Photo picker denied |
| Vet Map | Yes | Yes | Yes | Yes | No | Yes | Yes |
| Vet List | Yes | Yes | Yes | Yes | No | Yes | No |
| Vet Detail | Yes | Yes | Yes | Yes | No | Yes | No |
| Health Timeline | Yes | Yes | Yes | Yes | Yes | Yes | No |

## Action-level rules

- Auth submit buttons lock during request and keep page layout stable.
- Social auth buttons lock independently so one provider does not block the other forever after an error.
- OTP screen keeps resend timer visible while verify action is in progress.
- Pet avatar upload uses inline progress near the avatar instead of replacing the whole form.
- Vet map can show map loading while top search/filter controls stay interactive.
- Vet list refresh keeps current results visible until the new result set lands.

## Permission-blocked state

Use this only when the feature depends on device permission and the user has denied it.

- Title: `Cần quyền truy cập vị trí`
- Body: `Cho phép vị trí để xem phòng khám gần bạn hoặc chuyển sang danh sách tìm kiếm thủ công.`
- Primary CTA: `Thử lại`
- Secondary CTA: `Xem danh sách`

## Field mapping by screen

### Login
- `email`
- `password`

### Register
- `email`
- `phone`
- `password`
- `confirmPassword`
- `acceptTerms`

### Create Pet
- `name`
- `species`
- `breed`
- `gender`
- `dob`
- `weightKg`
- `color`
- `microchipNumber`
- `isNeutered`
- `avatarUrl`
- `healthStatus`

### Vet Card / Detail
- `name`
- `address`
- `phone`
- `openingHours`
- `is24h`
- `averageRating`
- `reviewCount`
- `services`

## Placeholder asset list

- Onboarding illustrations: 3 temporary SVG/PNG scenes
- Empty pet list illustration
- Empty vet result illustration
- Default pet avatar
- Clinic image placeholder
- Health record type icons

## Small-screen rules

- Default mobile width target is 360-430 px.
- `PetListScreen` uses 1 column below 390 px and 2 columns from 390 px upward.
- Vet service chips should wrap to two lines before truncating card meta.
- Clinic titles truncate after 2 lines; addresses truncate after 2 lines.

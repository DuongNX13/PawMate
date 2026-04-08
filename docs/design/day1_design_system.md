# PawMate Day 1 - Design System

Scope: `D1-09 Design System - Colors and Typography`, `D1-10 Design System - Spacing and Components`

## 1) Design goals

- Vietnamese-first UI copy, clear and calm.
- Trustworthy, friendly, and practical for pet owners.
- Mobile-first layout with strong readability in one-handed use.
- Support both light mode and dark mode from the start.
- Keep visual hierarchy simple enough for fast scanning in vet, pet, and health flows.

## 2) Color system

### 2.1 Brand palette

| Token | HSL | Use |
|---|---|---|
| `primary-50` | `hsl(165 60% 95%)` | Soft background tint |
| `primary-100` | `hsl(165 55% 88%)` | Subtle fill, chip background |
| `primary-300` | `hsl(166 60% 62%)` | Hover, secondary emphasis |
| `primary-500` | `hsl(166 68% 38%)` | Main action color |
| `primary-700` | `hsl(168 72% 26%)` | Pressed state, strong emphasis |
| `secondary-50` | `hsl(208 80% 96%)` | Soft info surfaces |
| `secondary-300` | `hsl(209 72% 62%)` | Supporting accent |
| `secondary-500` | `hsl(210 78% 45%)` | Links, map emphasis, secondary action |
| `secondary-700` | `hsl(214 82% 30%)` | Dark supporting emphasis |
| `accent-50` | `hsl(18 100% 96%)` | Warm highlight background |
| `accent-300` | `hsl(17 92% 68%)` | Badge, attention accent |
| `accent-500` | `hsl(16 88% 56%)` | Rare emphasis, urgent hint |
| `accent-700` | `hsl(14 84% 42%)` | Strong warm emphasis |

### 2.2 Neutral palette

| Token | HSL | Use |
|---|---|---|
| `neutral-0` | `hsl(0 0% 100%)` | Surface in light mode |
| `neutral-50` | `hsl(210 20% 98%)` | App background |
| `neutral-100` | `hsl(214 18% 94%)` | Soft divider or section fill |
| `neutral-200` | `hsl(214 16% 86%)` | Border |
| `neutral-500` | `hsl(217 10% 46%)` | Secondary text |
| `neutral-700` | `hsl(220 14% 28%)` | Primary text in light mode |
| `neutral-900` | `hsl(222 24% 12%)` | Strong text and dark surfaces |

### 2.3 Semantic colors

| Token | HSL | Use |
|---|---|---|
| `success` | `hsl(145 60% 38%)` | Done, saved, active |
| `warning` | `hsl(38 95% 52%)` | Needs attention, limited data |
| `error` | `hsl(0 78% 54%)` | Validation, failure, retry |
| `info` | `hsl(210 85% 45%)` | Tips, neutral guidance |

### 2.4 Dark mode mapping

- Background: `neutral-900`
- Surface: `hsl(224 18% 16%)`
- Elevated surface: `hsl(224 18% 20%)`
- Primary text: `hsl(0 0% 98%)`
- Secondary text: `hsl(220 10% 72%)`
- Border: `hsl(222 14% 28%)`
- Primary action keeps the same hue family but shifts one step lighter for contrast.

## 3) Typography

### 3.1 Font families

- Latin: `Inter`
- Vietnamese: `Be Vietnam Pro`
- System fallback: `system-ui, sans-serif`

### 3.2 Type scale

| Token | Size | Line height | Weight | Use |
|---|---:|---:|---:|---|
| `Display` | 32 px | 40 px | 700 | Landing hero, major empty states |
| `H1` | 28 px | 36 px | 700 | Screen title |
| `H2` | 24 px | 32 px | 700 | Section title |
| `H3` | 20 px | 28 px | 600 | Card title, modal title |
| `H4` | 18 px | 26 px | 600 | Subsection title |
| `Body` | 16 px | 24 px | 400 | Main reading text |
| `Body Strong` | 16 px | 24 px | 600 | Highlighted body text |
| `Label` | 14 px | 20 px | 600 | Form labels, chips |
| `Caption` | 12 px | 18 px | 400 | Meta, timestamps, helper text |
| `Overline` | 11 px | 16 px | 700 | Small category tag |

### 3.3 Type rules

- Use `Be Vietnam Pro` for all user-facing Vietnamese text.
- Keep sentence case and short labels.
- Avoid all-caps labels except small utility badges.
- Keep line length short on mobile, especially in onboarding and empty states.

## 4) Spacing, radius, shadow

### 4.1 Spacing scale

| Token | Value |
|---|---:|
| `space-1` | 4 px |
| `space-2` | 8 px |
| `space-3` | 12 px |
| `space-4` | 16 px |
| `space-5` | 24 px |
| `space-6` | 32 px |
| `space-7` | 48 px |
| `space-8` | 64 px |

### 4.2 Radius tokens

| Token | Value | Use |
|---|---:|---|
| `radius-sm` | 8 px | Small chips, inputs |
| `radius-md` | 12 px | Cards, buttons |
| `radius-lg` | 16 px | Bottom sheets, featured cards |
| `radius-xl` | 24 px | Hero cards, onboarding panels |
| `radius-pill` | 999 px | Pills, tags, segmented actions |

### 4.3 Shadow levels

| Token | Use |
|---|---|
| `shadow-1` | Small lift for cards and inputs |
| `shadow-2` | Floating action button, bottom sheet handle |
| `shadow-3` | Dialogs, important overlays |

Shadow should stay soft, not heavy, to keep PawMate friendly and calm.

## 5) Icon and illustration rules

- Base icon set: `Lucide`.
- Add custom pet icons for dog, cat, paw, clinic, map pin, health record, reminder, and rescue.
- Icon stroke should stay consistent across the app.
- Illustrations should be simple, rounded, and friendly, with low-detail shapes for empty states and onboarding.

## 6) Core components

### 6.1 Button

Variants:
- `Primary`: filled `primary-500`, white text
- `Secondary`: neutral outline with brand text
- `Ghost`: transparent, used for low-priority actions
- `Danger`: error-colored destructive action

States:
- Default
- Hover
- Pressed
- Disabled
- Loading with spinner

Rules:
- One primary action per screen.
- Button labels should be action-first in Vietnamese.
- Primary button min height: `48 px`.

### 6.2 Input

States:
- Default
- Focus
- Filled
- Error
- Disabled

Rules:
- Show label above the field.
- Use helper text for constraints, not long explanations.
- Error message must explain the fix.
- Text field min height: `48 px`.

### 6.3 Card

Use for:
- Pet summaries
- Vet summaries
- Health record entries
- Reminder items

Card anatomy:
- Leading icon or avatar
- Title
- Supporting text
- Status or meta row
- Optional action area

Rules:
- Card padding baseline: `16 px`.
- Vet card title max lines: `2`.
- Address max lines: `2`.

### 6.4 Chip or Filter pill

- Use for species, service, rating, open-now, or radius filters.
- Selected state uses `primary-100` with `primary-700` text.
- Chip min height: `32 px`.

### 6.5 Top bar

- Screen title on the left.
- Utility action on the right when needed.
- Keep actions minimal in MVP.

### 6.6 Floating action button

- Use only when the screen has a clear primary create action.
- Example: add pet, add health record.
- FAB size: `56 px`.

## 7) Flutter token mapping

Use these naming aliases in code to avoid ad hoc token names:

| Design token | Flutter alias |
|---|---|
| `primary-500` | `AppColors.primary500` |
| `neutral-50` | `AppColors.background` |
| `neutral-0` | `AppColors.surface` |
| `neutral-700` | `AppColors.textPrimary` |
| `neutral-500` | `AppColors.textSecondary` |
| `space-4` | `AppSpacing.s16` |
| `space-5` | `AppSpacing.s24` |
| `radius-md` | `AppRadius.md` |
| `radius-lg` | `AppRadius.lg` |
| `H1` | `AppTextStyles.h1` |
| `Body` | `AppTextStyles.body` |
| `Label` | `AppTextStyles.label` |

## 8) Semantic aliases

- Page background: `AppColors.background`
- Card background: `AppColors.surface`
- Input border default: `AppColors.border`
- Input border focus: `AppColors.primary500`
- Input border error: `AppColors.error`
- Disabled foreground: `AppColors.textSecondary`
- Disabled background: `AppColors.neutral100`
- Success container: `AppColors.success`
- Warning container: `AppColors.warning`
- Error container: `AppColors.error`
- Map selected marker: `AppColors.secondary500`
- Map default marker: `AppColors.primary500`

## 9) Implementation notes

- Use token names in code rather than hardcoded values.
- Preserve contrast in both light and dark mode.
- Keep Vietnamese copy short enough to fit on small screens.
- Design tokens should support `D1-11` wireframes and `D1-12` state standards without one-off exceptions.
- See `day1_flutter_handoff_matrix.md` for route, state, and component mapping.

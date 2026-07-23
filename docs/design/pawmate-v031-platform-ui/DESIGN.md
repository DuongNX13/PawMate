# Design System: PawMate v0.31 Cross-Platform Chocomint

## Source Of Truth

This `DESIGN.md` is a prompt contract for Stitch exploration. It does not replace the PawMate repository, the locked v0.29 Figma source, approved routes, accessibility requirements, Day 35/36 Rescue API contracts, or user instructions.

- Project: PawMate.
- Platform: Flutter phone app for Android and iOS, light theme only in this change control.
- Locked Figma source: file `zPyYIN058igxtbj44G30o8`, section `442:2`, 56 source frames. Never mutate historical nodes.
- Existing app shell: bottom navigation `Home / Vet / Health / Rescue / Profile`.
- IA lock: preserve those five tabs and their ownership. Do not add a dashboard or adoption tab.
- Phase lock: Phase 1 is runtime; Phase 2 is design-only except the fail-closed Rescue shell. Rescue browse/create remain disabled until G5A and their roadmap days pass.
- State and permission lock: loading, empty, error, disabled, permission, offline/stale, overflow, keyboard/IME, and success must remain explicit. Only a case owner may change Rescue found/not-found status.

## 1. Visual Theme And Dials

Design Read: a warm, trustworthy and practical Vietnamese pet-care mobile product, using a restrained Chocomint system with native Android/iOS behavior and compact task-led controls.

- `DESIGN_VARIANCE`: 3/10 — preserve proven information architecture and predictable mobile scanning.
- `MOTION_INTENSITY`: 2/10 — motion only for orientation, state change and feedback.
- `VISUAL_DENSITY`: 6/10 — useful care information remains visible without oversized cards or buttons.

The UI should feel calm, friendly and credible, not childish, luxury, game-like, neon or generically AI-generated. Use open layouts, clear section rhythm and warm photography only where a real pet subject adds meaning.

## 2. Color Palette And Roles

- **Primary / Deep Green** (`#2D6A4F`): primary actions, active structural cues, high-emphasis icons; use white content when contrast passes.
- **Brand Brown** (`#5C3C25`): primary text, warm outline icons and selected non-filled labels; never use as a low-contrast decorative tint.
- **Mint** (`#95D5B2`): secondary surfaces, selected quiet controls and success-adjacent decoration; use Deep Green or Brown content, not white text.
- **Light Beige** (`#E9F5DB`): app background and low-emphasis containers.
- **White** (`#FFFFFF`): cards, sheets, fields and high-contrast content on Deep Green.
- **Success** (`#2D6A4F`) and **Success Container** (`#D8F3DC`): completed/safe states.
- **Warning** (`#8A5A16`) and **Warning Container** (`#F7E7BF`): due/overdue or caution, never Rescue danger.
- **Error** (`#8A3D2F`) and **Error Container** (`#F4D8CF`): errors and destructive confirmation.
- **Info** (`#315B72`) and **Info Container** (`#DCEAF1`): neutral information and permission explanation.
- **Offline** (`#5F6368`): offline/stale content with a text label, never color alone.
- **Disabled Content** (`#7B746F`) and **Disabled Container** (`#E6E1DD`).
- **Outline** (`#B9AAA1`), **Divider** (`#DED4CE`), **Focus Ring** (`#2D6A4F`), **Scrim** (`#1B1C1B` at 40%).

Approved combinations must meet readable contrast: normal text at least 4.5:1 and large text/non-text controls at least 3:1. Do not use white text on Mint, pale beige text on White, or status color without a label/icon.

## 3. Typography Rules

- Family: bundled `Be Vietnam Pro` only, with weights 400, 500, 600 and 700. Material Icons may be used for platform icons. No Inter or Plus Jakarta Sans in v0.31 clones/runtime.
- Page title: 28/36, weight 700; may reduce to 24/32 on narrow or high text-scale layouts, never clip.
- Top app bar title: 22/28, weight 700.
- Section title: 20/28, weight 700.
- Card/row title: 16/24, weight 600 or 700.
- Body and field value: 16/24, weight 400.
- Button label: 14/20, weight 600.
- Supporting metadata: 13/18 or 12/16, weight 400/500; 12 is the minimum for non-critical metadata only.
- Vietnamese diacritics must remain intact. Body descriptions wrap naturally; chat and long descriptions never overflow their container.
- Primary action labels never truncate. If text does not fit, the component changes layout or height.

## 4. Component Rules

### Buttons and action clusters

- Primary buttons use Deep Green fill with White label, 12px radius, at least 48px visual and semantic height.
- Compact secondary/destructive actions may have a 36px visible control only when the label is one line and text scale is at most 1.3; the semantic touch target remains at least 48x48.
- At text scale above 1.3, with two-line copy, or when labels do not fit, change the action cluster to vertical/full-width and auto-height. No 52px hard maximum in accessibility layouts.
- Never use `FittedBox`, forced scaling or ellipsis for a primary CTA. Keep controls centered horizontally and vertically.
- Pressed state: restrained 8–12% overlay; disabled state: disabled semantic tokens; focus: 2px visible focus ring where keyboard/focus applies.

### Bottom navigation

- Preserve five equal destinations: Home, Vet, Health, Rescue, Profile.
- Compact content height is 68px plus the real bottom safe-area inset. The bar uses a White surface, 24px top corner radius, subtle outline and no heavy floating shadow.
- Icon size 24px; label 13/18. Each destination owns at least a 48x48 semantic target.
- Active destination uses a restrained Deep Green filled capsule sized by constraints, not a fixed screen width. Inactive icons/labels use Brown. Rescue uses the approved outlined shield/pet-rescue icon, not the paw icon from v0.29.
- Reselecting the active tab returns to branch root or scrolls to top. The bar never covers scroll content or the keyboard.

### Top bars and native primitives

- Use platform-adaptive Flutter primitives for back behavior, dialogs, date/time pickers and action sheets.
- Android root back follows system back and exits only from a branch root; iOS pushed screens support the native back affordance and edge-swipe semantics.
- Top bars keep the title visually consistent at 22/28; small contextual labels must not masquerade as a page title.

### Cards, rows, fields and status

- Use cards only for meaningful grouping. Prefer rows/dividers for dense health, reminder and notification lists; avoid nested-card stacks.
- Default card radius 16px, 1px semantic outline and very low elevation. Large sheets may use 24px top radius.
- Text fields have persistent label, helper/error association, at least 48px control height, centered single-line values and auto-growing multiline content.
- Rescue status chips expose exactly `Chưa thấy` and `Đã thấy`; only the owner sees the official status action.
- Loading uses deterministic skeletons. Empty/error/permission/offline views include a plain-language title, explanation and one real recovery action when available.

## 5. Layout And Responsive Rules

- Primary phone proof widths: 360, 390, 412 and 430 logical pixels. Canonical height is 844 where applicable; device-specific taller proofs may use 915/932.
- Use `SafeArea`, `MediaQuery` and constraint-driven layouts. Do not hardcode a 375/390 screen canvas in runtime.
- Page gutter: 20px canonical, allowed to reduce to 16px at 360. Spacing scale: 4, 8, 12, 16, 20, 24 and 32.
- Content scrolls behind neither fixed CTA nor bottom navigation; include their measured height and system inset in bottom padding.
- Map canvases may be edge-to-edge, but controls, sheets and semantics stay within safe areas. Rescue public location is approximate and shows an uncertainty area, never exact coordinates/directions.
- At large text scale, horizontal action groups become vertical; metadata can wrap; chat bubbles and descriptions cap width by constraints and grow vertically.
- Keyboard/IME must keep the focused field and submit action reachable. No horizontal overflow.

## 6. Motion And Interaction Rules

- Default feedback is 150–220ms with standard platform easing; use opacity/transform only when helpful.
- Tab changes preserve branch state without decorative page choreography.
- Loading animation is subtle and deterministic in tests. No infinite decorative loops.
- Reduced-motion mode removes non-essential transitions and preserves all state feedback.

## 7. Accessibility And State Rules

Required states: default, loading, empty, error, success, disabled, permission denied/restricted, offline/stale and overflow/long content.

- Touch targets are at least 48x48 in runtime even when the visible compact control is smaller.
- Every icon-only action has a Vietnamese semantic label. Status and validation do not rely on color alone.
- Support text scales 1.0, 1.3 and 2.0 without clipped or overlapping text.
- Keep traversal order aligned with visual order. Dialogs/sheets return focus to their trigger where applicable.
- Permission screens explain why access is needed and offer a non-map/list fallback when possible.
- Fixed controls never cover content; chat composers account for IME and safe-area insets.

## 8. Content, Imagery And Data Rules

- Voice: plain, warm Vietnamese; short verbs and concrete next steps. Avoid marketing filler.
- Use only test-safe/sample people, animals and locations. Never expose real email, token, exact address or exact Rescue coordinate in evidence.
- Generated Lulu/Mực images are synthetic design/test fixtures labelled `Dữ liệu minh họa`; they are never bundled as production assets.
- Do not invent statistics, medical claims, rescue precision, contacts or routes.
- Rescue browse data is in-memory only under `no-store`; stale content is labelled immediately and purged when route/session ends.

## 9. Anti-Patterns

Do not:

- mutate, rename, move, reparent or restyle historical Figma sections;
- replace the five-tab shell, add a Home Dashboard, or promote adoption to primary navigation;
- use a paw icon for Rescue when the approved outlined Rescue shield asset exists;
- use giant CTA blocks, two-line labels inside a 36px control, or `FittedBox` to hide overflow;
- hide owner/viewer permission differences or add `Báo thấy` as an official public status;
- expose exact lost-pet coordinates, directions, private contact data or fake map precision;
- repeat identical nested cards, use decorative gradients/glows, or use generic AI copy;
- generate UI screenshots, nav icons or logos with Image Gen.

## 10. Stitch Screen Task Contract

Generate exactly one named mobile screen per request using this design system and `GEMINI_3_1_PRO` in MOBILE mode. Preserve the five-tab shell and the screen's real route/state ownership. Include only requested states and controls. Treat output as visual exploration; it must pass IA, state, permission, safe-area, long-text and accessibility review before implementation.

Pilot set:

1. `S01_P1-01_Onboarding_SafeArea` — onboarding with safe-area and high text-scale behavior.
2. `S02_P1-07_Home_Hierarchy` — Home hierarchy and corrected compact bottom navigation.
3. `S03_P1-08_VetMap_Permission` — map permission/fallback with safe controls.
4. `S04_P2-01_RescueHome_FinalContract` — design-only Rescue browse shell with approximate-location privacy and flags off.
5. `S05_P2-12_ShelterChat_Overflow` — design-only chat overflow/IME proof.

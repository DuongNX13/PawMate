# PawMate Phase 1 - Day 1 User Stories and Definition of Done

## Scope

This document covers Morpheus ownership for:
- `D1-07` User Stories - Phase 1
- `D1-08` Definition of Done - Phase 1

## MVP priority order

If scope must be cut to preserve delivery, use this order:

1. Auth
2. Pet Profile
3. Vet Finder core discovery and actionability
4. Health Records basic capture and history
5. Reminder scheduling polish after the core record flow is stable

## Deferred note

- Review remains documented in architecture scope but is not treated as a Day 1 product-ready module in this file.
- Social, marketplace, adoption, rescue, payments, and AI features remain out of scope.

---

## 1) User Stories - Auth

### AUTH-01 - Register by email
**As a** pet owner, **I want** to create an account with my email and password, **so that** I can securely access PawMate and save my pet information.

**Description**
- User can submit email and password to create a new account.
- System validates email format, password minimum strength, and duplicate email.
- On success, system prompts the user to verify their account if verification is required.

### AUTH-02 - Login to existing account
**As a** returning pet owner, **I want** to log in with my account, **so that** I can continue managing my pets and clinic-related activities.

**Description**
- User can log in with valid credentials.
- System returns a valid authenticated session.
- User sees clear error messaging for invalid credentials or blocked access.

### AUTH-03 - Login with social account
**As a** pet owner, **I want** to sign in with Google or Apple, **so that** I can access PawMate faster without creating another password.

**Description**
- User can authenticate through supported OAuth providers.
- System creates or links the account safely.
- User lands in the authenticated flow after successful sign-in.

### AUTH-04 - Keep session active safely
**As a** logged-in user, **I want** my session to stay active securely, **so that** I do not need to log in again every time I reopen the app.

**Description**
- System supports token refresh or equivalent session renewal.
- Expired or invalid sessions require the user to re-authenticate safely.
- Session behavior should not create duplicate or broken login states.

### AUTH-05 - Logout from the app
**As a** pet owner, **I want** to log out of PawMate, **so that** my account stays safe on shared or lost devices.

**Description**
- User can log out from the authenticated area.
- System invalidates the active session.
- User is redirected back to the unauthenticated entry point.

---

## 2) User Stories - Pet Profile

### PET-01 - Create a pet profile
**As a** pet owner, **I want** to create a profile for my pet, **so that** I can store the pet identity and use PawMate features in the right context.

**Description**
- User can add a pet with core information such as name, species, breed, gender, date of birth, and photo.
- Required and optional fields are clearly separated.
- Newly created pet appears in the user pet list.

### PET-02 - View all my pets
**As a** multi-pet owner, **I want** to see a list of all my pets, **so that** I can quickly choose the correct pet when checking records or planning care.

**Description**
- User can open a pet list screen after login.
- Each pet card shows enough identifying information to distinguish pets quickly.
- Empty state clearly invites the user to create the first pet.

### PET-03 - Edit a pet profile
**As a** pet owner, **I want** to update my pet profile details, **so that** PawMate always reflects the latest information.

**Description**
- User can edit existing pet details, including avatar and health-related identity fields.
- Saved changes are reflected consistently in detail and list views.
- Validation prevents invalid or incomplete required data.

### PET-04 - Remove a pet profile
**As a** pet owner, **I want** to remove a pet profile I no longer manage, **so that** my account stays clean and relevant.

**Description**
- User can remove a pet profile they own.
- System prevents accidental destructive action through confirmation.
- Removed pet should no longer appear in the active list.

---

## 3) User Stories - Vet Finder

### VET-01 - Find nearby clinics
**As a** pet owner, **I want** to see nearby veterinary clinics based on my location, **so that** I can quickly find care close to me.

**Description**
- User can allow location access and view nearby vets.
- System returns clinics within a supported search radius.
- If location is unavailable, user still gets a safe fallback path.

### VET-02 - Browse clinics on a map
**As a** pet owner, **I want** to browse vets on a map, **so that** I can understand distance and choose the most convenient option.

**Description**
- User can view clinic markers on a map.
- Tapping a marker reveals enough summary information to continue.
- Map behavior remains understandable across loading, empty, and permission-denied states.

### VET-03 - Browse clinics in a list
**As a** pet owner, **I want** to browse clinics in a list, **so that** I can compare options quickly without relying only on the map.

**Description**
- User can switch to or access a list representation of nearby/search results.
- Each list item shows key decision information such as name, distance, rating, services, or open status.
- List ordering matches selected sort logic.

### VET-04 - Filter and sort clinic results
**As a** pet owner, **I want** to filter and sort clinic results, **so that** I can narrow options to the ones that match my urgency and needs.

**Description**
- User can apply filters such as distance, open now, 24h support, rating, or service-related tags.
- System updates results correctly for each supported combination.
- User can remove or reset filters easily.

### VET-05 - View clinic details
**As a** pet owner, **I want** to open a clinic detail page, **so that** I can review enough information before deciding where to go.

**Description**
- Detail page includes address, operating hours, contact info, services, and review summary if available.
- Information is structured for quick scanning.
- Missing data is handled clearly without breaking trust.

### VET-06 - Take action from clinic details
**As a** pet owner, **I want** to call the clinic or open directions from the detail page, **so that** I can act immediately when my pet needs care.

**Description**
- User can tap to call the clinic.
- User can open directions in the device supported map app.
- Failed external actions show clear fallback messaging.

---

## 4) User Stories - Health Records

### HEALTH-01 - Add a health record
**As a** pet owner, **I want** to add a health record for my pet, **so that** I can keep important care information in one place.

**Description**
- User can create records for events such as vaccination, check-up, medication, allergy, or note.
- Record entry captures date, type, and relevant notes.
- New records are associated with the correct pet.

### HEALTH-02 - View health history
**As a** pet owner, **I want** to view my pet health history in time order, **so that** I can quickly understand past care and prepare for future visits.

**Description**
- User can see health records in a timeline or history list.
- Recent and past events are easy to distinguish.
- Empty state explains how to add the first record.

### HEALTH-03 - Edit or delete a health record
**As a** pet owner, **I want** to update or remove incorrect health records, **so that** my pet history stays accurate.

**Description**
- User can edit existing records.
- User can delete records with confirmation.
- Updated data appears consistently across related views.

### HEALTH-04 - Set reminders for care events
**As a** pet owner, **I want** to create reminders for vaccinations and check-ups, **so that** I do not miss important care dates.

**Description**
- User can create reminders tied to a pet and care event.
- Reminder includes date/time and relevant label.
- System can surface reminder information in-app and through notification flows when supported.

---

## 5) Definition of Done - Phase 1

This is the broad quality bar for Phase 1. Use the operational addendum below to decide whether a Day 1 artifact is really done.

### Product and scope
- The deliverable maps to an approved Phase 1 user story or contract.
- Scope is limited to Phase 1 goals: Auth, Pet Profile, Vet Finder, Review, Health Records, and related notifications only.
- Any out-of-scope behavior is explicitly deferred and documented.

### Functional completeness
- Happy path works end-to-end for the target feature.
- Core edge cases and validation rules are handled.
- Ownership and access rules are enforced where relevant.
- All required fields, states, and actions are implemented as specified.

### Quality and testing
- Unit test coverage is at least 80% for relevant business logic.
- Critical integration paths are tested.
- No blocker or critical severity defects remain open.
- Repro steps exist for any known non-critical defects.

### Performance and reliability
- API responses for Phase 1 endpoints meet target performance of under 300 ms p95 in staging-normal conditions, excluding clearly documented third-party dependency latency.
- No known crash pattern exceeds 0.1% for the affected flow in test or staging evidence.
- Retry, timeout, and fallback behavior are defined for failure-prone actions where relevant.

### UX and accessibility
- Screens support dark mode.
- Loading, empty, error, success, and offline states are present where applicable.
- Copy is clear, action-oriented, and understandable to Vietnamese users.
- Touch targets, contrast, and form feedback meet a practical accessibility bar for MVP use.

### Language and content
- User-facing copy is 100% Vietnamese unless a third-party provider requires otherwise.
- Labels, validation messages, and error messages are consistent across the same flow.
- Placeholder or mock text is removed from production-ready screens.

### Data and security
- Sensitive user and auth data are handled securely.
- Validation exists at client and server boundary as appropriate.
- Users can access only their own protected data unless the feature explicitly requires public visibility.
- Audit-relevant actions and failure paths are traceable enough for QA and debugging.

### Release readiness
- Acceptance criteria are reviewed and signed off by product.
- QA evidence is available for the targeted stories.
- Technical contract changes are reflected in documentation.
- The feature is deployable without hidden manual steps.

---

## 6) Assumptions and notes

- Vet Finder review functionality may surface in Phase 1 detail pages, but the primary user value of MVP remains quick clinic discovery and actionability.
- Health reminders depend on notification capability; if push delivery is unavailable on Day 1, reminder creation and in-app visibility still define the base behavior.
- Social, rescue, adoption, marketplace, payment, and AI features are outside this Day 1 document.

---

## 7) Acceptance checkpoints by module

These checkpoints are the minimum Day 1 product handoff that Cypher and Neo can rely on before Day 2 expands.

### Auth
- Register requires valid email, minimum password rule, and duplicate email handling.
- Login returns an authenticated session or a clear failure state.
- Social login is split conceptually into provider-specific handling even if UI groups Google and Apple together.
- Logout invalidates the active session and returns the user to an unauthenticated entry.

### Pet Profile
- Pet create must support a required identity core: name and species.
- Pet list must distinguish first-use empty state from real data state.
- Pet update must preserve ownership boundaries.
- Pet remove must use confirmation before destructive action.

### Vet Finder
- Nearby search must define a supported first-pass radius set before implementation.
- Map and list must both have safe fallback behavior when location permission is denied.
- Vet detail must still render safely when phone, hours, photo, or reviews are missing.
- External actions such as call and directions must surface a failure message instead of failing silently.

### Health Records
- Record creation must support a small MVP-safe set of record types first.
- Timeline order must be newest first.
- Record edit and delete behavior must be owner-scoped.
- Reminders may be created even if push delivery is not ready yet, as long as in-app visibility is defined.

---

## 8) Operational Definition of Done

Use these two layers together so the team does not apply release-only rules to documentation work.

### Artifact DoD
- The artifact maps to an approved Day 1 task.
- Scope boundaries and deferrals are explicit.
- The artifact is specific enough for the next owner to act without guessing core behavior.
- Related files point to the latest source of truth.

### Feature DoD
- Happy path works end-to-end for the implemented slice.
- Core validation and negative-path behavior are visible to QA.
- Required states are present for the target screen or endpoint.
- Proof exists as a command result, test, screenshot, or linked artifact.

### Day 1 proof policy
- `Scaffolded` means the file or structure exists.
- `Verified` means a command, runtime, or test proved it works.
- `Blocked` means a runtime, credential, or remote dependency still prevents proof.

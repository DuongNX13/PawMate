# PawMate Phase 1 - Day 2 Acceptance Criteria

## Scope

This handoff covers Morpheus-owned Day 2 product acceptance for:
- `D2-01` Auth happy path
- `D2-02` Auth edge cases and errors
- `D2-03` Vet Finder search and filter

## Dependencies

Use these Day 1 artifacts as the source of truth when implementing or testing:
- [`docs/product/day1_user_stories_and_dod.md`](./day1_user_stories_and_dod.md) for the baseline product intent and module scope
- `D1-03` Auth OpenAPI contract for endpoint shapes and response expectations
- `D1-04` Vet Finder OpenAPI contract for search/filter endpoint scope
- `D2-06` Error response schema standard, if the team has already adopted it, for consistent auth and vet error payloads

If the Day 1 contract changes, update this file before QA starts.

---

## 1) D2-01 Auth Happy Path

### Register
- User can register with a valid email address and a password that meets the agreed strength rule from the auth contract.
- Registration rejects malformed email input before submission completes.
- Registration rejects duplicate email addresses with a clear conflict response.
- On success, the user receives a confirmation response that tells them to check their email.

### Login
- User can log in with valid email and password.
- Successful login returns an authenticated session with access token plus refresh token behavior matching the auth contract.
- Login response includes a predictable JWT payload shape that QA can verify consistently.
- `Remember me` keeps the user signed in longer only through the documented refresh/session policy, not by bypassing expiry rules.

### Token refresh
- Expired access tokens can be renewed through the refresh flow when the refresh token is still valid.
- Refresh returns a new token pair according to the rotation policy.
- Old refresh tokens are invalidated after rotation.

### Logout
- Logged-in user can log out successfully.
- Logout invalidates the active session and prevents the same refresh token from being reused.
- After logout, the user is treated as signed out on the next protected request.

---

## 2) D2-02 Auth Edge Cases and Errors

### Wrong password and lockout
- Invalid password attempts return a clear auth failure message without exposing whether the email exists.
- After 5 failed login attempts, the account enters a 15-minute lockout.
- During lockout, login is rejected even if the correct password is entered.
- After the lockout window ends, login is allowed again.

### Unverified email
- If email verification is required for the flow, unverified users cannot complete login until verification is finished.
- The response or UI message must clearly tell the user what to do next.

### OAuth account conflict
- If the same email already exists under a different OAuth provider, the system does not silently create a duplicate account.
- The conflict is surfaced as a clear account-linking or sign-in error.
- QA should be able to reproduce the conflict with the same email on two providers.

### Expired OTP
- OTP older than 5 minutes is rejected.
- The user sees a clear expiration message and a path to request a new OTP.
- Resending OTP does not reactivate the old code.

### Concurrent login limit
- The system allows at most 3 active devices or sessions for the same user, per the auth policy.
- When the limit is exceeded, the oldest session is revoked or the new login is rejected, according to the selected policy.
- The chosen behavior must be consistent across API and UI so QA can verify it deterministically.

---

## 3) D2-03 Vet Finder Search and Filter

### Search radius
- Nearby search supports the documented radius set: 1 km, 3 km, 5 km, and 10 km.
- Results are limited to the selected radius.
- Smaller radius should never return a clinic farther away than the radius allows.

### Open now
- When `open now` is enabled, only currently open clinics are shown.
- Clinics with missing or invalid hours data are excluded from the `open now` result set unless the contract says otherwise.

### 24h emergency
- When `24h emergency` is enabled, only clinics marked as 24-hour emergency service are shown.
- Clinics that are not explicitly tagged as emergency-ready are excluded.

### Rating filters
- Rating filter options work as:
  - `>= 3.0`
  - `>= 4.0`
  - `>= 4.5`
- Results must meet or exceed the chosen threshold.
- Clinics with no rating should not pass a rating filter.

### Sort order
- Sort by distance orders nearest first.
- Sort by rating orders highest rated first.
- Sort by review count orders highest review count first.
- The selected sort rule must remain stable after filters are applied.

### Filter combinations
- Filters can be combined in one search.
- Combined filters use AND logic, not OR logic.
- Example: `3 km + open now + rating >= 4` returns only clinics satisfying all three conditions.

### Empty and fallback states
- If no clinics match the current search, the user sees a clear no-results state.
- If location is unavailable, the product still shows a safe fallback path instead of failing silently.
- Search/filter behavior should remain understandable even when some clinic fields are missing.

---

## QA Ready Checks

- Auth happy path is testable end to end for register, login, refresh, and logout.
- Auth negative cases are testable for password failures, lockout, unverified email, OAuth conflict, OTP expiry, and session limits.
- Vet Finder search is testable for each radius, each filter, and each sort mode.
- Combined filter behavior is explicitly defined so QA does not infer rule order.
- Any implementation choice that changes the conflict, lockout, or concurrent-session policy must update this doc first.

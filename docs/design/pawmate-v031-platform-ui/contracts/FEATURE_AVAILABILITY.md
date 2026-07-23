# Feature availability contract — UI v0.31

- Status: `FROZEN_FOR_W5`
- Runtime owner: mobile release owner
- Approval owner: Product Owner

## Source and scope

Rescue availability is compile-time, build-global configuration supplied with
Flutter `--dart-define`. It is not remote config, is not account-specific, has
no cache, and therefore has no TTL.

| Capability | Dart define | Missing/invalid value | Dependency |
|---|---|---|---|
| Browse Rescue | `PAWMATE_RESCUE_BROWSE_ENABLED` | `false` | none |
| Create/update Rescue | `PAWMATE_RESCUE_CREATE_ENABLED` | `false` | Browse must also be `true` |

`AppFeatureAvailability` is the single runtime source. Tests may override its
Riverpod provider; production feature code must not read environment variables
directly.

## Fail-closed behavior

- A disabled Rescue root or deep link resolves to an honest in-app unavailable
  screen; it never calls Rescue API, location, map, upload, or persistence code.
- An enabled flag with a missing Day 39/40 handler still resolves to the honest
  unavailable screen. A flag alone cannot expose fabricated or partial data.
- `rescueCreate` is forced to `false` when `rescueBrowse` is `false`, even if its
  own define is `true`.
- Unknown and historical aliases are rejected by `AppRouteRegistry` and resolve
  through the safe unknown-route screen.

## Activation and rollback

- Only the mobile release owner may set flags in a staging or production build,
  after Product Owner approval and the Rescue final-contract gate.
- Staging and production values are set per build pipeline; values do not vary
  by user account.
- The current kill switch is a rebuild/redeploy with both flags set to `false`.
  There is no instant remote kill switch in v0.31; that limitation must be
  included in release risk review before Rescue is enabled.
- If config cannot be proven, the release must use the default-off build.

Remote config, cached rollout percentages, per-account targeting, and TTL are
outside the v0.31 UI lane. Introducing them requires a new security, privacy,
offline, and rollback contract rather than silently changing this one.

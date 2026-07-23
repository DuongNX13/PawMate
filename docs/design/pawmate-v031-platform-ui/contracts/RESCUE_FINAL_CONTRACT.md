# Rescue Final Contract for PawMate v0.31 UI

- Status: **W0/W1 contract lock — UI may design against it; runtime wiring is gated by G5A**
- Contract owners: Day 37/38 backend lane + PawMate v0.31 UI lane
- Approver: Product/engineering owner who signs G5A
- Last verified against repository: 2026-07-21

## 1. Purpose and authority

This document freezes the Rescue interface that Day 39 and Day 40 mobile work may consume. It is derived from the Day 35 read API and Day 36 write API that exist in the repository, not from historical mockups.

Authority order for an implementation dispute:

1. The live Day 35/36 route, service, mapper, repository, and tests.
2. `docs/architecture/pawmate_api_contract_v1.json`.
3. `docs/engineering/phase2_route_data_contract.json`.
4. This UI-facing freeze.
5. Historical SRS, mockups, and design-only fixtures.

The UI lane must not change backend code or silently widen this contract. A required backend change belongs to Day 37/38 and must be approved before G5A.

## 2. Entry and exit contract

### Definition of Ready

- Day 35 read API is PASS and its public response has been checked against the mapper.
- Day 36 write API is PASS and owner/version/idempotency behavior has been checked against the service and repository.
- The two G5A drift items in section 13 have a named owner.
- Protected-path baseline exists and is verified with `scripts/ci/ui-v031/protected/verify-protected-paths.ps1`.
- Day 39/40 implementation has no unapproved backend or historical-design delta.

### Definition of Done

- Day 38/G5A either resolves or explicitly accepts both drift items in section 13.
- Day 39 tests cover browse enabled, browse disabled, unavailable API, cursor reset, stale request, deleted case, privacy, and deep links.
- Day 40 tests cover create enabled/disabled, draft preservation, version conflict, owner-only status, idempotency, media limits, and publish validation.
- No public DTO, UI semantics, log, screenshot, or evidence leaks a forbidden private field.
- Protected paths match the approved baseline or an unexpired owner delta manifest exactly.
- G5A approver records PASS. Until then, runtime integration remains blocked even if design work is complete.

## 3. Feature flags and route behavior

There is no remote-config or operational kill-switch implementation in the current app. Day 39/40 therefore use compile-time release switches:

| Define | Default | Meaning |
|---|---:|---|
| `PAWMATE_RESCUE_BROWSE_ENABLED` | `false` | Enables live list, map, and case-detail reads. |
| `PAWMATE_RESCUE_CREATE_ENABLED` | `false` | Enables draft, media, publish, comment, discussion, and owner status writes. |

Rules:

- Implement with Flutter `--dart-define` or the repository's equivalent compile-time environment adapter.
- Missing, empty, or malformed values fail closed to `false`.
- `create == true` requires `browse == true`; an invalid combination fails closed for create and emits a non-sensitive diagnostic in debug/test only.
- A Riverpod/provider override is required for deterministic tests. Production code must not read test fixtures.
- The Rescue root tab and `/rescue` route remain present when browse is disabled. They render an honest staged/unavailable state and make **zero Rescue API calls**.
- A known disabled deep link is resolved only after the normal authentication guard, then lands on `FeatureUnavailableScreen`; it must not fall through to a generic 404.
- When a flag is true but the API is unavailable, show the real error/retry state. Never substitute fixture data.
- Release configuration plus the applicable Day owner controls staging/production activation. These flags are release switches, not a live kill switch.
- A remote operational kill switch, TTL, account rollout, and cache policy are outside W0/W1. If required for release, Day 38/platform work must define and implement them before activation.

Canonical routes:

| Route | Screen | Flag/permission |
|---|---|---|
| `/rescue` | Rescue Home | browse; staged state when off |
| `/rescue/create` | Create Lost Alert | authenticated + create |
| `/rescue/create/details` | Lost Info Form | authenticated + create |
| `/rescue/map` | Rescue Map | browse |
| `/rescue/:caseId` | Case Detail | browse |
| `/rescue/:caseId/comment` | Case Comment | authenticated + create |
| `/rescue/:caseId/status` | Case Status Update | owner + create |
| `/rescue/:caseId/discussion` | Case Discussion | authenticated + create |

## 4. Public read contract — Day 35

### Endpoints and authentication

| Method and path | Authentication | Response cache headers |
|---|---|---|
| `GET /rescue/cases` | Public; bearer token optional | `Cache-Control: no-store`, `Vary: Authorization` |
| `GET /rescue/cases/:caseId` | Public; bearer token optional | `Cache-Control: no-store`, `Vary: Authorization` |

An invalid optional bearer token is treated as anonymous by these backend read endpoints. The current mobile `/rescue` branch can still require authentication through its router; client routing policy must not be misrepresented as an API requirement.

### List query

| Field | Contract |
|---|---|
| `status` | Optional: `missing` or `found`. |
| `species` | Optional: `dog`, `cat`, or `other`. Persisted `bird` and `rabbit` project to public `other`. |
| `lostFrom`, `lostTo` | Optional ISO-8601 datetimes; when both exist, `lostFrom <= lostTo`. |
| `lat`, `lng` | Optional but must be supplied together. |
| `radiusMeters` | `100..20000`; legal only with coordinates; defaults to `1000` when coordinates exist. |
| `sort` | `recent` or `distance`; defaults to `recent`; `distance` requires coordinates. |
| `limit` | `1..50`; defaults to `20`. |
| `cursor` | Opaque server cursor bound to the exact filter fingerprint. |

The cursor fingerprint includes `status`, `species`, `lostFrom`, `lostTo`, `sort`, `lat`, `lng`, and `radiusMeters`. Clients must never decode, alter, or reuse it after any of those values changes.

Response envelope:

```json
{
  "data": [],
  "pageInfo": {
    "nextCursor": null,
    "hasMore": false,
    "limit": 20
  }
}
```

Day 39 list behavior:

- The “5 tin mới nhất” module explicitly calls `sort=recent&limit=5`; it does not assume the server default.
- Load more repeats the exact filter fingerprint and the returned opaque cursor.
- A filter or location change cancels/invalidates the old generation, clears items, and starts without a cursor.
- Deduplicate by `caseId`, retain server order, and ignore late responses from older request generations.
- Do not invent or display a total count; the API does not return one.

## 5. Public DTO and privacy allowlist

### Summary

Required fields:

`caseId`, `petName`, `species`, `status`, `lostAt`, `publicLocation`, `media`, `commentCount`, `createdAt`, `updatedAt`.

Optional fields:

`breedOrColor`, `ageLabel`, `distanceMeters`, `viewerPermissions`.

### Detail

Detail adds required `identifyingFeatures`, optional `behaviorHint`, and currently includes `viewerPermissions` from the live mapper.

`viewerPermissions` contains:

- `canComment`
- `canUpdateStatus`
- `canViewPrivateContact`

When permissions are absent, the client treats every permission as `false`. The live mapper currently always returns `canViewPrivateContact: false`.

### Forbidden everywhere in a public response or evidence artifact

`ownerUserId`, `sourceDraftId`, `exactLocation`, `privateLocation`, house number, phone, `contactPreference`, storage key, SHA-256 media internals, `deletedAt`, or any raw upload metadata.

The client must use an explicit DTO allowlist. Unknown fields are ignored and are never logged, persisted, added to accessibility semantics, or copied into analytics/evidence.

## 6. Location privacy contract

- Exact location remains private in persistence and write payloads.
- Public UI receives only `areaLabel`, `approximateLatitude`, `approximateLongitude`, and `privacyRadiusMeters`, plus optional `distanceMeters`.
- Map UI renders an uncertainty area/circle. It must not imply an exact pin.
- Do not expose coordinates, exact address, house number, directions, or copy/share actions for the private origin.
- Accessibility labels say “khu vực ước tính” and the area label; they do not announce coordinates.
- Logs, screenshots, videos, and CI artifacts use generated test locations only.

The backend precision/radius mismatch is not waived by the UI; see G5A-DRIFT-01.

## 7. Cache, offline, and stale-data contract

Because public reads send `Cache-Control: no-store`:

- Do not persist Rescue API responses to disk, shared preferences, SQLite, secure storage, or an HTTP cache.
- The client may retain only the currently rendered, sanitized page in process memory when a refresh fails.
- Retained content becomes visibly stale immediately and shows the last successful refresh time.
- Purge it on route/session/process end; it has no offline TTL and must not survive restart.
- Cold-start offline state is an honest error/retry state.
- A durable across-restart offline cache requires a separate Day 38 security/privacy contract and is not authorized here.

If a case is deleted while open, evict it from the current in-memory list, show “Tin này không còn khả dụng”, and offer Back/Refresh. Never continue presenting the stale detail as current.

## 8. Status lifecycle and ownership

The only live lifecycle is:

```text
missing (Chưa thấy) -> found (Đã thấy)
```

Rules:

- Status change is owner-only and is enforced by the backend repository, not merely hidden in the UI.
- `PATCH /rescue/cases/:caseId/status` requires:

```json
{
  "newStatus": "found",
  "expectedStatus": "missing",
  "expectedVersion": 1,
  "confirmedSafe": true
}
```

- There is no reverse transition or reopen flow.
- Older multi-state SRS language is superseded for Day 39/40.
- Non-owner or absent permission means the status CTA is not enabled; a crafted request still relies on backend `403` enforcement.

## 9. Day 40 draft and publish contract

### Create and update

- `POST /rescue/case-drafts` is authenticated, requires an idempotency key, and accepts optional `source: rescue_home|deep_link`.
- `PATCH /rescue/case-drafts/:draftId` is owner-only and requires `expectedVersion` plus at least one mutable field.
- Mutable fields:
  - `petName`: 1–50 characters.
  - `species`: `dog|cat|other`.
  - `breedOrColor`: 1–100 characters.
  - `lostAt`: ISO-8601 on the wire.
  - `exactLocation`: latitude, longitude, and optional address.
  - `mediaIds`: at most 5 verified attached items.
  - `identifyingFeatures`: 1–500 characters.
  - `behaviorHint`: 0–500 characters.
  - `contactPreference`: `in_app|phone_with_consent`.

### Publish

- `POST /rescue/case-drafts/:draftId/publish` is owner-only, requires `expectedVersion`, and requires an idempotency key.
- Required before publish: `petName`, `species`, `breedOrColor`, `lostAt`, exact private location, derived `areaLabel`, `identifyingFeatures`, and 1–5 verified attached media items.
- Publish creates the public case in `missing` state.
- A failed request preserves the draft and its last confirmed version.
- `RESCUE_011` triggers refetch/reconciliation; the client must not overwrite the newer server version.

## 10. Media contract

- Request upload through `POST /media/uploads`; complete it through `POST /media/uploads/:mediaId/complete`.
- Supported images: JPEG, PNG, WebP up to 10 MiB.
- Supported video: MP4 up to 50 MiB.
- Upload integrity uses SHA-256, but the hash and storage details remain private.
- Only verified, attached, sanitized derivatives may be published.
- Completion removes location metadata before a public URL is exposed.
- Fixtures and golden-test media must not be bundled into production by accident.

## 11. Error-to-UI contract

| Code | HTTP | Required client behavior |
|---|---:|---|
| `AUTH_013` | 401 | Re-authenticate; preserve a private draft only in authorized in-memory form. |
| `RESCUE_002` | 403 | Explain insufficient ownership/permission; do not retry as owner. |
| `RESCUE_003` | 404 | Show unavailable/deleted state; evict stale list/detail content. |
| `RESCUE_004` | 400 | Bind safe field/filter validation messages; do not expose raw internals. |
| `RESCUE_005` | 409 | Refresh status and explain that the transition is no longer valid. |
| `RESCUE_010` | 409 | Mark discussion closed; preserve unsent text locally in memory. |
| `RESCUE_011` | 409 | Refetch and reconcile optimistic version; never blind-overwrite. |
| `IDEMPOTENCY_001` | 409 | Stop automatic retry with that key; surface a safe conflict state. |
| `MEDIA_001..005` | endpoint-specific | Show upload/verify error, retain draft, and require a safe retry/reselect action. |
| `SYS_001`/network | 5xx/offline | Error + retry; never replace live data with fixtures. |

Automatic retries must reuse an idempotency key only for the same payload. A changed payload requires a new key.

## 12. Day 39/40 activation gates

| Gate | PASS condition | Blocking effect |
|---|---|---|
| G5A backend freeze | Day 38 passes; both drift items resolved/accepted; protected-path verification passes. | Blocks live Day 39 wiring. |
| Day 39 browse | Read states, cursor behavior, disabled flags, deep links, privacy, accessibility, and error handling pass. | Blocks Day 40 activation. |
| Day 40 write | Draft/publish/media/idempotency/version/owner tests pass. | Blocks create flag activation. |

Design-system and platform-neutral widget work may proceed before G5A. No pre-G5A work may claim that live Rescue integration is complete.

## 13. G5A drift register — must not be hidden

### G5A-DRIFT-01 — approximate coordinate precision does not prove a 500 m guarantee

Current implementation rounds latitude and longitude to three decimals while emitting `privacyRadiusMeters = 500`. Rounding alone does not prove that the public point is displaced or anonymized by 500 m.

Required resolution before G5A:

- Day 37/38 backend owner either implements a privacy transformation that satisfies a documented threat model, or explicitly accepts and documents what the 500 m value means.
- Privacy tests prove the chosen meaning.
- UI continues to render an uncertainty area and never labels the approximate point as exact.

The UI lane is not authorized to patch this in backend code.

### G5A-DRIFT-02 — `contactChannel` exists in contract JSON but not in the live mapper

The architecture JSON lists optional owner-only `contactChannel`, while the live Day 35 mapper does not emit it and always sets `canViewPrivateContact` to false.

Required resolution before G5A:

- Day 38 reconciles the canonical API contract and implementation.
- Until then, Day 39/40 assumes **no private-contact read channel** and renders no phone/contact disclosure CTA.
- The UI must not infer a contact channel from draft `contactPreference`.

## 14. Evidence and data handling

- Use test accounts, generated pet data, and generated locations only.
- Evidence paths are repo/build relative, for example `output-evidence/ui-v031/<wave>/<platform>/<artifact>`; CI publishes them to the approved artifact store.
- Each manifest records wave, baseline ID, commit SHA, platform/device/runtime, command, start/end time, exit code, artifact path, SHA-256, executor/reviewer, test-data-only status, and redaction status.
- Secret-scan logs before upload. Do not publish tokens, real emails, real phone numbers, exact addresses, or sensitive Rescue locations.
- Production rollout, crash/ANR monitoring, remote feature activation, and post-release observation are outside W0/W1. They must be covered by the later release gates; their absence must not be reported as complete monitoring.

## 15. Source anchors

- `backend/src/routes/rescue.ts`
- `backend/src/services/rescue/rescue-read-service.ts`
- `backend/src/services/rescue/rescue-read-mapper.ts`
- `backend/src/services/rescue/rescue-write-service.ts`
- `backend/src/services/rescue/rescue-location-privacy.ts`
- `backend/src/features/rescue/persistence/prisma-rescue-repository.ts`
- `backend/src/errors/error-codes.ts`
- `backend/prisma/schema.prisma`
- `docs/architecture/pawmate_api_contract_v1.json`
- `docs/engineering/phase2_route_data_contract.json`
- `docs/engineering/day35_rescue_read_api_status.md`
- `docs/engineering/day36_rescue_write_api_status.md`
- `docs/qa/phase2/day35_rescue_read_api_test_matrix.md`
- `docs/qa/phase2/day36_rescue_write_api_test_matrix.md`

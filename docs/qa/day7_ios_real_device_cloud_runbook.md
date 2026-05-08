# PawMate Day 7 iOS Real Device Cloud Runbook

Date: 2026-05-05

## Goal

Close `D7-04 iOS cloud smoke` without installing Xcode/Swift locally by using:

- Codemagic cloud macOS builder for a signed `.ipa`.
- Appetize iOS simulator for the active browser-based demo, exploration, and Network Logs path.
- TestFlight or a physical iPhone later for release-signing parity after Apple Developer signing is connected.

Appetize is the default Day 7 QA surface now. It is a simulator path and must not be used as release-signing proof.

## Required Accounts And Secrets

Codemagic app:

- Connect GitHub repo `DuongNX13/PawMate`.
- Use root-level `codemagic.yaml`.

Codemagic variable group `pawmate_ios_signing`:

- Apple Developer Program membership is required for installable iOS signing.
- Configure Codemagic iOS signing for bundle id `com.pawmate.pawmateMobile`.
- Recommended signing type for internal device testing after Apple setup: `ad_hoc` or App Store/TestFlight depending on the release lane.

Required for backend-backed register/login smoke:

- `PAWMATE_API_BASE_URL`: public HTTPS backend URL. It must not be `localhost`, `127.0.0.1`, `10.0.2.2`, a private IP, or any placeholder domain.
- The URL must pass `GET /health` before Codemagic builds the mobile artifact.
- The Codemagic workflows now run `scripts/ci/validate-mobile-backend-url.mjs` to fail fast if the mobile build would point to an unusable backend.

If the team intentionally wants visual-only simulator smoke, do not claim register/login E2E sign-off from that build.

## Workflow To Run

Primary Codemagic workflow:

```text
ios-appetize-simulator-smoke
```

Expected artifacts:

- `mobile/build/ios/appetize/PawMate-appetize-simulator.zip`

After Apple Developer signing is connected, run the signed IPA workflow separately:

```text
ios-real-device-smoke
```

Expected signed artifacts:

- `mobile/build/ios/ipa/*.ipa`
- `mobile/build/ios/archive/*.xcarchive`

## Manual Appetize Smoke Checklist

Run on Appetize iOS Simulator. Keep the simulator session short and close the browser tab when evidence capture is done.

Minimum Day 7 sign-off smoke:

1. Upload `PawMate-appetize-simulator.zip` to Appetize.
2. Launch app successfully, no crash within 30 seconds.
3. Onboarding shell renders PawMate branding and primary CTA.
4. Navigate through auth/register/login screens without layout overflow.
5. Open Pets, Vet, Health, and Profile tabs; bottom navigation remains stable.
6. Open Health timeline and Reminder Calendar.
7. Open Notification Center.
8. Capture screenshots plus Appetize Network Logs and Debug Logs.

Backend-backed smoke, only after `PAWMATE_API_BASE_URL` points to a public backend and Codemagic preflight passes:

1. Login with seeded E2E user.
2. Create or view a pet profile.
3. Create a reminder.
4. Process due reminders through backend worker/API path.
5. Confirm the notification appears in Notification Center.
6. Mark notifications read.
7. Confirm no regression in Health timeline.

Backend-backed register/login recovery steps:

1. Provision a public HTTPS backend URL. Preferred no-credit path is Render Free Web Service from root `render.yaml`; temporary HTTPS tunnel is acceptable only for short-lived QA evidence.
2. Verify locally: `GET <PAWMATE_API_BASE_URL>/health` returns `{"status":"ok"}`.
3. Add/update `PAWMATE_API_BASE_URL` in Codemagic environment variables for `DuongNX13/PawMate`.
4. Rerun `ios-appetize-simulator-smoke`, then upload the new artifact to Appetize.
5. On Appetize, enable `Network Logs` and `Debug Logs` before submitting Register.
6. Use a unique email for each run, capture the `/auth/register` request/response, and only sign off if the app reaches OTP/login-ready state with backend evidence.

## Evidence Required

Save these into `temp/qa/day7-ios-cloud/` after a run:

- Appetize app/build ID and simulator device/iOS version.
- Codemagic artifact name/build number.
- Screenshots for launch, navigation, reminders, notifications.
- Redacted HAR or Network Logs for `/auth/register` and `/auth/login` when doing backend proof.
- Result summary: `PASS`, `FAIL`, or `BLOCKED`, with exact blocker.

## Sign-Off Rule

`D7-04` simulator/network-log proof can be marked done after Appetize captures backend-backed Register/Login traffic against a public HTTPS backend.

Release/TestFlight parity remains blocked until Apple Developer signing is connected and a signed IPA/TestFlight or physical-device run is captured.

Historical BrowserStack evidence remains useful, but BrowserStack credentials/session time are no longer a required Day 7 blocker.

If Apple signing is missing, keep it blocked on Apple signing, not simulator availability.

## Latest Codemagic Attempt

Date: 2026-05-06

- Branch: `develop`
- Workflow: `Day 7 iOS Real Device Smoke`
- Build URL: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/69fb05ba75be451056919575`
- Result: `BLOCKED_APPLE_SIGNING`
- Error: `No matching profiles found for bundle identifier "com.pawmate.pawmateMobile" and distribution type "ad_hoc"`
- Evidence: `temp/qa/day7-ios-cloud-proof/16-codemagic-build-started.txt`

Next required action: add or fetch an Apple Ad Hoc provisioning profile and matching certificate in Codemagic for bundle id `com.pawmate.pawmateMobile`, then rerun the same workflow.

## BrowserStack Re-Sign Smoke Result

Date: 2026-05-06

- Branch: `develop`
- Commit: `8aabc63`
- Workflow: `Day 7 iOS BrowserStack Re-sign Smoke`
- Build URL: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/69fb0916be8a3ba0bd3513b0`
- Artifact: `PawMate-browserstack-unsigned.ipa` `[8.22 MB]`
- Local artifact copy: `temp/qa/day7-ios-cloud-proof/PawMate-browserstack-unsigned.ipa`
- BrowserStack upload: accepted as `PawMate-browserstack-unsigned.ipa v1.0.0`
- Real device: `iPhone 15 Pro Max v17.3`
- Bundle id observed in BrowserStack console: `com.pawmate.pawmateMobile`
- Smoke evidence:
  - App launch / Login screen: `temp/qa/day7-ios-cloud-proof/39-browserstack-ios-session-after-install.png`
  - Login -> Register navigation: `temp/qa/day7-ios-cloud-proof/41-browserstack-ios-register-smoke-retry.png`

Result: `DONE_CORE_SMOKE` for Day 7 iOS real-device install/launch/navigation. Keep `RELEASE_SIGNING_GAP` open for TestFlight/App Store/Ad Hoc release parity until Apple Developer signing is configured.

Limitation: BrowserStack free-trial device time was short, so this pass did not complete the full tab-by-tab exploratory checklist.

## Appetize Simulator Smoke Result

Date: 2026-05-06

- Branch: `develop`
- Commit: `5c3639a`
- Workflow: `Day 7 iOS Appetize Simulator Smoke`
- Build URL: `https://codemagic.io/app/69fb006fcb6fc5b8a49301e3/build/69fb188bbe4ca8fb32575ccc`
- Artifact: `PawMate-appetize-simulator.zip` `[55.70 MB]`
- Local artifact copy: `temp/qa/day7-ios-cloud-proof/PawMate-appetize-simulator.zip`
- Artifact SHA256: `937E065182CC8A02A1205EF876A8C2AD0EF081799BB3F28319CBC199766E1A60`
- Appetize app: `Pawmate Mobile`
- Appetize app id: `com.pawmate.pawmateMobile`
- Simulator: `iPhone 14 Pro iOS 16.2`
- Smoke evidence:
  - Codemagic build passed: `temp/qa/day7-ios-cloud-proof/48-codemagic-appetize-build-result.png`
  - Appetize player opened: `temp/qa/day7-ios-cloud-proof/50-appetize-pawmate-player-open.png`
  - App launched/onboarding rendered: `temp/qa/day7-ios-cloud-proof/52-appetize-pawmate-started-30s.png`
  - Register screen rendered: `temp/qa/day7-ios-cloud-proof/53-appetize-after-onboarding-start.png`

Result: `APPETIZE_SIM_DEMO_TEXT_ENTRY_DONE` for simulator build/upload/launch/onboarding/register-screen smoke and Register form text-entry.

Register text-entry evidence:

- Record-enabled player URL: `https://appetize.io/app/ios/com.pawmate.pawmateMobile?device=iphone14pro&osVersion=16.2&toolbar=true&record=true`
- Working automation path: direct Appetize `playAction` sent through the live session socket, with focus delays before each `typeText`.
- Filled Register form with email, password, confirm password, and terms switch: `temp/qa/day7-ios-cloud-proof/97-appetize-after-text-entry-keyboard-hidden.png`
- Submit tap result captured: `temp/qa/day7-ios-cloud-proof/99-appetize-register-submit-coord-result.png`

Backend-backed Register/Login follow-up:

- Rebuilt Codemagic Appetize artifact with `PAWMATE_API_BASE_URL=https://fed-spears-genetics-reviewing.trycloudflare.com` and health timeout `PAWMATE_BACKEND_HEALTH_TIMEOUT_MS=30000`.
- Uploaded the rebuilt simulator ZIP to Appetize; latest Appetize build id observed as `b_eft7tfzxzyksnqat43ekmaouue`.
- Filled and submitted Register in Appetize with email `qa07121901@pawmate.local`, password `PawMate123!`, confirm password, and terms switch value `1`.
- Public backend follow-up proof: `POST /auth/login` for that exact Appetize-only email returned status `200` with token and user id present.
- Evidence: `temp/qa/day7-ios-cloud-proof/163-fast-poll2.png`, `temp/qa/day7-ios-cloud-proof/164-submit-poll1.png`, `temp/qa/day7-ios-cloud-proof/165-submit-poll2.png`.

Network Logs closure on 2026-05-07:

- Rebuilt and uploaded a proxy-aware Appetize artifact from Codemagic build `69fc2cbd2f5a4736dae72725` with `PAWMATE_ENABLE_SYSTEM_PROXY=true`.
- Appetize build id: `b_ckyj2jwaqmbjjf63ovx4xjfpny`.
- Register UI submitted `q132006@p.io`; Appetize HAR captured `POST /auth/register` status `201 Created`.
- The app then moved to email verification and the verification probe returned `POST /auth/verify-email` status `400 Bad Request` for an invalid/expired token; this is not the login proof path.
- Login UI submitted verified Appetize-created account `qa07121901@pawmate.local`; Appetize HAR captured `POST /auth/login` status `200 OK`.
- Redacted HAR evidence: `temp/qa/day7-ios-cloud-proof/appetize-network-captures-run6_register-4b411586.redacted.har.json`, `temp/qa/day7-ios-cloud-proof/appetize-network-captures-run11_login200-3346819a.redacted.har.json`.
- Combined auth summary: `temp/qa/day7-ios-cloud-proof/appetize-auth-network-summary-run6-run11-69fc2cbd.json`.
- Result: `APPETIZE_BACKEND_AUTH_NETWORK_PROOF_DONE` for simulator Register/Login backend traffic. Remaining iOS release gap is Apple Developer signing for TestFlight/App Store/Ad Hoc parity.

## References

- Codemagic iOS signing: https://docs.codemagic.io/yaml-code-signing/signing-ios/
- Codemagic YAML configuration: https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/
- Render Free backend replacement status: ../management/day7_free_backend_replacement_status_2026-05-08.md
- Appetize iOS upload requirements: https://docs.appetize.io/platform/app-management/uploading-apps/ios
- Appetize JavaScript SDK session API: https://docs.appetize.io/javascript-sdk/api-reference/session

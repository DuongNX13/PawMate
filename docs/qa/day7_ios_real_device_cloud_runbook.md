# PawMate Day 7 iOS Real Device Cloud Runbook

Date: 2026-05-05

## Goal

Close `D7-04 iOS real-device smoke` without installing Xcode/Swift locally by using:

- Codemagic cloud macOS builder for a signed `.ipa`.
- BrowserStack real iPhone device for manual or automated smoke evidence.
- Appetize iOS simulator as a supplemental demo/QA path when BrowserStack session time is too short.

The BrowserStack path is the real-device path. The Appetize path is a simulator path and must not be used as release-signing proof.

## Required Accounts And Secrets

Codemagic app:

- Connect GitHub repo `DuongNX13/PawMate`.
- Use root-level `codemagic.yaml`.

Codemagic variable group `pawmate_ios_signing`:

- Apple Developer Program membership is required for installable iOS signing.
- Configure Codemagic iOS signing for bundle id `com.pawmate.pawmateMobile`.
- Recommended signing type for BrowserStack/internal device testing: `ad_hoc`.

Codemagic variable group `pawmate_browserstack`:

- `BROWSERSTACK_USERNAME`
- `BROWSERSTACK_ACCESS_KEY`

Required for backend-backed register/login smoke:

- `PAWMATE_API_BASE_URL`: public HTTPS backend URL. It must not be `localhost`, `127.0.0.1`, `10.0.2.2`, a private IP, or any placeholder domain.
- The URL must pass `GET /health` before Codemagic builds the mobile artifact.
- The Codemagic workflows now run `scripts/ci/validate-mobile-backend-url.mjs` to fail fast if the mobile build would point to an unusable backend.

If the team intentionally wants visual-only simulator smoke, do not claim register/login E2E sign-off from that build.

## Workflow To Run

Codemagic workflow:

```text
ios-real-device-smoke
```

Expected artifacts:

- `mobile/build/ios/ipa/*.ipa`
- `browserstack-ios-upload.json`, if BrowserStack credentials were configured

The upload response must include an `app_url` like:

```text
bs://...
```

## Manual BrowserStack Smoke Checklist

Run on a real iPhone, preferably one recent and one older supported iOS device when capacity allows.

Minimum Day 7 sign-off smoke:

1. Install the uploaded PawMate `.ipa` on BrowserStack real iPhone.
2. Launch app successfully, no crash within 30 seconds.
3. Onboarding shell renders PawMate branding and primary CTA.
4. Navigate through auth/register/login screens without layout overflow.
5. Open Pets, Vet, Health, and Profile tabs; bottom navigation remains stable.
6. Open Health timeline and Reminder Calendar.
7. Open Notification Center.
8. Rotate or background/resume once if BrowserStack device/session supports it.
9. Capture video, device logs, and screenshots for evidence.

Backend-backed smoke, only after `PAWMATE_API_BASE_URL` points to a public backend and Codemagic preflight passes:

1. Login with seeded E2E user.
2. Create or view a pet profile.
3. Create a reminder.
4. Process due reminders through backend worker/API path.
5. Confirm the notification appears in Notification Center.
6. Mark notifications read.
7. Confirm no regression in Health timeline.

Backend-backed register/login recovery steps:

1. Provision a public HTTPS backend URL. Preferred path is Fly staging after billing/app creation is unblocked; temporary HTTPS tunnel is acceptable only for short-lived QA evidence.
2. Verify locally: `GET <PAWMATE_API_BASE_URL>/health` returns `{"status":"ok"}`.
3. Add/update `PAWMATE_API_BASE_URL` in Codemagic environment variables for `DuongNX13/PawMate`.
4. Rerun the relevant iOS workflow, then upload the new artifact to BrowserStack or Appetize.
5. On Appetize, enable `Network Logs` and `Debug Logs` before submitting Register.
6. Use a unique email for each run, capture the `/auth/register` request/response, and only sign off if the app reaches OTP/login-ready state with backend evidence.

## Evidence Required

Save these into `temp/qa/day7-ios-real-device/` after a real run:

- BrowserStack session URL.
- Device model and iOS version.
- IPA artifact name/build number.
- `browserstack-ios-upload.json` with secret-free values only.
- Screenshots for launch, navigation, reminders, notifications.
- Video link or exported recording.
- Result summary: `PASS`, `FAIL`, or `BLOCKED`, with exact blocker.

## Sign-Off Rule

`D7-04` can be marked `DONE` only after the app is installed and smoke-tested on a real iPhone device, local or cloud.

If Codemagic builds the IPA but no BrowserStack/iPhone session runs, keep `D7-04` as `READY_TO_RUN`, not `DONE`.

If BrowserStack credentials are missing, keep it blocked on credentials, not code.

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

Limitation: Appetize backend-backed register/login E2E is still not claimed. Submit was tapped, but this pass did not capture clear API, OTP, or account-creation proof.

## References

- Codemagic iOS signing: https://docs.codemagic.io/yaml-code-signing/signing-ios/
- Codemagic YAML configuration: https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/
- BrowserStack Flutter real-device testing: https://www.browserstack.com/docs/app-automate/flutter
- BrowserStack app upload API: https://www.browserstack.com/docs/app-automate/appium/getting-started/java/testng/manage-apps/upload-app/from-local-machine
- Appetize iOS upload requirements: https://docs.appetize.io/platform/app-management/uploading-apps/ios
- Appetize JavaScript SDK session API: https://docs.appetize.io/javascript-sdk/api-reference/session

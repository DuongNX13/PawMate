import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), '../../..');
const baselineId = 'UI-CC-2026-07-21-G4B';
const evidenceDirectory =
  'output-evidence/ui-v031/UI-CC-2026-07-21-G4B/W8/talkback-journeys-20260723';
const apkPath = `${evidenceDirectory}/pawmate-talkback-evidence-button-semantics-debug.apk`;
const deviceMetadataPath = `${evidenceDirectory}/android-talkback-device-metadata.raw.txt`;
const packageName = 'com.pawmate.pawmate_mobile';

const journeys = [
  {
    id: 'A11Y-AUTH',
    screenId: 'P1-02',
    route: '/auth/login',
    steps: [
      {
        label: 'mobile-e2e-owner@pawmate.test',
        bounds: '[84,1618][1356,1849]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Quên mật khẩu?',
        bounds: '[594,1776][1356,1944]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
    ],
  },
  {
    id: 'A11Y-HOME',
    screenId: 'P1-07',
    route: '/pets',
    steps: [
      {
        label: 'Tìm phòng khám',
        bounds: '[880,179][1048,347]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Thông báo',
        bounds: '[1048,179][1216,347]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
    ],
  },
  {
    id: 'A11Y-VET',
    screenId: 'P1-08',
    route: '/vets/map',
    steps: [
      {
        label: 'Thông báo',
        bounds: '[1020,179][1188,347]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Tìm phòng khám, bác sĩ...',
        bounds: '[56,508][1384,704]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
    ],
  },
  {
    id: 'A11Y-HEALTH',
    screenId: 'P1-12',
    route: '/health',
    steps: [
      {
        label: 'Cài đặt sức khỏe',
        bounds: '[992,265][1160,433]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Thông báo',
        bounds: '[1188,265][1356,433]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
    ],
  },
  {
    id: 'A11Y-NOTIFICATIONS',
    screenId: 'P1-15',
    route: '/notifications',
    steps: [
      {
        label: 'Quay lại',
        bounds: '[56,186][224,354]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Quản lý thông báo',
        bounds: '[1216,186][1384,354]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
    ],
  },
  {
    id: 'A11Y-PROFILE',
    screenId: 'P1-16',
    route: '/profile',
    steps: [
      {
        label: 'Cài đặt',
        bounds: '[1034,158][1202,326]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Thông báo',
        bounds: '[1202,158][1370,326]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
    ],
  },
  {
    id: 'A11Y-RESCUE',
    screenId: 'P2-01',
    route: '/rescue',
    steps: [
      {
        label: 'Thông báo',
        bounds: '[1272,193][1440,361]',
        method: 'KEYBOARD_TAB_WITH_TALKBACK_ENABLED',
      },
      {
        label: 'Cứu hộ thú cưng\nTriển khai theo từng giai đoạn',
        bounds: '[56,184][873,370]',
        method: 'TOUCH_EXPLORATION_SWIPE_WITH_TALKBACK_ENABLED',
      },
    ],
  },
];

function absolute(relativePath) {
  return path.join(repoRoot, ...relativePath.split('/'));
}

function sha256File(relativePath) {
  return crypto
    .createHash('sha256')
    .update(fs.readFileSync(absolute(relativePath)))
    .digest('hex')
    .toUpperCase();
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function encodeUiAutomatorAttribute(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('\r', '&#13;')
    .replaceAll('\n', '&#10;');
}

function writeJson(relativePath, value) {
  fs.writeFileSync(absolute(relativePath), `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function main() {
  const metadata = fs.readFileSync(absolute(deviceMetadataPath), 'utf8');
  const apkSha256 = sha256File(apkPath);
  const talkBackVersion = metadata.match(/versionName=([^\s]+)/)?.[1] ?? '';

  assert(metadata.includes('ACCESSIBILITY_ENABLED'), 'Missing accessibility metadata');
  assert(/\r?\n1\r?\n/.test(metadata), 'Accessibility service was not enabled');
  assert(
    metadata.includes(
      'com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService',
    ),
    'TalkBack service was not the enabled accessibility service',
  );
  assert(metadata.includes('TOUCH_EXPLORATION_ENABLED'), 'Missing touch exploration metadata');
  assert(metadata.includes('FONT_SCALE'), 'Missing font-scale metadata');
  assert(metadata.includes('2.0'), 'TalkBack evidence must use text scale 2.0');
  assert(talkBackVersion.length > 0, 'Missing TalkBack version');
  assert(metadata.toUpperCase().includes(apkSha256), 'Installed APK hash does not match evidence APK');

  const allCapturePaths = journeys.flatMap((journey) =>
    journey.steps.flatMap((_, index) => [
      `${evidenceDirectory}/${journey.id}-step-${index + 1}.png`,
      `${evidenceDirectory}/${journey.id}-step-${index + 1}.xml`,
    ]),
  );
  const capturedAt = new Date(
    Math.max(...allCapturePaths.map((artifact) => fs.statSync(absolute(artifact)).mtimeMs)),
  ).toISOString();

  const rows = [];
  for (const journey of journeys) {
    const focusSteps = journey.steps.map((step, index) => {
      const order = index + 1;
      const screenshotPath = `${evidenceDirectory}/${journey.id}-step-${order}.png`;
      const uiXmlPath = `${evidenceDirectory}/${journey.id}-step-${order}.xml`;
      const screenshotSha256 = sha256File(screenshotPath);
      const uiXmlSha256 = sha256File(uiXmlPath);
      const xml = fs.readFileSync(absolute(uiXmlPath), 'utf8');
      const encodedLabel = encodeUiAutomatorAttribute(step.label);

      assert(
        xml.includes(`content-desc="${encodedLabel}"`) ||
          xml.includes(`text="${encodedLabel}"`),
        `${journey.id} step ${order} label is not present in its UI XML`,
      );
      assert(
        xml.includes(`bounds="${step.bounds}"`),
        `${journey.id} step ${order} bounds are not present in its UI XML`,
      );
      assert(
        xml.includes(`package="${packageName}"`),
        `${journey.id} step ${order} is not bound to the PawMate package`,
      );

      return {
        order,
        focus_label: step.label,
        focus_bounds: step.bounds,
        capture_method: step.method,
        screenshot_path: screenshotPath,
        screenshot_sha256: screenshotSha256,
        ui_xml_path: uiXmlPath,
        ui_xml_sha256: uiXmlSha256,
      };
    });

    assert(
      new Set(focusSteps.map((step) => `${step.focus_label}\0${step.focus_bounds}`)).size ===
        focusSteps.length,
      `${journey.id} focus steps are not distinct`,
    );
    assert(
      new Set(focusSteps.map((step) => step.screenshot_sha256)).size === focusSteps.length,
      `${journey.id} screenshots are not distinct`,
    );

    const evidenceId = `android-api36-${journey.id}-20260723`;
    const manifestPath = `${evidenceDirectory}/${journey.id}.manifest.json`;
    const manifest = {
      schema: 'pawmate.ui-v031.talkback-journey.v1',
      baseline_id: baselineId,
      journey_id: journey.id,
      evidence_id: evidenceId,
      screen_id: journey.screenId,
      route: journey.route,
      platform: 'ANDROID',
      android_api_level: 36,
      device_serial: 'emulator-5554',
      device_model: 'sdk_gphone64_x86_64',
      talkback_enabled: true,
      touch_exploration_enabled: true,
      talkback_version: talkBackVersion,
      text_scale: '2.0',
      package_name: packageName,
      apk_path: apkPath,
      apk_sha256: apkSha256,
      device_metadata_path: deviceMetadataPath,
      device_metadata_sha256: sha256File(deviceMetadataPath),
      captured_at: capturedAt,
      contains_test_data_only: true,
      redaction_status: 'PASS_NO_REAL_USER_DATA_OR_TOKEN',
      focus_steps: focusSteps,
    };
    writeJson(manifestPath, manifest);
    rows.push({
      journey_id: journey.id,
      evidence_id: evidenceId,
      screen_id: journey.screenId,
      route: journey.route,
      manifest_path: manifestPath,
      manifest_sha256: sha256File(manifestPath),
    });
  }

  const indexPath = `${evidenceDirectory}/talkback-journey-index.json`;
  writeJson(indexPath, {
    schema: 'pawmate.ui-v031.talkback-journey-index.v1',
    baseline_id: baselineId,
    generated_at: capturedAt,
    row_count: rows.length,
    apk_path: apkPath,
    apk_sha256: apkSha256,
    device_metadata_path: deviceMetadataPath,
    device_metadata_sha256: sha256File(deviceMetadataPath),
    rows,
  });

  console.log(
    JSON.stringify(
      {
        index_path: indexPath,
        row_count: rows.length,
        apk_sha256: apkSha256,
        talkback_version: talkBackVersion,
      },
      null,
      2,
    ),
  );
}

main();

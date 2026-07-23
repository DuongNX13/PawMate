import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const read = (relativePath) =>
  fs.readFileSync(path.join(root, relativePath), 'utf8');

const failures = [];
const checks = [];

function check(id, condition, detail) {
  checks.push({ id, status: condition ? 'PASS' : 'FAIL', detail });
  if (!condition) failures.push({ id, detail });
}

function occurrences(value, pattern) {
  return [...value.matchAll(pattern)].length;
}

function pngInfo(relativePath) {
  const filePath = path.join(root, relativePath);
  const buffer = fs.readFileSync(filePath);
  const signature = '89504e470d0a1a0a';
  if (buffer.subarray(0, 8).toString('hex') !== signature) {
    throw new Error(`${relativePath} is not a PNG file`);
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    bitDepth: buffer[24],
    colorType: buffer[25],
  };
}

const androidManifest = read(
  'mobile/android/app/src/main/AndroidManifest.xml',
);
const androidStrings = read(
  'mobile/android/app/src/main/res/values/strings.xml',
);
const androidColors = read(
  'mobile/android/app/src/main/res/values/colors.xml',
);
const androidSplash = read(
  'mobile/android/app/src/main/res/drawable/launch_background.xml',
);
const androidSplashV31 = read(
  'mobile/android/app/src/main/res/values-v31/styles.xml',
);
const iosInfo = read('mobile/ios/Runner/Info.plist');
const iosProject = read('mobile/ios/Runner.xcodeproj/project.pbxproj');
const iosLaunch = read(
  'mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard',
);
const codemagic = read('codemagic.yaml');

check(
  'ANDROID-NAME',
  androidManifest.includes('android:label="@string/app_name"') &&
    androidStrings.includes('<string name="app_name">PawMate</string>'),
  'Android launcher name resolves to PawMate.',
);
check(
  'ANDROID-PORTRAIT',
  androidManifest.includes('android:screenOrientation="portrait"'),
  'MainActivity is portrait-only.',
);

const permissions = [...androidManifest.matchAll(
  /<uses-permission android:name="([^"]+)"\s*\/>/g,
)].map((match) => match[1]);
const expectedPermissions = [
  'android.permission.INTERNET',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_FINE_LOCATION',
];
check(
  'ANDROID-PERMISSIONS',
  permissions.length === expectedPermissions.length &&
    expectedPermissions.every((permission) => permissions.includes(permission)),
  `Minimal permission set: ${permissions.join(', ')}`,
);
for (const scheme of ['tel', 'https', 'google.navigation', 'waze']) {
  check(
    `ANDROID-QUERY-${scheme.toUpperCase().replace('.', '-')}`,
    androidManifest.includes(`android:scheme="${scheme}"`),
    `Package visibility includes ${scheme}.`,
  );
}
check(
  'ANDROID-CHOCOMINT',
  androidColors.includes('#2D6A4F') && androidColors.includes('#E9F5DB'),
  'Native icon and splash colors use approved Chocomint tokens.',
);
check(
  'ANDROID-SPLASH-LEGACY',
  androidSplash.includes('@color/pawmate_splash_background') &&
    androidSplash.includes('@drawable/pawmate_splash_mark'),
  'Pre-Android 12 splash is branded.',
);
check(
  'ANDROID-SPLASH-31',
  androidSplashV31.includes('android:windowSplashScreenBackground') &&
    androidSplashV31.includes('@drawable/pawmate_splash_icon'),
  'Android 12+ splash contract is branded; Flutter metadata hands off to NormalTheme.',
);

check(
  'IOS-NAME',
  /<key>CFBundleDisplayName<\/key>\s*<string>PawMate<\/string>/.test(iosInfo) &&
    /<key>CFBundleName<\/key>\s*<string>PawMate<\/string>/.test(iosInfo),
  'iOS display and bundle names are PawMate.',
);
check(
  'IOS-PORTRAIT',
  occurrences(iosInfo, /UIInterfaceOrientationPortrait<\/string>/g) === 2 &&
    !iosInfo.includes('UIInterfaceOrientationLandscape') &&
    !iosInfo.includes('UIInterfaceOrientationPortraitUpsideDown'),
  'iPhone and fallback iPad orientation arrays contain portrait only.',
);
check(
  'IOS-IPHONE-ONLY',
  occurrences(iosProject, /TARGETED_DEVICE_FAMILY = 1;/g) === 3 &&
    !iosProject.includes('TARGETED_DEVICE_FAMILY = "1,2";'),
  'All Runner build configurations target iPhone only.',
);
check(
  'IOS-LOCATION-REASON',
  iosInfo.includes('NSLocationWhenInUseUsageDescription') &&
    iosInfo.includes('PawMate dùng vị trí để tìm phòng khám thú y gần bạn.'),
  'Location permission has a user-facing Vietnamese purpose string.',
);
check(
  'IOS-SPLASH-COLOR',
  iosLaunch.includes('red="0.9137254902"') &&
    iosLaunch.includes('green="0.9607843137"') &&
    iosLaunch.includes('blue="0.8588235294"'),
  'Launch storyboard uses #E9F5DB.',
);

for (const [key, value] of [
  ['flutter', '3.44.7'],
  ['xcode', '26.4'],
  ['cocoapods', '1.16.2'],
  ['java', '17'],
]) {
  check(
    `CI-${key.toUpperCase()}`,
    occurrences(codemagic, new RegExp(`^\\s+${key}: "${value.replace('.', '\\.') }"$`, 'gm')) === 2,
    `Both Codemagic workflows pin ${key}=${value}.`,
  );
}
check(
  'CI-NO-FLOATING-SELECTORS',
  !/^\s+(flutter: stable|xcode: latest|cocoapods: default)\s*$/m.test(codemagic),
  'No moving Flutter/Xcode/CocoaPods selector remains.',
);

const androidIcons = {
  'mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
};
for (const [relativePath, size] of Object.entries(androidIcons)) {
  const info = pngInfo(relativePath);
  check(
    `ICON-ANDROID-${size}`,
    info.width === size && info.height === size,
    `${relativePath} is ${info.width}x${info.height}.`,
  );
}

const iconContentsPath = path.join(
  root,
  'mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
);
const iconContents = JSON.parse(fs.readFileSync(iconContentsPath, 'utf8'));
for (const entry of iconContents.images) {
  const baseSize = Number.parseFloat(entry.size.split('x')[0]);
  const scale = Number.parseInt(entry.scale, 10);
  const expected = Math.round(baseSize * scale);
  const relativePath = `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.filename}`;
  const info = pngInfo(relativePath);
  check(
    `ICON-IOS-${entry.filename}`,
    info.width === expected &&
      info.height === expected &&
      info.colorType === 2,
    `${entry.filename} is ${info.width}x${info.height}, PNG color type ${info.colorType} (2 means RGB/no alpha).`,
  );
}

for (const [relativePath, width, height] of [
  ['mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', 168, 185],
  ['mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', 336, 370],
  ['mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', 504, 555],
  ['mobile/android/app/src/main/res/drawable-nodpi/pawmate_splash_mark.png', 128, 128],
  ['mobile/android/app/src/main/res/drawable-nodpi/pawmate_splash_icon.png', 288, 288],
  ['mobile/android/app/src/main/res/drawable-nodpi/pawmate_adaptive_foreground.png', 432, 432],
]) {
  const info = pngInfo(relativePath);
  check(
    `SPLASH-${path.basename(relativePath)}-${width}`,
    info.width === width && info.height === height,
    `${relativePath} is ${info.width}x${info.height}.`,
  );
}

const result = {
  status: failures.length === 0 ? 'PASS' : 'FAIL',
  checkedAt: new Date().toISOString(),
  checks,
  failures,
};

console.log(JSON.stringify(result, null, 2));
if (failures.length > 0) process.exitCode = 1;

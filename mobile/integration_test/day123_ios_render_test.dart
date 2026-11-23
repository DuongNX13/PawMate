// Day 123 QA-only iOS Simulator render and accessibility probe.
// Reuses the Day 122 fixture pumps; it does not change production code.
// VoiceOver is not driven here: accessibility is checked with Flutter's
// semantics guidelines instead (recorded deviation, Day123-deviation).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../test/test_support/day119_detail_support.dart' as details;
import 'day122_android_responsive_test.dart' as d122;

const _detailFamilies = ['DT-01', 'DT-03', 'DT-04', 'DT-05'];
// Adoption deck/profile fixtures stay blocked as in Day 122.
const _blocked = ['P2-09', 'P2-10'];
const _navLabels = ['Home', 'Vet', 'Health', 'Rescue', 'Profile'];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const device = String.fromEnvironment('D123_DEVICE', defaultValue: 'ios');
  final families = [
    ...d122.mainFamilies.keys.where((f) => !_blocked.contains(f)),
    ..._detailFamilies,
  ];
  final rows = <Map<String, dynamic>>[];
  binding.reportData = {'day': 123, 'device': device, 'rows': rows};
  Directory? fixtures;
  final prior = Directory.current;

  setUpAll(() async {
    if (!Platform.isIOS) throw StateError('Day 123 probe runs on iOS only');
    fixtures = await Directory.systemTemp.createTemp('day123-assets-');
    Directory.current = fixtures!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where(
      (s) => s.startsWith('assets/images/') || s.startsWith('assets/icons/'),
    )) {
      final bytes = await rootBundle.load(asset);
      final f = File(asset);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
  });
  tearDownAll(() async {
    Directory.current = prior;
    await fixtures?.delete(recursive: true);
  });

  for (final family in families) {
    testWidgets(
      'D123 $device $family render, insets and semantics',
      (t) async {
        final native = ui.PlatformDispatcher.instance.views.single;
        final dpr = native.devicePixelRatio;
        final size = native.physicalSize / dpr;
        if (d122.mainFamilies.containsKey(family)) {
          await d122.mainFamilies[family]!(t, size);
        } else {
          await details.pumpDay119(t, family, size);
        }
        d122.restoreNativeMetrics122(t);
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
        // Safe area and home indicator come from the simulator, not the fixture.
        expect(t.view.padding.top, native.padding.top);
        expect(t.view.viewPadding.bottom, native.viewPadding.bottom);
        final navIssues = _navAboveHomeIndicator(
          t,
          size,
          native.viewPadding.bottom / dpr,
        );
        final name = 'D123-$device-${family.toLowerCase()}';
        await binding.takeScreenshot('$name-top');
        final guidelines = await _guidelines(t);
        rows.add({
          'id': '$device-$family',
          'logical_size': [size.width, size.height],
          'dpr': dpr,
          'safe_area_top': native.padding.top / dpr,
          'home_indicator_inset': native.viewPadding.bottom / dpr,
          'nav_issues': navIssues,
          'guidelines': guidelines,
          'verdict':
              navIssues.isEmpty && guidelines.values.every((v) => v == 'PASS')
              ? 'RUNTIME_PASS_VISUAL_REVIEW_REQUIRED'
              : 'FINDINGS_REVIEW_REQUIRED',
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

List<String> _navAboveHomeIndicator(WidgetTester t, Size size, double inset) {
  final nav = find.byType(PawMateBottomNav);
  if (nav.evaluate().isEmpty) return const [];
  final issues = <String>[];
  final handle = t.ensureSemantics();
  for (final label in _navLabels) {
    final target = find.bySemanticsLabel(label);
    if (target.evaluate().length != 1) {
      issues.add('$label: ${target.evaluate().length} semantics nodes');
    } else if (t.getRect(target).bottom > size.height - inset + 1) {
      issues.add('$label overlaps the home indicator');
    }
  }
  handle.dispose();
  return issues;
}

// Findings are recorded, not thrown: Day 123 is a TEST day and every
// screen must still be captured.
Future<Map<String, String>> _guidelines(WidgetTester t) async {
  final handle = t.ensureSemantics();
  final checks = {
    'labeled_tap_targets': labeledTapTargetGuideline,
    'ios_tap_target_44': iOSTapTargetGuideline,
    'text_contrast': textContrastGuideline,
  };
  final out = <String, String>{};
  for (final e in checks.entries) {
    final r = await e.value.evaluate(t);
    out[e.key] = r.passed ? 'PASS' : 'FAIL: ${r.reason}';
  }
  handle.dispose();
  return out;
}

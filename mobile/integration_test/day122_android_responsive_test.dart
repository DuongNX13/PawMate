import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../test/test_support/day119_detail_support.dart' as details;
import '../test/visual/day120_support_scaling_test.dart' as support;
import '../test/visual/phase1_pet_golden_test.dart' as pets;
import '../test/visual/phase1_home_profile_golden_test.dart' as home;
import '../test/visual/day23_vet_finder_golden_test.dart' as vets;
import '../test/visual/day24_vet_detail_review_golden_test.dart' as vet_detail;
import '../test/visual/day27_health_timeline_event_golden_test.dart' as health;
import '../test/visual/day28_reminder_notification_golden_test.dart'
    as reminders;
import '../test/visual/ui_v031_rescue_live_golden_test.dart' as rescue;
import '../test/visual/ui_v031_rescue_case_detail_golden_test.dart'
    as rescue_detail;
import '../test/visual/day44_rescue_map_golden_test.dart' as rescue_map;
import '../test/visual/day46_rescue_status_discussion_golden_test.dart'
    as discussion;
import '../test/visual/day54_adoption_golden_test.dart' as adoption;
import '../test/visual/day55_adoption_request_chat_golden_test.dart' as chat;
import '../test/visual/day60_health_preferences_golden_test.dart' as hub;

typedef Pump = Future<void> Function(WidgetTester, Size);
final mainFamilies = <String, Pump>{
  'P1-05': pets.pumpDay118PetList,
  'P1-07': home.pumpDay118Home,
  'P1-08': vets.pumpDay118VetMap,
  'P1-09': vets.pumpDay118VetList,
  'P1-10': vet_detail.pumpDay118VetDetail,
  'P1-12': health.pumpDay118Timeline,
  'P1-14': reminders.pumpDay118Calendar,
  'P1-15': reminders.pumpDay118Notifications,
  'P1-16': home.pumpDay118Profile,
  'P2-01': rescue.pumpDay118RescueHome,
  'P2-04': rescue_detail.pumpDay118RescueDetail,
  'P2-05': rescue_map.pumpDay118RescueMap,
  'P2-08': discussion.pumpDay118Discussion,
  'P2-09': adoption.pumpDay118AdoptionDeck,
  'P2-10': adoption.pumpDay118AdoptionProfile,
  'P2-12': chat.pumpDay118Chat,
  'P2-13': hub.pumpDay118HealthHub,
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const width = int.fromEnvironment('D122_WIDTH');
  const height = int.fromEnvironment('D122_HEIGHT');
  const captureCanary = bool.fromEnvironment('D122_CAPTURE_CANARY');
  final size = Size(width.toDouble(), height.toDouble());
  final families = (captureCanary ? ['P1-07', 'P1-08'] : [
    ...mainFamilies.keys,
    'DT-01',
    'DT-03',
    'DT-04',
    'DT-05',
    if (width != 390) ...support.families,
  ]).where((f) => !const ['P2-09', 'P2-10', 'DT-10'].contains(f)).toList();
  Directory? fixtureDirectory;
  final priorDirectory = Directory.current;
  binding.reportData = {
    'day': 122,
    'viewport': [width, height],
    'proof': 'ANDROID_NATIVE_METRICS_FIXTURE_DATA',
    'rows': <Map<String, dynamic>>[],
  };
  setUpAll(() async {
    if (!(const [360, 390, 430].contains(width) || (captureCanary && width==320)) || height <= 0) {
      throw StateError('Explicit approved viewport required');
    }
    // Historical fixture builders enumerate assets from the host filesystem.
    // Materialize bundled fixtures in private QA temp space, not production.
    fixtureDirectory = await Directory.systemTemp.createTemp('day122-assets-');
    Directory.current = fixtureDirectory!;
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
    // Adoption fixture-dependent branch is BLOCKED after its bounded
    // correction failed. Do not retry it or silently substitute an image.
  });
  tearDownAll(() async {
    Directory.current = priorDirectory;
    if (fixtureDirectory != null) {
      await fixtureDirectory!.delete(recursive: true);
    }
  });

  for (final family in families) {
    final id = 'ANDROID-$family-${width}x$height';
    testWidgets(
      'D122 $id native runtime render and scroll',
      (t) async {
        final native = ui.PlatformDispatcher.instance.views.single;
        expect(
          native.physicalSize.width / native.devicePixelRatio,
          closeTo(width, .1),
        );
        expect(
          native.physicalSize.height / native.devicePixelRatio,
          closeTo(height, .1),
        );
        if (mainFamilies.containsKey(family)) {
          await mainFamilies[family]!(t, size);
        } else if (const [
          'DT-01',
          'DT-03',
          'DT-04',
          'DT-05',
        ].contains(family)) {
          await details.pumpDay119(t, family, size);
        } else {
          await support.pumpFamily(t, family, size);
        }
        restoreNativeMetrics122(t);
        await t.pump(const Duration(milliseconds: 500));
        // Convert only after this test's application frame exists. The native
        // plugin reverts the conversion at each test teardown.
        await binding.convertFlutterSurfaceToImage();
        await t.pump();
        if (family == 'DT-04' || family == 'DT-05') {
          final target = family == 'DT-04'
              ? find.byKey(const Key('rescue-load-more'))
              : find.byKey(
                  ValueKey('rescue-marker-${details.day119FirstCaseId}'),
                );
          await t.ensureVisible(target);
          await t.pump(const Duration(milliseconds: 400));
          await t.tap(target);
          await t.pump(const Duration(milliseconds: 400));
          expect(
            family == 'DT-04'
                ? find.text('Thu gọn')
                : find.byKey(const Key('rescue-selected-case-card')),
            findsOneWidget,
          );
        }
        expect(t.view.viewInsets.bottom, native.viewInsets.bottom);
        expect(t.view.padding.top, native.padding.top);
        expect(t.view.viewPadding.bottom, native.viewPadding.bottom);
        expect(t.takeException(), isNull);
        _nav(t, size, native.viewPadding.bottom / native.devicePixelRatio);
        await _shot122(t, binding, 'D122-${id.toLowerCase()}-top');

        final vertical = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (vertical.evaluate().isNotEmpty) {
          final p = t.state<ScrollableState>(vertical.first).position;
          for (var i = 0; i < 5 && p.extentAfter > .5; i++) {
            p.jumpTo(p.maxScrollExtent);
            await t.pump(const Duration(milliseconds: 300));
          }
          expect(p.extentAfter, lessThanOrEqualTo(.5));
        }
        expect(t.takeException(), isNull);
        _nav(t, size, native.viewPadding.bottom / native.devicePixelRatio);
        await _shot122(t, binding, 'D122-${id.toLowerCase()}-end');
        (binding.reportData!['rows'] as List<Map<String, dynamic>>).add({
          'id': id,
          'family': family,
          'at': DateTime.now().toUtc().toIso8601String(),
          'native_physical_size': [
            native.physicalSize.width,
            native.physicalSize.height,
          ],
          'dpr': native.devicePixelRatio,
          'native_insets': [native.viewPadding.top, native.viewPadding.bottom],
          'verdict': 'RUNTIME_ASSERTIONS_PASS_VISUAL_REVIEW_REQUIRED',
          'backend_map_clock': 'FIXTURE_NOT_LIVE',
          'talkback_proof': false,
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

// D124: on Android, takeScreenshot waits for a rasterized frame after the
// surface conversion. A settled screen schedules none, so the capture could
// wait until the 2-minute timeout. Force one frame first.
Future<void> _shot122(
  WidgetTester t,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  t.binding.scheduleFrame();
  await t.pump();
  await binding.takeScreenshot(name);
}

void restoreNativeMetrics122(WidgetTester t) {
  t.view.resetPhysicalSize();
  t.view.resetDevicePixelRatio();
  t.view.resetViewInsets();
  t.view.resetViewPadding();
  t.view.resetPadding();
}

void _nav(WidgetTester t, Size size, double bottomInset) {
  final nav = find.byType(PawMateBottomNav);
  if (nav.evaluate().isEmpty) return;
  final rect = t.getRect(nav.first);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width + .5));
  expect(
    rect.bottom,
    closeTo(size.height, .6),
    reason: 'Navigation shell stays at physical bottom',
  );
  final semantics = t.ensureSemantics();
  for (final label in ['Home', 'Vet', 'Health', 'Rescue', 'Profile']) {
    final target = find.bySemanticsLabel(label);
    expect(target, findsOneWidget);
    expect(
      t.getRect(target).bottom,
      lessThanOrEqualTo(size.height - bottomInset + 1),
    );
  }
  semantics.dispose();
}

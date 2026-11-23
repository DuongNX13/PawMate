import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/visual/phase1_entry_golden_test.dart' as entry;
import '../test/visual/phase1_home_profile_golden_test.dart' as home;

// Reuse only fixture builders, never their main()/golden/inset assertions.
// Backend/auth are synthetic. Surface metrics and IME come from Android.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.reportData = <String, dynamic>{
    'day': 122,
    'proof': 'ANDROID_NATIVE_CANARY',
    'observations': <Map<String, dynamic>>[],
  };

  testWidgets(
    'D122 native Home insets and onboarding IME canary',
    (t) async {
      expect(ui.PlatformDispatcher.instance.views.length, 1);
      final native = ui.PlatformDispatcher.instance.views.single;
      final size = native.physicalSize / native.devicePixelRatio;
      expect(size.width, greaterThan(0));
      await home.pumpDay118Home(t, size);
      _restoreNativeMetrics(t);
      await t.pumpAndSettle();
      _nativeObservation(binding, t, 'HOME-NATIVE');
      expect(find.text('PawMate'), findsOneWidget);
      expect(t.takeException(), isNull);
      await binding.convertFlutterSurfaceToImage();
      await t.pump();
      await binding.takeScreenshot('D122-home-native');

      // Separate fixture lifetimes. Riverpod forbids changing override counts
      // on an existing ProviderScope; this is harness isolation, not a route.
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      await entry.pumpDay120Entry(t, size, login: false);
      _restoreNativeMetrics(t);
      await t.pumpAndSettle();
      final field = find.byKey(const Key('onboarding-pet-name-field'));
      await t.ensureVisible(field);
      await t.tap(field);
      await t.showKeyboard(field);
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (native.viewInsets.bottom <= 0 &&
          DateTime.now().isBefore(deadline)) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(
        native.viewInsets.bottom,
        greaterThan(0),
        reason: 'Must observe actual Android IME, not FakeViewPadding',
      );
      await t.pumpAndSettle();
      final cta = find.byKey(const Key('onboarding-continue-button'));
      await t.ensureVisible(cta);
      await t.pumpAndSettle();
      final bottom =
          size.height - native.viewInsets.bottom / native.devicePixelRatio;
      expect(t.getRect(cta).bottom, lessThanOrEqualTo(bottom + 1));
      expect(cta.hitTestable(), findsOneWidget);
      _nativeObservation(binding, t, 'ONBOARDING-NATIVE-IME');
      expect(t.takeException(), isNull);
      await binding.takeScreenshot('D122-onboarding-native-ime');
      // Input values/actions are not claimed as TalkBack or physical typing.
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

void _restoreNativeMetrics(WidgetTester t) {
  t.view.resetPhysicalSize();
  t.view.resetDevicePixelRatio();
  t.view.resetViewInsets();
  t.view.resetViewPadding();
  t.view.resetPadding();
}

void _nativeObservation(
  IntegrationTestWidgetsFlutterBinding b,
  WidgetTester t,
  String id,
) {
  final n = ui.PlatformDispatcher.instance.views.single;
  expect(t.view.physicalSize, n.physicalSize);
  expect(t.view.devicePixelRatio, n.devicePixelRatio);
  expect(t.view.viewInsets.bottom, n.viewInsets.bottom);
  (b.reportData!['observations'] as List<Map<String, dynamic>>).add({
    'id': id,
    'at': DateTime.now().toUtc().toIso8601String(),
    'physical_size': [n.physicalSize.width, n.physicalSize.height],
    'dpr': n.devicePixelRatio,
    'native_top_inset': n.viewPadding.top,
    'native_bottom_inset': n.viewPadding.bottom,
    'native_ime_inset': n.viewInsets.bottom,
    'backend': 'FIXTURE_NOT_LIVE',
    'talkback_proof': false,
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_skeleton.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test the installed plugin boundary; no dependency or lockfile modification.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 R22 ST-03 P1-01 delayed local restore text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      SharedPreferences.setMockInitialValues({});
      final store = _PendingStore();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('onboarding-draft-loading')), findsOneWidget);
      expect(find.byType(PawMateSkeleton), findsWidgets);
      final before = tester.getRect(
        find.byKey(const ValueKey('onboarding-responsive-hero')),
      );
      final stem = 'R22-ST03-P101-text${scale.toString().replaceAll('.', '-')}';
      await captureDay116(tester, '$stem-loading');
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('onboarding-draft-loading')), findsOneWidget);
      store.pending.complete({
        'flutter.onboardingDraftPetName': 'Mochi R22',
        'flutter.onboardingDraftBreed': 'Poodle',
        'flutter.onboardingDraftAge': '2',
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-draft-loading')), findsNothing);
      expect(find.byType(PawMateSkeleton), findsNothing);
      expect(
        tester.getRect(
          find.byKey(const ValueKey('onboarding-responsive-hero')),
        ),
        before,
      );
      final name = find.descendant(
        of: find.byKey(const Key('onboarding-pet-name-field')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        name,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(name).controller!.text, 'Mochi R22');
      expect(tester.widget<TextFormField>(name).enabled, isTrue);
      await tester.enterText(name, 'Mochi giữ bản nháp');
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Mochi giữ bản nháp',
      );
      await captureDay116(tester, '$stem-restored');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expectNoFlutterOverflow(tester);
    });
  }
}

class _PendingStore extends InMemorySharedPreferencesStore {
  _PendingStore() : super.withData({});
  final pending = Completer<Map<String, Object>>();
  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => pending.future;
}

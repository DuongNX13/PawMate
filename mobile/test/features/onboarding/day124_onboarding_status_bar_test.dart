import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';

// ANDROID-STRESS-Onboarding: at 320x568 / text 2 the form scrolled under the
// transparent status bar. Once scrolled, a scrim must cover that band.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('status bar scrim appears after scrolling', (t) async {
    await setTestViewport(t, size: const Size(320, 568));
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24),
              viewPadding: const EdgeInsets.only(top: 24),
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    final scrim = find.byKey(const Key('onboarding-status-bar-scrim'));
    expect(scrim, findsOneWidget);
    expect(t.widget<AnimatedOpacity>(scrim).opacity, 0);

    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(t.widget<AnimatedOpacity>(scrim).opacity, 1);
    expect(t.getRect(scrim).height, 24);
  });
}

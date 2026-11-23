import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../features/rescue/rescue_test_fixtures.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  for (final size in const [Size(390, 844), Size(430, 932), Size(320, 568)]) {
    final scale = size.width == 320 ? 2.0 : 1.0;
    testWidgets('DT-05 selected card ${size.width} text $scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: size);
      const root = Key('day101-golden');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(
                pages: [samplePage(items: sampleCasesWithoutImages())],
              ),
            ),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
          ],
          child: RepaintBoundary(
            key: root,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              home: const RescueHomeScreen(
                browseEnabled: true,
                createEnabled: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byKey(root));
      for (final destination in PawMateBottomNav.destinations) {
        await tester.runAsync(
          () => precacheImage(AssetImage(destination.iconAsset), context),
        );
      }
      final marker = find.byKey(
        ValueKey('rescue-marker-${sampleCases().first.caseId}'),
      );
      await tester.scrollUntilVisible(
        marker,
        120,
        scrollable: find.descendant(
          of: find.byKey(const Key('rescue-live-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await Scrollable.ensureVisible(tester.element(marker), alignment: .25);
      await tester.pumpAndSettle();
      await tester.tap(marker);
      await tester.pumpAndSettle();
      final cta = find.byKey(const Key('rescue-selected-details'));
      await Scrollable.ensureVisible(tester.element(cta), alignment: .9);
      await tester.pumpAndSettle();
      expectNoFlutterOverflow(tester);
      expect(
        tester.getRect(cta).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(PawMateBottomNav)).top),
      );
      await expectLater(
        find.byKey(root),
        matchesGoldenFile(
          'goldens/day101/dt-05-selected-${size.width.toInt()}x${size.height.toInt()}-text${scale.toInt()}.png',
        ),
      );
    });
  }
}

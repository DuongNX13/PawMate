import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_layout.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  for (final entry in <(Size, PawMateResponsiveTier)>[
    (const Size(320, 568), PawMateResponsiveTier.small),
    (const Size(390, 844), PawMateResponsiveTier.standard),
    (const Size(430, 932), PawMateResponsiveTier.large),
    (const Size(840, 1024), PawMateResponsiveTier.wide),
  ]) {
    testWidgets('responsive frame selects ${entry.$2.name} at ${entry.$1}', (
      tester,
    ) async {
      await setTestViewport(tester, size: entry.$1);
      PawMateLayoutMetrics? observed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PawMateResponsiveFrame(
              builder: (context, metrics) {
                observed = metrics;
                return const SizedBox(
                  key: Key('responsive-content'),
                  width: double.infinity,
                  height: 80,
                );
              },
            ),
          ),
        ),
      );

      expect(observed?.tier, entry.$2);
      expect(
        tester.getSize(find.byKey(const Key('responsive-content'))).width,
        lessThanOrEqualTo(observed!.maxContentWidth),
      );
      expectNoFlutterOverflow(tester);
    });
  }

  testWidgets('scaled frame preserves composition without blind transform', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: PawMateScaledFrame(
            child: SizedBox(
              key: Key('scaled-content'),
              width: double.infinity,
              height: 720,
            ),
          ),
        ),
      ),
    );

    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(PawMateScaledFrame),
        matching: find.byType(Transform),
      ),
    );
    for (final transform in transforms) {
      expect(transform.transform.storage[0], 1, reason: 'No horizontal scale');
      expect(transform.transform.storage[5], 1, reason: 'No vertical scale');
    }
    expect(find.byType(FittedBox), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('scaled-content'))).width,
      lessThanOrEqualTo(288),
    );
    expectNoFlutterOverflow(tester);
  });
}

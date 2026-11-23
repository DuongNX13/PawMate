import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_fixed_cta_bar.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_page_scaffold.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'fixed CTA above bottom nav delegates physical bottom inset to nav only',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));

      await _pumpShell(tester, bottomInset: 0, includeNav: true);
      final ctaWithoutInset = tester.getSize(find.byType(PawMateFixedCtaBar));
      final navWithoutInset = tester.getSize(find.byType(PawMateBottomNav));

      await _pumpShell(tester, bottomInset: 24, includeNav: true);
      final ctaWithInset = tester.getSize(find.byType(PawMateFixedCtaBar));
      final navWithInset = tester.getSize(find.byType(PawMateBottomNav));

      expect(ctaWithInset.height, ctaWithoutInset.height);
      expect(navWithInset.height - navWithoutInset.height, 24);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('fixed CTA without nav still owns physical bottom inset', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

    await _pumpShell(tester, bottomInset: 0, includeNav: false);
    final withoutInset = tester.getSize(find.byType(PawMateFixedCtaBar));

    await _pumpShell(tester, bottomInset: 24, includeNav: false);
    final withInset = tester.getSize(find.byType(PawMateFixedCtaBar));

    expect(withInset.height - withoutInset.height, 24);
    expectNoFlutterOverflow(tester);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required double bottomInset,
  required bool includeNav,
}) async {
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: PawMatePageScaffold(
        body: const Center(child: Text('Nội dung')),
        fixedCtaBar: PawMateFixedCtaBar(
          primaryAction: PawMateAction(label: 'Tiếp tục', onPressed: () {}),
        ),
        bottomNavigationBar: includeNav
            ? PawMateBottomNav(
                currentRoute: '/pets',
                onDestinationSelected: (_) {},
              )
            : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(tester.view.resetPadding);
}

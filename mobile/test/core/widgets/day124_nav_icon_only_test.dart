import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../../test_support/ui_test_helpers.dart';

// D123-IOS-UI-001 / D123-IOS-NAV-001: Figma v0.34 locks an icon-only bar
// (`LOCKED/NAV/v0.33/ICON_ONLY`, shell 70, icon 28). Names stay available to
// assistive tech through semantics and tooltips.
void main() {
  setUpAll(loadPawMateTestFonts);

  for (final scale in [1.0, 2.0]) {
    testWidgets('D124 nav is icon-only with fixed height text=$scale', (
      t,
    ) async {
      await setTestViewport(t, size: const Size(390, 844));
      final semantics = t.ensureSemantics();
      try {
        final taps = <String>[];
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            home: Scaffold(
              bottomNavigationBar: PawMateBottomNav(
                currentRoute: '/health',
                onDestinationSelected: taps.add,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final nav = find.byType(PawMateBottomNav);
        expect(
          find.descendant(of: nav, matching: find.byType(Text)),
          findsNothing,
        );
        expect(t.getRect(nav).height, AppControlSize.bottomNavHeight);
        for (final icon in t.widgetList<ImageIcon>(
          find.descendant(of: nav, matching: find.byType(ImageIcon)),
        )) {
          expect(icon.size, AppControlSize.bottomNavIcon);
        }
        for (final d in PawMateBottomNav.destinations) {
          final control = find.bySemanticsLabel(d.label);
          expect(control, findsOneWidget);
          expect(
            t.getSemantics(control).flagsCollection.isSelected ==
                ui.Tristate.isTrue,
            d.isActive('/health'),
          );
          final r = t.getRect(control);
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
          expect(find.byTooltip(d.label), findsOneWidget);
          await t.tap(control);
          await t.pump();
        }
        expect(taps, PawMateBottomNav.destinations.map((d) => d.route));
        expectNoFlutterOverflow(t);
      } finally {
        semantics.dispose();
      }
    });
  }
}

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets(
      'D121 selected caption updates every destination width=$width',
      (t) async {
        await setTestViewport(t, size: Size(width, 568));
        final semantics = t.ensureSemantics();
        try {
          var route = '/pets';
          await t.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(2),
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  bottomNavigationBar: PawMateBottomNav(
                    currentRoute: route,
                    onDestinationSelected: (r) => setState(() => route = r),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final original = t.getRect(find.byType(PawMateBottomNav));
          for (final d in PawMateBottomNav.destinations) {
            await t.tap(find.bySemanticsLabel(d.label));
            await t.pumpAndSettle();
            expect(route, d.route);
            final caption = find.byKey(
              const Key('navigation-selected-caption'),
            );
            expect(t.widget<Text>(caption).data, d.label);
            final p = t.renderObject<RenderParagraph>(caption);
            expect(p.didExceedMaxLines, false);
            expect(p.textScaler.scale(13), 26);
            expect(
              t
                  .getSemantics(find.bySemanticsLabel(d.label))
                  .flagsCollection
                  .isSelected,
              ui.Tristate.isTrue,
            );
            expect(t.getRect(find.byType(PawMateBottomNav)), original);
            expect(find.byTooltip(d.label), findsOneWidget);
          }
          expectNoFlutterOverflow(t);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('D121 nav readable words and five targets text=$scale', (
      t,
    ) async {
      await setTestViewport(t, size: const Size(320, 568));
      final semantics = t.ensureSemantics();
      try {
        final taps = <String>[];
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            home: Scaffold(
              bottomNavigationBar: PawMateBottomNav(
                currentRoute: '/rescue',
                onDestinationSelected: taps.add,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.getRect(find.byType(PawMateBottomNav)).bottom, 568);
        for (final text
            in find
                .descendant(
                  of: find.byType(PawMateBottomNav),
                  matching: find.byType(Text),
                )
                .evaluate()) {
          final p = text.renderObject! as RenderParagraph;
          final painter = TextPainter(
            text: p.text,
            textDirection: p.textDirection,
            textScaler: p.textScaler,
          )..layout(maxWidth: p.size.width);
          expect(
            painter.computeLineMetrics().length,
            1,
            reason: 'Navigation words must never split mid-word',
          );
          expect(p.didExceedMaxLines, false);
          painter.dispose();
        }
        for (final d in PawMateBottomNav.destinations) {
          final control = find.bySemanticsLabel(d.label);
          expect(control, findsOneWidget);
          final n = t.getSemantics(control);
          expect(
            n.flagsCollection.isSelected == ui.Tristate.isTrue,
            d.isActive('/rescue'),
          );
          expect(n.getSemanticsData().hasAction(ui.SemanticsAction.tap), true);
          final r = t.getRect(control);
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
          await t.tap(control);
          await t.pump();
        }
        expect(
          taps,
          PawMateBottomNav.destinations.map((d) => d.route).toList(),
        );
        expect(find.byType(FittedBox), findsNothing);
        if (scale == 2) {
          expect(
            find.byKey(const Key('navigation-selected-caption')),
            findsOneWidget,
          );
        }
        expectNoFlutterOverflow(t);
      } finally {
        semantics.dispose();
      }
    });
  }
}

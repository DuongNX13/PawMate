import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 C05 actual Rescue nav glyphs at 320 text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final semantics = tester.ensureSemantics();
      try {
        final router = GoRouter(
          initialLocation: '/rescue',
          routes: [
            GoRoute(
              path: '/rescue',
              builder: (_, _) => const RescueHomeScreen(browseEnabled: true),
            ),
          ],
        );
        addTearDown(router.dispose);
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
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
              builder: testTextScaleBuilder(scale),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await captureDay116(
          tester,
          'R9-C05-Rescue-text${scale.toString().replaceAll('.', '-')}',
        );
        final metrics = <Map<String, Object?>>[];
        final nav = find.byType(PawMateBottomNav);
        expect(tester.getRect(nav).bottom, 568);
        for (final item in PawMateBottomNav.destinations) {
          final label = find.descendant(
            of: nav,
            matching: find.text(item.label),
          );
          final control = find.bySemanticsLabel(item.label);
          expect(control, findsOneWidget);
          expect(tester.getRect(control).width, greaterThanOrEqualTo(48));
          expect(tester.getRect(control).height, greaterThanOrEqualTo(48));
          if (label.evaluate().isEmpty) continue;
          final paragraph = tester.renderObject<RenderParagraph>(label);
          final rect = tester.getRect(label);
          final full = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          metrics.add({
            'label': item.label,
            'exceeded': paragraph.didExceedMaxLines,
            'rendered_height': paragraph.size.height,
            'full_height': full.height,
            'full_lines': full.computeLineMetrics().length,
            'bounds': [rect.left, rect.top, rect.right, rect.bottom],
          });
          expect(label.hitTestable(), findsOneWidget);
          final node = find.bySemanticsLabel(item.label);
          expect(node, findsOneWidget);
          final target = tester.getRect(node);
          expect(target.width, greaterThanOrEqualTo(48));
          expect(target.height, greaterThanOrEqualTo(48));
          full.dispose();
        }
        debugPrint('D116_C05_METRICS:${jsonEncode(metrics)}');
        for (final item in metrics) {
          expect(
            item['exceeded'],
            false,
            reason: '${item['label']} must not ellipsize',
          );
          expect(
            item['rendered_height'] as double,
            greaterThanOrEqualTo((item['full_height'] as double) - 0.1),
            reason: '${item['label']} hidden glyphs',
          );
        }
        expectNoFlutterOverflow(tester);
      } finally {
        semantics.dispose();
      }
    });
  }
}

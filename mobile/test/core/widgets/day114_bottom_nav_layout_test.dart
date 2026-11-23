import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';

import '../../test_support/day114_capture.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final inset in [0.0, 34.0]) {
    testWidgets('D114 actual Health Hub nav full glyphs text2 safe=$inset', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      tester.view.padding = FakeViewPadding(bottom: inset);
      tester.view.viewPadding = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final semantics = tester.ensureSemantics();
      try {
        final router = GoRouter(
          initialLocation: '/health/hub',
          routes: [
            GoRoute(
              path: '/health/hub',
              builder: (_, _) => const HealthHubScreen(),
            ),
            GoRoute(
              path: '/pets/create',
              builder: (_, _) =>
                  const Scaffold(body: Text('Pet create target')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [petBackendListProvider.overrideWith((ref) async => [])],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
              builder: testTextScaleBuilder(2),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Thêm hồ sơ thú cưng'));
        await tester.pumpAndSettle();
        await captureDay114(tester, 'ST-04-hub-nav-text2-safe${inset.toInt()}');
        final metrics = <Map<String, Object?>>[];
        for (final item in PawMateBottomNav.destinations) {
          final finder = find.descendant(
            of: find.byType(PawMateBottomNav),
            matching: find.text(item.label),
          );
          final control = find.bySemanticsLabel(item.label);
          expect(control, findsOneWidget);
          expect(tester.getRect(control).width, greaterThanOrEqualTo(48));
          expect(tester.getRect(control).height, greaterThanOrEqualTo(48));
          if (finder.evaluate().isEmpty) {
            // Full accessible names remain on all five icon targets.
            continue;
          }
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          final rect = tester.getRect(finder);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: item.label.length),
          );
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          metrics.add({
            'label': item.label,
            'did_exceed_max_lines': paragraph.didExceedMaxLines,
            'height': paragraph.size.height,
            'full_height': painter.height,
            'top': rect.top,
            'bottom': rect.bottom,
            'usable_bottom': 568 - inset,
            'glyph_bottom': boxes
                .map((b) => b.bottom + rect.top)
                .reduce((a, b) => a > b ? a : b),
            'font_scale': paragraph.textScaler.scale(13) / 13,
          });
          expect(paragraph.didExceedMaxLines, isFalse, reason: item.label);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(painter.height - 0.1),
            reason: item.label,
          );
          expect(rect.bottom, lessThanOrEqualTo(568 - inset));
          for (final box in boxes) {
            expect(
              box.bottom,
              lessThanOrEqualTo(paragraph.size.height + 0.1),
              reason: item.label,
            );
          }
          expect(finder.hitTestable(), findsOneWidget);
          final target = tester.getRect(find.bySemanticsLabel(item.label));
          expect(target.width, greaterThanOrEqualTo(48));
          expect(target.height, greaterThanOrEqualTo(48));
          expect(
            paragraph.textScaler.scale(13),
            26,
          ); // No accessibility font clamp.
          painter.dispose();
        }
        final output = Platform.environment['D114_LAYOUT_METRICS'];
        if (output != null) {
          await tester.runAsync(() async {
            final directory = Directory(output)..createSync(recursive: true);
            final file = File(
              '${directory.path}/health-hub-safe${inset.toInt()}.json',
            );
            if (file.existsSync()) throw StateError('Metrics already exist');
            await file.writeAsString(jsonEncode(metrics), flush: true);
          });
        }
        await tester.tap(find.text('Thêm hồ sơ thú cưng'));
        await tester.pumpAndSettle();
        expect(find.text('Pet create target'), findsOneWidget);
        expectNoFlutterOverflow(tester);
      } finally {
        semantics.dispose();
      }
    });
  }
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('D114 nav complete labels width=$width scale=$scale', (
        tester,
      ) async {
        await setTestViewport(tester, size: Size(width, 568));
        final tapped = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            home: Scaffold(
              body: const Text('Navigation component layout proof'),
              bottomNavigationBar: PawMateBottomNav(
                currentRoute: '/health',
                onDestinationSelected: tapped.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Capture first so a failing visual/layout oracle retains its evidence.
        await captureDay114(
          tester,
          'ST-04-nav-${width.toInt()}-text${scale.toInt()}',
        );
        final navRect = tester.getRect(find.byType(PawMateBottomNav));
        expect(navRect.bottom, 568);
        final metrics = <Map<String, Object?>>[];
        for (final destination in PawMateBottomNav.destinations) {
          final finder = find.text(destination.label);
          if (finder.evaluate().isEmpty) continue;
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          metrics.add({
            'label': destination.label,
            'width': paragraph.size.width,
            'height': paragraph.size.height,
            'full_height': painter.height,
            'full_lines': painter.computeLineMetrics().length,
            'did_exceed_max_lines': paragraph.didExceedMaxLines,
          });
          painter.dispose();
        }
        final output = Platform.environment['D114_LAYOUT_METRICS'];
        if (output != null) {
          await tester.runAsync(() async {
            final directory = Directory(output)..createSync(recursive: true);
            final file = File(
              '${directory.path}/${width.toInt()}-text${scale.toInt()}.json',
            );
            if (file.existsSync()) throw StateError('Metrics already exist');
            await file.writeAsString(jsonEncode(metrics), flush: true);
          });
        }
        for (final metric in metrics) {
          expect(
            metric['did_exceed_max_lines'],
            false,
            reason: '${metric['label']} truncated',
          );
          expect(
            metric['height'] as double,
            greaterThanOrEqualTo((metric['full_height'] as double) - 0.1),
            reason:
                '${metric['label']} full text must fit without hidden line clipping',
          );
        }
        for (final destination in PawMateBottomNav.destinations) {
          final finder = find.bySemanticsLabel(destination.label);
          final rect = tester.getRect(finder);
          expect(navRect.contains(rect.topLeft), isTrue);
          expect(navRect.bottom, greaterThanOrEqualTo(rect.bottom));
          expect(finder.hitTestable(), findsOneWidget);
          await tester.tap(finder);
          await tester.pump();
        }
        expect(
          tapped,
          PawMateBottomNav.destinations.map((d) => d.route).toList(),
        );
        expect(find.byType(FittedBox), findsNothing);
        expectNoFlutterOverflow(tester);
      });
    }
  }
}

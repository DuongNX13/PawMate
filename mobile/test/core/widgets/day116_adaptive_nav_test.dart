import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.2, 1.3, 1.4, 2.0]) {
      for (final inset in [0.0, 34.0]) {
        for (final active in ['/rescue', '/health']) {
          testWidgets(
            'D116 adaptive nav width=$width text=$scale safe=$inset active=$active',
            (tester) async {
              await setTestViewport(tester, size: Size(width, 568));
              tester.view.padding = FakeViewPadding(bottom: inset);
              tester.view.viewPadding = FakeViewPadding(bottom: inset);
              addTearDown(tester.view.resetPadding);
              addTearDown(tester.view.resetViewPadding);
              final semantics = tester.ensureSemantics();
              final tapped = <String>[];
              try {
                await tester.pumpWidget(
                  MaterialApp(
                    theme: AppTheme.light(),
                    builder: testTextScaleBuilder(scale),
                    home: Scaffold(
                      body: const Text('Navigation layout proof'),
                      bottomNavigationBar: PawMateBottomNav(
                        currentRoute: active,
                        onDestinationSelected: tapped.add,
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                if (width == 320 && scale == 1.3 && active == '/rescue') {
                  await captureDay116(
                    tester,
                    'R10-C05-width320-text130-safe${inset.toInt()}',
                  );
                }
                final nav = find.byType(PawMateBottomNav);
                final bounds = tester.getRect(nav);
                expect(bounds.bottom, 568);
                for (final item in PawMateBottomNav.destinations) {
                  final label = find.text(item.label);
                  if (label.evaluate().isNotEmpty) {
                    final paragraph = tester.renderObject<RenderParagraph>(
                      label,
                    );
                    final full = TextPainter(
                      text: paragraph.text,
                      textDirection: paragraph.textDirection,
                      textScaler: paragraph.textScaler,
                    )..layout(maxWidth: paragraph.size.width);
                    expect(
                      paragraph.didExceedMaxLines,
                      isFalse,
                      reason: item.label,
                    );
                    expect(
                      paragraph.size.height,
                      greaterThanOrEqualTo(full.height - .1),
                    );
                    expect(
                      paragraph.textScaler.scale(13),
                      closeTo(13 * scale, .0001),
                    );
                    expect(
                      tester.getRect(label).bottom,
                      lessThanOrEqualTo(568 - inset),
                    );
                    for (final box in paragraph.getBoxesForSelection(
                      TextSelection(
                        baseOffset: 0,
                        extentOffset: item.label.length,
                      ),
                    )) {
                      expect(
                        box.bottom,
                        lessThanOrEqualTo(paragraph.size.height + .1),
                      );
                    }
                    full.dispose();
                  }
                  final node = tester.getSemantics(
                    find.bySemanticsLabel(item.label),
                  );
                  expect(
                    node.flagsCollection.isSelected == ui.Tristate.isTrue,
                    item.isActive(active),
                  );
                  expect(
                    node.getSemanticsData().hasAction(SemanticsAction.tap),
                    isTrue,
                  );
                  final target = tester.getRect(
                    find.bySemanticsLabel(item.label),
                  );
                  expect(target.width, greaterThanOrEqualTo(48));
                  expect(target.height, greaterThanOrEqualTo(48));
                  final icon = tester.widget<ImageIcon>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is ImageIcon &&
                          w.image is AssetImage &&
                          (w.image as AssetImage).assetName == item.iconAsset,
                    ),
                  );
                  expect(
                    icon.color,
                    item.isActive(active)
                        ? AppColors.white
                        : AppColors.navInactiveIcon,
                  );
                  if (label.evaluate().isNotEmpty &&
                      find
                          .byKey(const Key('navigation-selected-caption'))
                          .evaluate()
                          .isEmpty) {
                    expect(
                      tester.widget<Text>(label).style!.color,
                      item.isActive(active)
                          ? AppColors.white
                          : AppColors.navInactiveLabel,
                    );
                  }
                  final control = find.bySemanticsLabel(item.label);
                  expect(control.hitTestable(), findsOneWidget);
                  await tester.tap(control);
                  await tester.pump();
                }
                expect(
                  tapped,
                  PawMateBottomNav.destinations.map((d) => d.route).toList(),
                );
                expect(tester.getRect(nav), bounds);
                expect(find.byType(FittedBox), findsNothing);
                expectNoFlutterOverflow(tester);
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
  testWidgets(
    'D116 adaptive nav routes and height stable across real tab selection',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final router = GoRouter(
        initialLocation: '/rescue',
        routes: PawMateBottomNav.destinations
            .map(
              (d) => GoRoute(
                path: d.route,
                builder: (_, _) => Scaffold(
                  body: Text('target:${d.route}'),
                  bottomNavigationBar: PawMateBottomNav(currentRoute: d.route),
                ),
              ),
            )
            .toList(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: testTextScaleBuilder(1.3),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.getRect(find.byType(PawMateBottomNav));
      for (final item in PawMateBottomNav.destinations) {
        await tester.tap(find.bySemanticsLabel(item.label));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, item.route);
        expect(find.text('target:${item.route}'), findsOneWidget);
        expect(tester.getRect(find.byType(PawMateBottomNav)), original);
      }
      expectNoFlutterOverflow(tester);
    },
  );
}

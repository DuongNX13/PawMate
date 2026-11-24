import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_preview.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

final _firstId = sampleCases().first.caseId;
Finder get _marker => find.byKey(ValueKey('rescue-marker-$_firstId'));
Finder get _card => find.byKey(const Key('rescue-selected-case-card'));

void main() {
  testWidgets('DT-05 all five marker targets are separate and selectable', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final items = [
      ...sampleCases(),
      for (final name in ['Nắng', 'Mây'])
        rescueCase(
          caseId: name,
          petName: name,
          species: RescueSpecies.dog,
          status: RescueCaseStatus.missing,
          areaLabel: 'Khu vực thử nghiệm',
          breedOrColor: 'Poodle',
        ),
    ];
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RescueMapPreview(
              items: items,
              onOpenMap: () {},
              onSelectCase: (item) => selected = item.caseId,
            ),
          ),
        ),
      ),
    );
    final rectangles = <Rect>[];
    for (final item in items) {
      final target = find.byKey(ValueKey('rescue-marker-${item.caseId}'));
      final rect = tester.getRect(target);
      for (final other in rectangles) {
        expect(rect.overlaps(other), isFalse);
      }
      rectangles.add(rect);
      await tester.tap(target);
      await tester.pump();
      expect(selected, item.caseId);
    }
  });
  testWidgets('DT-05 marker selects locally, exposes semantics and closes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final source = FakeRescueSource(pages: [samplePage()]);
    final router = await _pump(tester, source);
    addTearDown(router.dispose);
    expect(_card, findsNothing);
    expect(tester.getSize(_marker), const Size(48, 48));
    expect(
      tester
          .getSemantics(_marker)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(_marker);
    await tester.pumpAndSettle();
    expect(_card, findsOneWidget);
    expect(
      tester.getSemantics(_marker).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(source.detailCaseIds, isEmpty);
    expect(source.callCount, 1);
    // Figma v0.34 DT-05: the card floats over the lower edge of the map but
    // never covers the selected marker (D123-IOS-UI-003).
    expect(
      tester.getRect(_card).top,
      lessThan(
        tester.getRect(find.byKey(const Key('rescue-map-preview'))).bottom,
      ),
    );
    expect(
      tester.getRect(_card).top,
      greaterThan(tester.getRect(_marker).bottom),
    );
    await tester.tap(find.byKey(const Key('rescue-selected-close')));
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
    expect(
      tester.getSemantics(_marker).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    semantics.dispose();
  });

  testWidgets('DT-05 detail and back retain selection, scroll and filter', (
    tester,
  ) async {
    final source = FakeRescueSource(pages: [samplePage()]);
    final router = await _pump(tester, source);
    addTearDown(router.dispose);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RescueHomeScreen)),
    );
    await container
        .read(rescueHomeProvider.notifier)
        .applyFilter(RescueHomeFilter.dogs);
    await tester.pumpAndSettle();
    await tester.tap(_marker);
    await tester.pumpAndSettle();
    final cta = find.byKey(const Key('rescue-selected-details'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('rescue-live-list')),
        matching: find.byType(Scrollable),
      ),
    );
    final offset = scroll.position.pixels;
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-case-detail-screen')), findsOneWidget);
    expect(source.detailCaseIds, [_firstId]);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(_card, findsOneWidget);
    expect(scroll.position.pixels, closeTo(offset, 0.1));
    expect(container.read(rescueHomeProvider).filter, RescueHomeFilter.dogs);
    expect(source.callCount, 2);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('DT-05 deleted detail recovers to selected context', (
    tester,
  ) async {
    final source = FakeRescueSource(
      pages: [samplePage()],
      detailError: const RescueApiException(
        'Tin báo không còn tồn tại.',
        statusCode: 404,
        code: 'RESCUE_CASE_NOT_FOUND',
      ),
    );
    final router = await _pump(tester, source);
    addTearDown(router.dispose);
    await tester.tap(_marker);
    await tester.pumpAndSettle();
    final cta = find.byKey(const Key('rescue-selected-details'));
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-detail-unavailable')), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(_card, findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('DT-05 refresh removes selected case and offers safe recovery', (
    tester,
  ) async {
    final source = FakeRescueSource(pages: [samplePage(), emptyPage()]);
    final router = await _pump(
      tester,
      source,
      size: const Size(320, 568),
      textScale: 2,
    );
    addTearDown(router.dispose);
    await tester.scrollUntilVisible(
      _marker,
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('rescue-live-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(tester.element(_marker), alignment: 0.25);
    await tester.pumpAndSettle();
    await tester.tap(_marker);
    await tester.pumpAndSettle();
    expect(_card, findsOneWidget);
    expect(tester.getRect(find.byType(PawMateBottomNav)).bottom, 568);
    expectNoFlutterOverflow(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RescueHomeScreen)),
    );
    await container.read(rescueHomeProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rescue-selected-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rescue-selected-details')), findsNothing);
    expectNoFlutterOverflow(tester);
  });
}

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeRescueSource source, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await setTestViewport(tester, size: size);
  final router = GoRouter(
    initialLocation: '/rescue',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (_, _) =>
            const RescueHomeScreen(browseEnabled: true, createEnabled: true),
      ),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (_, state) =>
            RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: testTextScaleBuilder(textScale),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  testWidgets('D122-TB-RESCUE-001 toggles through the accessibility action', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      pages: [samplePage(items: _sixCases(), hasMore: true)],
    );
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router: router, source: source, textScale: 2));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('rescue-nearby-toggle'));
    Future<void> activate(String label) async {
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(toggle);
      expect(node.label, label);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'TalkBack must be able to activate the labeled control.',
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
    }

    final semantics = tester.ensureSemantics();
    try {
      expect(find.text('Bông'), findsNothing);
      await activate('Mở rộng 5 ca gần nhất');
      expect(find.text('Mây'), findsOneWidget);
      expect(find.text('Sáo'), findsNothing);
      await activate('Thu gọn danh sách ca gần nhất');
      expect(find.text('Bông'), findsNothing);
      expect(source.callCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'DT-04 expands at most five nearby cases and collapses in place',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = FakeRescueSource(
        pages: [samplePage(items: _sixCases(), hasMore: true)],
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router: router, source: source));
      await tester.pumpAndSettle();

      expect(find.text('LuLu'), findsOneWidget);
      expect(find.text('Mực'), findsOneWidget);
      expect(find.text('Bông'), findsNothing);
      expect(find.text('Sáo'), findsNothing);
      expect(source.callCount, 1);

      final toggle = find.byKey(const Key('rescue-load-more'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      for (final name in const ['LuLu', 'Mực', 'Bông', 'Nắng', 'Mây']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Sáo'), findsNothing);
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(
        source.callCount,
        1,
        reason: 'Expand is local UI state, not paging.',
      );

      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Bông'), findsNothing);
      expect(find.text('Xem thêm'), findsOneWidget);
      expect(source.callCount, 1);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'DT-04 320x568 text 2 keeps map useful, nav fixed and disables motion',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final source = FakeRescueSource(
        pages: [samplePage(items: _sixCases(), hasMore: true)],
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _app(
          router: router,
          source: source,
          textScale: 2,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      final map = find.byKey(const Key('rescue-map-preview'));
      await tester.scrollUntilVisible(
        map,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('rescue-live-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.getSize(map).height, greaterThanOrEqualTo(208));

      final toggle = find.byKey(const Key('rescue-load-more'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();

      final motionRegion = find.byKey(const Key('rescue-nearby-animated-size'));
      expect(
        find.descendant(of: motionRegion, matching: find.byType(AnimatedSize)),
        findsNothing,
      );
      expect(find.text('Mây'), findsOneWidget);
      expect(find.text('Sáo'), findsNothing);

      final navRect = tester.getRect(find.byType(PawMateBottomNav));
      expect(navRect.bottom, closeTo(568, 0.01));
      expect(navRect.left, closeTo(0, 0.01));
      expect(navRect.right, closeTo(320, 0.01));
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('DT-04 restores expanded state after app restoration', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      pages: [samplePage(items: _sixCases(), hasMore: true)],
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router: router, source: source));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('rescue-load-more'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Mây'), findsOneWidget);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();
    expect(find.text('Mây'), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

Widget _app({
  required GoRouter router,
  required RescueCaseSource source,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: [
      rescueApiProvider.overrideWithValue(source),
      rescueClockProvider.overrideWithValue(fixedRescueClock()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'day100-app',
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          accessibleNavigation: disableAnimations,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/rescue',
    restorationScopeId: 'day100-router',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (context, state) =>
            const RescueHomeScreen(browseEnabled: true, createEnabled: true),
      ),
      for (final path in const [
        '/pets',
        '/vets/map',
        '/health',
        '/profile',
        '/profile/controls',
        '/notifications',
        '/rescue/map',
        '/rescue/create',
      ])
        GoRoute(path: path, builder: (context, state) => const Scaffold()),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (context, state) => const Scaffold(),
      ),
    ],
  );
}

List<RescueCaseSummary> _sixCases() {
  final original = sampleCases();
  return [
    ...original,
    rescueCase(
      caseId: '44444444-4444-4444-8444-444444444444',
      petName: 'Nắng',
      species: RescueSpecies.dog,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 1',
      breedOrColor: 'Corgi',
    ),
    rescueCase(
      caseId: '55555555-5555-4555-8555-555555555555',
      petName: 'Mây',
      species: RescueSpecies.cat,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 5',
      breedOrColor: 'Mèo Anh lông ngắn',
    ),
    rescueCase(
      caseId: '66666666-6666-4666-8666-666666666666',
      petName: 'Sáo',
      species: RescueSpecies.dog,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 7',
      breedOrColor: 'Poodle',
    ),
  ];
}

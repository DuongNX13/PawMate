import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  testWidgets('browse-enabled home renders real cases and privacy-safe map', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      pages: [samplePage(items: _withoutImages(sampleCases()))],
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cứu hộ'), findsOneWidget);
    expect(find.text('5 ca gần nhất'), findsOneWidget);
    expect(find.text('LuLu'), findsOneWidget);
    expect(find.text('Chưa thấy'), findsWidgets);
    expect(find.text('Đã thấy'), findsOneWidget);
    expect(find.text('CẬP NHẬT VỪA XONG'), findsOneWidget);
    expect(find.textContaining('2 giờ trước'), findsNWidgets(3));
    expect(find.text('Báo thấy'), findsNothing);
    expect(find.byKey(const Key('rescue-map-preview')), findsOneWidget);
    expect(find.textContaining('10.8'), findsNothing);
    expect(source.callCount, 1);
    expect(source.queries.single.limit, 5);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'filter sheet resets query and keeps the selected state visible',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = FakeRescueSource(
        pages: [
          samplePage(items: _withoutImages(sampleCases())),
          samplePage(items: _withoutImages([sampleCases()[1]])),
        ],
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_liveApp(router, source));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rescue-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rescue-filter-cats')));
      await tester.pumpAndSettle();

      expect(source.queries.last.species, RescueSpecies.cat);
      expect(source.queries.last.cursor, isNull);
      expect(find.text('Mực'), findsOneWidget);
      expect(find.text('LuLu'), findsNothing);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('error state offers retry without creating fixture data', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _ErrorSource();
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_liveApp(router, source));
    await tester.pumpAndSettle();

    expect(find.text('Chưa tải được ca cứu hộ'), findsOneWidget);
    expect(find.text('LuLu'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('live home remains readable at 360 and text scale 1.3', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final source = FakeRescueSource(
      pages: [samplePage(items: _withoutImages(sampleCases()))],
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(source),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cứu hộ'), findsOneWidget);
    expect(find.byKey(const Key('rescue-refresh')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

Widget _liveApp(GoRouter router, RescueCaseSource source) {
  return ProviderScope(
    overrides: [
      rescueApiProvider.overrideWithValue(source),
      rescueClockProvider.overrideWithValue(fixedRescueClock()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/rescue',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (context, state) =>
            const RescueHomeScreen(browseEnabled: true),
      ),
      for (final path in const [
        '/pets',
        '/vets/map',
        '/health',
        '/profile',
        '/profile/controls',
        '/notifications',
        '/rescue/map',
      ])
        GoRoute(
          path: path,
          builder: (context, state) =>
              Scaffold(body: Center(child: Text('Target $path'))),
        ),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (context, state) =>
            Scaffold(body: Text('Case ${state.pathParameters['caseId']}')),
      ),
    ],
  );
}

List<RescueCaseSummary> _withoutImages(List<RescueCaseSummary> items) => items
    .map(
      (item) => RescueCaseSummary(
        caseId: item.caseId,
        petName: item.petName,
        species: item.species,
        status: item.status,
        lostAt: item.lostAt,
        publicLocation: item.publicLocation,
        media: const [],
        commentCount: item.commentCount,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        breedOrColor: item.breedOrColor,
        ageLabel: item.ageLabel,
        distanceMeters: item.distanceMeters,
      ),
    )
    .toList(growable: false);

class _ErrorSource implements RescueCaseSource {
  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) {
    throw const RescueApiException('Máy chủ đang tạm thời không phản hồi.');
  }
}

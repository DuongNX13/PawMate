import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_skeleton.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day116_capture.dart';
import 'rescue_test_fixtures.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 R9 ST-03 P2-01 bounded loading viewport text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      // Capture uses real font metrics. Establish the same metrics before
      // measuring navigation, rather than comparing Ahem with Be Vietnam Pro.
      await tester.runAsync(loadPawMateTestFonts);
      final pending = Completer<RescueCasePage>();
      final source = _ControlledHomeSource(pending: pending);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_liveApp(router, source, textScale: scale));
      await tester.pump(const Duration(milliseconds: 50));
      expect(source.calls, 1);
      // A lazy child may not exist yet. Move the actual list viewport in
      // bounded increments; never resolve `.first` on an unbuilt child.
      final list = find.byKey(const Key('rescue-live-list'));
      for (
        var n = 0;
        n < 12 && find.byType(PawMateSkeleton).hitTestable().evaluate().isEmpty;
        n++
      ) {
        await tester.drag(list, const Offset(0, -100));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(PawMateSkeleton).hitTestable(), findsWidgets);
      expect(find.text('LuLu'), findsNothing);
      final nav = tester.getRect(find.byType(PawMateBottomNav));
      await captureDay116(
        tester,
        'R9-ST03-P201-text${scale.toString().replaceAll('.', '-')}',
      );
      // Font precaching can change the lazy viewport. Re-establish visibility
      // before asserting the after-capture checkpoint.
      for (
        var n = 0;
        n < 12 && find.byType(PawMateSkeleton).hitTestable().evaluate().isEmpty;
        n++
      ) {
        await tester.drag(list, const Offset(0, -100));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(PawMateSkeleton).hitTestable(), findsWidgets);
      pending.complete(samplePage(items: _withoutImages(sampleCases())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('LuLu'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('LuLu'), findsOneWidget);
      expect(find.byType(PawMateSkeleton), findsNothing);
      expect(source.calls, 1);
      expect(tester.getRect(find.byType(PawMateBottomNav)), nav);
      expectNoFlutterOverflow(tester);
    });
  }
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final state in ['ST-01', 'ST-02']) {
      testWidgets('D116 $state P2-01 actual retry text$scale', (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _ControlledHomeSource(
          failure: RescueApiException(
            state == 'ST-01'
                ? 'Không thể kết nối tới máy chủ PawMate.'
                : 'Máy chủ đang tạm thời không phản hồi.',
            code: state == 'ST-01' ? 'NETWORK_OFFLINE' : 'SERVER_UNAVAILABLE',
            statusCode: state == 'ST-01' ? null : 503,
          ),
        );
        final router = _router();
        addTearDown(router.dispose);
        await tester.pumpWidget(_liveApp(router, source, textScale: scale));
        await tester.pumpAndSettle();
        expect(source.calls, 1);
        expect(find.text('LuLu'), findsNothing);
        final retry = find.widgetWithText(PawMateButton, 'Thử lại');
        await tester.scrollUntilVisible(
          retry,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Chưa tải được ca cứu hộ'), findsOneWidget);
        expect(retry.hitTestable(), findsOneWidget);
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
        final navBefore = tester.getRect(find.byType(PawMateBottomNav));
        await captureDay116(
          tester,
          'D116-${state.replaceAll('-', '')}-P201-text${scale.toString().replaceAll('.', '-')}',
        );
        source.failure = null;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(source.calls, 2);
        expect(source.queries[1].species, source.queries[0].species);
        expect(source.queries[1].status, source.queries[0].status);
        final pet = find.text('LuLu');
        await tester.scrollUntilVisible(
          pet,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(pet, findsOneWidget);
        expect(find.text('Chưa tải được ca cứu hộ'), findsNothing);
        expect(tester.getRect(find.byType(PawMateBottomNav)), navBefore);
        expectNoFlutterOverflow(tester);
      });
    }
  }
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
    expect(find.text('Đã thấy'), findsNothing);
    expect(find.text('CẬP NHẬT VỪA XONG'), findsOneWidget);
    expect(find.textContaining('2 giờ trước'), findsNWidgets(2));
    expect(find.text('Báo thấy'), findsNothing);
    expect(find.byKey(const Key('rescue-map-preview')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('rescue-map-preview'))).height,
      greaterThanOrEqualTo(240),
      reason: 'The approved Rescue anchor keeps the map as the visual stage.',
    );
    expect(
      tester.getSize(find.byKey(const Key('rescue-create-entry'))).height,
      lessThanOrEqualTo(80),
      reason: 'Báo mất must stay compact so it does not displace the map.',
    );
    final loadMore = find.byKey(const Key('rescue-load-more'));
    expect(find.text('Bông'), findsNothing);
    expect(loadMore, findsOneWidget);
    await tester.drag(
      find.byKey(const Key('rescue-live-list')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    expect(find.text('Bông'), findsOneWidget);
    expect(find.text('Đã thấy'), findsOneWidget);
    expect(find.textContaining('2 giờ trước'), findsNWidgets(3));
    expect(find.text('Thu gọn'), findsOneWidget);
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

  testWidgets('live home remains readable at 360 and text scale 2.0', (
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
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
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

  testWidgets('live home remains scrollable at 320x568 and text scale 2.0', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final source = FakeRescueSource(
      pages: [samplePage(items: _withoutImages(sampleCases()))],
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
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

    final mapPreview = find.byKey(const Key('rescue-map-preview'));
    await tester.scrollUntilVisible(
      mapPreview,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(mapPreview, findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'live home keeps long rescue-case data readable at text scale 2.0',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      const petName = 'Bông Tuyết Golden Retriever Siêu Dễ Thương 2026';
      const breed = 'Golden Retriever lai lông dài màu kem đậm';
      const area = 'Phường 13, Quận Tân Bình, Thành phố Hồ Chí Minh';
      final source = FakeRescueSource(
        pages: [
          samplePage(
            items: _withoutImages([
              rescueCase(
                caseId: '44444444-4444-4444-8444-444444444444',
                petName: petName,
                species: RescueSpecies.dog,
                status: RescueCaseStatus.missing,
                areaLabel: area,
                breedOrColor: breed,
              ),
            ]),
          ),
        ],
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
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

      await tester.scrollUntilVisible(
        find.byKey(
          const Key('rescue-case-44444444-4444-4444-8444-444444444444'),
        ),
        280,
        scrollable: find.descendant(
          of: find.byKey(const Key('rescue-live-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        petName,
        breed,
        '$area · 2 giờ trước',
        'CẬP NHẬT VỪA XONG',
        'Chưa thấy',
      ]) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
          reason: 'Visible rescue-case data must remain readable: $label',
        );
      }
      expectNoFlutterOverflow(tester);
    },
  );
}

Widget _liveApp(
  GoRouter router,
  RescueCaseSource source, {
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      rescueApiProvider.overrideWithValue(source),
      rescueClockProvider.overrideWithValue(fixedRescueClock()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: testTextScaleBuilder(textScale),
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
  Future<RescueCaseDetail> getCase(String caseId) {
    throw const RescueApiException('Máy chủ đang tạm thời không phản hồi.');
  }

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) {
    throw const RescueApiException('Máy chủ đang tạm thời không phản hồi.');
  }
}

class _ControlledHomeSource implements RescueCaseSource {
  _ControlledHomeSource({this.failure, this.pending});
  RescueApiException? failure;
  final Completer<RescueCasePage>? pending;
  final queries = <RescueCaseQuery>[];
  int calls = 0;

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    calls++;
    queries.add(query);
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return samplePage(items: _withoutImages(sampleCases()));
  }

  @override
  Future<RescueCaseDetail> getCase(String caseId) async =>
      throw StateError('Unexpected detail request in Home-only proof');
}

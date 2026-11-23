import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_share_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_actions.dart';
import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R23 UX-25 DT-07 text$scale deleted clinic in review pagination returns to real list',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _DeletedReviewVetApi();
        final router = _router('/vets/pawmate-q1?returnTo=/vets/list');
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [vetApiProvider.overrideWithValue(source)],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final open = find.byKey(const Key('review-list-open-button'));
        await tester.scrollUntilVisible(
          open,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(open.hitTestable(), findsOneWidget);
        await tester.tap(open);
        await tester.pumpAndSettle();
        final more = find.byKey(const Key('review-load-more-button'));
        await tester.scrollUntilVisible(
          more,
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('review-list-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(more.hitTestable(), findsOneWidget);
        source.deleted = true;
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(source.moreCalls, 1);
        final missing = find.byKey(const Key('review-list-unavailable'));
        expect(missing, findsOneWidget);
        final heading = find.text('Phòng khám không còn khả dụng');
        final stateScroll = find.descendant(
          of: missing,
          matching: find.byType(Scrollable),
        );
        final statePosition = tester
            .state<ScrollableState>(stateScroll)
            .position;
        statePosition.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(heading).top,
          greaterThanOrEqualTo(tester.getRect(missing).top),
        );
        expect(heading.hitTestable(), findsOneWidget);
        await captureDay116(
          tester,
          'R23-UX25-DT07-heading-text${scale.toString().replaceAll('.', '-')}',
        );
        expect(
          find.byKey(const Key('review-list-item-review-1')),
          findsNothing,
        );
        expect(more, findsNothing);
        final back = find.text('Về danh sách phòng khám');
        await tester.scrollUntilVisible(
          back,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(back.hitTestable(), findsOneWidget);
        await captureDay116(
          tester,
          'R23-UX25-DT07-missing-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(VetListScreen), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/vets/list',
        );
        expect(source.moreCalls, 1);
        await captureDay116(
          tester,
          'R23-UX25-DT07-safe-text${scale.toString().replaceAll('.', '-')}',
        );
        expectNoFlutterOverflow(tester);
      },
    );
  }
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 R22 ST-23 P1-10 directions failure retry text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final requests = <String>[];
      var available = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'launch');
        requests.add((call.arguments as Map)['url'] as String);
        return available;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final source = _FakeVetApi();
      final vet = await source.getDetail('pawmate-q1');
      final router = _router('/vets/pawmate-q1?returnTo=/vets/list');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [vetApiProvider.overrideWith((_) => source)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final directions = find.text('Chỉ đường');
      await tester.scrollUntilVisible(
        directions,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(directions.hitTestable(), findsOneWidget);
      await tester.tap(directions);
      await tester.pumpAndSettle();
      expect(
        requests,
        buildVetDirectionCandidates(vet).map((u) => u.toString()).toList(),
      );
      expect(find.text('Không thể mở chỉ đường từ PawMate.'), findsOneWidget);
      expect(find.byType(VetDetailScreen), findsOneWidget);
      await captureDay116(
        tester,
        'R22-ST23-P110-error-text${scale.toString().replaceAll('.', '-')}',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      available = true;
      await tester.tap(directions);
      await tester.pumpAndSettle();
      expect(requests.length, buildVetDirectionCandidates(vet).length + 1);
      expect(requests.last, buildVetDirectionCandidates(vet).first.toString());
      expect(find.text('Không thể mở chỉ đường từ PawMate.'), findsNothing);
      expect(find.byType(VetDetailScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/vets/pawmate-q1',
      );
      await captureDay116(
        tester,
        'R22-ST23-P110-retry-text${scale.toString().replaceAll('.', '-')}',
      );
      expectNoFlutterOverflow(tester);
    });
  }
  testWidgets('Vet Detail back returns to the source Map route', (
    tester,
  ) async {
    final router = _router('/vets/pawmate-q1?returnTo=/vets/map');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => _FakeVetApi())],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/vets/map');
  });

  testWidgets('Vet Detail back returns to the source List route', (
    tester,
  ) async {
    final router = _router('/vets/pawmate-q1?returnTo=/vets/list');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => _FakeVetApi())],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/vets/list');
  });

  testWidgets('Vet Detail share action opens the native share contract', (
    tester,
  ) async {
    final shareSource = _RecordingVetShareSource();
    final router = _router('/vets/pawmate-q1?returnTo=/vets/list');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi()),
          vetShareSourceProvider.overrideWithValue(shareSource),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chia sẻ'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(shareSource.calls, 1);
    expect(shareSource.lastVet?.name, 'PawMate Q1');
    expect(shareSource.lastVet?.address, '120 Nguyễn Huệ');
    expect(shareSource.lastOrigin, isNotNull);
  });
}

class _RecordingVetShareSource implements VetShareSource {
  int calls = 0;
  VetDetail? lastVet;
  Rect? lastOrigin;

  @override
  Future<void> shareVet(
    VetDetail vet, {
    required Rect sharePositionOrigin,
  }) async {
    calls += 1;
    lastVet = vet;
    lastOrigin = sharePositionOrigin;
  }
}

GoRouter _router(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/vets/map',
        builder: (context, state) => const VetMapScreen(),
      ),
      GoRoute(
        path: '/vets/list',
        builder: (context, state) => const VetListScreen(),
      ),
      GoRoute(
        path: '/vets/:id',
        builder: (context, state) => VetDetailScreen(
          vetId: state.pathParameters['id'] ?? 'unknown-vet',
          returnPath: state.uri.queryParameters['returnTo'] ?? '/vets/list',
        ),
      ),
    ],
  );
}

class _DeletedReviewVetApi extends _FakeVetApi {
  bool deleted = false;
  int moreCalls = 0;
  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async {
    if (request.cursor != null) {
      moreCalls++;
      expect(request.cursor, 'next-page');
      if (deleted) {
        throw const VetApiException('Phòng khám đã được gỡ.', statusCode: 404);
      }
    }
    return const VetReviewResult(
      items: [
        VetReview(
          id: 'review-1',
          vetId: 'pawmate-q1',
          rating: 5,
          body: 'Phòng khám thân thiện.',
          photoUrls: [],
          isAnonymous: false,
          isVerifiedVisit: false,
          helpfulCount: 0,
          reportCount: 0,
          status: 'visible',
          sentiment: 'UNPROCESSED',
          isFlagged: false,
          reviewer: VetReviewer(
            id: 'fixture-reviewer',
            displayName: 'Chủ nuôi',
          ),
          createdAt: '2026-10-19T02:00:00Z',
          updatedAt: '2026-10-19T02:00:00Z',
        ),
      ],
      summary: VetReviewSummary(
        averageRating: 5,
        reviewCount: 2,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 2},
      ),
      total: 2,
      limit: 1,
      nextCursor: 'next-page',
    );
  }

  @override
  Future<VetSearchResult> search(VetSearchRequest request) async =>
      const VetSearchResult(items: [], total: 0, limit: 20);
}

class _FakeVetApi extends VetApi {
  _FakeVetApi() : super(Dio());

  @override
  Future<VetDetail> getDetail(String vetId) async {
    return const VetDetail(
      id: 'pawmate-q1',
      name: 'PawMate Q1',
      city: 'TP Hồ Chí Minh',
      district: 'Quận 1',
      address: '120 Nguyễn Huệ',
      phone: '0903 111 222',
      services: ['Khám tổng quát'],
      seedRank: 1,
      averageRating: 4.8,
      reviewCount: 12,
      is24h: true,
      isOpen: true,
      readyForMap: true,
      latitude: 10.778,
      longitude: 106.701,
      openHours: ['Mở cửa 24/7'],
      photoUrls: [],
      source: VetSource(
        url: 'https://pawmate.test',
        list: 'test',
        priorityTier: 'P0',
        enrichmentStatus: 'verified',
        selectionReason: 'test',
      ),
    );
  }

  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async {
    return const VetReviewResult(
      items: [],
      summary: VetReviewSummary(
        averageRating: null,
        reviewCount: 0,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      ),
      total: 0,
      limit: 20,
    );
  }
}

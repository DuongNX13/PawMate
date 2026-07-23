import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

void main() {
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

  testWidgets('Vet Detail share action copies real clinic details', (
    tester,
  ) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
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

    await tester.tap(find.byTooltip('Chia sẻ'));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('PawMate Q1'));
    expect(clipboardText, contains('120 Nguyễn Huệ'));
    expect(clipboardText, contains('0903 111 222'));
    expect(
      find.text('Đã sao chép thông tin phòng khám để chia sẻ.'),
      findsOneWidget,
    );
  });
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

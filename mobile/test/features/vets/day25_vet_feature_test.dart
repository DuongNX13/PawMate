import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

import '../../test_support/ui_test_helpers.dart';

const _vet = VetSummary(
  id: 'day25-vet',
  name: 'PetCare Elite',
  city: 'TP Hồ Chí Minh',
  district: 'Quận 1',
  address: '120 Nguyễn Huệ',
  phone: '0903 111 222',
  summary: 'Cấp cứu 24/7 và tiêm phòng định kỳ.',
  services: ['Cấp cứu 24/7', 'Tiêm phòng'],
  seedRank: 1,
  averageRating: 4.8,
  reviewCount: 12,
  is24h: true,
  isOpen: true,
  readyForMap: true,
  latitude: 10.778,
  longitude: 106.701,
  distanceMeters: 1200,
);

const _detail = VetDetail(
  id: 'day25-vet',
  name: 'PetCare Elite',
  city: 'TP Hồ Chí Minh',
  district: 'Quận 1',
  address: '120 Nguyễn Huệ',
  phone: '0903 111 222',
  summary: 'Cấp cứu 24/7 và tiêm phòng định kỳ.',
  services: ['Cấp cứu 24/7', 'Tiêm phòng'],
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
    list: 'Day25 fixture',
    priorityTier: 'P0',
    enrichmentStatus: 'verified',
    selectionReason: 'feature-journey',
  ),
);

void main() {
  testWidgets(
    'Day25 completes Map -> Detail -> Review and preserves source back state',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final fakeApi = _FakeVetApi();
      final router = _router('/vets/map');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vetApiProvider.overrideWith((ref) => fakeApi),
            vetReviewAccessTokenProvider.overrideWith((ref) async => 'token'),
            vetLocationServiceProvider.overrideWith(
              (ref) => _FakeLocationService(),
            ),
            vetMapCanvasBuilderProvider.overrideWith(
              (ref) =>
                  (
                    VetMapLocation center,
                    List<VetSummary> items,
                    VetMapStyle style,
                    ValueChanged<String> onMarkerTap,
                    ValueChanged<Object> onMapUnavailable,
                  ) => Semantics(
                    button: true,
                    label: 'Mở ${_vet.name}',
                    child: GestureDetector(
                      onTap: () => onMarkerTap(_vet.vetId),
                      child: const SizedBox(
                        width: 120,
                        height: 120,
                        child: Icon(Icons.local_hospital_rounded),
                      ),
                    ),
                  ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VetMapScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Mở ${_vet.name}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết'));
      await tester.pumpAndSettle();

      expect(find.byType(VetDetailScreen), findsOneWidget);
      expect(find.text('Gọi ngay'), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);

      final reviewButton = find.byKey(
        const Key('vet-detail-write-review-button'),
      );
      await tester.scrollUntilVisible(
        reviewButton,
        520,
        maxScrolls: 30,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(reviewButton);
      await tester.pumpAndSettle();
      if (tester.getRect(reviewButton).bottom > 720) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -380));
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(reviewButton).bottom, lessThanOrEqualTo(720));
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('write-review-star-5')));
      await tester.enterText(
        find.byKey(const Key('write-review-body-field')),
        'Bác sĩ tư vấn rất kỹ và theo dõi sau tiêm.',
      );
      await tester.tap(find.byKey(const Key('write-review-submit')));
      await tester.pumpAndSettle();

      expect(fakeApi.createdReview, isTrue);
      expect(find.text('Đánh giá đã được gửi thành công.'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/vets/map');

      router.go('/vets/list');
      await tester.pumpAndSettle();
      expect(find.byType(VetListScreen), findsOneWidget);
      expect(find.text(_vet.name), findsOneWidget);
    },
  );

  testWidgets(
    'Day25 keeps permission and map-unavailable fallbacks recoverable',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final fakeApi = _FakeVetApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vetApiProvider.overrideWith((ref) => fakeApi),
            vetLocationServiceProvider.overrideWith(
              (ref) => _DeniedLocationService(),
            ),
            vetMapCanvasBuilderProvider.overrideWith(
              (ref) =>
                  (
                    VetMapLocation center,
                    List<VetSummary> items,
                    VetMapStyle style,
                    ValueChanged<String> onMarkerTap,
                    ValueChanged<Object> onMapUnavailable,
                  ) => const ColoredBox(color: Colors.white),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const VetMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
      expect(find.text('Xem dạng danh sách'), findsOneWidget);
    },
  );
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

  bool createdReview = false;

  @override
  Future<VetNearbyResult> nearby(VetNearbyRequest request) async {
    return const VetNearbyResult(items: [_vet], total: 1, limit: 20);
  }

  @override
  Future<VetSearchResult> search(VetSearchRequest request) async {
    return const VetSearchResult(items: [_vet], total: 1, limit: 20);
  }

  @override
  Future<VetDetail> getDetail(String vetId) async => _detail;

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

  @override
  Future<VetReview> createReview(
    String vetId,
    CreateVetReviewInput input, {
    required String accessToken,
  }) async {
    createdReview = true;
    return const VetReview(
      id: 'created-review',
      vetId: 'day25-vet',
      rating: 5,
      photoUrls: [],
      isAnonymous: false,
      isVerifiedVisit: false,
      helpfulCount: 0,
      reportCount: 0,
      status: 'visible',
      sentiment: 'UNPROCESSED',
      isFlagged: false,
      reviewer: VetReviewer(id: 'tester', displayName: 'Tester'),
      createdAt: '2026-07-16T00:00:00.000Z',
      updatedAt: '2026-07-16T00:00:00.000Z',
    );
  }
}

class _FakeLocationService implements VetLocationService {
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    return const VetMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

class _DeniedLocationService implements VetLocationService {
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    throw const VetLocationException(
      VetLocationFailureType.permissionDenied,
      'Location permission was denied for the Day25 fallback fixture.',
    );
  }
}

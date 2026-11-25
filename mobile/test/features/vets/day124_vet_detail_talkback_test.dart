import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import '../../test_support/ui_test_helpers.dart';

// D122-TB-P2-003: TalkBack swipe could not reach "Xem danh sách đánh giá".
// Everything below the hero was one ListView item, several screens tall, so
// TalkBack's auto-scroll had no next item to bring in. Each section must be
// its own list item that fits within one viewport.
void main() {
  setUpAll(loadPawMateTestFonts);
  testWidgets('D124 TB-003 review list button sits in its own list item', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWithValue(_Day124VetApi())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const VetDetailScreen(
            vetId: 'pawmate-q1',
            returnPath: '/vets/list',
          ),
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
    final item = find
        .ancestor(of: open, matching: find.byType(IndexedSemantics))
        .first;
    final viewportHeight = tester.getSize(find.byType(Scrollable).first).height;
    expect(tester.getSize(item).height, lessThanOrEqualTo(viewportHeight));
  });
}

class _Day124VetApi extends VetApi {
  _Day124VetApi() : super(Dio());

  @override
  Future<VetDetail> getDetail(String vetId) async => const VetDetail(
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

  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async => const VetReviewResult(
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

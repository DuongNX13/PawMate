import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day24-vet-detail-review-golden-root');
const _detailExtraViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];
const _reviewExtraViewports = <Size>[Size(360, 844), Size(430, 932)];

const _detail = VetDetail(
  id: 'pawmate-q1',
  name: 'Phòng khám Thú y PawMate Quận 1',
  city: 'TP Hồ Chí Minh',
  district: 'Quận 1',
  address: '120 Nguyễn Huệ',
  phone: '0903 111 222',
  summary: 'Cấp cứu 24/7 và chăm sóc định kỳ cho thú cưng.',
  services: ['Khám tổng quát', 'Tiêm phòng', 'Cấp cứu 24/7'],
  seedRank: 1,
  averageRating: 4.8,
  reviewCount: 120,
  is24h: true,
  isOpen: true,
  readyForMap: true,
  latitude: 10.778,
  longitude: 106.701,
  website: 'https://pawmate.test/vets/pawmate-q1',
  openHours: ['Mở cửa 24/7'],
  photoUrls: [],
  source: VetSource(
    url: 'https://pawmate.test',
    list: 'PawMate seeded clinic',
    priorityTier: 'P0',
    enrichmentStatus: 'verified',
    selectionReason: 'golden-fixture',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-10 Vet Detail golden at 390x844', (tester) async {
    await _pumpDetail(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.bySemanticsLabel('Gọi ngay')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.bySemanticsLabel('Chỉ đường')).height,
      greaterThanOrEqualTo(48),
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day24/p1-10-vet-detail-390x844.png'),
    );
  });

  testWidgets('P1-11 Write Review sheet golden at 390x844', (tester) async {
    await _pumpReviewSheet(tester, const Size(390, 844));
    expect(find.text('Viết đánh giá'), findsWidgets);
    expect(
      tester.getSize(find.byKey(const Key('write-review-star-5'))).height,
      greaterThanOrEqualTo(48),
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day24/p1-11-write-review-390x844.png'),
    );
  });

  for (final viewport in _detailExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-10 Vet Detail responsive golden at $tag', (tester) async {
      await _pumpDetail(tester, viewport: viewport);
      await tester.pump(const Duration(milliseconds: 100));
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day24/p1-10-vet-detail-$tag.png'),
      );
    });
  }

  for (final viewport in _reviewExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-11 Write Review responsive golden at $tag', (tester) async {
      await _pumpReviewSheet(tester, viewport);
      expect(find.text('Viết đánh giá'), findsWidgets);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day24/p1-11-write-review-$tag.png'),
      );
    });
  }
}

Future<void> _pumpReviewSheet(WidgetTester tester, Size viewport) async {
  await _pumpDetail(tester, viewport: viewport);
  final reviewButton = find.byKey(const Key('vet-detail-write-review-button'));
  await tester.scrollUntilVisible(
    reviewButton,
    520,
    maxScrolls: 20,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(reviewButton);
  await tester.pumpAndSettle();
  final safeTapBottom = viewport.height - 124;
  if (tester.getRect(reviewButton).bottom > safeTapBottom) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(tester.getRect(reviewButton).bottom, lessThanOrEqualTo(safeTapBottom));
  await tester.tap(reviewButton);
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  Size viewport = const Size(390, 844),
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [vetApiProvider.overrideWith((ref) => _FakeVetApi())],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const VetDetailScreen(vetId: 'pawmate-q1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeVetApi extends VetApi {
  _FakeVetApi() : super(Dio());

  @override
  Future<VetDetail> getDetail(String vetId) async => _detail;

  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async {
    return VetReviewResult(
      items: const [
        VetReview(
          id: 'review-1',
          vetId: 'pawmate-q1',
          rating: 5,
          title: 'Theo dõi rất kỹ',
          body: 'Bác sĩ tư vấn rõ và chăm sóc sau tiêm rất tốt.',
          photoUrls: [],
          isAnonymous: false,
          isVerifiedVisit: true,
          helpfulCount: 12,
          reportCount: 0,
          status: 'visible',
          sentiment: 'POSITIVE',
          isFlagged: false,
          reviewer: VetReviewer(id: 'reviewer-1', displayName: 'Nguyễn An'),
          createdAt: '2026-07-10T10:00:00.000Z',
          updatedAt: '2026-07-10T10:00:00.000Z',
        ),
      ],
      summary: const VetReviewSummary(
        averageRating: 4.8,
        reviewCount: 120,
        distribution: {1: 1, 2: 2, 3: 5, 4: 22, 5: 90},
      ),
      total: 1,
      limit: request.limit,
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';

void main() {
  testWidgets('renders backend-backed vet list result', (tester) async {
    final fakeApi = _FakeVetApi(
      searchHandler: (_) async => const VetSearchResult(
        items: [
          VetSummary(
            id: 'petcare-elite',
            name: 'PetCare Elite',
            city: 'Hà Nội',
            district: 'Quận 1',
            address: '128 Nguyễn Huệ',
            phone: '0903 111 222',
            summary: 'Cấp cứu 24/7 và tiêm phòng định kỳ.',
            services: ['Cấp cứu 24/7', 'Tiêm phòng'],
            seedRank: 1,
            averageRating: 4.9,
            reviewCount: 124,
            is24h: true,
            isOpen: true,
            readyForMap: false,
          ),
        ],
        total: 1,
        limit: 20,
      ),
      detailHandler: (_) async => throw UnimplementedError(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => fakeApi)],
        child: const MaterialApp(home: VetListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Chăm sóc tốt nhất\ncho thú cưng của bạn.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('PetCare Elite'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('PetCare Elite'), findsOneWidget);
    expect(find.text('★ 4.9'), findsOneWidget);
    expect(find.text('Tiêm phòng'), findsOneWidget);
    expect(find.text('(124 đánh giá)'), findsOneWidget);
    expect(find.text('Hà Nội • Quận 1'), findsOneWidget);
  });

  testWidgets('renders empty state when search has no results', (tester) async {
    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          const VetSearchResult(items: [], total: 0, limit: 20),
      detailHandler: (_) async => throw UnimplementedError(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => fakeApi)],
        child: const MaterialApp(home: VetListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Chưa có phòng khám phù hợp'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa có phòng khám phù hợp'), findsOneWidget);
    expect(
      find.textContaining('Thử đổi từ khóa', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders error state when search request fails', (tester) async {
    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          throw const VetApiException('Vet list failed'),
      detailHandler: (_) async => throw UnimplementedError(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => fakeApi)],
        child: const MaterialApp(home: VetListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Vet list failed'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Vet list failed'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('renders vet detail with fallback opening note', (tester) async {
    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          const VetSearchResult(items: [], total: 0, limit: 20),
      detailHandler: (_) async => _sampleVetDetail(),
      reviewHandler: (_) async =>
          _reviewResult(items: [_sampleReview(helpfulCount: 2)]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => fakeApi)],
        child: const MaterialApp(home: VetDetailScreen(vetId: 'mochi-vet')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Đánh giá gần đây'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đánh giá gần đây'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Danh sách kiểm duyệt PawMate'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Danh sách kiểm duyệt PawMate'), findsOneWidget);
  });

  testWidgets('submits write review with auth token after rating validation', (
    tester,
  ) async {
    CreateVetReviewInput? submittedInput;
    String? submittedVetId;
    String? submittedAccessToken;

    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          const VetSearchResult(items: [], total: 0, limit: 20),
      detailHandler: (_) async => _sampleVetDetail(),
      reviewHandler: (_) async => _reviewResult(),
      createReviewHandler: (vetId, input, accessToken) async {
        submittedVetId = vetId;
        submittedInput = input;
        submittedAccessToken = accessToken;
        return _sampleReview(id: 'created-review', rating: input.rating);
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => fakeApi),
          vetReviewAccessTokenProvider.overrideWith(
            (ref) async => 'review-token',
          ),
        ],
        child: const MaterialApp(home: VetDetailScreen(vetId: 'mochi-vet')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('vet-detail-write-review-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('vet-detail-write-review-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('write-review-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('write-review-submit')));
    await tester.pump();
    expect(find.byKey(const Key('write-review-error')), findsOneWidget);
    expect(find.text('Vui lòng chọn số sao trước khi gửi.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('write-review-star-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('write-review-star-5')));
    await tester.enterText(
      find.byKey(const Key('write-review-title-field')),
      'Chăm sóc kỹ',
    );
    await tester.enterText(
      find.byKey(const Key('write-review-body-field')),
      'Bác sĩ tư vấn rất kỹ và theo dõi sau tiêm.',
    );
    await tester.ensureVisible(find.byKey(const Key('write-review-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('write-review-submit')));
    await tester.pumpAndSettle();

    expect(submittedVetId, 'mochi-vet');
    expect(submittedAccessToken, 'review-token');
    expect(submittedInput?.rating, 5);
    expect(submittedInput?.title, 'Chăm sóc kỹ');
    expect(submittedInput?.body, 'Bác sĩ tư vấn rất kỹ và theo dõi sau tiêm.');
    expect(find.text('Review đã được gửi thành công.'), findsOneWidget);
  });

  test('serializes review photo upload payload and result', () {
    const input = UploadReviewPhotoInput(
      fileName: 'review.png',
      contentType: 'image/png',
      base64Data: 'abc123',
    );
    expect(input.toJson(), {
      'fileName': 'review.png',
      'contentType': 'image/png',
      'base64Data': 'abc123',
    });

    final result = UploadReviewPhotoResult.fromJson({
      'url': 'https://cdn.pawmate.test/reviews/review.png',
      'path': 'vet/user/review.png',
      'contentType': 'image/png',
      'sizeBytes': 68,
      'storage': 'supabase',
    });
    expect(result.url, 'https://cdn.pawmate.test/reviews/review.png');
    expect(result.storage, 'supabase');
  });

  testWidgets('keeps write review sheet open on duplicate review error', (
    tester,
  ) async {
    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          const VetSearchResult(items: [], total: 0, limit: 20),
      detailHandler: (_) async => _sampleVetDetail(),
      reviewHandler: (_) async => _reviewResult(),
      createReviewHandler: (_, _, _) async => throw const VetApiException(
        'Bạn đã đánh giá phòng khám này rồi.',
        code: 'REVIEW_001',
        statusCode: 409,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => fakeApi),
          vetReviewAccessTokenProvider.overrideWith(
            (ref) async => 'review-token',
          ),
        ],
        child: const MaterialApp(home: VetDetailScreen(vetId: 'mochi-vet')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('vet-detail-write-review-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('vet-detail-write-review-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('write-review-star-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('write-review-star-4')));
    await tester.enterText(
      find.byKey(const Key('write-review-body-field')),
      'Review thứ hai cần bị backend chặn lại.',
    );
    await tester.ensureVisible(find.byKey(const Key('write-review-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('write-review-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('write-review-submit')), findsOneWidget);
    expect(find.text('Bạn đã đánh giá phòng khám này rồi.'), findsOneWidget);
  });

  testWidgets('toggles helpful and reports latest review with auth token', (
    tester,
  ) async {
    String? helpfulReviewId;
    String? helpfulAccessToken;
    String? reportReviewId;
    String? reportReason;
    String? reportDescription;
    String? reportAccessToken;

    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          const VetSearchResult(items: [], total: 0, limit: 20),
      detailHandler: (_) async => _sampleVetDetail(reviewCount: 1),
      reviewHandler: (_) async =>
          _reviewResult(items: [_sampleReview(helpfulCount: 2)]),
      helpfulHandler: (reviewId, accessToken) async {
        helpfulReviewId = reviewId;
        helpfulAccessToken = accessToken;
        return VetReviewHelpfulResult(
          reviewId: reviewId,
          helpfulCount: 3,
          hasVoted: true,
        );
      },
      reportHandler: (reviewId, reason, description, accessToken) async {
        reportReviewId = reviewId;
        reportReason = reason;
        reportDescription = description;
        reportAccessToken = accessToken;
        return VetReviewReportResult(
          reportId: 'report-1',
          reviewId: reviewId,
          reportCount: 1,
          reviewStatus: 'visible',
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => fakeApi),
          vetReviewAccessTokenProvider.overrideWith(
            (ref) async => 'review-token',
          ),
        ],
        child: const MaterialApp(home: VetDetailScreen(vetId: 'mochi-vet')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('review-helpful-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('review-helpful-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-helpful-button')));
    await tester.pumpAndSettle();

    expect(helpfulReviewId, 'review-1');
    expect(helpfulAccessToken, 'review-token');

    await tester.ensureVisible(find.byKey(const Key('review-report-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-report-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-reason-false_information')));
    await tester.enterText(
      find.byKey(const Key('report-description-field')),
      'Thông tin trong review không đúng trải nghiệm thực tế.',
    );
    await tester.tap(find.byKey(const Key('report-review-submit')));
    await tester.pumpAndSettle();

    expect(reportReviewId, 'review-1');
    expect(reportReason, 'false_information');
    expect(
      reportDescription,
      'Thông tin trong review không đúng trải nghiệm thực tế.',
    );
    expect(reportAccessToken, 'review-token');
    expect(find.text('Báo cáo đã được gửi.'), findsOneWidget);
  });

  testWidgets('opens review list sheet and loads next cursor page', (
    tester,
  ) async {
    final requestedCursors = <String?>[];
    final firstPageReview = _sampleReview(
      id: 'review-1',
      title: 'Trang đầu tốt',
      body: 'Review đầu tiên hiển thị trong sheet danh sách.',
    );
    final secondPageReview = _sampleReview(
      id: 'review-2',
      rating: 4,
      title: 'Trang hai tốt',
      body: 'Review trang tiếp theo được tải bằng cursor.',
    );

    final fakeApi = _FakeVetApi(
      searchHandler: (_) async =>
          const VetSearchResult(items: [], total: 0, limit: 20),
      detailHandler: (_) async =>
          _sampleVetDetail(reviewCount: 2, averageRating: 4.5),
      reviewRequestHandler: (_, request) async {
        requestedCursors.add(request.cursor);
        if (request.cursor == 'cursor-2') {
          return _reviewResult(items: [secondPageReview], total: 2);
        }

        return _reviewResult(
          items: [firstPageReview],
          nextCursor: 'cursor-2',
          total: 2,
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => fakeApi)],
        child: const MaterialApp(home: VetDetailScreen(vetId: 'mochi-vet')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('rating-row-5')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('rating-row-5')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('review-list-open-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-list-open-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-list-item-review-1')), findsOneWidget);
    expect(find.textContaining('Trang đầu tốt'), findsWidgets);

    await tester.tap(find.byKey(const Key('review-load-more-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-list-item-review-2')), findsOneWidget);
    expect(find.textContaining('Trang hai tốt'), findsOneWidget);
    expect(requestedCursors, [null, 'cursor-2']);
  });
}

typedef _CreateReviewHandler =
    Future<VetReview> Function(
      String vetId,
      CreateVetReviewInput input,
      String accessToken,
    );
typedef _HelpfulHandler =
    Future<VetReviewHelpfulResult> Function(
      String reviewId,
      String accessToken,
    );
typedef _ReportHandler =
    Future<VetReviewReportResult> Function(
      String reviewId,
      String reason,
      String? description,
      String accessToken,
    );
typedef _ReviewRequestHandler =
    Future<VetReviewResult> Function(
      String vetId,
      VetReviewListRequest request,
    );

class _FakeVetApi extends VetApi {
  _FakeVetApi({
    required this.searchHandler,
    required this.detailHandler,
    Future<VetReviewResult> Function(String vetId)? reviewHandler,
    this.reviewRequestHandler,
    this.createReviewHandler,
    this.helpfulHandler,
    this.reportHandler,
  }) : reviewHandler =
           reviewHandler ??
           ((_) async => const VetReviewResult(
             items: [],
             summary: VetReviewSummary(
               averageRating: null,
               reviewCount: 0,
               distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
             ),
             total: 0,
             limit: 20,
           )),
       super(Dio());

  final Future<VetSearchResult> Function(VetSearchRequest request)
  searchHandler;
  final Future<VetDetail> Function(String vetId) detailHandler;
  final Future<VetReviewResult> Function(String vetId) reviewHandler;
  final _ReviewRequestHandler? reviewRequestHandler;
  final _CreateReviewHandler? createReviewHandler;
  final _HelpfulHandler? helpfulHandler;
  final _ReportHandler? reportHandler;

  @override
  Future<VetSearchResult> search(VetSearchRequest request) {
    return searchHandler(request);
  }

  @override
  Future<VetDetail> getDetail(String vetId) {
    return detailHandler(vetId);
  }

  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) {
    final requestHandler = reviewRequestHandler;
    if (requestHandler != null) {
      return requestHandler(vetId, request);
    }

    return reviewHandler(vetId);
  }

  @override
  Future<VetReview> createReview(
    String vetId,
    CreateVetReviewInput input, {
    required String accessToken,
  }) {
    final handler = createReviewHandler;
    if (handler == null) {
      throw UnimplementedError('createReview');
    }

    return handler(vetId, input, accessToken);
  }

  @override
  Future<UploadReviewPhotoResult> uploadReviewPhoto(
    String vetId,
    UploadReviewPhotoInput input, {
    required String accessToken,
  }) {
    throw UnimplementedError('uploadReviewPhoto');
  }

  @override
  Future<VetReviewHelpfulResult> toggleHelpful(
    String reviewId, {
    required String accessToken,
  }) {
    final handler = helpfulHandler;
    if (handler == null) {
      throw UnimplementedError('toggleHelpful');
    }

    return handler(reviewId, accessToken);
  }

  @override
  Future<VetReviewReportResult> reportReview(
    String reviewId, {
    required String reason,
    String? description,
    required String accessToken,
  }) {
    final handler = reportHandler;
    if (handler == null) {
      throw UnimplementedError('reportReview');
    }

    return handler(reviewId, reason, description, accessToken);
  }
}

VetDetail _sampleVetDetail({
  String id = 'mochi-vet',
  int reviewCount = 0,
  double? averageRating,
}) {
  return VetDetail(
    id: id,
    name: 'Mochi Vet',
    city: 'Đà Nẵng',
    district: 'Hải Châu',
    address: '22 Bạch Đằng',
    phone: '0912 333 444',
    summary: 'Khám tổng quát và theo dõi hồ sơ sức khỏe.',
    services: const [],
    seedRank: 4,
    averageRating: averageRating,
    reviewCount: reviewCount,
    is24h: false,
    isOpen: null,
    readyForMap: false,
    openHours: const [],
    photoUrls: const [],
    source: const VetSource(
      url: 'https://example.com/mochi-vet',
      list: 'Danh sách kiểm duyệt PawMate',
      priorityTier: 'P1',
      enrichmentStatus: 'BASE_ONLY',
      selectionReason: 'Top local vet',
    ),
  );
}

VetReview _sampleReview({
  String id = 'review-1',
  int rating = 5,
  String title = 'Chăm sóc rất kỹ',
  String body = 'Bác sĩ giải thích rõ và theo dõi sau khi tiêm.',
  int helpfulCount = 0,
}) {
  return VetReview(
    id: id,
    vetId: 'mochi-vet',
    rating: rating,
    title: title,
    body: body,
    photoUrls: const [],
    isAnonymous: false,
    isVerifiedVisit: true,
    helpfulCount: helpfulCount,
    reportCount: 0,
    status: 'visible',
    sentiment: 'UNPROCESSED',
    isFlagged: false,
    reviewer: const VetReviewer(
      id: 'user-1',
      displayName: 'Thành viên PawMate',
    ),
    createdAt: '2026-04-29T05:00:00.000Z',
    updatedAt: '2026-04-29T05:00:00.000Z',
  );
}

VetReviewResult _reviewResult({
  List<VetReview> items = const [],
  String? nextCursor,
  int? total,
}) {
  final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  for (final review in items) {
    distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
  }

  final averageRating = items.isEmpty
      ? null
      : items.fold<int>(0, (sum, review) => sum + review.rating) / items.length;

  return VetReviewResult(
    items: items,
    summary: VetReviewSummary(
      averageRating: averageRating,
      reviewCount: items.length,
      distribution: distribution,
    ),
    nextCursor: nextCursor,
    total: total ?? items.length,
    limit: 20,
  );
}

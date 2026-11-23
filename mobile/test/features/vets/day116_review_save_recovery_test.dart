import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

const _body = 'Bác sĩ chăm sóc Mochi chu đáo. Giữ nguyên nội dung khi thử lại.';
const _error = 'Chưa gửi được đánh giá. Hãy thử lại.';
final _detail = VetDetail.fromJson({
  'id': 'r10-vet',
  'name': 'PetCare Elite',
  'city': 'TP Hồ Chí Minh',
  'district': 'Quận 1',
  'address': 'Địa chỉ fixture',
  'phone': '',
  'services': ['Khám tổng quát'],
  'photoUrls': [],
  'openHours': ['08:00–21:00'],
});

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R10 ST-12 P1-11 text$scale IME review retry retains rating body and result',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _ReviewSource();
        final router = GoRouter(
          initialLocation: '/vets/r10-vet',
          routes: [
            GoRoute(
              path: '/vets/:id',
              builder: (context, state) =>
                  VetDetailScreen(vetId: state.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vetApiProvider.overrideWithValue(source),
              vetReviewAccessTokenProvider.overrideWith(
                (ref) async => 'fixture-token',
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final open = find.byKey(const Key('vet-detail-write-review-button'));
        await tester.scrollUntilVisible(
          open,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(open.hitTestable(), findsOneWidget);
        await tester.tap(open);
        await tester.pumpAndSettle();
        final star = find.byKey(const Key('write-review-star-5'));
        await tester.scrollUntilVisible(
          star,
          140,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(star);
        await tester.pumpAndSettle();
        final body = find.byKey(const Key('write-review-body-field'));
        await tester.scrollUntilVisible(
          body,
          140,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.enterText(body, _body);
        await setKeyboardInset(tester, bottom: 250);
        await tester.pumpAndSettle();
        final submit = find.byKey(const Key('write-review-submit'));
        expect(submit.hitTestable(), findsOneWidget);
        expect(tester.getRect(submit).bottom, lessThanOrEqualTo(318));
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(source.inputs, hasLength(1));
        expect(source.records, isEmpty);
        expect(source.inputs.single.rating, 5);
        expect(source.inputs.single.title, 'Khám tổng quát');
        expect(source.inputs.single.body, _body);
        expect(source.inputs.single.photoUrls, isEmpty);
        final error = find.byKey(const Key('write-review-error'));
        // The visible modal has its own scrollable; exclude the detail behind it.
        final scroll = find
            .descendant(
              of: find
                  .ancestor(
                    of: error,
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(error, 120, scrollable: scroll);
        await tester.pumpAndSettle();
        expect(find.text(_error), findsOneWidget);
        expect(error.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(error).bottom,
          lessThanOrEqualTo(tester.getRect(submit).top),
        );
        await captureDay116(
          tester,
          'R10-P111-error-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(source.inputs, hasLength(2));
        expect(source.inputs[1].toJson(), source.inputs[0].toJson());
        expect(source.records, hasLength(1));
        expect(source.vetIds, ['r10-vet', 'r10-vet']);
        expect(find.byKey(const Key('write-review-body-field')), findsNothing);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/vets/r10-vet',
        );
        await setKeyboardInset(tester, bottom: 0);
        await tester.pumpAndSettle();
        // Detail renders one Text containing rating/title, body and count.
        // Match the entire stored review preview, not a nonexistent body Text.
        final result = find.text(
          '★★★★★ Khám tổng quát\n$_body\n1 đánh giá - 0 hữu ích',
        );
        await tester.scrollUntilVisible(
          result,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(result.hitTestable(), findsOneWidget);
        expectNoFlutterOverflow(tester);
        await captureDay116(
          tester,
          'R10-P111-success-text${scale.toString().replaceAll('.', '-')}',
        );
      },
    );
  }
}

/// Review API boundary is controlled; no live network/storage claim.
class _ReviewSource extends VetApi {
  _ReviewSource() : super(Dio());
  final inputs = <CreateVetReviewInput>[];
  final vetIds = <String>[];
  final records = <VetReview>[];
  @override
  Future<VetDetail> getDetail(String vetId) async => _detail;
  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async => VetReviewResult(
    items: [...records],
    summary: VetReviewSummary(
      averageRating: records.isEmpty ? null : 5,
      reviewCount: records.length,
      distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: records.length},
    ),
    total: records.length,
    limit: 20,
  );
  @override
  Future<VetReview> createReview(
    String vetId,
    CreateVetReviewInput input, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    vetIds.add(vetId);
    inputs.add(input);
    if (inputs.length == 1) {
      throw const VetApiException(_error, statusCode: 503);
    }
    final review = VetReview(
      id: 'r10-review',
      vetId: vetId,
      rating: input.rating,
      title: input.title,
      body: input.body,
      photoUrls: input.photoUrls,
      isAnonymous: false,
      isVerifiedVisit: false,
      helpfulCount: 0,
      reportCount: 0,
      status: 'visible',
      sentiment: 'UNPROCESSED',
      isFlagged: false,
      reviewer: const VetReviewer(
        id: 'r10-owner',
        displayName: 'Fixture owner',
      ),
      createdAt: '2026-10-14T02:30:00Z',
      updatedAt: '2026-10-14T02:30:00Z',
    );
    records.add(review);
    return review;
  }
}

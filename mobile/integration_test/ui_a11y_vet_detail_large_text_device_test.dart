import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P1-10 vet identity stays readable on Android at text scale 2', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => _LargeTextVetApi())],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const VetDetailScreen(vetId: 'long-clinic'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    void expectVisibleTextIsReadable(String label) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
        isFalse,
        reason: 'Visible vet-detail copy must not ellipsize: $label',
      );
    }

    expectVisibleTextIsReadable(
      'Longkhanhpets.com Specialist Hospital And Vaccination Center',
    );
    expectVisibleTextIsReadable('Đang mở cửa • Đóng lúc 20:00');
    expectVisibleTextIsReadable(
      '83 Nghi Tam, Tay Ho, Ha Noi, second floor reception\nHải Châu, Đà Nẵng',
    );
    expect(tester.takeException(), isNull);
  });
}

class _LargeTextVetApi extends VetApi {
  _LargeTextVetApi() : super(Dio());

  @override
  Future<VetDetail> getDetail(String vetId) async => const VetDetail(
    id: 'long-clinic',
    name: 'Longkhanhpets.com Specialist Hospital And Vaccination Center',
    city: 'Đà Nẵng',
    district: 'Hải Châu',
    address: '83 Nghi Tam, Tay Ho, Ha Noi, second floor reception',
    phone: '0912 333 444',
    summary: 'Khám tổng quát và theo dõi hồ sơ sức khỏe.',
    services: [
      'General consultation',
      'Vaccination',
      'Pet wellness counseling',
      'Open until 20:00',
    ],
    seedRank: 4,
    averageRating: 4.6,
    reviewCount: 42,
    is24h: false,
    isOpen: true,
    readyForMap: false,
    openHours: ['08:00 - 20:00'],
    photoUrls: [],
    source: VetSource(
      url: 'https://example.com/long-clinic',
      list: 'Danh sách kiểm duyệt PawMate',
      priorityTier: 'P1',
      enrichmentStatus: 'BASE_ONLY',
      selectionReason: 'Large-text fixture',
    ),
  );

  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async => VetReviewResult(
    items: const [],
    summary: const VetReviewSummary(
      averageRating: 4.6,
      reviewCount: 42,
      distribution: {1: 0, 2: 0, 3: 0, 4: 12, 5: 30},
    ),
    total: 0,
    limit: request.limit,
  );
}

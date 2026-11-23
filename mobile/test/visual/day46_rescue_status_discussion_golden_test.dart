import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_status_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_status_screen.dart';

import '../features/rescue/rescue_comment_test_fixtures.dart';
import '../features/rescue/rescue_test_fixtures.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day46-rescue-golden-root');
const _viewport = Size(390, 844);
const _statusPetAsset = 'assets/images/rescue/p2_07_status_mochi.png';
const _discussionPetAsset = 'assets/images/rescue/p2_08_case_mochi.png';
const _discussionOwnerAsset = 'assets/images/rescue/p2_08_owner_avatar.png';
const _discussionAnBinhAsset = 'assets/images/rescue/p2_08_an_binh_avatar.png';
const _discussionThanhNamAsset =
    'assets/images/rescue/p2_08_thanh_nam_avatar.png';
const _discussionMediaAsset = 'assets/images/rescue/p2_08_comment_sighting.jpg';

Future<void> pumpDay120Status(WidgetTester tester, Size size) async {
  await _pump(
    tester,
    viewport: size,
    wrap: (child) => ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: _statusGoldenDetail()),
        ),
        rescueStatusSourceProvider.overrideWithValue(_NoopStatusSource()),
        authAccessTokenProvider.overrideWith((ref) async => 'golden-owner'),
      ],
      child: child,
    ),
    child: const RescueStatusScreen(caseId: sampleCommentCaseId),
  );
  final context = tester.element(find.byKey(_goldenKey));
  await tester.runAsync(
    () => precacheImage(const AssetImage(_statusPetAsset), context),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-07 Case Status Update golden at 390x844', (tester) async {
    final detail = _statusGoldenDetail();
    await _pump(
      tester,
      wrap: (child) => ProviderScope(
        overrides: [
          rescueApiProvider.overrideWithValue(FakeRescueSource(detail: detail)),
          rescueStatusSourceProvider.overrideWithValue(_NoopStatusSource()),
          authAccessTokenProvider.overrideWith((ref) async => 'golden-owner'),
        ],
        child: child,
      ),
      child: const RescueStatusScreen(caseId: sampleCommentCaseId),
    );
    final context = tester.element(find.byKey(_goldenKey));
    await tester.runAsync(
      () => precacheImage(const AssetImage(_statusPetAsset), context),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cập nhật trạng thái'), findsOneWidget);
    expect(find.text('PawMate'), findsOneWidget);
    expect(find.text('Mochi'), findsWidgets);
    expect(find.text('mất lúc 18:40 25/05/2026'), findsOneWidget);
    expect(find.byKey(const Key('rescue-status-pet-image')), findsOneWidget);
    expect(find.text('Lưu trạng thái'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day46/p2-07-case-status-390x844.png'),
    );
  });

  testWidgets('P2-08 Case Discussion golden at 390x844', (tester) async {
    final comments = [
      RescueComment(
        commentId: '11111111-1111-4111-8111-111111111111',
        caseId: sampleCommentCaseId,
        author: RescueCommentAuthor(
          displayName: 'Chủ tin (Bạn)',
          avatarUrl: Uri.parse('asset:$_discussionOwnerAsset'),
        ),
        body:
            'Mọi người ơi, Mochi rất thích ăn pate cá hồi. Nếu có thấy bé ở khu vực Công viên nước, hãy thử dùng pate để gọi bé nhé. Cảm ơn cả nhà rất nhiều!',
        media: const [],
        createdAt: DateTime(2026, 5, 22, 18, 30),
        updatedAt: DateTime(2026, 5, 22, 18, 30),
        moderationState: RescueCommentModerationState.visible,
      ),
      RescueComment(
        commentId: '44444444-4444-4444-8444-444444444444',
        caseId: sampleCommentCaseId,
        author: RescueCommentAuthor(
          displayName: 'An Bình',
          avatarUrl: Uri.parse('asset:$_discussionAnBinhAsset'),
        ),
        body:
            'Đã ghi chú, chiều nay mình dắt cún đi dạo sẽ để ý khu vực này giúp bạn.',
        media: const [],
        createdAt: DateTime(2026, 5, 22, 18, 32),
        updatedAt: DateTime(2026, 5, 22, 18, 32),
        moderationState: RescueCommentModerationState.visible,
        replyToCommentId: '11111111-1111-4111-8111-111111111111',
      ),
      RescueComment(
        commentId: '55555555-5555-4555-8555-555555555555',
        caseId: sampleCommentCaseId,
        author: RescueCommentAuthor(
          displayName: 'Thanh Nam',
          avatarUrl: Uri.parse('asset:$_discussionThanhNamAsset'),
        ),
        body:
            'Mình vừa thấy một bé khá giống Mochi ở ngõ 12 Lạc Long Quân. Bé chạy rất nhanh nên mình chỉ kịp chụp mờ mờ như này thôi.',
        media: [
          RescueCommentMedia(
            mediaId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            mimeType: 'image/jpeg',
            publicUrl: Uri.parse('asset:$_discussionMediaAsset'),
            width: 276,
            height: 156,
          ),
        ],
        createdAt: DateTime(2026, 5, 22, 18, 35),
        updatedAt: DateTime(2026, 5, 22, 18, 35),
        moderationState: RescueCommentModerationState.visible,
      ),
    ];
    final detail = _discussionGoldenDetail();
    await _pump(
      tester,
      wrap: (child) => ProviderScope(
        overrides: [
          rescueCommentSourceProvider.overrideWithValue(
            FakeRescueCommentSource(comments: comments),
          ),
          rescueCommentClockProvider.overrideWithValue(
            () => DateTime(2026, 5, 22, 18, 40),
          ),
          authAccessTokenProvider.overrideWith((ref) async => 'golden-viewer'),
          rescueApiProvider.overrideWithValue(FakeRescueSource(detail: detail)),
          rescueCommentMediaBuilderProvider.overrideWithValue(
            (context, media) => _discussionGoldenMedia(media),
          ),
        ],
        child: child,
      ),
      child: const RescueCommentScreen(
        caseId: sampleCommentCaseId,
        discussionMode: true,
      ),
    );

    final context = tester.element(find.byKey(_goldenKey));
    for (final asset in [
      _discussionPetAsset,
      _discussionOwnerAsset,
      _discussionAnBinhAsset,
      _discussionThanhNamAsset,
      _discussionMediaAsset,
    ]) {
      await tester.runAsync(() => precacheImage(AssetImage(asset), context));
    }
    await tester.pumpAndSettle();
    expect(find.text('Thảo luận ca tìm'), findsOneWidget);
    expect(find.text('Mochi'), findsWidgets);
    expect(find.text('Phản hồi Chủ tin (Bạn)'), findsOneWidget);
    expect(find.byKey(const Key('rescue-discussion-share')), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day46/p2-08-case-discussion-390x844.png'),
    );
  });
}

Future<void> pumpDay118Discussion(WidgetTester tester, Size viewport) async {
  await _pump(
    tester,
    viewport: viewport,
    wrap: (child) => ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: _discussionGoldenDetail()),
        ),
        rescueCommentSourceProvider.overrideWithValue(
          FakeRescueCommentSource(
            comments: [
              for (var i = 0; i < 12; i++)
                RescueComment(
                  commentId: 'discussion-$i',
                  caseId: sampleCommentCaseId,
                  author: RescueCommentAuthor(
                    displayName: i == 0 ? 'Chủ tin (Bạn)' : 'Người hỗ trợ $i',
                    avatarUrl: Uri.parse('asset:$_discussionOwnerAsset'),
                  ),
                  body:
                      'Mình vừa thấy một bé khá giống Mochi ở ngõ 12 Lạc Long Quân. Bé chạy rất nhanh nên mình chỉ kịp chụp mờ mờ như này thôi. Cảm ơn mọi người đã quan tâm và giúp đỡ!',
                  media: const [],
                  createdAt: DateTime(2026, 5, 22, 18, 30),
                  updatedAt: DateTime(2026, 5, 22, 18, 30),
                  moderationState: RescueCommentModerationState.visible,
                ),
            ],
          ),
        ),
        rescueCommentClockProvider.overrideWithValue(
          () => DateTime(2026, 5, 22, 18, 40),
        ),
        authAccessTokenProvider.overrideWith((ref) async => 'golden-viewer'),
      ],
      child: child,
    ),
    child: const RescueCommentScreen(
      caseId: sampleCommentCaseId,
      discussionMode: true,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget Function(Widget child) wrap,
  required Widget child,
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    wrap(
      RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoopStatusSource implements RescueStatusSource {
  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => throw UnimplementedError();
}

RescueCaseDetail _discussionGoldenDetail() {
  final base = sampleCaseDetail(canComment: true);
  final lostAt = DateTime(2026, 5, 22, 18, 20);
  return RescueCaseDetail(
    caseId: base.caseId,
    petName: 'Mochi',
    species: RescueSpecies.cat,
    status: RescueCaseStatus.missing,
    version: base.version,
    lostAt: lostAt,
    publicLocation: const RescuePublicLocation(
      areaLabel: 'Tây Hồ, Hà Nội',
      approximateLatitude: 21.069,
      approximateLongitude: 105.818,
      privacyRadiusMeters: 500,
    ),
    media: [
      RescuePublicMedia(
        mediaId: '66666666-6666-4666-8666-666666666666',
        mimeType: 'image/png',
        publicUrl: Uri.parse('asset:$_discussionPetAsset'),
        createdAt: lostAt,
      ),
    ],
    commentCount: 3,
    createdAt: lostAt,
    updatedAt: lostAt,
    identifyingFeatures: base.identifyingFeatures,
    viewerPermissions: base.viewerPermissions,
    breedOrColor: 'Mèo tam thể',
    ageLabel: base.ageLabel,
    distanceMeters: base.distanceMeters,
    behaviorHint: base.behaviorHint,
  );
}

Widget _discussionGoldenMedia(RescueCommentMedia media) => ClipRRect(
  key: ValueKey('rescue-comment-image-${media.mediaId}'),
  borderRadius: BorderRadius.circular(AppRadius.md),
  child: AspectRatio(
    aspectRatio: 16 / 9,
    child: Image.asset(
      _discussionMediaAsset,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  ),
);

RescueCaseDetail _statusGoldenDetail() {
  final base = sampleCaseDetail(canUpdateStatus: true, version: 3);
  final lostAt = DateTime(2026, 5, 25, 18, 40);
  return RescueCaseDetail(
    caseId: base.caseId,
    petName: 'Mochi',
    species: RescueSpecies.cat,
    status: RescueCaseStatus.missing,
    version: base.version,
    lostAt: lostAt,
    publicLocation: const RescuePublicLocation(
      areaLabel: 'Tây Hồ',
      approximateLatitude: 21.069,
      approximateLongitude: 105.818,
      privacyRadiusMeters: 500,
    ),
    media: [
      RescuePublicMedia(
        mediaId: '55555555-5555-4555-8555-555555555555',
        mimeType: 'image/png',
        publicUrl: Uri.parse('asset:$_statusPetAsset'),
        createdAt: lostAt,
      ),
    ],
    commentCount: base.commentCount,
    createdAt: lostAt,
    updatedAt: lostAt,
    identifyingFeatures: base.identifyingFeatures,
    viewerPermissions: base.viewerPermissions,
    breedOrColor: 'Mèo tam thể',
    ageLabel: base.ageLabel,
    distanceMeters: base.distanceMeters,
    behaviorHint: base.behaviorHint,
  );
}

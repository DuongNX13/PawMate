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
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../features/rescue/rescue_comment_test_fixtures.dart';
import '../features/rescue/rescue_test_fixtures.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day45-rescue-comment-golden-root');
const _viewport = Size(390, 844);

Future<void> pumpDay120Comment(WidgetTester tester, Size size) =>
    _pumpComment(tester, viewport: size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-06 Case Comment golden at 390x844', (tester) async {
    await _pumpComment(tester);

    expect(find.text('Bình luận'), findsOneWidget);
    expect(find.text('Lâm Hoàng'), findsOneWidget);
    expect(
      find.byKey(const Key('rescue-comment-privacy-warning')),
      findsOneWidget,
    );
    expect(find.byTooltip('Vị trí'), findsNothing);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day45/p2-06-case-comment-390x844.png'),
    );
  });

  testWidgets('P2-06 failed send keeps draft golden at 390x844', (
    tester,
  ) async {
    final source = FakeRescueCommentSource(comments: _figmaComments())
      ..failSends = 1;
    await _pumpComment(tester, commentSource: source);
    await tester.enterText(
      find.byKey(const Key('rescue-comment-field')),
      'Mình vừa thấy bé gần công viên.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('rescue-comment-send')));
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rescue-comment-error')), findsOneWidget);
    expect(find.text('Gửi lại'), findsOneWidget);
    expect(find.text('Mình vừa thấy bé gần công viên.'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/day45/p2-06-case-comment-send-failure-390x844.png',
      ),
    );
  });
}

Future<void> _pumpComment(
  WidgetTester tester, {
  FakeRescueCommentSource? commentSource,
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  final source =
      commentSource ?? FakeRescueCommentSource(comments: _figmaComments());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueCommentSourceProvider.overrideWithValue(source),
        authAccessTokenProvider.overrideWith((ref) async => 'golden-token'),
        rescueCommentClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 27, 10, 30),
        ),
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: _figmaCaseDetail()),
        ),
        rescueCommentMediaBuilderProvider.overrideWithValue(
          _goldenMediaBuilder,
        ),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const RescueCommentScreen(caseId: sampleCommentCaseId),
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byKey(_goldenKey));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/rescue/p2_06_comment_cat.png'),
      context,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _goldenMediaBuilder(BuildContext context, RescueCommentMedia media) {
  return ClipRRect(
    key: ValueKey('golden-comment-media-${media.mediaId}'),
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: AspectRatio(
      aspectRatio: 1,
      child: Image.asset(
        'assets/images/rescue/p2_06_comment_cat.png',
        fit: BoxFit.cover,
        semanticLabel: 'Ảnh manh mối đã làm sạch metadata',
      ),
    ),
  );
}

RescueCaseDetail _figmaCaseDetail() {
  final date = DateTime.utc(2026, 7, 27, 10);
  return RescueCaseDetail(
    caseId: sampleCommentCaseId,
    petName: 'Mochi',
    species: RescueSpecies.cat,
    status: RescueCaseStatus.missing,
    version: 1,
    lostAt: date,
    publicLocation: const RescuePublicLocation(
      areaLabel: 'Tây Hồ',
      approximateLatitude: 21.07,
      approximateLongitude: 105.82,
      privacyRadiusMeters: 500,
    ),
    media: const [],
    commentCount: 3,
    createdAt: date,
    updatedAt: date,
    breedOrColor: 'Mèo tam thể',
    ageLabel: '2 tuổi',
    identifyingFeatures: 'Đuôi có khoang vàng',
    viewerPermissions: const RescueViewerPermissions(
      canComment: true,
      canUpdateStatus: false,
      canViewPrivateContact: false,
    ),
  );
}

List<RescueComment> _figmaComments() => [
  RescueComment(
    commentId: '11111111-1111-4111-8111-111111111111',
    caseId: sampleCommentCaseId,
    author: const RescueCommentAuthor(displayName: 'Lâm Hoàng'),
    body:
        'Mình vừa thấy một bé rất giống ở ngõ 123 Thụy Khuê lúc 10h sáng nay.',
    media: const [],
    createdAt: DateTime.utc(2026, 7, 27, 10, 20),
    updatedAt: DateTime.utc(2026, 7, 27, 10, 20),
    moderationState: RescueCommentModerationState.visible,
  ),
  RescueComment(
    commentId: '22222222-2222-4222-8222-222222222222',
    caseId: sampleCommentCaseId,
    author: const RescueCommentAuthor(displayName: 'Minh Anh'),
    body: 'Bé đang nằm dưới gầm xe hơi, đuôi có khoang vàng đúng như mô tả.',
    media: [
      RescueCommentMedia(
        mediaId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        mimeType: 'image/png',
        publicUrl: Uri.parse('https://example.test/comment-cat.png'),
        width: 324,
        height: 324,
      ),
    ],
    createdAt: DateTime.utc(2026, 7, 27, 10, 5),
    updatedAt: DateTime.utc(2026, 7, 27, 10, 5),
    moderationState: RescueCommentModerationState.visible,
  ),
  RescueComment(
    commentId: '33333333-3333-4333-8333-333333333333',
    caseId: sampleCommentCaseId,
    author: const RescueCommentAuthor(displayName: 'Thanh Tùng'),
    body: 'Mình đang ở gần đó và sẽ kiểm tra thêm.',
    media: const [],
    createdAt: DateTime.utc(2026, 7, 27, 9, 30),
    updatedAt: DateTime.utc(2026, 7, 27, 9, 30),
    moderationState: RescueCommentModerationState.visible,
  ),
];

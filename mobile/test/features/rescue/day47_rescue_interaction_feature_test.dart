import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_status_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_status_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_status_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_comment_test_fixtures.dart';
import 'rescue_test_fixtures.dart';

void main() {
  test(
    'concurrency conflict blocks blind status retry until detail refresh',
    () async {
      final source = _ConflictStatusSource();
      final container = ProviderContainer(
        overrides: [
          rescueStatusSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        rescueStatusProvider(sampleCommentCaseId).notifier,
      );
      notifier.setConfirmedSafe(true);

      expect(
        await notifier.submit(
          sampleCaseDetail(canUpdateStatus: true, version: 3),
        ),
        isNull,
      );
      final state = container.read(rescueStatusProvider(sampleCommentCaseId));
      expect(state.needsRefresh, isTrue);
      expect(
        state.canSubmit,
        isFalse,
        reason:
            'A stale expectedVersion must not be submitted again before refetch.',
      );
      expect(
        await notifier.submit(
          sampleCaseDetail(canUpdateStatus: true, version: 3),
        ),
        isNull,
      );
      expect(source.calls, 1);
    },
  );

  for (final fixture in <({Size size, double textScale})>[
    (size: const Size(320, 568), textScale: 1),
    (size: const Size(430, 932), textScale: 1.3),
    (size: const Size(360, 800), textScale: 2),
  ]) {
    testWidgets('status and discussion remain usable at '
        '${fixture.size.width.toInt()}x${fixture.size.height.toInt()} '
        'text ${fixture.textScale}', (tester) async {
      await setTestViewport(tester, size: fixture.size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(
                detail: sampleCaseDetail(canUpdateStatus: true, version: 2),
              ),
            ),
            rescueStatusSourceProvider.overrideWithValue(
              _SuccessfulStatusSource(),
            ),
            authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(fixture.textScale),
            home: const RescueStatusScreen(caseId: sampleCommentCaseId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lưu trạng thái'), findsOneWidget);
      expectNoFlutterOverflow(tester);

      // Tear down the first ProviderScope before mounting a scope with a
      // different override set. Riverpod intentionally rejects changing the
      // override shape of an existing scope.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueCommentSourceProvider.overrideWithValue(
              FakeRescueCommentSource(comments: [sampleComments().first]),
            ),
            authAccessTokenProvider.overrideWith((ref) async => 'viewer-token'),
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: sampleCaseDetail()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(fixture.textScale),
            home: const RescueCommentScreen(
              caseId: sampleCommentCaseId,
              discussionMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Thảo luận ca tìm'), findsOneWidget);
      expect(
        find.text(fixture.textScale > 1.3 ? 'Trao đổi' : 'Thảo luận ca tìm'),
        findsOneWidget,
      );
      expect(find.byTooltip('Vị trí'), findsNothing);
      expect(find.textContaining('10.8'), findsNothing);
      expectNoFlutterOverflow(tester);
    });
  }
}

class _ConflictStatusSource implements RescueStatusSource {
  int calls = 0;

  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    calls += 1;
    throw const RescueStatusApiException(
      'Version conflict.',
      code: 'RESCUE_011',
      statusCode: 409,
    );
  }
}

class _SuccessfulStatusSource implements RescueStatusSource {
  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => sampleCaseDetail(
    caseId: caseId,
    canUpdateStatus: true,
    version: expectedVersion + 1,
  ).copyWith(status: RescueCaseStatus.found);
}

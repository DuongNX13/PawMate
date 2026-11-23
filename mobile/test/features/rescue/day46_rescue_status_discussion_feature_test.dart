import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/router/app_feature_availability.dart';
import 'package:pawmate_mobile/app/router/app_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_map_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_status_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_status_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_status_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day115_capture.dart';
import '../../test_support/day116_capture.dart';
import 'rescue_comment_test_fixtures.dart';
import 'rescue_test_fixtures.dart';

void main() {
  for (final label in ['Về bài đăng', 'Xem danh sách']) {
    testWidgets(
      'D116 R9 ST-22 P2-04 success CTA $label production destination',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _FakeStatusSource();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appFeatureAvailabilityProvider.overrideWithValue(
              const AppFeatureAvailability(
                rescueBrowse: true,
                rescueCreate: true,
              ),
            ),
            authSessionSnapshotProvider.overrideWithValue(
              const AsyncValue<AuthSession?>.data(_session),
            ),
            authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(
                detail: sampleCaseDetail(canUpdateStatus: true, version: 2),
              ),
            ),
            rescueStatusSourceProvider.overrideWithValue(source),
            rescueCommentSourceProvider.overrideWithValue(
              FakeRescueCommentSource(),
            ),
          ],
        );
        final router = container.read(appRouterProvider);
        addTearDown(router.dispose);
        addTearDown(container.dispose);
        router.go('/rescue/$sampleCommentCaseId/status');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
              builder: testTextScaleBuilder(2),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final confirm = find.byKey(const Key('rescue-status-confirm-safe'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(confirm.hitTestable(), findsOneWidget);
        await tester.tap(confirm);
        await tester.pump();
        final submit = find.text('Lưu trạng thái');
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(submit.hitTestable(), findsOneWidget);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(source.calls, 1);
        expect(source.versions, [2]);
        expect(
          container
              .read(rescueStatusProvider(sampleCommentCaseId))
              .updatedDetail
              ?.status,
          RescueCaseStatus.found,
        );
        expect(
          container
              .read(rescueCommentProvider(sampleCommentCaseId))
              .commentsClosed,
          isTrue,
        );
        final action = find.text(label);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        await captureDay116(
          tester,
          label == 'Về bài đăng' ? 'R9-ST22-detail-CTA' : 'R9-ST22-list-CTA',
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(RescueStatusScreen), findsNothing);
        if (label == 'Về bài đăng') {
          expect(
            router.routeInformationProvider.value.uri.path,
            '/rescue/$sampleCommentCaseId',
          );
          expect(find.byType(RescueCaseDetailScreen), findsOneWidget);
        } else {
          expect(router.routeInformationProvider.value.uri.path, '/rescue');
          expect(find.byType(RescueHomeScreen), findsOneWidget);
        }
        expectNoFlutterOverflow(tester);
      },
    );
  }
  test(
    'status API sends the optimistic concurrency contract exactly',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {'data': _detailPayload(status: 'found', version: 4)},
                ),
              );
            },
          ),
        );

      final detail = await RescueStatusApi(dio).markFound(
        accessToken: 'owner-token',
        caseId: sampleCommentCaseId,
        expectedVersion: 3,
        idempotencyKey: 'stable-status-key',
      );

      expect(request.method, 'PATCH');
      expect(request.uri.path, '/rescue/cases/$sampleCommentCaseId/status');
      expect(request.headers['Authorization'], 'Bearer owner-token');
      expect(request.headers['Idempotency-Key'], 'stable-status-key');
      expect(request.headers['Cache-Control'], 'no-store');
      expect(request.data, {
        'newStatus': 'found',
        'expectedStatus': 'missing',
        'expectedVersion': 3,
        'confirmedSafe': true,
      });
      expect(detail.status, RescueCaseStatus.found);
      expect(detail.version, 4);
    },
  );

  test(
    'status API maps auth, owner, conflict, network, and malformed responses',
    () async {
      final fixtures =
          <
            ({
              int status,
              String code,
              bool Function(RescueStatusApiException) check,
            })
          >[
            (
              status: 401,
              code: 'AUTH_013',
              check: (error) => error.isAuthRequired,
            ),
            (
              status: 403,
              code: 'RESCUE_002',
              check: (error) => error.isForbidden,
            ),
            (
              status: 409,
              code: 'RESCUE_011',
              check: (error) => error.isConflict,
            ),
          ];
      for (final fixture in fixtures) {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: fixture.status,
                    data: {
                      'error': {
                        'code': fixture.code,
                        'message': 'Safe status failure.',
                      },
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              ),
            ),
          );
        await expectLater(
          RescueStatusApi(dio).markFound(
            accessToken: 'token',
            caseId: sampleCommentCaseId,
            expectedVersion: 1,
            idempotencyKey: 'key-${fixture.code}',
          ),
          throwsA(
            isA<RescueStatusApiException>().having(
              fixture.check,
              'mapped flag',
              isTrue,
            ),
          ),
        );
      }

      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
      ]) {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.reject(
                DioException(requestOptions: options, type: type),
              ),
            ),
          );
        await expectLater(
          RescueStatusApi(dio).markFound(
            accessToken: 'token',
            caseId: sampleCommentCaseId,
            expectedVersion: 1,
            idempotencyKey: 'network-$type',
          ),
          throwsA(
            isA<RescueStatusApiException>().having(
              (error) => error.message,
              'safe network message',
              contains('Không thể kết nối'),
            ),
          ),
        );
      }

      final malformed = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: const {'data': true},
              ),
            ),
          ),
        );
      await expectLater(
        RescueStatusApi(malformed).markFound(
          accessToken: 'token',
          caseId: sampleCommentCaseId,
          expectedVersion: 1,
          idempotencyKey: 'malformed',
        ),
        throwsA(
          isA<RescueStatusApiException>().having(
            (error) => error.code,
            'invalid response',
            'INVALID_RESPONSE',
          ),
        ),
      );
    },
  );

  test(
    'owner retry keeps idempotency key and conflict requires refresh',
    () async {
      final source = _FakeStatusSource()..failures = 1;
      final container = _statusContainer(source);
      addTearDown(container.dispose);
      final detail = sampleCaseDetail(canUpdateStatus: true, version: 8);
      final notifier = container.read(
        rescueStatusProvider(sampleCommentCaseId).notifier,
      );

      notifier.setConfirmedSafe(true);
      expect(await notifier.submit(detail), isNull);
      final retryKey = source.keys.single;
      final updated = await notifier.submit(detail);

      expect(source.keys, [retryKey, retryKey]);
      expect(source.versions, [8, 8]);
      expect(updated?.status, RescueCaseStatus.found);
      expect(updated?.version, 9);

      final conflict = _FakeStatusSource()..conflict = true;
      final conflictContainer = _statusContainer(conflict);
      addTearDown(conflictContainer.dispose);
      final conflictNotifier = conflictContainer.read(
        rescueStatusProvider(sampleCommentCaseId).notifier,
      );
      conflictNotifier.setConfirmedSafe(true);
      expect(await conflictNotifier.submit(detail), isNull);
      expect(
        conflictContainer
            .read(rescueStatusProvider(sampleCommentCaseId))
            .needsRefresh,
        isTrue,
      );
      expect(
        conflictContainer
            .read(rescueStatusProvider(sampleCommentCaseId))
            .canSubmit,
        isFalse,
      );
      expect(await conflictNotifier.submit(detail), isNull);
      expect(conflict.calls, 1);

      conflictNotifier.prepareForRefresh();
      expect(
        conflictContainer
            .read(rescueStatusProvider(sampleCommentCaseId))
            .needsRefresh,
        isFalse,
      );
      expect(
        conflictContainer
            .read(rescueStatusProvider(sampleCommentCaseId))
            .canSubmit,
        isFalse,
      );
      conflict.conflict = false;
      conflictNotifier.setConfirmedSafe(true);
      final refreshed = await conflictNotifier.submit(
        detail.copyWith(version: 9),
      );
      expect(refreshed?.status, RescueCaseStatus.found);
      expect(conflict.versions, [8, 9]);
    },
  );

  test('viewer cannot invoke the owner status source', () async {
    final source = _FakeStatusSource();
    final container = _statusContainer(source);
    addTearDown(container.dispose);
    final notifier = container.read(
      rescueStatusProvider(sampleCommentCaseId).notifier,
    );
    notifier.setConfirmedSafe(true);

    expect(await notifier.submit(sampleCaseDetail()), isNull);
    expect(source.calls, 0);
    expect(
      container.read(rescueStatusProvider(sampleCommentCaseId)).errorMessage,
      contains('Chỉ chủ bài viết'),
    );
  });

  test(
    'status validation blocks unsafe states and maps unexpected failures',
    () async {
      final source = _FakeStatusSource();
      final noToken = ProviderContainer(
        overrides: [
          rescueStatusSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(noToken.dispose);
      final notifier = noToken.read(
        rescueStatusProvider(sampleCommentCaseId).notifier,
      );
      final owner = sampleCaseDetail(canUpdateStatus: true);

      expect(await notifier.submit(owner), isNull);
      expect(source.calls, 0);
      notifier.setConfirmedSafe(true);
      expect(await notifier.submit(owner), isNull);
      expect(
        noToken.read(rescueStatusProvider(sampleCommentCaseId)).errorMessage,
        contains('hết hạn'),
      );
      expect(
        await notifier.submit(owner.copyWith(status: RescueCaseStatus.found)),
        isNull,
      );

      final broken = ProviderContainer(
        overrides: [
          rescueStatusSourceProvider.overrideWithValue(_ThrowingStatusSource()),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(broken.dispose);
      final brokenNotifier = broken.read(
        rescueStatusProvider(sampleCommentCaseId).notifier,
      );
      brokenNotifier.setConfirmedSafe(true);
      expect(await brokenNotifier.submit(owner), isNull);
      expect(
        broken.read(rescueStatusProvider(sampleCommentCaseId)).errorMessage,
        contains('Không thể cập nhật'),
      );
    },
  );

  test(
    'status synchronization updates loaded home and map projections',
    () async {
      final source = FakeRescueSource(
        pages: [samplePage(items: sampleCasesWithoutImages())],
      );
      final container = ProviderContainer(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
          rescueLocationServiceProvider.overrideWithValue(_FixedLocation()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(rescueHomeProvider.notifier).initialize();
      await container.read(rescueMapProvider.notifier).initialize();
      final updated = sampleCaseDetail(canUpdateStatus: true).copyWith(
        status: RescueCaseStatus.found,
        version: 2,
        updatedAt: DateTime.utc(2026, 7, 27, 12),
      );

      container.read(rescueHomeProvider.notifier).applyStatusUpdate(updated);
      container.read(rescueMapProvider.notifier).applyStatusUpdate(updated);

      expect(
        container
            .read(rescueHomeProvider)
            .items
            .firstWhere((item) => item.caseId == updated.caseId)
            .status,
        RescueCaseStatus.found,
      );
      expect(
        container
            .read(rescueMapProvider)
            .items
            .firstWhere((item) => item.caseId == updated.caseId)
            .status,
        RescueCaseStatus.found,
      );
    },
  );

  test(
    'discussion reply preserves parent, media contract, and ordering',
    () async {
      final source = FakeRescueCommentSource();
      final container = ProviderContainer(
        overrides: [
          rescueCommentSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'comment-token'),
          rescueCommentClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 7, 27, 10, 30),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );

      await notifier.load();
      notifier.setReplyTarget(source.comments.first);
      notifier.setDraftText('Mình sẽ kiểm tra lại khu vực công khai.');
      expect(await notifier.send(), isTrue);

      final state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(
        source.sentReplyToCommentIds.single,
        '11111111-1111-4111-8111-111111111111',
      );
      expect(
        state.comments.last.replyToCommentId,
        source.sentReplyToCommentIds.single,
      );
      expect(state.replyToCommentId, isNull);
      expect(
        state.comments.map((comment) => comment.createdAt).toList(),
        orderedEquals(
          [...state.comments.map((comment) => comment.createdAt)]..sort(),
        ),
      );

      notifier.setReplyTarget(state.comments.first);
      notifier.markClosed();
      expect(
        container.read(rescueCommentProvider(sampleCommentCaseId)).canSend,
        isFalse,
      );
    },
  );

  testWidgets(
    'owner status screen confirms and synchronizes closed discussion',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final statusSource = _FakeStatusSource();
      final container = ProviderContainer(
        overrides: [
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(
              detail: sampleCaseDetail(canUpdateStatus: true, version: 2),
            ),
          ),
          rescueStatusSourceProvider.overrideWithValue(statusSource),
          authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const RescueStatusScreen(caseId: sampleCommentCaseId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Cập nhật trạng thái'), findsOneWidget);
      final title = find.text('Trạng thái');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-07 title must not ellipsize at text scale 2.0',
      );
      expect(find.text('Lưu trạng thái'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('rescue-status-confirm-safe')),
      );
      await tester.tap(find.byKey(const Key('rescue-status-confirm-safe')));
      await tester.pump();
      await tester.ensureVisible(find.text('Lưu trạng thái'));
      await tester.tap(find.text('Lưu trạng thái'));
      await tester.pumpAndSettle();

      expect(find.text('Đã cập nhật thành “Đã thấy”'), findsOneWidget);
      await captureDay115(tester, 'ST-22');
      expect(statusSource.versions, [2]);
      expect(
        container
            .read(rescueCommentProvider(sampleCommentCaseId))
            .commentsClosed,
        isTrue,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('discussion renders reply context and survives keyboard inset', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final source = FakeRescueCommentSource(
      comments: [
        sampleComments().first,
        RescueComment(
          commentId: '44444444-4444-4444-8444-444444444444',
          caseId: sampleCommentCaseId,
          author: const RescueCommentAuthor(displayName: 'Hà My'),
          body: 'Mình sẽ theo dõi thêm.',
          media: const [],
          createdAt: DateTime.utc(2026, 7, 27, 10, 20),
          updatedAt: DateTime.utc(2026, 7, 27, 10, 20),
          moderationState: RescueCommentModerationState.visible,
          replyToCommentId: '11111111-1111-4111-8111-111111111111',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueCommentSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(detail: sampleCaseDetail()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: const RescueCommentScreen(
            caseId: sampleCommentCaseId,
            discussionMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Thảo luận ca tìm'), findsOneWidget);
    final title = find.text('Trao đổi');
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
      reason: 'Visible P2-08 title must not ellipsize at text scale 2.0',
    );
    final replyAction = find.byKey(
      const ValueKey(
        'rescue-comment-reply-11111111-1111-4111-8111-111111111111',
      ),
    );
    await tester.scrollUntilVisible(
      replyAction,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(replyAction);
    await tester.pumpAndSettle();
    await tester.tap(replyAction);
    await tester.pump();
    expect(
      find.byKey(const Key('rescue-comment-reply-banner')),
      findsOneWidget,
    );
    await setKeyboardInset(tester, bottom: 300);
    await tester.pump();
    expectNoFlutterOverflow(tester);
  });

  testWidgets('router enables both Day 46 routes only behind create flag', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final container = ProviderContainer(
      overrides: [
        appFeatureAvailabilityProvider.overrideWithValue(
          const AppFeatureAvailability(rescueBrowse: true, rescueCreate: true),
        ),
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue<AuthSession?>.data(_session),
        ),
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: sampleCaseDetail(canUpdateStatus: true)),
        ),
        rescueStatusSourceProvider.overrideWithValue(_FakeStatusSource()),
        rescueCommentSourceProvider.overrideWithValue(
          FakeRescueCommentSource(),
        ),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    router.go('/rescue/$sampleCommentCaseId/status');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-status-screen')), findsOneWidget);

    router.go('/rescue/$sampleCommentCaseId/discussion');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-comment-screen')), findsOneWidget);
    expect(find.text('Thảo luận ca tìm'), findsOneWidget);
  });

  testWidgets('Day 46 routes fail closed when create flag is disabled', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final container = ProviderContainer(
      overrides: [
        appFeatureAvailabilityProvider.overrideWithValue(
          const AppFeatureAvailability(rescueBrowse: true, rescueCreate: false),
        ),
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue<AuthSession?>.data(_session),
        ),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    router.go('/rescue/$sampleCommentCaseId/status');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-status-screen')), findsNothing);
    expect(find.text('Cập nhật trạng thái'), findsWidgets);
    expect(find.textContaining('chưa được bật'), findsOneWidget);

    router.go('/rescue/$sampleCommentCaseId/discussion');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-comment-screen')), findsNothing);
    expect(find.text('Trao đổi ca cứu hộ'), findsWidgets);
  });
}

ProviderContainer _statusContainer(_FakeStatusSource source) =>
    ProviderContainer(
      overrides: [
        rescueStatusSourceProvider.overrideWithValue(source),
        authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
        rescueStatusClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 27, 12),
        ),
      ],
    );

class _FakeStatusSource implements RescueStatusSource {
  int calls = 0;
  int failures = 0;
  bool conflict = false;
  final List<String> keys = [];
  final List<int> versions = [];

  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    calls += 1;
    keys.add(idempotencyKey);
    versions.add(expectedVersion);
    if (conflict) {
      throw const RescueStatusApiException(
        'Version conflict.',
        code: 'RESCUE_011',
        statusCode: 409,
      );
    }
    if (failures > 0) {
      failures -= 1;
      throw const RescueStatusApiException(
        'Không thể kết nối. Trạng thái chưa được thay đổi.',
        code: 'SYS_001',
        statusCode: 503,
      );
    }
    return sampleCaseDetail(
      caseId: caseId,
      canUpdateStatus: true,
      version: expectedVersion,
    ).copyWith(
      status: RescueCaseStatus.found,
      version: expectedVersion + 1,
      updatedAt: DateTime.utc(2026, 7, 27, 12),
    );
  }
}

class _ThrowingStatusSource implements RescueStatusSource {
  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) => Future<RescueCaseDetail>.error(StateError('unexpected'));
}

class _FixedLocation implements RescueLocationService {
  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async => const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
}

Map<String, dynamic> _detailPayload({
  required String status,
  required int version,
}) => {
  'caseId': sampleCommentCaseId,
  'petName': 'LuLu',
  'species': 'dog',
  'status': status,
  'version': version,
  'lostAt': '2026-07-23T08:00:00.000Z',
  'publicLocation': {
    'areaLabel': 'Q. Tân Bình',
    'approximateLatitude': 10.8,
    'approximateLongitude': 106.7,
    'privacyRadiusMeters': 500,
  },
  'media': <Map<String, dynamic>>[],
  'commentCount': 3,
  'createdAt': '2026-07-23T08:00:00.000Z',
  'updatedAt': '2026-07-27T12:00:00.000Z',
  'breedOrColor': 'Poodle màu nâu',
  'ageLabel': '2 tuổi',
  'distanceMeters': 1200,
  'identifyingFeatures': 'Đeo vòng cổ màu xanh.',
  'behaviorHint': 'Hơi nhút nhát.',
  'viewerPermissions': {
    'canComment': status == 'missing',
    'canUpdateStatus': true,
    'canViewPrivateContact': true,
  },
};

const _session = AuthSession(
  user: AuthUser(
    id: 'day46-owner',
    email: 'day46@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'day46-test-access',
  refreshToken: 'day46-test-refresh',
  accessTokenExpiresAt: '2026-07-28T00:00:00.000Z',
  refreshTokenExpiresAt: '2026-08-27T00:00:00.000Z',
);

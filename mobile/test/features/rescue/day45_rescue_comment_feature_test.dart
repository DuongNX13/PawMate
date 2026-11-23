import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawmate_mobile/app/router/app_feature_availability.dart';
import 'package:pawmate_mobile/app/router/app_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day115_capture.dart';
import 'rescue_comment_test_fixtures.dart';
import 'rescue_test_fixtures.dart';

void main() {
  test(
    'comment API lists in order with auth/no-store and ignores private data',
    () async {
      late RequestOptions request;
      final payloads = [_commentPayload(hour: 10), _commentPayload(hour: 9)];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'data': payloads,
                    'pageInfo': {'nextCursor': 'opaque-next'},
                  },
                ),
              );
            },
          ),
        );

      final page = await RescueCommentApi(
        dio,
      ).listComments(accessToken: 'comment-token', caseId: sampleCommentCaseId);

      expect(request.uri.path, '/rescue/cases/$sampleCommentCaseId/discussion');
      expect(request.headers['Authorization'], 'Bearer comment-token');
      expect(request.headers['Cache-Control'], 'no-store');
      expect(request.extra['pawmate.cache'], 'disabled');
      expect(page.items.map((item) => item.createdAt.hour), [9, 10]);
      expect(page.nextCursor, 'opaque-next');
      expect(page.items.first.author.displayName, 'Cộng đồng');
      expect(page.items.first.body, 'Đã nhìn thấy bé ở khu vực công khai.');
      expect(page.items.first.toString(), isNot(contains('private-address')));
    },
  );

  test(
    'comment API posts bounded payload with a stable idempotency key',
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
                  data: {'data': _commentPayload(hour: 11)},
                ),
              );
            },
          ),
        );

      final comment = await RescueCommentApi(dio).sendComment(
        accessToken: 'comment-token',
        caseId: sampleCommentCaseId,
        body: '  Manh mối an toàn.  ',
        mediaIds: const ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'],
        idempotencyKey: 'stable-comment-key',
      );

      expect(request.method, 'POST');
      expect(request.uri.path, '/rescue/cases/$sampleCommentCaseId/comments');
      expect(request.headers['Idempotency-Key'], 'stable-comment-key');
      expect(request.data['body'], 'Manh mối an toàn.');
      expect(request.data['mediaIds'], hasLength(1));
      expect(comment.body, 'Đã nhìn thấy bé ở khu vực công khai.');
    },
  );

  test('comment models parse media, moderation, and reject malformed data', () {
    final payload = _commentPayload(hour: 12)
      ..['moderationState'] = 'hidden'
      ..['replyToCommentId'] = 'reply-1'
      ..['media'] = [
        {
          'mediaId': 'video-1',
          'mimeType': 'video/mp4',
          'publicUrl': 'https://example.test/clue.mp4',
          'width': 640,
          'height': 360,
          'durationSeconds': 8,
        },
      ];

    final comment = RescueComment.fromJson(payload);
    expect(comment.moderationState, RescueCommentModerationState.hidden);
    expect(comment.replyToCommentId, 'reply-1');
    expect(comment.media.single.isVideo, isTrue);
    expect(comment.media.single.width, 640);
    expect(RescueCommentModerationState.visible.label, 'Đã đăng');
    expect(RescueCommentModerationState.pending.label, 'Đang kiểm duyệt');
    expect(RescueCommentModerationState.hidden.label, 'Đã ẩn');

    const draft = RescueCommentDraftMedia(
      localId: 'video-local',
      path: r'C:\fixtures\clue.mp4',
      mimeType: 'video/mp4',
      sizeBytes: 128,
      mediaId: 'video-1',
      status: RescueCommentUploadStatus.uploaded,
      errorMessage: 'old',
    );
    expect(draft.uploaded, isTrue);
    expect(draft.isVideo, isTrue);
    expect(
      draft.copyWith(clearMediaId: true, clearError: true).mediaId,
      isNull,
    );
    expect(draft.copyWith(clearError: true).errorMessage, isNull);
    expect(RescueCommentDraftMedia.isSupported('image/webp'), isTrue);

    expect(
      () => RescueComment.fromJson({...payload, 'author': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => RescueCommentMedia.fromJson({
        'mediaId': 'bad',
        'mimeType': 'image/jpeg',
        'publicUrl': 'relative-only',
      }),
      throwsFormatException,
    );
    expect(
      RescueCommentAuthor.fromJson({
        'displayName': ' Cộng đồng ',
        'avatarUrl': 'not-a-public-uri',
      }).avatarUrl,
      isNull,
    );
  });

  test(
    'comment API uploads media through ticket, bytes, and completion',
    () async {
      final temp = await Directory.systemTemp.createTemp('pawmate-day45-api-');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}${Platform.pathSeparator}clue.webp');
      await file.writeAsBytes(List<int>.generate(64, (index) => index));
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              final data = switch (options.path) {
                '/media/uploads' => {
                  'data': {
                    'uploadUrl': 'https://uploads.example.test/target',
                    'mediaId': 'ticket-media',
                    'uploadHeaders': {'x-upload-token': 'safe-ticket'},
                  },
                },
                '/media/uploads/ticket-media/complete' => {
                  'data': {'mediaId': 'completed-media'},
                },
                _ => <String, dynamic>{},
              };
              handler.resolve(
                Response<dynamic>(requestOptions: options, data: data),
              );
            },
          ),
        );
      final progress = <double>[];

      final uploaded = await RescueCommentApi(dio).uploadMedia(
        accessToken: 'comment-token',
        media: RescueCommentDraftMedia(
          localId: 'local-upload',
          path: file.path,
          mimeType: 'image/webp',
          sizeBytes: 64,
        ),
        onProgress: progress.add,
      );

      expect(requests.map((item) => item.method), ['POST', 'PUT', 'POST']);
      expect(requests.first.data['purpose'], 'rescue_comment');
      expect(requests.first.data['fileName'], 'clue.webp');
      expect(
        requests.first.headers['Idempotency-Key'],
        'pawmate-day45-upload-local-upload',
      );
      expect(requests[1].headers['x-upload-token'], 'safe-ticket');
      expect(
        requests.last.headers['Idempotency-Key'],
        'pawmate-day45-complete-local-upload',
      );
      expect(uploaded.mediaId, 'completed-media');
      expect(uploaded.uploaded, isTrue);
      expect(progress.last, 1);
    },
  );

  test(
    'comment API maps invalid, closed, network, and missing-file errors',
    () async {
      Dio invalidDio(dynamic data) =>
          Dio(BaseOptions(baseUrl: 'https://api.example.test'))
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) => handler.resolve(
                  Response<dynamic>(requestOptions: options, data: data),
                ),
              ),
            );

      await expectLater(
        RescueCommentApi(
          invalidDio({'data': 'not-a-list'}),
        ).listComments(accessToken: 'token', caseId: sampleCommentCaseId),
        throwsA(
          isA<RescueCommentApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
      await expectLater(
        RescueCommentApi(
          invalidDio({
            'data': [
              {'body': 'missing required fields'},
            ],
          }),
        ).listComments(accessToken: 'token', caseId: sampleCommentCaseId),
        throwsA(isA<RescueCommentApiException>()),
      );
      await expectLater(
        RescueCommentApi(
          invalidDio({
            'data': {'body': 'missing required fields'},
          }),
        ).sendComment(
          accessToken: 'token',
          caseId: sampleCommentCaseId,
          body: 'safe',
          mediaIds: const [],
          idempotencyKey: 'invalid-response-key',
        ),
        throwsA(
          isA<RescueCommentApiException>().having(
            (error) => error.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );

      final closedDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'error': {
                      'code': 'RESCUE_010',
                      'message': 'Discussion closed',
                    },
                  },
                ),
              ),
            ),
          ),
        );
      final closedError = await RescueCommentApi(closedDio)
          .sendComment(
            accessToken: 'token',
            caseId: sampleCommentCaseId,
            body: 'safe',
            mediaIds: const [],
            idempotencyKey: 'closed-key',
          )
          .then<RescueCommentApiException>(
            (_) => throw StateError('Expected request to fail'),
            onError: (Object error, StackTrace _) =>
                error as RescueCommentApiException,
          );
      expect(closedError.commentsClosed, isTrue);
      expect(closedError.toString(), 'Discussion closed');

      final offlineDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'offline',
              ),
            ),
          ),
        );
      await expectLater(
        RescueCommentApi(offlineDio).listComments(
          accessToken: 'token',
          caseId: sampleCommentCaseId,
          cursor: 'opaque',
        ),
        throwsA(
          isA<RescueCommentApiException>().having(
            (error) => error.message,
            'message',
            contains('Không thể kết nối'),
          ),
        ),
      );
      await expectLater(
        RescueCommentApi(invalidDio(const <String, dynamic>{})).uploadMedia(
          accessToken: 'token',
          media: const RescueCommentDraftMedia(
            localId: 'missing',
            path: r'Z:\not-present\missing.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1,
          ),
          onProgress: (_) {},
        ),
        throwsA(
          isA<RescueCommentApiException>().having(
            (error) => error.code,
            'code',
            'MEDIA_001',
          ),
        ),
      );
    },
  );

  test(
    'provider persists optimistic send, clears draft, and keeps ordering',
    () async {
      final source = FakeRescueCommentSource();
      final container = _commentContainer(source);
      addTearDown(container.dispose);

      final notifier = container.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );
      await notifier.load();
      notifier.setDraftText('Mình vừa thấy bé gần cổng công viên.');

      expect(await notifier.send(), isTrue);

      final state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.comments, hasLength(3));
      expect(state.comments.last.body, contains('cổng công viên'));
      expect(state.comments.any((item) => item.isOptimistic), isFalse);
      expect(state.draftText, isEmpty);
      expect(state.media, isEmpty);
      expect(source.sentKeys.single, startsWith('pawmate-day45-comment-'));
    },
  );

  test(
    'failed send keeps text and reuses the same key for exact retry',
    () async {
      final source = FakeRescueCommentSource()..failSends = 1;
      final container = _commentContainer(source);
      addTearDown(container.dispose);
      final notifier = container.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );
      await notifier.load();
      notifier.setDraftText('Giữ nguyên nội dung này để gửi lại.');

      expect(await notifier.send(), isFalse);
      var state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.draftText, contains('Giữ nguyên'));
      expect(state.pendingSendKey, isNotNull);
      expect(state.comments, hasLength(2));

      expect(await notifier.send(), isTrue);
      state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(source.sentKeys, hasLength(2));
      expect(source.sentKeys[1], source.sentKeys[0]);
      expect(state.draftText, isEmpty);
    },
  );

  test(
    'closed discussion preserves unsent text and becomes read-only',
    () async {
      final source = FakeRescueCommentSource()..closeOnSend = true;
      final container = _commentContainer(source);
      addTearDown(container.dispose);
      final notifier = container.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );
      await notifier.load();
      notifier.setDraftText('Nội dung chưa gửi phải được giữ.');

      expect(await notifier.send(), isFalse);

      final state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.commentsClosed, isTrue);
      expect(state.canSend, isFalse);
      expect(state.draftText, contains('phải được giữ'));
      expect(state.errorMessage, contains('đóng bình luận'));
    },
  );

  test(
    'session change purges draft and ignores an in-flight send result',
    () async {
      final source = FakeRescueCommentSource()
        ..sendDelay = const Duration(milliseconds: 20);
      final container = _commentContainer(source);
      addTearDown(container.dispose);
      final notifier = container.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );
      await notifier.load();
      notifier.setDraftText('Không được đi sang phiên đăng nhập kế tiếp.');

      final pending = notifier.send();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.resetForSessionChange();

      expect(await pending, isFalse);
      final state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.draftText, isEmpty);
      expect(state.comments, isEmpty);
      expect(state.pendingSendKey, isNull);
    },
  );

  test('media upload exposes retry and preserves the comment draft', () async {
    final source = FakeRescueCommentSource()..failUploads = 1;
    final container = _commentContainer(source);
    addTearDown(container.dispose);
    final temp = await Directory.systemTemp.createTemp('pawmate-day45-');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}${Platform.pathSeparator}clue.jpg');
    await file.writeAsBytes(List<int>.filled(256, 7));

    final notifier = container.read(
      rescueCommentProvider(sampleCommentCaseId).notifier,
    );
    notifier.setDraftText('Nội dung vẫn còn khi ảnh tải lỗi.');
    await notifier.addMediaFile(XFile(file.path));

    var state = container.read(rescueCommentProvider(sampleCommentCaseId));
    expect(state.media.single.status, RescueCommentUploadStatus.failed);
    expect(state.draftText, contains('vẫn còn'));
    expect(state.canSend, isFalse);

    await notifier.retryMedia(state.media.single.localId);
    state = container.read(rescueCommentProvider(sampleCommentCaseId));
    expect(state.media.single.status, RescueCommentUploadStatus.uploaded);
    expect(state.media.single.progress, 1);
    expect(source.uploadAttempts, 2);
    expect(state.canSend, isTrue);
  });

  test(
    'provider handles load, validation, auth, and generic failures safely',
    () async {
      final source = FakeRescueCommentSource(
        comments: [sampleComments().first],
      );
      final container = _commentContainer(source);
      addTearDown(container.dispose);
      final notifier = container.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );

      await notifier.load();
      source.listError = const RescueCommentApiException(
        'Tạm mất kết nối.',
        code: 'SYS_001',
      );
      await notifier.load(force: true);
      var state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.isStale, isTrue);
      expect(state.comments, hasLength(1));

      notifier.setDraftText('');
      expect(await notifier.send(), isFalse);
      expect(
        container.read(rescueCommentProvider(sampleCommentCaseId)).errorMessage,
        contains('nhập nội dung'),
      );
      notifier.setDraftText('x' * 501);
      expect(await notifier.send(), isFalse);
      expect(
        container.read(rescueCommentProvider(sampleCommentCaseId)).errorMessage,
        contains('500'),
      );

      notifier.setDraftText('Lỗi bất ngờ vẫn phải giữ bản nháp.');
      source.sendError = StateError('unexpected');
      expect(await notifier.send(), isFalse);
      state = container.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.draftText, contains('giữ bản nháp'));
      expect(state.comments.any((item) => item.isOptimistic), isFalse);
      expect(state.errorMessage, contains('Không thể gửi'));
    },
  );

  test(
    'provider rejects unsupported media, removes media, and handles no token',
    () async {
      final source = FakeRescueCommentSource();
      final noToken = _commentContainer(source, accessToken: null);
      addTearDown(noToken.dispose);
      final notifier = noToken.read(
        rescueCommentProvider(sampleCommentCaseId).notifier,
      );
      final temp = await Directory.systemTemp.createTemp(
        'pawmate-day45-media-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final invalid = File('${temp.path}${Platform.pathSeparator}clue.txt');
      await invalid.writeAsString('not supported');

      await notifier.addMediaFile(XFile(invalid.path));
      expect(
        noToken.read(rescueCommentProvider(sampleCommentCaseId)).errorMessage,
        contains('JPEG'),
      );

      final valid = File('${temp.path}${Platform.pathSeparator}clue.png');
      await valid.writeAsBytes(List<int>.filled(32, 1));
      await notifier.addMediaFile(XFile(valid.path));
      var state = noToken.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.media.single.status, RescueCommentUploadStatus.failed);
      expect(state.media.single.errorMessage, contains('đăng nhập'));

      notifier.removeMedia(state.media.single.localId);
      state = noToken.read(rescueCommentProvider(sampleCommentCaseId));
      expect(state.media, isEmpty);

      notifier.setDraftText('Giữ lại khi phiên đăng nhập hết hạn.');
      expect(await notifier.send(), isFalse);
      expect(
        noToken.read(rescueCommentProvider(sampleCommentCaseId)).errorMessage,
        contains('hết hạn'),
      );
    },
  );

  testWidgets('closed discussion renders safe read-only and error states', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueCommentSource(comments: const [])
      ..listError = const RescueCommentApiException(
        'Ca cứu hộ đã đóng bình luận.',
        code: 'RESCUE_010',
        statusCode: 409,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueCommentSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
          rescueCommentClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 7, 27, 10, 30),
          ),
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(detail: sampleCaseDetail()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RescueCommentScreen(caseId: sampleCommentCaseId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('rescue-comment-closed-warning')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rescue-comment-error')), findsOneWidget);
    expect(find.text('Chưa tải được bình luận'), findsOneWidget);
    expect(find.text('Thử tải lại'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('rescue-comment-field')))
          .enabled,
      isFalse,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('empty discussion invites a privacy-safe first comment', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueCommentSourceProvider.overrideWithValue(
            FakeRescueCommentSource(comments: const []),
          ),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(detail: sampleCaseDetail()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RescueCommentScreen(caseId: sampleCommentCaseId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có bình luận'), findsOneWidget);
    expect(find.textContaining('không kèm vị trí riêng tư'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('comment media preserves the bounded API aspect ratio', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueCommentSourceProvider.overrideWithValue(
            FakeRescueCommentSource(),
          ),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(detail: sampleCaseDetail()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RescueCommentScreen(caseId: sampleCommentCaseId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final media = find.byKey(
      const ValueKey(
        'rescue-comment-image-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
    );
    final aspectRatio = tester.widget<AspectRatio>(
      find.descendant(of: media, matching: find.byType(AspectRatio)),
    );
    expect(aspectRatio.aspectRatio, closeTo(4 / 3, 0.001));
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'comment screen has privacy-safe composer and survives keyboard inset',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = FakeRescueCommentSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueCommentSourceProvider.overrideWithValue(source),
            authAccessTokenProvider.overrideWith((ref) async => 'token'),
            rescueCommentClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 7, 27, 10, 30),
            ),
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: sampleCaseDetail()),
            ),
            rescueCommentMediaBuilderProvider.overrideWithValue(
              (context, media) => Container(
                key: ValueKey('fixture-media-${media.mediaId}'),
                height: 140,
                color: const Color(0xFF95D5B2),
                alignment: Alignment.center,
                child: const Text('Ảnh manh mối'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const RescueCommentScreen(caseId: sampleCommentCaseId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('rescue-comment-privacy-warning')),
        findsOneWidget,
      );
      expect(find.text('Minh Anh'), findsOneWidget);
      expect(find.text('15 phút trước'), findsOneWidget);
      expect(find.text('Ảnh manh mối'), findsOneWidget);
      expect(find.byTooltip('Vị trí'), findsNothing);
      expect(find.byIcon(Icons.location_on), findsNothing);
      expect(find.byKey(const Key('rescue-comment-composer')), findsOneWidget);

      final commentList = find.byKey(const Key('rescue-comment-list'));
      final commentScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Lâm Hoàng'),
        300,
        scrollable: commentScrollable,
      );
      expect(find.text('Lâm Hoàng'), findsOneWidget);
      expect(find.text('40 phút trước'), findsOneWidget);

      await tester.drag(commentList, const Offset(0, 600));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'rescue-comment-options-22222222-2222-4222-8222-222222222222',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tùy chọn bình luận'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rescue-comment-field')));
      await setKeyboardInset(tester, bottom: 300);
      await tester.enterText(
        find.byKey(const Key('rescue-comment-field')),
        'Composer vẫn ở trên bàn phím.',
      );
      await tester.pump();

      final composer = tester.getRect(
        find.byKey(const Key('rescue-comment-composer')),
      );
      expect(composer.bottom, lessThanOrEqualTo(544));
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'ST-18 send failure keeps retry and composer reachable at large text',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      await tester.runAsync(loadPawMateTestFonts);
      final source = FakeRescueCommentSource()..failSends = 1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueCommentSourceProvider.overrideWithValue(source),
            authAccessTokenProvider.overrideWith((ref) async => 'token'),
            rescueCommentClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 7, 27, 10, 30),
            ),
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: sampleCaseDetail()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const RescueCommentScreen(caseId: sampleCommentCaseId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'Bình luận. LuLu • Poodle màu nâu • Q. Tân Bình • Chưa thấy',
        ),
        findsOneWidget,
      );
      final caseSummary = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('LuLu'),
      );
      expect(caseSummary, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(caseSummary).didExceedMaxLines,
        isFalse,
        reason:
            'Visible P2-06 case context must not ellipsize at text scale 2.0',
      );

      final field = find.byKey(const Key('rescue-comment-field'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await setKeyboardInset(tester, bottom: 300);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'Mình vẫn đang theo dõi khu vực này.');
      await tester.pumpAndSettle();

      final send = find.byKey(const Key('rescue-comment-send'));
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();

      final error = find.byKey(const Key('rescue-comment-error'));
      expect(error, findsOneWidget);
      await tester.ensureVisible(error);
      await tester.pumpAndSettle();
      expect(find.text('Gửi lại'), findsOneWidget);

      final retry = find.text('Gửi lại');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      final retryButton = find.ancestor(
        of: retry,
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(retryButton).height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(find.byKey(const Key('rescue-comment-composer'))).bottom,
        lessThanOrEqualTo(268),
      );
      expectNoFlutterOverflow(tester);
      await captureDay115(tester, 'ST-18');
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rescue-comment-error')), findsNothing);
      expect(find.text('Mình vẫn đang theo dõi khu vực này.'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        isEmpty,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('production router renders P2-06 when both flags are enabled', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final commentSource = FakeRescueCommentSource();
    final container = ProviderContainer(
      overrides: [
        appFeatureAvailabilityProvider.overrideWithValue(
          const AppFeatureAvailability(rescueBrowse: true, rescueCreate: true),
        ),
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue<AuthSession?>.data(_session),
        ),
        rescueCommentSourceProvider.overrideWithValue(commentSource),
        rescueCommentClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 27, 10, 30),
        ),
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: sampleCaseDetail()),
        ),
        rescueCommentMediaBuilderProvider.overrideWithValue(
          (context, media) =>
              const SizedBox(height: 80, child: Text('route media')),
        ),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    router.go('/rescue/$sampleCommentCaseId/comment');
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

    expect(
      router.routeInformationProvider.value.uri.path,
      '/rescue/$sampleCommentCaseId/comment',
    );
    expect(find.byKey(const Key('rescue-comment-screen')), findsOneWidget);
    expect(find.byKey(const Key('rescue-comment-field')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

ProviderContainer _commentContainer(
  FakeRescueCommentSource source, {
  String? accessToken = 'comment-token',
}) => ProviderContainer(
  overrides: [
    rescueCommentSourceProvider.overrideWithValue(source),
    authAccessTokenProvider.overrideWith((ref) async => accessToken),
    rescueCommentClockProvider.overrideWithValue(
      () => DateTime.utc(2026, 7, 27, 10, 30),
    ),
  ],
);

Map<String, dynamic> _commentPayload({required int hour}) => {
  'commentId': '11111111-1111-4111-8111-${hour.toString().padLeft(12, '0')}',
  'caseId': sampleCommentCaseId,
  'author': {
    'userId': 'public-user',
    'displayName': 'Cộng đồng',
    'avatarUrl': 'https://example.test/avatar.png',
    'phone': '0900000000',
  },
  'body': 'Đã nhìn thấy bé ở khu vực công khai.',
  'media': <Map<String, dynamic>>[],
  'createdAt': '2026-07-27T${hour.toString().padLeft(2, '0')}:00:00.000Z',
  'updatedAt': '2026-07-27T${hour.toString().padLeft(2, '0')}:00:00.000Z',
  'moderationState': 'visible',
  'privateLocation': {
    'formattedAddress': 'private-address',
    'latitude': 10.812345,
    'longitude': 106.712345,
  },
  'ownerUserId': 'private-owner',
};

const _session = AuthSession(
  user: AuthUser(
    id: 'day45-user',
    email: 'day45@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'day45-test-access',
  refreshToken: 'day45-test-refresh',
  accessTokenExpiresAt: '2026-07-28T00:00:00.000Z',
  refreshTokenExpiresAt: '2026-08-27T00:00:00.000Z',
);

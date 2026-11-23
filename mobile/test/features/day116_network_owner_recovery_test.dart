import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/media/image_picker_service.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_state_view.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_text_field.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';
import 'adoption/adoption_ui_test_support.dart';
import 'rescue/rescue_comment_test_fixtures.dart';
import 'rescue/rescue_test_fixtures.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    final suffix = scale.toString().replaceAll('.', '-');
    for (final discussion in [false, true]) {
      final owner = discussion ? 'P2-08' : 'P2-06';
      testWidgets(
        'D116 R15 D116-P04 $owner text$scale semantics media actions and closed state',
        (tester) async {
          final picker = _CancelPicker();
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              imagePickerProvider.overrideWithValue(picker),
              rescueCommentSourceProvider.overrideWithValue(
                FakeRescueCommentSource(comments: []),
              ),
              rescueApiProvider.overrideWithValue(
                FakeRescueSource(detail: sampleCaseDetail()),
              ),
              authAccessTokenProvider.overrideWith(
                (ref) async => 'fixture-token',
              ),
              privacyDefaultsProvider.overrideWith(_PrivacyFixture.new),
            ],
          );
          addTearDown(container.dispose);
          final router = GoRouter(
            initialLocation: '/proof',
            routes: [
              GoRoute(
                path: '/proof',
                builder: (_, _) => RescueCommentScreen(
                  caseId: sampleCommentCaseId,
                  discussionMode: discussion,
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await _pump(tester, scale, router, container);
          expectNoFlutterOverflow(tester);
          final targets = discussion
              ? ['rescue-comment-attach-image', 'rescue-comment-attach-video']
              : ['rescue-comment-attach'];
          for (final key in targets) {
            final target = find.byKey(Key(key));
            await _touch(tester, target);
            await _activateSemantics(tester, target);
            expectNoFlutterOverflow(tester);
            if (!discussion) {
              expect(find.text('Chọn ảnh'), findsOneWidget);
              await tester.tap(find.text('Chọn ảnh'));
              await tester.pumpAndSettle();
              expectNoFlutterOverflow(tester);
              await _activateSemantics(tester, target);
              final video = find.byKey(const Key('rescue-comment-pick-video'));
              await _touch(tester, video);
              await captureDay116(tester, 'R15-P06-sheet-text$suffix');
              await _activateSemantics(tester, video);
            }
          }
          expect(picker.images, 1);
          expect(picker.videos, 1);
          container
              .read(rescueCommentProvider(sampleCommentCaseId).notifier)
              .markClosed();
          await tester.pumpAndSettle();
          final handle = tester.ensureSemantics();
          try {
            await tester.pump();
            for (final key in [...targets, 'rescue-comment-send']) {
              final data = tester
                  .getSemantics(find.byKey(Key(key)))
                  .getSemanticsData();
              expect(data.label.trim(), isNotEmpty);
              expect(data.hasAction(SemanticsAction.tap), isFalse);
            }
          } finally {
            handle.dispose();
          }
          final warning = find.byKey(
            const Key('rescue-comment-closed-warning'),
          );
          await tester.ensureVisible(warning);
          await tester.pumpAndSettle();
          expect(warning.hitTestable(), findsOneWidget);
          await captureDay116(tester, 'R15-P04-$owner-closed-text$suffix');
          expectNoFlutterOverflow(tester);
        },
      );
    }
    testWidgets(
      'D116 R15 ST-18 P2-08 text$scale real send retry preserves payload key',
      (tester) async {
        final source = FakeRescueCommentSource(comments: [])..failSends = 1;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            rescueCommentSourceProvider.overrideWithValue(source),
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: sampleCaseDetail()),
            ),
            authAccessTokenProvider.overrideWith(
              (ref) async => 'fixture-token',
            ),
            privacyDefaultsProvider.overrideWith(_PrivacyFixture.new),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/rescue/$sampleCommentCaseId/discussion',
          routes: [
            GoRoute(
              path: '/rescue/:id/discussion',
              builder: (_, state) => RescueCommentScreen(
                caseId: state.pathParameters['id']!,
                discussionMode: true,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await _pump(tester, scale, router, container);
        final field = find.byKey(const Key('rescue-comment-field'));
        await tester.enterText(field, 'Manh mối an toàn chưa gửi.');
        await setKeyboardInset(tester, bottom: 200);
        await tester.pumpAndSettle();
        final send = find.byKey(const Key('rescue-comment-send'));
        await _touch(tester, send);
        await _activateSemantics(tester, send);
        await tester.pumpAndSettle();
        final failed = container.read(
          rescueCommentProvider(sampleCommentCaseId),
        );
        expect(failed.pendingSendKey, isNotNull);
        expect(failed.draftText, 'Manh mối an toàn chưa gửi.');
        expect(failed.comments, isEmpty);
        expect(source.sentBodies, ['Manh mối an toàn chưa gửi.']);
        expect(source.sentKeys.single, failed.pendingSendKey);
        expect(
          tester.widget<TextField>(field).controller!.text,
          failed.draftText,
        );
        final retry = find.widgetWithText(TextButton, 'Gửi lại');
        await _touch(tester, retry);
        expect(tester.getRect(retry).bottom, lessThanOrEqualTo(368));
        await captureDay116(tester, 'R15-ST18-P2-08-error-text$suffix');
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(source.sentKeys, [failed.pendingSendKey, failed.pendingSendKey]);
        expect(source.sentBodies, [
          'Manh mối an toàn chưa gửi.',
          'Manh mối an toàn chưa gửi.',
        ]);
        expect(source.sentMediaIds, [<String>[], <String>[]]);
        expect(source.sentReplyToCommentIds, [null, null]);
        expect(source.comments, hasLength(1));
        expect(
          source.comments.single.moderationState,
          RescueCommentModerationState.visible,
        );
        final saved = container.read(
          rescueCommentProvider(sampleCommentCaseId),
        );
        expect(saved.comments.single.body, 'Manh mối an toàn chưa gửi.');
        expect(saved.draftText, isEmpty);
        expect(saved.pendingSendKey, isNull);
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(find.byKey(const Key('rescue-comment-error')), findsNothing);
        await captureDay116(tester, 'R15-ST18-P2-08-sent-text$suffix');
        expectNoFlutterOverflow(tester);
      },
    );
    for (final discussion in [false, true]) {
      final owner = discussion ? 'P2-08' : 'P2-06';
      testWidgets(
        'D116 R15 ST-02 $owner text$scale real request retry preserves draft',
        (tester) async {
          final source =
              FakeRescueCommentSource(
                  comments: sampleComments().take(1).toList(),
                )
                ..listError = const RescueCommentApiException(
                  'Máy chủ tạm lỗi. Thử tải lại.',
                  statusCode: 503,
                );
          final details = FakeRescueSource(detail: sampleCaseDetail());
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              rescueCommentSourceProvider.overrideWithValue(source),
              rescueApiProvider.overrideWithValue(details),
              authAccessTokenProvider.overrideWith(
                (ref) async => 'fixture-token',
              ),
              privacyDefaultsProvider.overrideWith(_PrivacyFixture.new),
              rescueCommentClockProvider.overrideWithValue(
                () => DateTime.utc(2026, 7, 27, 11),
              ),
            ],
          );
          addTearDown(container.dispose);
          container
              .read(rescueCommentProvider(sampleCommentCaseId).notifier)
              .setDraftText('Manh mối chưa gửi.');
          final router = GoRouter(
            initialLocation:
                '/rescue/$sampleCommentCaseId/${discussion ? 'discussion' : 'comment'}',
            routes: [
              GoRoute(
                path: '/rescue/:id/comment',
                builder: (_, state) =>
                    RescueCommentScreen(caseId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/rescue/:id/discussion',
                builder: (_, state) => RescueCommentScreen(
                  caseId: state.pathParameters['id']!,
                  discussionMode: true,
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await _pump(tester, scale, router, container);
          expect(
            tester
                .widget<RescueCommentScreen>(find.byType(RescueCommentScreen))
                .discussionMode,
            discussion,
          );
          expect(source.requestedCaseIds, [sampleCommentCaseId]);
          expect(details.detailCaseIds, [sampleCommentCaseId]);
          expect(
            container.read(rescueCommentProvider(sampleCommentCaseId)).status,
            RescueCommentLoadStatus.error,
          );
          final error = find.byKey(const Key('rescue-comment-error'));
          expect(error, findsOneWidget);
          final retry = find.widgetWithText(TextButton, 'Thử tải lại');
          await _touch(tester, retry);
          final field = find.byKey(const Key('rescue-comment-field'));
          expect(
            tester.widget<TextField>(field).controller!.text,
            'Manh mối chưa gửi.',
          );
          expect(find.text(sampleComments().first.body), findsNothing);
          await captureDay116(tester, 'R15-ST02-$owner-error-text$suffix');
          source.listError = null;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(source.requestedCaseIds, [
            sampleCommentCaseId,
            sampleCommentCaseId,
          ]);
          expect(source.sentBodies, isEmpty);
          expect(source.uploadAttempts, 0);
          expect(find.byKey(const Key('rescue-comment-error')), findsNothing);
          expect(
            container.read(rescueCommentProvider(sampleCommentCaseId)).status,
            RescueCommentLoadStatus.ready,
          );
          expect(
            container
                .read(rescueCommentProvider(sampleCommentCaseId))
                .comments
                .single
                .body,
            sampleComments().first.body,
          );
          expect(
            tester.widget<TextField>(field).controller!.text,
            'Manh mối chưa gửi.',
          );
          final body = find.text(sampleComments().first.body);
          await tester.scrollUntilVisible(
            body,
            100,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(body.hitTestable(), findsOneWidget);
          await captureDay116(tester, 'R15-ST02-$owner-ready-text$suffix');
          expectNoFlutterOverflow(tester);
        },
      );
    }
    testWidgets(
      'D116 R15 ST-02 P2-04 text$scale real detail retry restores same case',
      (tester) async {
        final source = _RetryCaseSource();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [rescueApiProvider.overrideWithValue(source)],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/rescue/$sampleCommentCaseId',
          routes: [
            GoRoute(
              path: '/rescue/:id',
              builder: (_, state) =>
                  RescueCaseDetailScreen(caseId: state.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(router.dispose);
        await _pump(tester, scale, router, container);
        expect(source.detailCaseIds, [sampleCommentCaseId]);
        // The provider explicitly uses defaultRetry (ten bounded attempts),
        // overriding container.retry. Reach its terminal error in fake time.
        for (var retry = 0; retry < 10; retry++) {
          await tester.pump(const Duration(seconds: 7));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(source.detailCaseIds, List.filled(11, sampleCommentCaseId));
        expect(find.byKey(const Key('rescue-detail-error')), findsOneWidget);
        expect(
          find.byKey(const Key('rescue-detail-comment-bar')),
          findsNothing,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('rescue-detail-share')))
              .onPressed,
          isNull,
        );
        final retry = find.widgetWithText(PawMateButton, 'Thử lại');
        await _touch(tester, retry);
        await captureDay116(tester, 'R15-ST02-P2-04-error-text$suffix');
        source.fail = false;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(source.detailCaseIds, List.filled(12, sampleCommentCaseId));
        expect(find.byKey(const Key('rescue-detail-error')), findsNothing);
        expect(find.text('LuLu'), findsOneWidget);
        expect(
          find.byKey(const Key('rescue-detail-comment-bar')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('rescue-detail-share')))
              .onPressed,
          isNotNull,
        );
        await captureDay116(tester, 'R15-ST02-P2-04-ready-text$suffix');
        expectNoFlutterOverflow(tester);
      },
    );
    testWidgets(
      'D116 R15 ST-01 P2-11 text$scale offline retry restores saved request draft',
      (tester) async {
        final source = FakeAdoptionUiSource(
          detailError: const AdoptionApiException(
            'Không thể kết nối. Hãy thử lại.',
          ),
        );
        final store = _RequestDraftFixture();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            adoptionSourceProvider.overrideWithValue(source),
            adoptionRequestChatSourceProvider.overrideWithValue(
              _NoRequestWrites(),
            ),
            adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
            authSessionSnapshotProvider.overrideWithValue(
              const AsyncData<AuthSession?>(_session),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/adoption/$adoptionListingId/request',
          routes: [
            GoRoute(
              path: '/adoption/:id/request',
              builder: (_, state) => AdoptionRequestFormScreen(
                listingId: state.pathParameters['id']!,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await _pump(tester, scale, router, container);
        expect(source.detailCalls, [adoptionListingId]);
        expect(store.reads, 1);
        expect(
          find.byKey(const Key('adoption-request-submit-cta')),
          findsNothing,
        );
        expect(
          tester
              .widget<PawMateStateView>(
                find.byKey(const Key('adoption-request-error')),
              )
              .type,
          PawMateStateType.offline,
        );
        final retry = find.widgetWithText(PawMateButton, 'Thử lại');
        await _touch(tester, retry);
        await captureDay116(tester, 'R15-ST01-P2-11-offline-text$suffix');
        source.detailError = null;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(source.detailCalls, [adoptionListingId, adoptionListingId]);
        expect(store.reads, 2);
        expect(find.byKey(const Key('adoption-request-error')), findsNothing);
        final care = find.byKey(const Key('adoption-request-care-plan-field'));
        await tester.scrollUntilVisible(
          care,
          130,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<PawMateTextField>(care).controller!.text,
          'Khám định kỳ và chăm sóc hằng ngày.',
        );
        expect(
          find.byKey(const Key('adoption-request-submit-cta')).hitTestable(),
          findsOneWidget,
        );
        expect(source.decisionCalls, isEmpty);
        await captureDay116(tester, 'R15-ST01-P2-11-ready-text$suffix');
        expectNoFlutterOverflow(tester);
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  double scale,
  GoRouter router,
  ProviderContainer container,
) async {
  await setTestViewport(tester, size: const Size(320, 568));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _touch(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
  expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final semantics = tester.getSemantics(target).getSemanticsData();
    expect(semantics.label.trim(), isNotEmpty);
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
  } finally {
    handle.dispose();
  }
}

Future<void> _activateSemantics(WidgetTester tester, Finder target) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final node = tester.getSemantics(target);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
  } finally {
    handle.dispose();
  }
}

class _CancelPicker extends ImagePicker {
  int images = 0, videos = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    images++;
    return null;
  }

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    videos++;
    return null;
  }
}

class _RetryCaseSource extends FakeRescueSource {
  bool fail = true;
  @override
  Future<RescueCaseDetail> getCase(String caseId) async {
    detailCaseIds.add(caseId);
    if (fail) {
      throw const RescueApiException(
        'Máy chủ tạm lỗi. Thử tải lại.',
        statusCode: 503,
      );
    }
    return sampleCaseDetail(caseId: caseId);
  }
}

class _PrivacyFixture extends PrivacyDefaultsNotifier {
  @override
  Future<PrivacyDefaults> build() async => PrivacyDefaults(
    userId: 'r15-owner',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 15),
  );
}

class _RequestDraftFixture implements AdoptionRequestChatDraftStore {
  int reads = 0;
  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async {
    expect(userId, 'r15-owner');
    expect(listingId, adoptionListingId);
    reads++;
    return const AdoptionRequestDraft(
      livingCondition: 'Căn hộ',
      petExperience: 'Đã có kinh nghiệm',
      carePlan: 'Khám định kỳ và chăm sóc hằng ngày.',
      commitmentAccepted: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected draft mutation: ${invocation.memberName}');
}

class _NoRequestWrites implements AdoptionRequestChatSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected request/chat operation: ${invocation.memberName}',
  );
}

const _session = AuthSession(
  user: AuthUser(
    id: 'r15-owner',
    email: 'fixture@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'fixture-token',
  refreshToken: 'fixture-refresh',
  accessTokenExpiresAt: '2099-01-01T00:00:00Z',
  refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
);

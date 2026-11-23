import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_text_field.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_request_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';
import 'adoption/adoption_ui_test_support.dart';
import 'rescue/rescue_comment_test_fixtures.dart';
import 'rescue/rescue_test_fixtures.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  setUpAll(() => GoRouter.optionURLReflectsImperativeAPIs = true);
  tearDownAll(() => GoRouter.optionURLReflectsImperativeAPIs = false);
  for (final scale in [1.0, 1.3, 2.0]) {
    final suffix = scale.toString().replaceAll('.', '-');
    for (final discussion in [false, true]) {
      final owner = discussion ? 'P2-08' : 'P2-06';
      testWidgets(
        'D116 R17 ST-01 $owner text$scale offline retry retains unsent draft',
        (tester) async {
          final source = FakeRescueCommentSource(comments: [])
            ..listError = const RescueCommentApiException(
              'Không thể kết nối. Nội dung chưa gửi vẫn được giữ.',
            );
          final container = _comments(source);
          addTearDown(container.dispose);
          container
              .read(rescueCommentProvider(sampleCommentCaseId).notifier)
              .setDraftText('Manh mối đang chờ kết nối.');
          final path =
              '/rescue/$sampleCommentCaseId/${discussion ? 'discussion' : 'comment'}';
          final router = _rescueRouter(path);
          addTearDown(router.dispose);
          await _pump(tester, scale, router, container);
          expect(source.requestedCaseIds, [sampleCommentCaseId]);
          final field = find.byKey(const Key('rescue-comment-field'));
          expect(
            tester.widget<TextField>(field).controller!.text,
            'Manh mối đang chờ kết nối.',
          );
          final error = find.byKey(const Key('rescue-comment-error'));
          expect(error, findsOneWidget);
          final retry = find.widgetWithText(TextButton, 'Thử tải lại');
          await _touch(tester, retry);
          await captureDay116(tester, 'R17-ST01-$owner-offline-text$suffix');
          source.listError = null;
          source.comments = sampleComments().take(1).toList();
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(source.requestedCaseIds, [
            sampleCommentCaseId,
            sampleCommentCaseId,
          ]);
          expect(error, findsNothing);
          final state = container.read(
            rescueCommentProvider(sampleCommentCaseId),
          );
          expect(state.status, RescueCommentLoadStatus.ready);
          expect(state.comments.single.body, source.comments.single.body);
          expect(state.draftText, 'Manh mối đang chờ kết nối.');
          expect(
            tester.widget<TextField>(field).controller!.text,
            state.draftText,
          );
          expect(source.sentBodies, isEmpty);
          await captureDay116(tester, 'R17-ST01-$owner-ready-text$suffix');
          expectNoFlutterOverflow(tester);
        },
      );
    }
    testWidgets(
      'D116 R17 ST-18 P2-04 text$scale detail entry send failure retry returns safely',
      (tester) async {
        final source = FakeRescueCommentSource(comments: [])..failSends = 1;
        final container = _comments(source);
        addTearDown(container.dispose);
        final router = _rescueRouter('/rescue/$sampleCommentCaseId');
        addTearDown(router.dispose);
        await _pump(tester, scale, router, container);
        expect(
          find.byKey(const Key('rescue-detail-comment-bar')),
          findsOneWidget,
        );
        final entry = find.widgetWithText(PawMateButton, 'Bình luận');
        await _touch(tester, entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/rescue/$sampleCommentCaseId/comment',
        );
        final field = find.byKey(const Key('rescue-comment-field'));
        await tester.enterText(field, 'Đã thấy bé gần công viên.');
        await setKeyboardInset(tester, bottom: 200);
        await tester.pumpAndSettle();
        final send = find.byKey(const Key('rescue-comment-send'));
        await _touch(tester, send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        final failed = container.read(
          rescueCommentProvider(sampleCommentCaseId),
        );
        expect(failed.draftText, 'Đã thấy bé gần công viên.');
        expect(failed.pendingSendKey, isNotNull);
        expect(failed.comments, isEmpty);
        expect(
          tester.widget<TextField>(field).controller!.text,
          failed.draftText,
        );
        final retry = find.widgetWithText(TextButton, 'Gửi lại');
        await _touch(tester, retry);
        expect(tester.getRect(retry).bottom, lessThanOrEqualTo(368));
        await captureDay116(tester, 'R17-ST18-P204-error-text$suffix');
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(source.sentKeys, [failed.pendingSendKey, failed.pendingSendKey]);
        expect(source.sentBodies, [failed.draftText, failed.draftText]);
        expect(source.sentMediaIds, [<String>[], <String>[]]);
        expect(source.sentReplyToCommentIds, [null, null]);
        expect(source.comments, hasLength(1));
        expect(source.comments.single.caseId, sampleCommentCaseId);
        expect(
          container.read(rescueCommentProvider(sampleCommentCaseId)).draftText,
          isEmpty,
        );
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        await setKeyboardInset(tester, bottom: 0);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await captureDay116(tester, 'R17-ST18-P204-sent-text$suffix');
        final back = find.byTooltip('Quay lại').last;
        await _touch(tester, back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/rescue/$sampleCommentCaseId',
        );
        expect(
          find.byKey(const Key('rescue-detail-comment-bar')),
          findsOneWidget,
        );
        expect(source.comments, hasLength(1));
        expectNoFlutterOverflow(tester);
      },
    );
    testWidgets(
      'D116 R17 ST-19 P2-10 text$scale profile entry retries exact request draft',
      (tester) async {
        final listing = FakeAdoptionUiSource();
        final store = _DraftStore();
        final source = _Requests();
        final container = _adoption(listing, source, store);
        addTearDown(container.dispose);
        final router = _adoptionRouter('/adoption/$adoptionListingId');
        addTearDown(router.dispose);
        await _pump(tester, scale, router, container);
        final entry = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Mở biểu mẫu gửi yêu cầu nhận nuôi Mochi',
        );
        await _touch(tester, entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/adoption/$adoptionListingId/request',
        );
        expect(store.reads, 1);
        final initial = container.read(
          adoptionRequestProvider(adoptionListingId),
        );
        expect(initial.canSubmit, isTrue);
        final submit = find.widgetWithText(PawMateButton, 'Gửi yêu cầu');
        await _touch(tester, submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        final failed = container.read(
          adoptionRequestProvider(adoptionListingId),
        );
        expect(
          failed.errorMessage,
          'Không thể kết nối. Bản nháp vẫn được giữ để thử lại.',
        );
        expect(failed.result, isNull);
        expect(failed.draft.toRequestJson(), initial.draft.toRequestJson());
        expect(store.draft.toRequestJson(), initial.draft.toRequestJson());
        expect(failed.draft.pendingSubmitKey, isNotNull);
        final care = find.byKey(const Key('adoption-request-care-plan-field'));
        await tester.scrollUntilVisible(
          care,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<PawMateTextField>(care).controller!.text,
          initial.draft.carePlan,
        );
        final retry = find.widgetWithText(PawMateButton, 'Gửi lại yêu cầu');
        await _touch(tester, retry);
        await captureDay116(tester, 'R17-ST19-P210-error-text$suffix');
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(source.keys, [
          failed.draft.pendingSubmitKey,
          failed.draft.pendingSubmitKey,
        ]);
        expect(source.listings, [adoptionListingId, adoptionListingId]);
        expect(source.payloads, [
          initial.draft.toRequestJson(),
          initial.draft.toRequestJson(),
        ]);
        expect(source.stored, hasLength(1));
        final saved = container.read(
          adoptionRequestProvider(adoptionListingId),
        );
        expect(saved.result!.requestId, source.stored.single.requestId);
        expect(saved.draft.carePlan, isEmpty);
        expect(saved.errorMessage, isNull);
        expect(store.clears, 1);
        expect(store.contexts.single.petName, 'Mochi');
        expect(
          find.byKey(const Key('adoption-request-submitted')),
          findsOneWidget,
        );
        expect(find.text('Gửi lại yêu cầu'), findsNothing);
        await captureDay116(tester, 'R17-ST19-P210-saved-text$suffix');
        expectNoFlutterOverflow(tester);
      },
    );
    for (final fromProfile in [false, true]) {
      final emptyOwner = fromProfile ? 'P2-10' : 'P2-09';
      testWidgets(
        fromProfile
            ? 'D116 R23 ST-20 P2-10 text$scale actual back to deck entry empty requests returns to discovery'
            : 'D116 R17 ST-20 P2-09 text$scale deck entry empty requests returns to discovery',
        (tester) async {
          final listing = FakeAdoptionUiSource();
          final source = _Requests();
          final container = _adoption(listing, source, _DraftStore());
          addTearDown(container.dispose);
          final router = _adoptionRouter(
            fromProfile ? '/adoption/$adoptionListingId' : '/adoption',
          );
          addTearDown(router.dispose);
          await _pump(tester, scale, router, container);
          if (fromProfile) {
            expect(find.byType(AdoptionProfileScreen), findsOneWidget);
            final back = find.byTooltip('Quay lại');
            await _touch(tester, back);
            await tester.tap(back);
            await tester.pumpAndSettle();
            expect(find.byType(AdoptionSwipeDeckScreen), findsOneWidget);
            expect(source.listReads, 0);
          }
          final filter = find.byKey(const Key('adoption-filter-button'));
          await captureDay116(
            tester,
            '${fromProfile ? 'R23' : 'R17'}-ST20-${emptyOwner.replaceAll('-', '')}-entry-text$suffix',
          );
          await _touch(tester, filter);
          await tester.tap(filter);
          await tester.pumpAndSettle();
          final entry = find.byKey(const Key('adoption-my-requests-button'));
          await _touch(tester, entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            '/adoption/requests',
          );
          expect(source.listReads, 1);
          expect(
            find.byKey(const Key('my-adoption-requests-empty')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('my-adoption-requests-list')),
            findsNothing,
          );
          final discover = find.widgetWithText(
            PawMateButton,
            'Khám phá bé cần nhận nuôi',
          );
          await _touch(tester, discover);
          await captureDay116(
            tester,
            '${fromProfile ? 'R23' : 'R17'}-ST20-${emptyOwner.replaceAll('-', '')}-empty-text$suffix',
          );
          await tester.tap(discover);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/adoption');
          expect(
            find.byKey(const Key('adoption-swipe-deck-screen')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('adoption-filter-sheet')), findsNothing);
          expect(
            find.byKey(const Key('adoption-filter-button')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('my-adoption-requests-empty')),
            findsNothing,
          );
          expect(listing.listQueries, isNotEmpty);
          expect(listing.decisionCalls, isEmpty);
          expect(source.stored, isEmpty);
          await captureDay116(
            tester,
            '${fromProfile ? 'R23' : 'R17'}-ST20-${emptyOwner.replaceAll('-', '')}-discovery-text$suffix',
          );
          expectNoFlutterOverflow(tester);
        },
      );
    }
  }
}

ProviderContainer _comments(FakeRescueCommentSource source) =>
    ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        rescueCommentSourceProvider.overrideWithValue(source),
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: sampleCaseDetail()),
        ),
        authAccessTokenProvider.overrideWith((ref) async => 'fixture-token'),
        privacyDefaultsProvider.overrideWith(_Privacy.new),
      ],
    );

GoRouter _rescueRouter(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/rescue/:id',
      builder: (_, state) =>
          RescueCaseDetailScreen(caseId: state.pathParameters['id']!),
    ),
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

ProviderContainer _adoption(
  FakeAdoptionUiSource listing,
  _Requests source,
  _DraftStore store,
) => ProviderContainer(
  retry: (_, _) => null,
  overrides: [
    adoptionSourceProvider.overrideWithValue(listing),
    adoptionRequestChatSourceProvider.overrideWithValue(source),
    adoptionRequestListSourceProvider.overrideWithValue(source),
    adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
    adoptionSavedListingStoreProvider.overrideWithValue(
      MemoryAdoptionSavedListingStore(),
    ),
    authSessionSnapshotProvider.overrideWithValue(
      const AsyncData<AuthSession?>(_session),
    ),
  ],
);

GoRouter _adoptionRouter(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/adoption',
      builder: (_, _) => const AdoptionSwipeDeckScreen(),
    ),
    GoRoute(
      path: '/adoption/requests',
      builder: (_, _) => const MyAdoptionRequestsScreen(),
    ),
    GoRoute(
      path: '/adoption/:id/request',
      builder: (_, state) =>
          AdoptionRequestFormScreen(listingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/adoption/:id',
      builder: (_, state) =>
          AdoptionProfileScreen(listingId: state.pathParameters['id']!),
    ),
  ],
);

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
    final data = tester.getSemantics(target).getSemanticsData();
    expect('${data.label} ${data.tooltip}'.trim(), isNotEmpty);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  } finally {
    handle.dispose();
  }
}

class _Privacy extends PrivacyDefaultsNotifier {
  @override
  Future<PrivacyDefaults> build() async => PrivacyDefaults(
    userId: 'r17-owner',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 15),
  );
}

class _DraftStore implements AdoptionRequestChatDraftStore {
  AdoptionRequestDraft draft = const AdoptionRequestDraft(
    livingCondition: 'Căn hộ',
    petExperience: 'Đã có kinh nghiệm',
    carePlan: 'Chăm sóc hằng ngày.',
    commitmentAccepted: true,
  );
  int reads = 0, clears = 0;
  final contexts = <AdoptionChatContext>[];
  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async {
    expect(userId, 'r17-owner');
    expect(listingId, adoptionListingId);
    reads++;
    return draft;
  }

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {
    expect(userId, 'r17-owner');
    expect(listingId, adoptionListingId);
    this.draft = draft;
  }

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {
    expect(userId, 'r17-owner');
    expect(listingId, adoptionListingId);
    clears++;
    draft = const AdoptionRequestDraft();
  }

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {
    expect(userId, 'r17-owner');
    expect(threadId, 'r17-thread');
    contexts.add(context);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected store call: ${invocation.memberName}');
}

class _Requests
    implements AdoptionRequestChatSource, AdoptionRequestListSource {
  final keys = <String>[];
  final listings = <String>[];
  final payloads = <Map<String, dynamic>>[];
  final stored = <AdoptionRequestResult>[];
  int listReads = 0;
  @override
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    listReads++;
    return [];
  }

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) async {
    expect(accessToken, 'fixture-token');
    keys.add(idempotencyKey);
    listings.add(listingId);
    payloads.add(draft.toRequestJson());
    if (keys.length == 1) {
      throw const AdoptionApiException(
        'Fixture offline',
        code: 'NETWORK_OFFLINE',
      );
    }
    final result = AdoptionRequestResult(
      requestId: 'r17-request',
      listingId: listingId,
      adopterUserId: 'r17-owner',
      shelterId: 'r17-shelter',
      livingCondition: draft.livingCondition,
      petExperience: draft.petExperience,
      carePlan: draft.carePlan,
      commitmentAccepted: draft.commitmentAccepted,
      status: AdoptionRequestStatus.submitted,
      threadId: 'r17-thread',
      createdAt: DateTime.utc(2026, 10, 15),
    );
    stored.add(result);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected request call: ${invocation.memberName}');
}

const _session = AuthSession(
  user: AuthUser(
    id: 'r17-owner',
    email: 'fixture@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'fixture-token',
  refreshToken: 'fixture-refresh',
  accessTokenExpiresAt: '2099-01-01T00:00:00Z',
  refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
);

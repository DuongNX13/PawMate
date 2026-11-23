import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_request_provider.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';

import '../test/features/adoption/adoption_ui_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D112 Android adopter filter to profile to request to My Requests to Chat',
    (tester) async {
      await binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => binding.setSurfaceSize(null));
      final source = _Day112Source();
      final store = _Day112Store();
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router, source, store));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
      );

      await tester.tap(find.byKey(const Key('adoption-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mèo'));
      await tester.pump();
      expect(source.listQueries, hasLength(1));
      await tester.tap(find.byKey(const Key('adoption-apply-filters')));
      await _waitFor(
        tester,
        find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
      );
      expect(source.listQueries.last.species, AdoptionSpecies.cat);

      await tester.tap(find.byKey(const Key('adoption-profile-action')));
      await _waitFor(tester, find.byKey(const Key('adoption-profile-screen')));
      await tester.ensureVisible(find.text('Gửi yêu cầu nhận nuôi'));
      await tester.tap(find.text('Gửi yêu cầu nhận nuôi'));
      await _waitFor(tester, find.byKey(const Key('adoption-request-form')));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdoptionRequestFormScreen)),
      );
      container.read(adoptionRequestProvider(adoptionListingId).notifier)
        ..setLivingCondition('Căn hộ')
        ..setPetExperience('Đã có kinh nghiệm')
        ..setCarePlan('Nguyễn An')
        ..setCommitmentAccepted(true);
      await tester.pump();
      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await _waitFor(
        tester,
        find.byKey(const Key('adoption-request-submitted')),
      );

      await tester.ensureVisible(find.text('Xem đơn của tôi'));
      await tester.tap(find.text('Xem đơn của tôi'));
      await _waitFor(
        tester,
        find.byKey(const Key('my-adoption-requests-list')),
      );
      final chatAction = find.byKey(
        const Key('my-adoption-request-chat-request-day112'),
      );
      await tester.ensureVisible(chatAction);
      await tester.tap(chatAction);
      await _waitFor(tester, find.byKey(const Key('adoption-chat-composer')));

      await tester.enterText(
        find.byKey(const Key('adoption-chat-composer')),
        'Mình muốn đặt lịch gặp Mochi.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('adoption-chat-send')));
      await _waitFor(tester, find.text('Mình muốn đặt lịch gặp Mochi.'));
      expect(source.sentBodies, ['Mình muốn đặt lịch gặp Mochi.']);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  testWidgets('D112 Android shelter participant can read and send chat', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => binding.setSurfaceSize(null));
    final source = _Day112Source(
      participantRole: AdoptionChatParticipantRole.shelter,
    );
    await tester.pumpWidget(
      _chatApp(source, userId: 'shelter-day112', token: 'shelter-token'),
    );
    await _waitFor(tester, find.byKey(const Key('adoption-chat-composer')));
    await tester.enterText(
      find.byKey(const Key('adoption-chat-composer')),
      'Mái ấm đã nhận được yêu cầu.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('adoption-chat-send')));
    await _waitFor(tester, find.text('Mái ấm đã nhận được yêu cầu.'));
    expect(source.lastReadToken, 'shelter-token');
    expect(source.sentBodies, ['Mái ấm đã nhận được yêu cầu.']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D112 Android outsider is denied without exposing chat', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => binding.setSurfaceSize(null));
    final source = _Day112Source(denyChat: true);
    await tester.pumpWidget(
      _chatApp(source, userId: 'outsider-day112', token: 'outsider-token'),
    );
    await _waitFor(tester, find.byKey(const Key('adoption-chat-error')));
    expect(find.byKey(const Key('adoption-chat-composer')), findsNothing);
    expect(source.sentBodies, isEmpty);
    expect(source.lastReadToken, 'outsider-token');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'D112 Android expired and deleted requests keep chat but hide stale profile',
    (tester) async {
      await binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => binding.setSurfaceSize(null));
      final source = _Day112Source()
        ..requests = [
          _summary(
            requestId: 'expired',
            availability: AdoptionRequestListingAvailability.expired,
          ),
          _summary(
            requestId: 'deleted',
            availability: AdoptionRequestListingAvailability.deleted,
          ),
        ];
      final router = _router(initialLocation: '/adoption/requests');
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, source, _Day112Store()));
      await _waitFor(
        tester,
        find.byKey(const Key('my-adoption-requests-list')),
      );
      expect(
        find.byKey(const Key('my-adoption-request-profile-expired')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('my-adoption-request-profile-deleted')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('my-adoption-request-chat-expired')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('my-adoption-request-chat-deleted')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(GoRouter router, _Day112Source source, _Day112Store store) {
  return ProviderScope(
    overrides: [
      adoptionSourceProvider.overrideWithValue(source),
      adoptionRequestChatSourceProvider.overrideWithValue(source),
      adoptionRequestListSourceProvider.overrideWithValue(source),
      adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
      adoptionAccessTokenProvider.overrideWith((ref) async => 'adopter-token'),
      authSessionSnapshotProvider.overrideWith(
        (ref) async => _session('adopter-day112', 'adopter-token'),
      ),
      preferenceSourceProvider.overrideWithValue(_Day112Preferences()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

Widget _chatApp(
  _Day112Source source, {
  required String userId,
  required String token,
}) {
  return ProviderScope(
    overrides: [
      adoptionRequestChatSourceProvider.overrideWithValue(source),
      adoptionRequestChatDraftStoreProvider.overrideWithValue(_Day112Store()),
      authSessionSnapshotProvider.overrideWith(
        (ref) async => _session(userId, token),
      ),
      preferenceSourceProvider.overrideWithValue(_Day112Preferences()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ShelterChatScreen(threadId: 'thread-day112'),
    ),
  );
}

GoRouter _router({String initialLocation = '/adoption'}) => GoRouter(
  initialLocation: initialLocation,
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
      path: '/adoption/chat/:threadId',
      builder: (_, state) =>
          ShelterChatScreen(threadId: state.pathParameters['threadId']!),
    ),
    GoRoute(
      path: '/adoption/:listingId/request',
      builder: (_, state) => AdoptionRequestFormScreen(
        listingId: state.pathParameters['listingId']!,
      ),
    ),
    GoRoute(
      path: '/adoption/:listingId',
      builder: (_, state) =>
          AdoptionProfileScreen(listingId: state.pathParameters['listingId']!),
    ),
    for (final path in const [
      '/pets',
      '/vets/map',
      '/health',
      '/rescue',
      '/profile',
      '/profile/controls',
      '/notifications',
    ])
      GoRoute(path: path, builder: (_, _) => const Scaffold()),
  ],
);

AuthSession _session(String userId, String token) => AuthSession(
  user: AuthUser(
    id: userId,
    email: '$userId@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: token,
  refreshToken: 'refresh-$userId',
  accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
  refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
);

AdoptionRequestSummary _summary({
  String requestId = 'request-day112',
  AdoptionRequestListingAvailability availability =
      AdoptionRequestListingAvailability.available,
}) => AdoptionRequestSummary(
  requestId: requestId,
  listingId: adoptionListingId,
  petName: 'Mochi',
  status: AdoptionRequestStatus.submitted,
  listingAvailability: availability,
  threadId: 'thread-day112',
  createdAt: DateTime.utc(2026, 9, 18, 4),
  updatedAt: DateTime.utc(2026, 9, 18, 4),
);

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(finder, findsAtLeastNWidgets(1));
}

class _Day112Source
    implements
        AdoptionSource,
        AdoptionRequestChatSource,
        AdoptionRequestListSource {
  _Day112Source({
    this.participantRole = AdoptionChatParticipantRole.adopter,
    this.denyChat = false,
  });

  final AdoptionChatParticipantRole participantRole;
  final bool denyChat;
  final List<AdoptionListQuery> listQueries = [];
  final List<String> sentBodies = [];
  List<AdoptionRequestSummary> requests = [];
  String? lastReadToken;

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) async {
    listQueries.add(query);
    return uiAdoptionPage();
  }

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) async => uiAdoptionDetail(listingId: listingId);

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) async => AdoptionDecisionResult(
    listingId: listingId,
    adopterUserId: 'adopter-day112',
    decision: decision,
    createdAt: DateTime.utc(2026, 9, 18, 4),
  );

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) async {
    final summary = _summary();
    requests = [summary];
    return AdoptionRequestResult(
      requestId: summary.requestId,
      listingId: listingId,
      adopterUserId: 'adopter-day112',
      shelterId: 'shelter-day112',
      livingCondition: draft.livingCondition,
      petExperience: draft.petExperience,
      carePlan: draft.carePlan,
      commitmentAccepted: true,
      status: AdoptionRequestStatus.submitted,
      threadId: 'thread-day112',
      createdAt: summary.createdAt,
    );
  }

  @override
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  }) async => List.unmodifiable(requests);

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    lastReadToken = accessToken;
    if (denyChat) {
      throw const AdoptionApiException(
        'Không tìm thấy cuộc trò chuyện.',
        code: 'CHAT_NOT_FOUND',
        statusCode: 404,
      );
    }
    return AdoptionChatPage(
      messages: [
        for (var index = 0; index < sentBodies.length; index++)
          AdoptionChatMessage(
            messageId: 'message-$index',
            threadId: threadId,
            senderUserId: participantRole == AdoptionChatParticipantRole.shelter
                ? 'shelter-day112'
                : 'adopter-day112',
            body: sentBodies[index],
            media: const [],
            createdAt: DateTime.utc(2026, 9, 18, 4, index),
          ),
      ],
      thread: AdoptionChatThread(
        threadId: threadId,
        requestId: 'request-day112',
        participantRole: participantRole,
        lastReadAt: DateTime.utc(2026, 9, 18, 3),
        unreadCount: 0,
      ),
      hasMore: false,
      limit: limit,
    );
  }

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) async {
    sentBodies.add(body);
    return AdoptionChatMessage(
      messageId: 'message-${sentBodies.length}',
      threadId: threadId,
      senderUserId: participantRole == AdoptionChatParticipantRole.shelter
          ? 'shelter-day112'
          : 'adopter-day112',
      body: body,
      media: const [],
      createdAt: DateTime.utc(2026, 9, 18, 5),
    );
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async => AdoptionChatReadState(
    threadId: threadId,
    lastReadAt: DateTime.utc(2026, 9, 18, 5),
    unreadCount: 0,
  );

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) => Future.error(UnimplementedError('Media is outside this device proof.'));
}

class _Day112Store implements AdoptionRequestChatDraftStore {
  AdoptionRequestDraft requestDraft = const AdoptionRequestDraft();
  AdoptionChatDraft chatDraft = const AdoptionChatDraft();
  AdoptionChatContext? context;

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async {
    chatDraft = const AdoptionChatDraft();
  }

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {
    requestDraft = const AdoptionRequestDraft();
  }

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => context;

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => chatDraft;

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async => requestDraft;

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {
    this.context = context;
  }

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async {
    chatDraft = draft;
  }

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {
    requestDraft = draft;
  }
}

class _Day112Preferences implements PreferenceSource {
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: 'day112-user',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 9, 18),
  );

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) => Future.error(UnimplementedError());

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) => Future.error(UnimplementedError());

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async => defaults;
}

// QA-only journey readiness. Widget actions here are NOT TalkBack input proof.
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/domain/health_record.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/data/notification_api.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/notification_preferences_screen.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/test_support/day119_detail_support.dart' as detail;
import '../test/test_support/ui_test_helpers.dart';
import '../test/features/adoption/adoption_ui_test_support.dart' as adoption;
import 'day122_closure_recipes.dart' show closureDogAvatar, closureScrollFor;

typedef ClosureStage = Future<void> Function(String stage);

class ClosureChatSource implements AdoptionRequestChatSource {
  final sent = <String>[];
  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) => throw StateError('Request creation not in this journey');
  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async => AdoptionChatPage(
    messages: [
      AdoptionChatMessage(
        messageId: 'qa-greeting',
        threadId: threadId,
        senderUserId: 'qa-shelter',
        body: 'QA: Chào bạn và Mochi.',
        media: [],
        createdAt: DateTime.utc(2026, 7, 16, 9),
      ),
    ],
    thread: AdoptionChatThread(
      threadId: threadId,
      requestId: 'qa-request',
      participantRole: AdoptionChatParticipantRole.adopter,
      lastReadAt: DateTime.utc(2026, 7, 16, 9),
      unreadCount: 0,
    ),
    hasMore: false,
    limit: limit,
  );
  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async => AdoptionChatReadState(
    threadId: threadId,
    lastReadAt: DateTime.utc(2026, 7, 16, 9),
    unreadCount: 0,
  );
  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) async {
    sent.add(body);
    return AdoptionChatMessage(
      messageId: 'qa-sent-${sent.length}',
      threadId: threadId,
      senderUserId: 'qa-adopter',
      body: body,
      media: [],
      createdAt: DateTime.utc(2026, 7, 16, 9, sent.length),
    );
  }

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) => throw StateError('Media not in this journey');
}

Future<ClosureChatSource> pumpClosureAdoptionChatJourney(
  WidgetTester tester,
  Size size,
) async {
  await setTestViewport(tester, size: size);
  SharedPreferences.setMockInitialValues({});
  final store = SharedPreferencesAdoptionRequestChatDraftStore();
  await store.saveChatContext(
    userId: 'qa-adopter',
    threadId: 'qa-thread',
    context: const AdoptionChatContext(
      listingId: 'qa-listing',
      petName: 'Mochi',
      shelterId: 'qa-shelter',
    ),
  );
  final source = ClosureChatSource();
  final router = GoRouter(
    initialLocation: '/adoption/qa-listing',
    routes: [
      GoRoute(
        path: '/adoption',
        builder: (_, _) => const AdoptionSwipeDeckScreen(
          heroImageProvider: AssetImage(closureDogAvatar),
        ),
      ),
      GoRoute(
        path: '/adoption/requests',
        builder: (_, _) => const MyAdoptionRequestsScreen(),
      ),
      GoRoute(
        path: '/adoption/chat/:threadId',
        builder: (_, s) =>
            ShelterChatScreen(threadId: s.pathParameters['threadId']!),
      ),
      GoRoute(
        path: '/adoption/:listingId',
        builder: (_, s) => AdoptionProfileScreen(
          listingId: s.pathParameters['listingId']!,
          heroImageProvider: const AssetImage(closureDogAvatar),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  const session = AuthSession(
    user: AuthUser(
      id: 'qa-adopter',
      email: 'fixture@example.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: 'qa-local-only',
    refreshToken: 'qa-local-only',
    accessTokenExpiresAt: '2099-01-01T00:00:00Z',
    refreshTokenExpiresAt: '2099-01-02T00:00:00Z',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionSnapshotProvider.overrideWithValue(const AsyncData(session)),
        authAccessTokenProvider.overrideWith((_) async => 'qa-local-only'),
        adoptionSessionRevisionProvider.overrideWithValue(0),
        adoptionClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 16, 9),
        ),
        adoptionSourceProvider.overrideWithValue(
          adoption.FakeAdoptionUiSource(
            detail: adoption.uiAdoptionDetail(listingId: 'qa-listing'),
            page: adoption.uiAdoptionPage(
              items: [adoption.uiAdoptionSummary(listingId: 'qa-listing')],
            ),
          ),
        ),
        adoptionSavedListingStoreProvider.overrideWithValue(
          adoption.MemoryAdoptionSavedListingStore(),
        ),
        adoptionRequestChatSourceProvider.overrideWithValue(source),
        adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
        preferenceSourceProvider.overrideWithValue(_ClosurePreferenceSource()),
        myAdoptionRequestsProvider.overrideWithValue(
          AsyncData([
            AdoptionRequestSummary.fromJson({
              'requestId': 'qa-request',
              'listingId': 'qa-listing',
              'petName': 'Mochi',
              'status': 'reviewing',
              'listingAvailability': 'available',
              'threadId': 'qa-thread',
              'createdAt': '2026-07-16T08:00:00Z',
              'updatedAt': '2026-07-16T08:00:00Z',
            }),
          ]),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await detail.readyDay119(tester);
  return source;
}

Future<void> rehearseClosureAdoptionChatJourney(
  WidgetTester tester,
  ClosureChatSource source, {
  required ClosureStage capture,
}) async {
  Future<void> tap(Finder target) async {
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder sentMessage(String body) => find.descendant(
    of: find.byKey(const Key('adoption-chat-message-list')),
    matching: find.text(body),
  );

  Future<void> revealSentMessage(String body) async {
    // The context header precedes a lazily built message group. With a real
    // IME the group may not be built yet; a text finder alone is not a scroll
    // oracle. Resolve this screen's message list, never a global Scrollable.
    final list = find.byKey(const Key('adoption-chat-message-list'));
    expect(list, findsOneWidget);
    final scroll = find.descendant(of: list, matching: find.byType(Scrollable));
    expect(scroll, findsOneWidget);
    final position = tester.state<ScrollableState>(scroll).position;
    final message = sentMessage(body);
    // Lazy extents can change after the first layout. Bound the reveal and
    // fail rather than accepting a fixture effect without a visible bubble.
    for (var attempt = 0; attempt < 8; attempt++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      if (message.evaluate().isNotEmpty) {
        expect(message, findsOneWidget);
        await tester.ensureVisible(message);
        await tester.pumpAndSettle();
        if (message.hitTestable().evaluate().length == 1) return;
      }
    }
    expect(message.hitTestable(), findsOneWidget,
        reason: 'Sent message must be visible after bounded list reveal');
  }

  expect(find.byType(AdoptionProfileScreen), findsOneWidget);
  await capture('adoption-profile');
  await tap(find.byTooltip('Quay lại'));
  expect(find.byType(AdoptionSwipeDeckScreen), findsOneWidget);
  await tap(find.byKey(const Key('adoption-filter-button')));
  await tap(find.byKey(const Key('adoption-my-requests-button')));
  expect(find.byType(MyAdoptionRequestsScreen), findsOneWidget);
  await capture('my-adoption-requests');
  await tap(find.byKey(const Key('my-adoption-request-chat-qa-request')));
  expect(find.byType(ShelterChatScreen), findsOneWidget);
  expect(find.text('QA: Chào bạn và Mochi.'), findsOneWidget);
  await capture('shelter-chat');
  final composer = find.byKey(const Key('adoption-chat-composer'));
  await tap(find.byKey(const Key('adoption-chat-quick-reply-0')));
  expect(tester.widget<TextField>(composer).controller!.text, 'Đặt lịch hẹn');
  await capture('chat-quick-reply-draft');
  await tap(find.byKey(const Key('adoption-chat-send')));
  expect(source.sent, ['Đặt lịch hẹn']);
  await revealSentMessage('Đặt lịch hẹn');
  expect(sentMessage('Đặt lịch hẹn').hitTestable(), findsOneWidget);
  expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
  await capture('chat-quick-reply-sent');
  // Widget test IME only. Native IME input must be proven separately.
  await tester.showKeyboard(composer);
  await tester.enterText(composer, 'QA: Tôi muốn tìm hiểu về Mochi.');
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(composer).controller!.text,
    'QA: Tôi muốn tìm hiểu về Mochi.',
  );
  await tap(find.byKey(const Key('adoption-chat-send')));
  expect(source.sent, ['Đặt lịch hẹn', 'QA: Tôi muốn tìm hiểu về Mochi.']);
  await revealSentMessage('QA: Tôi muốn tìm hiểu về Mochi.');
  expect(sentMessage('QA: Tôi muốn tìm hiểu về Mochi.').hitTestable(), findsOneWidget);
  expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
  await capture('chat-composed-message-sent');
  FocusManager.instance.primaryFocus?.unfocus();
  if (tester.testTextInput.isRegistered) {
    tester.testTextInput.hide();
  } else {
    // IntegrationTest leaves the stub unregistered for the actual Android
    // keyboard. Do not call its assert-guarded fake hide() on that binding.
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }
  await tester.pumpAndSettle();
  await tap(find.byTooltip('Quay lại'));
  expect(find.byType(ShelterChatScreen), findsNothing);
  expect(find.byType(AdoptionSwipeDeckScreen), findsOneWidget);
  expect(source.sent, hasLength(2));
  await capture('chat-back-to-adoption');
}

class ClosureVetSource extends VetApi {
  ClosureVetSource() : super(Dio());
  final details = <String>[];
  final nearbyQueries = <VetNearbyRequest>[];
  final reviews = <String>[];
  static const clinic = VetDetail(
    id: 'qa-clinic',
    name: 'QA PetHome',
    city: 'TP Hồ Chí Minh',
    district: 'Quận 7',
    address: 'Địa chỉ QA tổng hợp',
    phone: '',
    services: ['Khám tổng quát'],
    seedRank: 1,
    averageRating: 4.8,
    reviewCount: 0,
    is24h: false,
    isOpen: true,
    readyForMap: true,
    latitude: 10.7769,
    longitude: 106.7009,
    openHours: ['08:00 - 21:00'],
    photoUrls: [],
    source: VetSource(
      url: 'https://example.test',
      list: 'QA',
      priorityTier: 'P0',
      enrichmentStatus: 'fixture',
      selectionReason: 'local-only',
    ),
  );
  @override
  Future<VetSearchResult> search(VetSearchRequest request) async =>
      VetSearchResult(items: [clinic], total: 1, limit: request.limit);
  @override
  Future<VetNearbyResult> nearby(VetNearbyRequest request) async {
    nearbyQueries.add(request);
    return VetNearbyResult(items: [clinic], total: 1, limit: request.limit);
  }

  @override
  Future<VetDetail> getDetail(String id) async {
    details.add(id);
    return clinic;
  }

  @override
  Future<VetReviewResult> listReviews(
    String id, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async {
    reviews.add(id);
    return VetReviewResult(
      items: [],
      summary: const VetReviewSummary(
        averageRating: null,
        reviewCount: 0,
        distribution: {},
      ),
      total: 0,
      limit: request.limit,
    );
  }
}

class ClosureVetLocation implements VetLocationService {
  bool denied = true;
  int requests = 0;
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    requests++;
    if (denied) {
      throw const VetLocationException(
        VetLocationFailureType.permissionDenied,
        'QA: Quyền vị trí bị từ chối',
      );
    }
    return const VetMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

class ClosureVetHarness {
  const ClosureVetHarness(this.router, this.source, this.location);
  final GoRouter router;
  final ClosureVetSource source;
  final ClosureVetLocation location;
}

Future<ClosureVetHarness> pumpClosureVetJourney(
  WidgetTester tester,
  Size size,
) async {
  await setTestViewport(tester, size: size);
  final source = ClosureVetSource();
  final location = ClosureVetLocation();
  final router = GoRouter(
    initialLocation: '/vets/map',
    routes: [
      GoRoute(path: '/vets/map', builder: (_, _) => const VetMapScreen()),
      GoRoute(path: '/vets/list', builder: (_, _) => const VetListScreen()),
      GoRoute(
        path: '/vets/:vetId',
        builder: (_, s) => VetDetailScreen(
          vetId: s.pathParameters['vetId']!,
          returnPath: s.uri.queryParameters['returnTo'] ?? '/vets/list',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vetApiProvider.overrideWithValue(source),
        vetLocationServiceProvider.overrideWithValue(location),
        // Exclude tile/network rendering only. Real screen, controls, API notifier,
        // detail and review sheet remain mounted. This is not a map visual proof.
        vetMapCanvasBuilderProvider.overrideWithValue(
          (center, items, style, onMarker, onError) =>
              const ColoredBox(color: Color(0xffF8F3EA)),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await detail.readyDay119(tester);
  return ClosureVetHarness(router, source, location);
}

Future<void> rehearseClosureVetJourney(
  WidgetTester tester,
  ClosureVetHarness h, {
  required ClosureStage capture,
}) async {
  Future<void> tap(Finder target) async {
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  expect(find.byKey(const ValueKey('permission-denied')), findsOneWidget);
  expect(h.location.requests, 1);
  expect(h.source.nearbyQueries, isEmpty);
  await capture('vet-location-denied');
  await tap(find.text('Xem dạng danh sách'));
  expect(find.byType(VetListScreen), findsOneWidget);
  await capture('vet-manual-list-fallback');
  await tap(find.byKey(const Key('vet-list-card-qa-clinic')));
  expect(find.byType(VetDetailScreen), findsOneWidget);
  expect(h.source.details, ['qa-clinic']);
  await capture('vet-detail');
  await tap(find.byKey(const Key('review-list-open-button')));
  expect(find.byKey(const Key('review-list-scroll')), findsOneWidget);
  expect(find.byKey(const Key('review-list-empty')), findsOneWidget);
  expect(h.source.reviews, isNotEmpty);
  expect(h.source.reviews.every((id) => id == 'qa-clinic'), isTrue);
  await capture('vet-review-sheet-empty');
  Navigator.of(
    tester.element(find.byKey(const Key('review-list-scroll'))),
  ).pop();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('review-list-scroll')), findsNothing);
  expect(find.byType(VetDetailScreen), findsOneWidget);
  await capture('vet-review-closed');
  // The detail header is a lazily built list child, not a pinned app bar.
  // Restore its owning scroll position before locating the Back control.
  final detailScroll = tester.state<ScrollableState>(
    closureScrollFor(tester, find.byKey(const Key('review-list-open-button'))),
  );
  detailScroll.position.jumpTo(detailScroll.position.minScrollExtent);
  await tester.pumpAndSettle();
  await tap(find.byTooltip('Quay lại'));
  expect(find.byType(VetListScreen), findsOneWidget);
  await capture('vet-back-to-list');
  // Independent fixture setup for granted-location branch, not user input.
  h.router.go('/vets/map');
  await tester.pumpAndSettle();
  h.location.denied = false;
  await tap(find.byKey(const Key('vet-map-current-location-button')));
  expect(h.source.nearbyQueries, isNotEmpty);
  final query = h.source.nearbyQueries.last;
  expect(query.latitude, 10.7769);
  expect(query.longitude, 106.7009);
  await capture('vet-location-fixture-granted');
}

class _ClosurePreferenceSource implements PreferenceSource {
  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => NotificationPreferences(
    userId: 'qa-owner',
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    quietHoursStart: '22:00',
    quietHoursEnd: '07:00',
    updatedAt: DateTime.utc(2026, 7, 16),
  );
  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences value, {
    required String accessToken,
  }) async => value;
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({required String accessToken}) =>
      Future.value(
        PrivacyDefaults(
          userId: 'qa-owner',
          version: 1,
          hideHouseNumber: true,
          hidePhoneByDefault: true,
          reviewMediaBeforePublish: true,
          updatedAt: DateTime.utc(2026, 7, 16),
        ),
      );
  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults value, {
    required String accessToken,
  }) => throw StateError('Privacy is outside this QA journey');
}

class ClosureNotificationSource extends NotificationApi {
  ClosureNotificationSource() : super(Dio());
  String mode = 'error';
  int lists = 0;
  final readIds = <String>[];
  final item = PawMateNotification(
    id: 'qa-health',
    type: 'reminder_due',
    title: 'QA: Kiểm tra sức khỏe Mochi',
    body: 'Nhắc lịch kiểm thử tổng hợp',
    reminderId: 'qa-reminder',
    createdAt: DateTime(2026, 7, 16, 8),
  );
  @override
  Future<int> processDueReminders({required String accessToken}) async => 0;
  @override
  Future<NotificationListResult> listNotifications({
    required String accessToken,
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async {
    lists++;
    if (mode == 'error') {
      throw const NotificationApiException('QA: Mất kết nối thông báo');
    }
    final values = mode == 'empty' ? <PawMateNotification>[] : [item];
    return NotificationListResult(
      items: values,
      total: values.length,
      unreadCount: values.length,
      limit: limit,
    );
  }

  @override
  Future<PawMateNotification> markRead(
    String id, {
    required String accessToken,
  }) async {
    readIds.add(id);
    return PawMateNotification(
      id: item.id,
      type: item.type,
      title: item.title,
      body: item.body,
      reminderId: item.reminderId,
      createdAt: item.createdAt,
      readAt: DateTime(2026, 7, 16, 9),
    );
  }
}

class ClosureNotificationHarness {
  const ClosureNotificationHarness(this.source, this.container);
  final ClosureNotificationSource source;
  final ProviderContainer container;
}

Future<ClosureNotificationHarness> pumpClosureNotificationJourney(
  WidgetTester tester,
  Size size,
) async {
  await setTestViewport(tester, size: size);
  final source = ClosureNotificationSource();
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) =>
            NotificationCenterScreen(now: () => DateTime(2026, 7, 16, 9)),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (_, _) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: '/health/reminders',
        builder: (_, _) =>
            ReminderCalendarScreen(now: () => DateTime(2026, 7, 16, 9)),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authAccessTokenProvider.overrideWith((_) async => 'qa-local-only'),
        notificationApiProvider.overrideWithValue(source),
        preferenceSourceProvider.overrideWithValue(_ClosurePreferenceSource()),
        petBackendListProvider.overrideWithValue(
          AsyncData([
            detail.day119Pet().copyWith(avatarPath: closureDogAvatar),
          ]),
        ),
        petSessionRevisionProvider.overrideWithValue(0),
        reminderApiProvider.overrideWithValue(ClosureReminderSource()),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await detail.readyDay119(tester);
  return ClosureNotificationHarness(
    source,
    ProviderScope.containerOf(
      tester.element(find.byType(NotificationCenterScreen)),
    ),
  );
}

Future<void> rehearseClosureNotificationJourney(
  WidgetTester tester,
  ClosureNotificationHarness harness, {
  required ClosureStage capture,
}) async {
  Future<void> tap(Finder target) async {
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  expect(find.text('Chưa tải được thông báo'), findsOneWidget);
  expect(harness.source.lists, 1);
  await capture('notifications-error');
  harness.source.mode = 'empty'; // Declared next synthetic API response.
  await tap(find.text('Thử lại'));
  expect(harness.source.lists, 2);
  expect(
    find.byKey(const ValueKey('notification-empty-profile-button')),
    findsOneWidget,
  );
  await capture('retry-empty');
  await tap(find.byKey(const ValueKey('notification-settings-button')));
  expect(find.byType(NotificationPreferencesScreen), findsOneWidget);
  expect(find.text('Cài đặt thông báo'), findsOneWidget);
  await capture('notification-settings');
  await tap(find.byTooltip('Quay lại'));
  expect(find.byType(NotificationCenterScreen), findsOneWidget);
  await capture('settings-back');

  // Separate fixture-state transition, not claimed as a user interaction.
  harness.source.mode = 'data';
  harness.container.invalidate(notificationListProvider);
  await tester.pumpAndSettle();
  expect(find.text(harness.source.item.title), findsOneWidget);
  await capture('notifications-list');
  await tap(find.byKey(const ValueKey('notification-card-qa-health')));
  expect(harness.source.readIds, ['qa-health']);
  expect(find.byType(ReminderCalendarScreen), findsOneWidget);
  await capture('notification-opens-calendar');
}

class ClosureReminderSource extends ReminderApi {
  ClosureReminderSource() : super(Dio());
  final saved = <Reminder>[];
  int createAttempts = 0;
  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async => ReminderListResult(
    items: saved.where((r) => r.petId == query.petId).toList(),
    total: saved.length,
    limit: query.limit,
  );
  @override
  Future<Reminder> createReminder(
    String petId,
    CreateReminderInput input, {
    required String accessToken,
  }) async {
    createAttempts++;
    // Explicit synthetic API validation response, not client-validation proof.
    if (input.title.trim().isEmpty) {
      throw const ReminderApiException(
        'QA: Vui lòng nhập tiêu đề lịch nhắc.',
        statusCode: 400,
      );
    }
    final value = Reminder(
      id: 'qa-reminder-${saved.length + 1}',
      petId: petId,
      title: input.title,
      reminderAt: input.reminderAt,
      note: input.note,
      repeatRule: input.repeatRule,
      timezone: input.timezone,
      status: ReminderStatus.scheduled,
      createdAt: '2026-07-16T00:00:00Z',
      updatedAt: '2026-07-16T00:00:00Z',
    );
    saved.add(value);
    return value;
  }
}

Future<ClosureReminderSource> pumpClosureHealthJourney(
  WidgetTester tester,
  Size size,
) async {
  await setTestViewport(tester, size: size);
  final source = ClosureReminderSource();
  final now = DateTime(2026, 7, 16, 9);
  final router = GoRouter(
    initialLocation: '/health',
    routes: [
      GoRoute(
        path: '/health',
        builder: (_, _) => HealthTimelineScreen(now: () => now),
      ),
      GoRoute(
        path: '/health/reminders',
        builder: (_, _) => ReminderCalendarScreen(now: () => now),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          AsyncData([
            detail.day119Pet().copyWith(avatarPath: closureDogAvatar),
          ]),
        ),
        petSessionRevisionProvider.overrideWithValue(0),
        reminderAccessTokenProvider.overrideWith((_) async => 'qa-local-only'),
        reminderApiProvider.overrideWithValue(source),
        upcomingRemindersProvider.overrideWithValue(const AsyncData([])),
        healthRecordListProvider.overrideWith(
          (_, query) async =>
              const HealthRecordListResult(items: [], total: 0, limit: 20),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await detail.readyDay119(tester);
  return source;
}

Future<void> rehearseClosureHealthJourney(
  WidgetTester tester,
  ClosureReminderSource source, {
  required ClosureStage capture,
}) async {
  Future<void> tap(Finder target) async {
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  expect(find.byType(HealthTimelineScreen), findsOneWidget);
  await capture('health-timeline');
  await tap(find.byKey(const Key('health-reminder-hero')));
  expect(find.byType(ReminderCalendarScreen), findsOneWidget);
  await capture('reminder-calendar');
  Finder getFab() => find.byType(FloatingActionButton);
  final sheet = find.byKey(const ValueKey('reminder-create-sheet-viewport'));
  await tap(getFab());
  expect(sheet, findsOneWidget);
  expect(source.saved, isEmpty);
  // Product seeds a default title. Clear it explicitly for the empty-input
  // branch; opening the editor alone does not establish that precondition.
  final title = find.byKey(const ValueKey('reminder-create-title-field'));
  await tester.ensureVisible(title);
  await tester.enterText(title, '');
  await tester.pumpAndSettle();
  expect(tester.widget<TextField>(title).controller!.text, isEmpty);
  await capture('reminder-editor-empty');
  final save = find.byKey(const ValueKey('reminder-create-save-button'));
  await tap(save);
  expect(find.text('QA: Vui lòng nhập tiêu đề lịch nhắc.'), findsOneWidget);
  expect(source.createAttempts, 1);
  expect(source.saved, isEmpty);
  await capture('reminder-api-validation');
  await tester.ensureVisible(title);
  await tester.enterText(title, 'QA: Kiểm tra sức khỏe Mochi');
  await tester.pumpAndSettle();
  await tap(save);
  expect(sheet, findsNothing);
  expect(source.saved.single.title, 'QA: Kiểm tra sức khỏe Mochi');
  expect(source.saved.single.petId, 'mochi');
  expect(source.createAttempts, 2);
  await capture('reminder-saved');
  await tap(getFab());
  expect(sheet, findsOneWidget);
  // Local modal cancellation; Android Back/focus return needs native proof.
  Navigator.of(tester.element(sheet)).pop();
  await tester.pumpAndSettle();
  expect(sheet, findsNothing);
  expect(source.createAttempts, 2);
  expect(source.saved, hasLength(1));
  await capture('reminder-cancel-no-write');
}

class ClosureAuthSource extends AuthApi {
  ClosureAuthSource() : super(Dio());
  int registerCalls = 0;
  String? lastEmail;
  static const rejection = 'QA: Chưa thể tạo tài khoản, vui lòng thử lại.';
  @override
  Future<RegisterResponse> register({
    required String email,
    required String password,
    String? phone,
    String? displayName,
  }) async {
    registerCalls++;
    lastEmail = email;
    throw const AuthApiException(rejection, code: 'QA_UNAVAILABLE');
  }
}

Future<ClosureAuthSource> pumpClosureAuthJourney(
  WidgetTester tester,
  Size size,
) async {
  await setTestViewport(tester, size: size);
  SharedPreferences.setMockInitialValues({});
  final source = ClosureAuthSource();
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const RegisterScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authApiProvider.overrideWithValue(source)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await detail.readyDay119(tester);
  return source;
}

Future<void> rehearseClosureAuthJourney(
  WidgetTester tester,
  ClosureAuthSource source, {
  required ClosureStage capture,
}) async {
  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
  Future<void> fill(String key, String value) async {
    final target = field(key);
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(target).controller!.text, value);
  }

  Future<void> tap(String key) async {
    final target = find.byKey(ValueKey(key));
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  expect(find.byType(OnboardingScreen), findsOneWidget);
  await capture('onboarding-empty');
  await tap('onboarding-continue-button');
  expect(find.text('Vui lòng nhập tên thú cưng'), findsOneWidget);
  expect(find.byType(RegisterScreen), findsNothing);
  await capture('onboarding-validation');
  await fill('onboarding-pet-name-field', 'Mochi');
  await fill('onboarding-breed-field', 'Golden Retriever');
  await fill('onboarding-age-field', '2');
  await tap('onboarding-continue-button');
  expect(find.byType(RegisterScreen), findsOneWidget);
  expect(source.registerCalls, 0);
  final submit = find.byKey(const ValueKey('register-submit-button'));
  expect(tester.widget<PawMateButton>(submit).onPressed, isNull);
  await capture('register-empty-disabled');
  await fill('register-email-field', 'fixture@example.test');
  await fill('register-phone-field', '0900000000');
  await fill('register-password-field', 'Fixture-only-Password1!');
  await fill('register-confirm-password-field', 'Fixture-only-Password1!');
  expect(tester.widget<PawMateButton>(submit).onPressed, isNotNull);
  await capture('register-valid-enabled');
  await tap('register-submit-button');
  expect(source.registerCalls, 1);
  expect(source.lastEmail, 'fixture@example.test');
  expect(find.text(ClosureAuthSource.rejection), findsOneWidget);
  expect(find.byType(RegisterScreen), findsOneWidget);
  await capture('register-error-retains-form');
}

class ClosureHomePetHarness {
  const ClosureHomePetHarness(this.router, this.container);
  final GoRouter router;
  final ProviderContainer container;
}

class _ClosureSelectedPet extends SelectedPetIdNotifier {
  @override
  String? build() => 'mochi';
}

Future<ClosureHomePetHarness> pumpClosureHomePetJourney(
  WidgetTester tester,
  Size size, {
  VoidCallback? restoreNativeMetrics,
}) async {
  await setTestViewport(tester, size: size);
  final pets = [
    detail.day119Pet().copyWith(avatarPath: closureDogAvatar),
    PetProfile(
      id: 'bap',
      name: 'Bắp',
      species: 'dog',
      breed: 'Poodle',
      gender: 'male',
      healthStatus: 'healthy',
      avatarPath: closureDogAvatar,
    ),
  ];
  final router = GoRouter(
    initialLocation: '/pets',
    routes: [
      GoRoute(
        path: '/pets',
        builder: (_, _) => PetHomeScreen(now: DateTime(2026, 7, 16)),
      ),
      GoRoute(
        path: '/pets/:petId',
        builder: (_, state) =>
            PetDetailScreen(petId: state.pathParameters['petId']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(AsyncData(pets)),
        petSessionRevisionProvider.overrideWithValue(0),
        authSessionSnapshotProvider.overrideWithValue(const AsyncData(null)),
        upcomingRemindersProvider.overrideWithValue(const AsyncData([])),
        selectedPetIdProvider.overrideWith(_ClosureSelectedPet.new),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await detail.readyDay119(tester);
  restoreNativeMetrics?.call();
  await tester.pumpAndSettle();
  return ClosureHomePetHarness(
    router,
    ProviderScope.containerOf(tester.element(find.byType(PetHomeScreen))),
  );
}

Future<void> rehearseClosureHomePetJourney(
  WidgetTester tester,
  ClosureHomePetHarness harness, {
  required ClosureStage capture,
  bool pickWrongPetForCounterfactual = false,
}) async {
  expect(find.byType(PetHomeScreen), findsOneWidget);
  expect(harness.container.read(selectedPetIdProvider), 'mochi');
  await capture('home-first-pet-selected');
  final avatar = find.byKey(
    ValueKey(
      'home-pet-avatar-${pickWrongPetForCounterfactual ? 'mochi' : 'bap'}',
    ),
  );
  expect(avatar, findsOneWidget);
  await tester.ensureVisible(avatar);
  await tester.pumpAndSettle();
  expect(avatar.hitTestable(), findsOneWidget);
  await tester.tap(avatar);
  await tester.pumpAndSettle();
  final screen = find.byType(PetDetailScreen);
  expect(screen, findsOneWidget);
  expect(tester.widget<PetDetailScreen>(screen).petId, 'bap');
  expect(GoRouterState.of(tester.element(screen)).uri.path, '/pets/bap');
  expect(harness.container.read(selectedPetIdProvider), 'bap');
  expect(find.text('Bắp'), findsOneWidget);
  await capture('second-pet-detail');

  // Exercise the actual product AppBar back control, not a route replacement.
  final back = find.byType(BackButton);
  expect(back, findsOneWidget);
  expect(back.hitTestable(), findsOneWidget);
  await tester.tap(back);
  await tester.pumpAndSettle();
  expect(find.byType(PetHomeScreen), findsOneWidget);
  expect(find.byType(PetDetailScreen), findsNothing);
  expect(harness.container.read(selectedPetIdProvider), 'bap');
  expect(
    tester
        .getSemantics(find.byKey(const Key('home-pet-avatar-bap')))
        .flagsCollection
        .isSelected,
    Tristate.isTrue,
  );
  await capture('home-retains-second-pet');
}

/// Mount the real Home/Map/Detail widgets with a local, observable data source.
/// No production flag or route is modified. The fixture's unrelated sentinel
/// routes must never be counted as mounted product screens.
Future<detail.Day119Harness> pumpClosureRescueJourney(
  WidgetTester tester,
  Size size, {
  VoidCallback? restoreNativeMetrics,
}) async {
  final harness = await detail.pumpDay119(tester, 'DT-04', size);
  restoreNativeMetrics?.call();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('rescue-live-list')), findsOneWidget);
  expect(harness.router.routeInformationProvider.value.uri.path, '/rescue');
  expect(harness.source.detailCaseIds, isEmpty);
  return harness;
}

/// Local rehearsal with assertions at each stage, not a native acceptance run.
/// Native TalkBack must dispatch its own gestures and retain focus/video proof.
Future<void> rehearseClosureRescueJourney(
  WidgetTester tester,
  detail.Day119Harness harness, {
  required ClosureStage capture,
  bool omitMarkerForCounterfactual = false,
}) async {
  final marker = find.byKey(
    ValueKey('rescue-marker-${detail.day119FirstCaseId}'),
  );
  final card = find.byKey(const Key('rescue-selected-case-card'));
  final toggle = find.byKey(const Key('rescue-load-more'));
  final toggleSemantics = find.byKey(const Key('rescue-nearby-toggle'));

  Future<void> tapVisible(Finder target) async {
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target, warnIfMissed: true);
    await tester.pumpAndSettle();
  }

  expect(card, findsNothing);
  expect(find.text('Thu gọn'), findsNothing);
  await capture('home-collapsed');

  await tapVisible(toggle);
  expect(find.text('Thu gọn'), findsOneWidget);
  expect(
    tester.getSemantics(toggleSemantics).getSemanticsData().label,
    'Thu gọn danh sách ca gần nhất',
  );
  await capture('home-expanded');

  await tapVisible(toggle);
  expect(find.text('Thu gọn'), findsNothing);
  expect(
    tester.getSemantics(toggleSemantics).getSemanticsData().label,
    'Mở rộng 5 ca gần nhất',
  );
  await capture('home-recollapsed');

  if (!omitMarkerForCounterfactual) await tapVisible(marker);
  expect(
    card,
    findsOneWidget,
    reason: 'Marker action must expose selected card',
  );
  expect(
    tester.getSemantics(marker).flagsCollection.isSelected,
    Tristate.isTrue,
  );
  expect(
    harness.source.detailCaseIds,
    isEmpty,
    reason: 'Selection alone must not fetch detail',
  );
  await capture('case-selected');

  await tapVisible(find.byKey(const Key('rescue-selected-details')));
  expect(find.byKey(const Key('rescue-case-detail-screen')), findsOneWidget);
  // Imperative push need not update platform route information. Inspect the
  // mounted product screen's route, not the browser/platform root URI.
  expect(
    GoRouterState.of(
      tester.element(find.byKey(const Key('rescue-case-detail-screen'))),
    ).uri.path,
    '/rescue/${detail.day119FirstCaseId}',
  );
  expect(harness.source.detailCaseIds, [detail.day119FirstCaseId]);
  await capture('case-detail');

  // Navigator pop is only the local route rehearsal, not Android Back proof.
  expect(harness.router.canPop(), isTrue);
  harness.router.pop();
  await tester.pumpAndSettle();
  expect(harness.router.routeInformationProvider.value.uri.path, '/rescue');
  expect(card, findsOneWidget);
  expect(
    tester.getSemantics(marker).flagsCollection.isSelected,
    Tristate.isTrue,
  );
  await capture('back-retains-selection');

  await tapVisible(find.byKey(const Key('rescue-selected-close')));
  expect(card, findsNothing);
  expect(
    tester.getSemantics(marker).flagsCollection.isSelected,
    Tristate.isFalse,
  );
  await capture('selection-cleared');
}

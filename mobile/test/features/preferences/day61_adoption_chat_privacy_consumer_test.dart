import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('Adoption chat requires consent before sharing a phone number', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final chat = _ChatSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceSourceProvider.overrideWithValue(
            _PrivacyPreferenceSource(),
          ),
          adoptionRequestChatSourceProvider.overrideWithValue(chat),
          adoptionRequestChatDraftStoreProvider.overrideWithValue(
            _MemoryChatStore(),
          ),
          authSessionSnapshotProvider.overrideWith((ref) async => _session()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShelterChatScreen(threadId: 'thread-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('adoption-chat-composer')),
      'Liên hệ 0901 234 567 nhé',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('adoption-chat-send')));
    await tester.pump();

    expect(
      find.byKey(const Key('adoption-chat-privacy-confirmation')),
      findsOneWidget,
    );
    expect(chat.sentBodies, isEmpty);

    await tester.tap(
      find.byKey(const Key('adoption-chat-privacy-confirm-send')),
    );
    await tester.pumpAndSettle();

    expect(chat.sentBodies, ['Liên hệ 0901 234 567 nhé']);
    expectNoFlutterOverflow(tester);
  });
}

AuthSession _session() => AuthSession(
  user: const AuthUser(
    id: 'adopter-1',
    email: 'adopter@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'owner-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: '2026-07-30T00:00:00Z',
  refreshTokenExpiresAt: '2026-08-30T00:00:00Z',
);

class _ChatSource implements AdoptionRequestChatSource {
  final List<String> sentBodies = [];
  final List<AdoptionChatMessage> messages = [];

  AdoptionChatThread get thread => AdoptionChatThread(
    threadId: 'thread-1',
    requestId: 'request-1',
    participantRole: AdoptionChatParticipantRole.adopter,
    lastReadAt: DateTime.utc(2026, 7, 29, 8),
    unreadCount: 0,
  );

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async => AdoptionChatPage(
    messages: List.unmodifiable(messages),
    thread: thread,
    hasMore: false,
    limit: limit,
  );

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) async {
    sentBodies.add(body);
    final message = AdoptionChatMessage(
      messageId: 'message-${sentBodies.length}',
      threadId: threadId,
      senderUserId: 'adopter-1',
      body: body,
      media: const [],
      createdAt: DateTime.utc(2026, 7, 29, 10),
    );
    messages.add(message);
    return message;
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async => AdoptionChatReadState(
    threadId: threadId,
    lastReadAt: DateTime.utc(2026, 7, 29, 10),
    unreadCount: 0,
  );

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }
}

class _MemoryChatStore implements AdoptionRequestChatDraftStore {
  AdoptionChatDraft draft = const AdoptionChatDraft();

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => draft;

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async {
    this.draft = draft;
  }

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async {
    draft = const AdoptionChatDraft();
  }

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => const AdoptionChatContext(
    listingId: 'listing-1',
    petName: 'Mochi',
    shelterId: 'shelter-1',
  );

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {}

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async => const AdoptionRequestDraft();

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {}

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {}
}

class _PrivacyPreferenceSource implements PreferenceSource {
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: 'adopter-1',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 7, 29),
  );

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async => defaults;
}

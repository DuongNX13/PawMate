import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_request_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';
import 'adoption_test_fixtures.dart';
import 'adoption_ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('request draft validates bounds and serializes only API fields', () {
    const draft = AdoptionRequestDraft(
      livingCondition: '  Căn hộ  ',
      petExperience: 'Đã nuôi chó',
      carePlan: 'Khám định kỳ',
      note: '  Gọi trước khi đến  ',
      commitmentAccepted: true,
      pendingSubmitKey: 'retry-key',
    );

    expect(draft.isValid, isTrue);
    expect(draft.toRequestJson(), {
      'livingCondition': 'Căn hộ',
      'petExperience': 'Đã nuôi chó',
      'carePlan': 'Khám định kỳ',
      'commitmentAccepted': true,
      'note': 'Gọi trước khi đến',
    });
    expect(AdoptionChatMediaPolicy.isSupported('video/mp4'), isTrue);
    expect(AdoptionChatMediaPolicy.maxItems, 5);
  });

  test('request and chat wire models parse every frozen state', () {
    for (final entry in const {
      'submitted': AdoptionRequestStatus.submitted,
      'reviewing': AdoptionRequestStatus.reviewing,
      'approved': AdoptionRequestStatus.approved,
      'rejected': AdoptionRequestStatus.rejected,
      'cancelled': AdoptionRequestStatus.cancelled,
    }.entries) {
      expect(AdoptionRequestStatus.fromJson(entry.key), entry.value);
      expect(entry.value.label, isNotEmpty);
    }
    expect(
      () => AdoptionRequestStatus.fromJson('unknown'),
      throwsFormatException,
    );
    for (final entry in const {
      'available': AdoptionRequestListingAvailability.available,
      'unavailable': AdoptionRequestListingAvailability.unavailable,
      'expired': AdoptionRequestListingAvailability.expired,
      'deleted': AdoptionRequestListingAvailability.deleted,
    }.entries) {
      expect(
        AdoptionRequestListingAvailability.fromJson(entry.key),
        entry.value,
      );
      expect(entry.value.label, isNotEmpty);
    }
    expect(
      () => AdoptionRequestListingAvailability.fromJson('unknown'),
      throwsFormatException,
    );
    expect(AdoptionRequestListingAvailability.available.canOpenProfile, isTrue);
    expect(AdoptionRequestListingAvailability.deleted.canOpenProfile, isFalse);

    final result = AdoptionRequestResult.fromJson({
      'requestId': 'request-1',
      'listingId': 'listing-1',
      'adopterUserId': 'adopter-1',
      'shelterId': 'shelter-1',
      'livingCondition': 'Căn hộ',
      'petExperience': 'Đã nuôi chó',
      'carePlan': 'Khám định kỳ',
      'note': 'Gọi trước',
      'commitmentAccepted': true,
      'status': 'reviewing',
      'threadId': 'thread-1',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-07-28T05:01:00.000Z',
    });
    expect(result.status, AdoptionRequestStatus.reviewing);
    expect(result.note, 'Gọi trước');
    expect(result.updatedAt, DateTime.utc(2026, 7, 28, 5, 1));
    expect(
      () => AdoptionRequestResult.fromJson({'commitmentAccepted': false}),
      throwsFormatException,
    );

    for (final entry in const {
      'adopter': AdoptionChatParticipantRole.adopter,
      'shelter': AdoptionChatParticipantRole.shelter,
    }.entries) {
      expect(AdoptionChatParticipantRole.fromJson(entry.key), entry.value);
      expect(entry.value.label, isNotEmpty);
    }
    expect(
      () => AdoptionChatParticipantRole.fromJson('visitor'),
      throwsFormatException,
    );

    final mediaJson = {
      'mediaId': 'media-1',
      'ownerUserId': 'adopter-1',
      'purpose': 'adoption_chat',
      'mimeType': 'image/webp',
      'sizeBytes': 2048,
      'sha256': 'abc',
      'status': 'attached',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'publicUrl': 'https://cdn.example.test/chat.webp',
      'width': 1200,
      'height': 900,
      'durationSeconds': 1.5,
    };
    final messageJson = {
      'messageId': 'message-1',
      'threadId': 'thread-1',
      'senderUserId': 'adopter-1',
      'body': 'Chào mái ấm',
      'media': [mediaJson],
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-07-28T05:01:00.000Z',
    };
    final page = AdoptionChatPage.fromJson({
      'data': [messageJson],
      'thread': {
        'threadId': 'thread-1',
        'requestId': 'request-1',
        'participantRole': 'adopter',
        'lastReadAt': '2026-07-28T04:59:00.000Z',
        'unreadCount': 2,
        'closedAt': '2026-07-28T06:00:00.000Z',
      },
      'pageInfo': {'nextCursor': 'older', 'hasMore': true, 'limit': 20},
    });
    expect(page.messages.single.media.single.width, 1200);
    expect(page.thread.isClosed, isTrue);
    expect(page.nextCursor, 'older');
    expect(
      page.thread
          .copyWith(lastReadAt: DateTime.utc(2026, 7, 28, 5), unreadCount: 0)
          .unreadCount,
      0,
    );
    expect(
      AdoptionChatReadState.fromJson({
        'threadId': 'thread-1',
        'lastReadAt': '2026-07-28T05:00:00.000Z',
        'unreadCount': 0,
      }).threadId,
      'thread-1',
    );
    expect(
      () => AdoptionChatMedia.fromJson({
        ...mediaJson,
        'purpose': 'adoption_listing',
      }),
      throwsFormatException,
    );
    expect(
      () =>
          AdoptionChatMedia.fromJson({...mediaJson, 'publicUrl': 'not-a-url'}),
      throwsFormatException,
    );
    expect(
      () => AdoptionChatMessage.fromJson({...messageJson, 'media': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => AdoptionChatPage.fromJson({'data': 'invalid'}),
      throwsFormatException,
    );

    final draftMedia = AdoptionChatDraftMedia.fromJson({
      'localId': 'local-1',
      'path': 'C:/tmp/chat.webp',
      'mimeType': 'image/webp',
      'sizeBytes': 100,
      'mediaId': 'media-1',
      'status': 'uploaded',
      'progress': 1,
      'errorMessage': 'old',
    });
    expect(
      draftMedia
          .copyWith(
            status: AdoptionChatUploadStatus.failed,
            clearMediaId: true,
            clearError: true,
          )
          .mediaId,
      isNull,
    );
    final chatDraft = AdoptionChatDraft.fromJson({
      'body': 'Xin chào',
      'media': [draftMedia.toJson()],
      'pendingSendKey': 'send-key',
    });
    expect(chatDraft.media.single.status, AdoptionChatUploadStatus.uploaded);
    expect(
      chatDraft.copyWith(clearPendingSendKey: true).pendingSendKey,
      isNull,
    );
    expect(
      AdoptionChatContext.fromJson({
        'listingId': 'listing-1',
        'petName': 'Mochi',
        'shelterId': 'shelter-1',
        'heroMediaUrl': 'https://cdn.example.test/mochi.webp',
      }).toJson()['petName'],
      'Mochi',
    );
  });

  test('local drafts are scoped by user and resource', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesAdoptionRequestChatDraftStore();
    const draft = AdoptionRequestDraft(
      livingCondition: 'Căn hộ',
      petExperience: 'Đã nuôi chó',
      carePlan: 'Khám định kỳ',
      commitmentAccepted: true,
    );

    await store.saveRequestDraft(
      userId: 'user-a',
      listingId: 'listing-1',
      draft: draft,
    );

    expect(
      (await store.readRequestDraft(
        userId: 'user-a',
        listingId: 'listing-1',
      )).livingCondition,
      'Căn hộ',
    );
    expect(
      (await store.readRequestDraft(
        userId: 'user-b',
        listingId: 'listing-1',
      )).livingCondition,
      isEmpty,
    );
    expect(
      (await store.readRequestDraft(
        userId: 'user-a',
        listingId: 'listing-2',
      )).livingCondition,
      isEmpty,
    );

    const chatDraft = AdoptionChatDraft(
      body: 'Xin chào',
      pendingSendKey: 'send-key',
    );
    const context = AdoptionChatContext(
      listingId: 'listing-1',
      petName: 'Mochi',
      shelterId: 'shelter-1',
    );
    await store.saveChatDraft(
      userId: 'user-a',
      threadId: 'thread-1',
      draft: chatDraft,
    );
    await store.saveChatContext(
      userId: 'user-a',
      threadId: 'thread-1',
      context: context,
    );
    expect(
      (await store.readChatDraft(userId: 'user-a', threadId: 'thread-1')).body,
      'Xin chào',
    );
    expect(
      (await store.readChatContext(
        userId: 'user-a',
        threadId: 'thread-1',
      ))?.petName,
      'Mochi',
    );
    expect(
      await store.readChatContext(userId: 'user-b', threadId: 'thread-1'),
      isNull,
    );
    await store.clearChatDraft(userId: 'user-a', threadId: 'thread-1');
    await store.clearRequestDraft(userId: 'user-a', listingId: 'listing-1');
    expect(
      (await store.readChatDraft(userId: 'user-a', threadId: 'thread-1')).body,
      isEmpty,
    );
    expect(
      (await store.readRequestDraft(
        userId: 'user-a',
        listingId: 'listing-1',
      )).livingCondition,
      isEmpty,
    );
  });

  test(
    'request retry reuses idempotency key and clears draft on success',
    () async {
      final source = _FakeRequestChatSource(failFirstRequest: true);
      final store = _MemoryDraftStore();
      final notifier = AdoptionRequestNotifier(
        listingId: 'listing-1',
        listingSource: FakeAdoptionUiSource(detail: adoptionDetail()),
        requestSource: source,
        draftStore: store,
        readSession: () async => _session,
        now: () => DateTime.utc(2026, 7, 28, 5),
        keyFactory: (_, _, sequence) => 'request-key-$sequence',
      );

      await notifier.load();
      notifier.setLivingCondition('Căn hộ an toàn');
      notifier.setPetExperience('Đã nuôi chó');
      notifier.setCarePlan('Khám định kỳ');
      notifier.setCommitmentAccepted(true);

      expect(await notifier.submit(), isFalse);
      expect(source.requestKeys, ['request-key-0']);
      expect(store.requestDrafts, isNotEmpty);
      expect(await notifier.submit(), isTrue);
      expect(source.requestKeys, ['request-key-0', 'request-key-0']);
      expect(notifier.state.result?.threadId, 'thread-1');
      expect(store.requestDrafts, isEmpty);
    },
  );

  testWidgets('P2-11 request form and P2-12 chat render without overflow', (
    tester,
  ) async {
    final source = _FakeRequestChatSource();
    final store = _MemoryDraftStore();
    await setTestViewport(tester, size: const Size(390, 844));
    final overrides = [
      adoptionSourceProvider.overrideWithValue(
        FakeAdoptionUiSource(detail: adoptionDetail()),
      ),
      adoptionRequestChatSourceProvider.overrideWithValue(source),
      adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
      authSessionSnapshotProvider.overrideWithValue(
        const AsyncValue.data(_session),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdoptionRequestFormScreen(listingId: 'listing-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adoption-request-form')), findsOneWidget);
    expect(
      find.byKey(const Key('adoption-request-living-condition-field')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ShelterChatScreen(threadId: 'thread-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adoption-chat-screen')), findsOneWidget);
    expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Day55 remains usable at 360dp, text scale 2 and open IME', (
    tester,
  ) async {
    final source = _FakeRequestChatSource();
    final store = _MemoryDraftStore();
    await setTestViewport(
      tester,
      size: const Size(360, 800),
      keyboardInset: 280,
    );
    final overrides = [
      adoptionSourceProvider.overrideWithValue(
        FakeAdoptionUiSource(detail: adoptionDetail()),
      ),
      adoptionRequestChatSourceProvider.overrideWithValue(source),
      adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
      authSessionSnapshotProvider.overrideWithValue(
        const AsyncValue.data(_session),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: const AdoptionRequestFormScreen(listingId: 'listing-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('adoption-request-submit-cta')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: const ShelterChatScreen(threadId: 'thread-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

const _session = AuthSession(
  user: AuthUser(
    id: 'adopter-1',
    email: 'test@example.com',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
  refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
);

class _FakeRequestChatSource implements AdoptionRequestChatSource {
  _FakeRequestChatSource({this.failFirstRequest = false});

  final bool failFirstRequest;
  final requestKeys = <String>[];
  var _requestCalls = 0;

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) async {
    requestKeys.add(idempotencyKey);
    if (failFirstRequest && _requestCalls++ == 0) {
      throw const AdoptionApiException('offline', code: 'NETWORK_OFFLINE');
    }
    return AdoptionRequestResult(
      requestId: 'request-1',
      listingId: listingId,
      adopterUserId: 'adopter-1',
      shelterId: 'shelter-1',
      livingCondition: draft.livingCondition.trim(),
      petExperience: draft.petExperience.trim(),
      carePlan: draft.carePlan.trim(),
      commitmentAccepted: true,
      status: AdoptionRequestStatus.submitted,
      threadId: 'thread-1',
      createdAt: DateTime.utc(2026, 7, 28, 5),
    );
  }

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    final message = AdoptionChatMessage(
      messageId: 'message-1',
      threadId: threadId,
      senderUserId: 'shelter-1',
      body: 'Chào bạn, mình đã nhận được yêu cầu.',
      media: const [],
      createdAt: DateTime.utc(2026, 7, 28, 5),
    );
    return AdoptionChatPage(
      messages: [message],
      thread: AdoptionChatThread(
        threadId: threadId,
        requestId: 'request-1',
        participantRole: AdoptionChatParticipantRole.adopter,
        lastReadAt: DateTime.utc(2026, 7, 28, 5),
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
    return AdoptionChatMessage(
      messageId: 'message-2',
      threadId: threadId,
      senderUserId: 'adopter-1',
      body: body,
      media: const [],
      createdAt: DateTime.utc(2026, 7, 28, 5, 1),
    );
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async {
    return AdoptionChatReadState(
      threadId: threadId,
      lastReadAt: DateTime.utc(2026, 7, 28, 5),
      unreadCount: 0,
    );
  }

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) async {
    onProgress(1);
    return media.copyWith(
      mediaId: 'media-chat-1',
      status: AdoptionChatUploadStatus.uploaded,
      progress: 1,
    );
  }
}

class _MemoryDraftStore implements AdoptionRequestChatDraftStore {
  final requestDrafts = <String, AdoptionRequestDraft>{};
  final chatDrafts = <String, AdoptionChatDraft>{};
  final contexts = <String, AdoptionChatContext>{};

  String _key(String userId, String id) => '$userId:$id';

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async =>
      requestDrafts[_key(userId, listingId)] ?? const AdoptionRequestDraft();

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {
    requestDrafts[_key(userId, listingId)] = draft;
  }

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {
    requestDrafts.remove(_key(userId, listingId));
  }

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => chatDrafts[_key(userId, threadId)] ?? const AdoptionChatDraft();

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async {
    chatDrafts[_key(userId, threadId)] = draft;
  }

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async {
    chatDrafts.remove(_key(userId, threadId));
  }

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => contexts[_key(userId, threadId)];

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {
    contexts[_key(userId, threadId)] = context;
  }
}

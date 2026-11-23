import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_chat_provider.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_request_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';

import 'adoption_ui_test_support.dart';

void main() {
  const session = AuthSession(
    user: AuthUser(
      id: 'adopter-1',
      email: 'day55@example.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
    refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
  );

  test(
    'request rejects invalid, unavailable and unauthenticated states',
    () async {
      final source = _ConfigurableSource();
      final store = _MemoryStore();
      final unauthenticated = _requestNotifier(
        source: source,
        store: store,
        readSession: () async => null,
      );
      await unauthenticated.load();
      expect(unauthenticated.state.isLoading, isFalse);
      expect(unauthenticated.state.errorMessage, contains('đăng nhập'));

      final invalid = _requestNotifier(
        source: source,
        store: store,
        readSession: () async => session,
      );
      await invalid.load();
      expect(await invalid.submit(), isFalse);
      expect(invalid.state.showValidation, isTrue);
      expect(invalid.state.errorMessage, contains('bắt buộc'));

      final unavailable = AdoptionRequestNotifier(
        listingId: 'listing-1',
        listingSource: FakeAdoptionUiSource(
          detail: uiAdoptionDetail(canRequest: false),
        ),
        requestSource: source,
        draftStore: store,
        readSession: () async => session,
        now: () => DateTime.utc(2026, 7, 28, 5),
        keyFactory: (_, _, sequence) => 'request-$sequence',
      );
      await unavailable.load();
      _completeRequest(unavailable);
      expect(await unavailable.submit(), isFalse);
      expect(unavailable.state.errorMessage, contains('không nhận thêm'));
    },
  );

  test(
    'request duplicate clears key while edits clear duplicate state',
    () async {
      final source = _ConfigurableSource(
        requestErrors: [
          const AdoptionApiException(
            'duplicate',
            code: 'ADOPTION_006',
            statusCode: 409,
          ),
        ],
      );
      final store = _MemoryStore();
      final notifier = _requestNotifier(
        source: source,
        store: store,
        readSession: () async => session,
      );
      await notifier.load();
      _completeRequest(notifier);

      expect(await notifier.submit(), isFalse);
      expect(notifier.state.duplicateActive, isTrue);
      expect(notifier.state.draft.pendingSubmitKey, isNull);
      notifier.setNote('Có thể gọi sau 18 giờ');
      await _drain();
      expect(notifier.state.duplicateActive, isFalse);
      expect(store.requestDrafts.values.single.note, contains('18 giờ'));
    },
  );

  test('request keeps local warning when persistence fails', () async {
    final store = _MemoryStore()..failRequestWrites = true;
    final notifier = _requestNotifier(
      source: _ConfigurableSource(),
      store: store,
      readSession: () async => session,
    );
    await notifier.load();
    notifier.setLivingCondition('Căn hộ có lưới an toàn');
    await _drain();
    expect(notifier.state.draftPersistenceWarning, contains('Chưa thể lưu'));
  });

  test(
    'chat restores draft, paginates, sorts, deduplicates and marks read',
    () async {
      final missing = AdoptionChatDraftMedia(
        localId: 'missing',
        path: 'Z:/definitely-missing/day55.webp',
        mimeType: 'image/webp',
        sizeBytes: 12,
        status: AdoptionChatUploadStatus.uploaded,
        mediaId: 'old-media',
      );
      final store = _MemoryStore()
        ..chatDrafts['adopter-1:thread-1'] = AdoptionChatDraft(
          body: 'Bản nháp an toàn',
          media: [missing],
        )
        ..contexts['adopter-1:thread-1'] = const AdoptionChatContext(
          listingId: 'listing-1',
          petName: 'Mochi',
          shelterId: 'shelter-1',
        );
      final source = _ConfigurableSource(
        pages: {
          null: _page(
            messages: [
              _message('message-2', minute: 2),
              _message('message-1', minute: 1),
            ],
            nextCursor: 'older',
            hasMore: true,
            unreadCount: 2,
          ),
          'older': _page(
            messages: [
              _message('message-1', minute: 1),
              _message('message-0', minute: 0),
            ],
          ),
        },
        markReadErrors: [StateError('synthetic read failure')],
      );
      final notifier = _chatNotifier(
        source: source,
        store: store,
        readSession: () async => session,
      );

      await notifier.load();
      await _drain();
      expect(notifier.state.draft.body, 'Bản nháp an toàn');
      expect(
        notifier.state.draft.media.single.status,
        AdoptionChatUploadStatus.failed,
      );
      expect(notifier.state.context?.petName, 'Mochi');
      expect(notifier.state.messages.map((item) => item.messageId), [
        'message-1',
        'message-2',
      ]);
      expect(notifier.state.readWarning, contains('Chưa đồng bộ'));

      await notifier.loadOlder();
      expect(notifier.state.messages.map((item) => item.messageId), [
        'message-0',
        'message-1',
        'message-2',
      ]);
      expect(source.readCursors, [null, 'older']);
      expect(notifier.state.hasMore, isFalse);

      await notifier.load(refresh: true);
      await _drain();
      expect(notifier.state.isRefreshing, isFalse);
      expect(notifier.state.readWarning, isNull);
    },
  );

  test(
    'chat validates media and retries upload without losing draft',
    () async {
      final source = _ConfigurableSource(
        uploadErrors: [
          const AdoptionApiException('offline', code: 'NETWORK_OFFLINE'),
        ],
      );
      final store = _MemoryStore();
      final notifier = _chatNotifier(
        source: source,
        store: store,
        readSession: () async => session,
      );
      await notifier.load();
      notifier.setDraftBody('Xin chào mái ấm');

      await notifier.addMedia(
        path: 'day55.gif',
        mimeType: 'image/gif',
        sizeBytes: 10,
      );
      expect(notifier.state.errorMessage, contains('JPG'));
      await notifier.addMedia(
        path: 'day55.mp4',
        mimeType: 'video/mp4',
        sizeBytes: AdoptionChatMediaPolicy.maxVideoBytes + 1,
      );
      expect(notifier.state.errorMessage, contains('50 MB'));

      await notifier.addMedia(
        path: 'day55.webp',
        mimeType: 'image/webp',
        sizeBytes: 1024,
      );
      expect(
        notifier.state.draft.media.single.status,
        AdoptionChatUploadStatus.failed,
      );
      expect(notifier.state.draft.body, 'Xin chào mái ấm');
      await notifier.retryMedia(notifier.state.draft.media.single.localId);
      expect(
        notifier.state.draft.media.single.status,
        AdoptionChatUploadStatus.uploaded,
      );
      notifier.removeMedia(notifier.state.draft.media.single.localId);
      expect(notifier.state.draft.media, isEmpty);
    },
  );

  test(
    'chat send retries same key and clears draft only after success',
    () async {
      final source = _ConfigurableSource(
        sendErrors: [
          const AdoptionApiException('offline', code: 'NETWORK_OFFLINE'),
        ],
      );
      final store = _MemoryStore();
      final notifier = _chatNotifier(
        source: source,
        store: store,
        readSession: () async => session,
      );
      await notifier.load();
      notifier.setDraftBody('  Xin chào mái ấm  ');
      await _drain();

      expect(await notifier.send(), isFalse);
      expect(notifier.state.draft.body, contains('Xin chào'));
      expect(source.sendKeys, ['message-0']);
      expect(await notifier.send(), isTrue);
      expect(source.sendKeys, ['message-0', 'message-0']);
      expect(notifier.state.draft.body, isEmpty);
      expect(store.chatDrafts, isEmpty);
      expect(notifier.state.messages.last.senderUserId, 'adopter-1');
    },
  );

  test(
    'chat protects validation, closed, auth and idempotency failures',
    () async {
      AuthSession? activeSession = session;
      final source = _ConfigurableSource(
        pages: {null: _page(closed: true)},
        sendErrors: [
          const AdoptionApiException(
            'key conflict',
            code: 'IDEMPOTENCY_001',
            statusCode: 409,
          ),
        ],
      );
      final store = _MemoryStore();
      final notifier = _chatNotifier(
        source: source,
        store: store,
        readSession: () async => activeSession,
      );
      await notifier.load();
      expect(await notifier.send(), isFalse);
      expect(notifier.state.errorMessage, contains('nhập nội dung'));
      notifier.setDraftBody('Xin chào');
      expect(await notifier.send(), isFalse);
      expect(notifier.state.errorMessage, contains('đã đóng'));

      source.pages[null] = _page();
      await notifier.load(refresh: true);
      activeSession = null;
      expect(await notifier.send(), isFalse);
      expect(notifier.state.errorMessage, contains('hết hạn'));

      activeSession = session;
      expect(await notifier.send(), isFalse);
      expect(notifier.state.draft.pendingSendKey, isNull);
      notifier.setDraftBody(List<String>.filled(1001, 'x').join());
      expect(await notifier.send(), isFalse);
      expect(notifier.state.errorMessage, contains('1000'));
    },
  );
}

AdoptionRequestNotifier _requestNotifier({
  required _ConfigurableSource source,
  required _MemoryStore store,
  required Future<AuthSession?> Function() readSession,
}) {
  return AdoptionRequestNotifier(
    listingId: 'listing-1',
    listingSource: FakeAdoptionUiSource(detail: uiAdoptionDetail()),
    requestSource: source,
    draftStore: store,
    readSession: readSession,
    now: () => DateTime.utc(2026, 7, 28, 5),
    keyFactory: (_, _, sequence) => 'request-$sequence',
  );
}

AdoptionChatNotifier _chatNotifier({
  required _ConfigurableSource source,
  required _MemoryStore store,
  required Future<AuthSession?> Function() readSession,
}) {
  return AdoptionChatNotifier(
    threadId: 'thread-1',
    source: source,
    draftStore: store,
    readSession: readSession,
    now: () => DateTime.utc(2026, 7, 28, 5),
    keyFactory: (_, _, sequence) => 'message-$sequence',
  );
}

void _completeRequest(AdoptionRequestNotifier notifier) {
  notifier
    ..setLivingCondition('Căn hộ an toàn')
    ..setPetExperience('Đã nuôi chó')
    ..setCarePlan('Khám định kỳ')
    ..setCommitmentAccepted(true);
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AdoptionChatPage _page({
  List<AdoptionChatMessage> messages = const [],
  String? nextCursor,
  bool hasMore = false,
  bool closed = false,
  int unreadCount = 0,
}) {
  return AdoptionChatPage(
    messages: messages,
    thread: AdoptionChatThread(
      threadId: 'thread-1',
      requestId: 'request-1',
      participantRole: AdoptionChatParticipantRole.adopter,
      lastReadAt: DateTime.utc(2026, 7, 28, 4),
      unreadCount: unreadCount,
      closedAt: closed ? DateTime.utc(2026, 7, 28, 5) : null,
    ),
    nextCursor: nextCursor,
    hasMore: hasMore,
    limit: 50,
  );
}

AdoptionChatMessage _message(
  String id, {
  int minute = 0,
  String senderUserId = 'shelter-1',
  String body = 'Đã nhận yêu cầu',
}) {
  return AdoptionChatMessage(
    messageId: id,
    threadId: 'thread-1',
    senderUserId: senderUserId,
    body: body,
    media: const [],
    createdAt: DateTime.utc(2026, 7, 28, 5, minute),
  );
}

class _ConfigurableSource implements AdoptionRequestChatSource {
  _ConfigurableSource({
    Map<String?, AdoptionChatPage>? pages,
    List<Object>? requestErrors,
    List<Object>? sendErrors,
    List<Object>? uploadErrors,
    List<Object>? markReadErrors,
  }) : pages = pages ?? {null: _page()},
       requestErrors = [...?requestErrors],
       sendErrors = [...?sendErrors],
       uploadErrors = [...?uploadErrors],
       markReadErrors = [...?markReadErrors];

  final Map<String?, AdoptionChatPage> pages;
  final List<Object> requestErrors;
  final List<Object> sendErrors;
  final List<Object> uploadErrors;
  final List<Object> markReadErrors;
  final List<String?> readCursors = [];
  final List<String> requestKeys = [];
  final List<String> sendKeys = [];
  final List<String> readMessageIds = [];

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) async {
    requestKeys.add(idempotencyKey);
    if (requestErrors.isNotEmpty) throw requestErrors.removeAt(0);
    return AdoptionRequestResult(
      requestId: 'request-1',
      listingId: listingId,
      adopterUserId: 'adopter-1',
      shelterId: 'shelter-1',
      livingCondition: draft.livingCondition,
      petExperience: draft.petExperience,
      carePlan: draft.carePlan,
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
    readCursors.add(cursor);
    return pages[cursor] ?? _page();
  }

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) async {
    sendKeys.add(idempotencyKey);
    if (sendErrors.isNotEmpty) throw sendErrors.removeAt(0);
    return _message(
      'sent-${sendKeys.length}',
      minute: 5 + sendKeys.length,
      senderUserId: 'adopter-1',
      body: body,
    );
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async {
    readMessageIds.add(throughMessageId);
    if (markReadErrors.isNotEmpty) throw markReadErrors.removeAt(0);
    return AdoptionChatReadState(
      threadId: threadId,
      lastReadAt: DateTime.utc(2026, 7, 28, 6),
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
    if (uploadErrors.isNotEmpty) throw uploadErrors.removeAt(0);
    onProgress(0.5);
    onProgress(1);
    return media.copyWith(
      mediaId: 'uploaded-${media.localId}',
      status: AdoptionChatUploadStatus.uploaded,
      progress: 1,
    );
  }
}

class _MemoryStore implements AdoptionRequestChatDraftStore {
  final requestDrafts = <String, AdoptionRequestDraft>{};
  final chatDrafts = <String, AdoptionChatDraft>{};
  final contexts = <String, AdoptionChatContext>{};
  bool failRequestWrites = false;
  bool failChatWrites = false;

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
    if (failRequestWrites) throw StateError('request persistence failed');
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
    if (failChatWrites) throw StateError('chat persistence failed');
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

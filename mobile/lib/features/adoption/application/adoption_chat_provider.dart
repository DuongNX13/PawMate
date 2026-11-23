import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../../auth/data/auth_api.dart';
import '../data/adoption_api.dart';
import '../data/adoption_request_chat_api.dart';
import '../data/adoption_request_chat_draft_store.dart';
import '../domain/adoption_request_chat_models.dart';
import 'adoption_runtime_providers.dart';

typedef AdoptionChatKeyFactory =
    String Function(String threadId, DateTime timestamp, int sequence);
typedef AdoptionSessionReader = Future<AuthSession?> Function();

final adoptionChatKeyFactoryProvider = Provider<AdoptionChatKeyFactory>((ref) {
  return (threadId, timestamp, sequence) {
    final safeId = threadId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return 'pawmate-day55-message-$safeId-'
        '${timestamp.microsecondsSinceEpoch}-$sequence';
  };
});

final adoptionChatProvider = StateNotifierProvider.autoDispose
    .family<AdoptionChatNotifier, AdoptionChatState, String>((ref, threadId) {
      ref.watch(adoptionSessionRevisionProvider);
      final notifier = AdoptionChatNotifier(
        threadId: threadId,
        source: ref.watch(adoptionRequestChatSourceProvider),
        draftStore: ref.watch(adoptionRequestChatDraftStoreProvider),
        readSession: () => ref.read(authSessionSnapshotProvider.future),
        now: ref.watch(adoptionClockProvider),
        keyFactory: ref.watch(adoptionChatKeyFactoryProvider),
      );
      unawaited(notifier.load());
      return notifier;
    });

class AdoptionChatState {
  const AdoptionChatState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.thread,
    this.messages = const [],
    this.draft = const AdoptionChatDraft(),
    this.context,
    this.currentUserId,
    this.nextCursor,
    this.hasMore = false,
    this.errorMessage,
    this.readWarning,
    this.draftPersistenceWarning,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingOlder;
  final bool isSending;
  final AdoptionChatThread? thread;
  final List<AdoptionChatMessage> messages;
  final AdoptionChatDraft draft;
  final AdoptionChatContext? context;
  final String? currentUserId;
  final String? nextCursor;
  final bool hasMore;
  final String? errorMessage;
  final String? readWarning;
  final String? draftPersistenceWarning;

  bool get hasPendingUpload => draft.media.any(
    (item) =>
        item.status == AdoptionChatUploadStatus.pending ||
        item.status == AdoptionChatUploadStatus.uploading,
  );

  bool get hasFailedUpload =>
      draft.media.any((item) => item.status == AdoptionChatUploadStatus.failed);

  bool get canSend {
    final body = draft.body.trim();
    return !isSending &&
        thread?.isClosed != true &&
        body.isNotEmpty &&
        body.length <= 1000 &&
        !hasPendingUpload &&
        !hasFailedUpload;
  }

  AdoptionChatState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingOlder,
    bool? isSending,
    AdoptionChatThread? thread,
    List<AdoptionChatMessage>? messages,
    AdoptionChatDraft? draft,
    AdoptionChatContext? context,
    String? currentUserId,
    String? nextCursor,
    bool? hasMore,
    String? errorMessage,
    String? readWarning,
    String? draftPersistenceWarning,
    bool clearError = false,
    bool clearReadWarning = false,
    bool clearPersistenceWarning = false,
    bool clearNextCursor = false,
  }) {
    return AdoptionChatState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      thread: thread ?? this.thread,
      messages: messages ?? this.messages,
      draft: draft ?? this.draft,
      context: context ?? this.context,
      currentUserId: currentUserId ?? this.currentUserId,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      readWarning: clearReadWarning ? null : readWarning ?? this.readWarning,
      draftPersistenceWarning: clearPersistenceWarning
          ? null
          : draftPersistenceWarning ?? this.draftPersistenceWarning,
    );
  }
}

class AdoptionChatNotifier extends StateNotifier<AdoptionChatState> {
  AdoptionChatNotifier({
    required this.threadId,
    required AdoptionRequestChatSource source,
    required AdoptionRequestChatDraftStore draftStore,
    required AdoptionSessionReader readSession,
    required DateTime Function() now,
    required AdoptionChatKeyFactory keyFactory,
  }) : _source = source,
       _draftStore = draftStore,
       _readSession = readSession,
       _now = now,
       _keyFactory = keyFactory,
       super(const AdoptionChatState());

  final String threadId;
  final AdoptionRequestChatSource _source;
  final AdoptionRequestChatDraftStore _draftStore;
  final AdoptionSessionReader _readSession;
  final DateTime Function() _now;
  final AdoptionChatKeyFactory _keyFactory;

  int _sequence = 0;
  String? _userId;

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      if (state.isRefreshing) return;
      state = state.copyWith(isRefreshing: true, clearError: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    final session = await _readSession();
    if (!mounted) return;
    if (session == null ||
        session.user.id.trim().isEmpty ||
        session.accessToken.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Bạn cần đăng nhập để mở cuộc trò chuyện.',
      );
      return;
    }
    _userId = session.user.id.trim();
    try {
      final local = refresh
          ? <Object?>[state.draft, state.context]
          : await Future.wait<Object?>([
              _draftStore.readChatDraft(userId: _userId!, threadId: threadId),
              _draftStore.readChatContext(userId: _userId!, threadId: threadId),
            ]);
      final draft = await _restoreMedia(local[0]! as AdoptionChatDraft);
      final page = await _source.readChat(
        accessToken: session.accessToken.trim(),
        threadId: threadId,
      );
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        thread: page.thread,
        messages: _mergeMessages(page.messages),
        draft: draft,
        context: local[1] as AdoptionChatContext?,
        currentUserId: _userId,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMore: page.hasMore,
        clearError: true,
      );
      unawaited(_markLatestRead(session));
    } on Object catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: _messageFor(error),
      );
    }
  }

  Future<void> loadOlder() async {
    if (!state.hasMore ||
        state.nextCursor == null ||
        state.isLoadingOlder ||
        state.isLoading) {
      return;
    }
    final session = await _readSession();
    if (!mounted || session == null || session.accessToken.trim().isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingOlder: true, clearError: true);
    try {
      final page = await _source.readChat(
        accessToken: session.accessToken.trim(),
        threadId: threadId,
        cursor: state.nextCursor,
      );
      if (!mounted) return;
      state = state.copyWith(
        isLoadingOlder: false,
        thread: page.thread,
        messages: _mergeMessages([...page.messages, ...state.messages]),
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMore: page.hasMore,
        clearError: true,
      );
    } on Object catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingOlder: false,
        errorMessage: _messageFor(error),
      );
    }
  }

  void setDraftBody(String value) {
    _replaceDraft(state.draft.copyWith(body: value, clearPendingSendKey: true));
  }

  Future<void> addMedia({
    required String path,
    required String mimeType,
    required int sizeBytes,
  }) async {
    if (!AdoptionChatMediaPolicy.isSupported(mimeType)) {
      state = state.copyWith(
        errorMessage: 'Chỉ hỗ trợ JPG, PNG, WebP hoặc MP4.',
      );
      return;
    }
    if (sizeBytes < 1 ||
        sizeBytes > AdoptionChatMediaPolicy.maxBytesFor(mimeType)) {
      state = state.copyWith(
        errorMessage: mimeType == 'video/mp4'
            ? 'Video không được vượt quá 50 MB.'
            : 'Ảnh không được vượt quá 10 MB.',
      );
      return;
    }
    if (state.draft.media.length >= AdoptionChatMediaPolicy.maxItems) {
      state = state.copyWith(
        errorMessage: 'Mỗi tin nhắn chỉ được tối đa 5 tệp.',
      );
      return;
    }
    final item = AdoptionChatDraftMedia(
      localId: 'chat-media-${_now().microsecondsSinceEpoch}-${_sequence++}',
      path: path,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
    _replaceDraft(
      state.draft.copyWith(
        media: [...state.draft.media, item],
        clearPendingSendKey: true,
      ),
    );
    await retryMedia(item.localId);
  }

  Future<void> retryMedia(String localId) async {
    final index = state.draft.media.indexWhere(
      (item) => item.localId == localId,
    );
    if (index < 0) return;
    final session = await _readSession();
    if (!mounted || session == null || session.accessToken.trim().isEmpty) {
      _replaceMedia(
        localId,
        state.draft.media[index].copyWith(
          status: AdoptionChatUploadStatus.failed,
          errorMessage: 'Bạn cần đăng nhập lại để tải tệp.',
        ),
      );
      return;
    }
    final uploading = state.draft.media[index].copyWith(
      status: AdoptionChatUploadStatus.uploading,
      progress: 0,
      clearMediaId: true,
      clearError: true,
    );
    _replaceMedia(localId, uploading);
    try {
      final uploaded = await _source.uploadChatMedia(
        accessToken: session.accessToken.trim(),
        threadId: threadId,
        media: uploading,
        onProgress: (progress) {
          if (!mounted) return;
          final current = _findMedia(localId);
          if (current?.status != AdoptionChatUploadStatus.uploading) return;
          _replaceMedia(
            localId,
            current!.copyWith(progress: progress.clamp(0, 1)),
          );
        },
      );
      if (!mounted) return;
      _replaceMedia(localId, uploaded);
      state = state.copyWith(clearError: true);
    } on Object catch (error) {
      if (!mounted) return;
      final current = _findMedia(localId) ?? uploading;
      _replaceMedia(
        localId,
        current.copyWith(
          status: AdoptionChatUploadStatus.failed,
          errorMessage: _messageFor(error),
        ),
      );
      state = state.copyWith(
        errorMessage: 'Tải tệp thất bại. Nội dung tin nhắn vẫn được giữ.',
      );
    }
  }

  void removeMedia(String localId) {
    _replaceDraft(
      state.draft.copyWith(
        media: [
          for (final item in state.draft.media)
            if (item.localId != localId) item,
        ],
        clearPendingSendKey: true,
      ),
    );
  }

  Future<bool> send() async {
    final body = state.draft.body.trim();
    if (state.isSending) return false;
    if (body.isEmpty || body.length > 1000) {
      state = state.copyWith(
        errorMessage: body.isEmpty
            ? 'Vui lòng nhập nội dung tin nhắn.'
            : 'Tin nhắn không được vượt quá 1000 ký tự.',
      );
      return false;
    }
    if (state.thread?.isClosed == true) {
      state = state.copyWith(
        errorMessage:
            'Cuộc trò chuyện đã đóng. Nội dung chưa gửi vẫn được giữ.',
      );
      return false;
    }
    if (state.hasPendingUpload || state.hasFailedUpload) {
      state = state.copyWith(
        errorMessage:
            'Hãy đợi tệp tải xong hoặc thử lại tệp lỗi trước khi gửi.',
      );
      return false;
    }
    final session = await _readSession();
    if (!mounted || session == null || session.accessToken.trim().isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Phiên đăng nhập đã hết hạn. Nội dung chưa gửi vẫn được giữ.',
      );
      return false;
    }
    final key =
        state.draft.pendingSendKey ??
        _keyFactory(threadId, _now(), _sequence++);
    final draft = state.draft.copyWith(pendingSendKey: key);
    state = state.copyWith(isSending: true, draft: draft, clearError: true);
    try {
      await _persist(draft);
      final message = await _source.sendMessage(
        accessToken: session.accessToken.trim(),
        threadId: threadId,
        body: body,
        mediaIds: [for (final item in draft.media) item.mediaId!],
        idempotencyKey: key,
      );
      await _draftStore.clearChatDraft(
        userId: session.user.id.trim(),
        threadId: threadId,
      );
      if (!mounted) return false;
      state = state.copyWith(
        isSending: false,
        messages: _mergeMessages([...state.messages, message]),
        draft: const AdoptionChatDraft(),
        clearError: true,
        clearPersistenceWarning: true,
      );
      unawaited(_markLatestRead(session));
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      final apiError = error is AdoptionApiException ? error : null;
      final clearKey = apiError?.code == 'IDEMPOTENCY_001';
      final failedDraft = clearKey
          ? draft.copyWith(clearPendingSendKey: true)
          : draft;
      state = state.copyWith(
        isSending: false,
        draft: failedDraft,
        errorMessage: _messageFor(error),
      );
      if (clearKey) await _persist(failedDraft);
      return false;
    }
  }

  Future<void> _markLatestRead(AuthSession session) async {
    if (!mounted || state.messages.isEmpty) return;
    final latest = state.messages.last;
    try {
      final read = await _source.markRead(
        accessToken: session.accessToken.trim(),
        threadId: threadId,
        throughMessageId: latest.messageId,
      );
      if (!mounted || read.threadId != threadId) return;
      final thread = state.thread;
      state = state.copyWith(
        thread: thread?.copyWith(
          lastReadAt: read.lastReadAt,
          unreadCount: read.unreadCount,
        ),
        clearReadWarning: true,
      );
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        readWarning:
            'Chưa đồng bộ trạng thái đã đọc. Tin nhắn và bản nháp vẫn an toàn.',
      );
    }
  }

  void _replaceDraft(AdoptionChatDraft draft) {
    state = state.copyWith(
      draft: draft,
      clearError: true,
      clearPersistenceWarning: true,
    );
    unawaited(_persist(draft));
  }

  void _replaceMedia(String localId, AdoptionChatDraftMedia replacement) {
    _replaceDraft(
      state.draft.copyWith(
        media: [
          for (final item in state.draft.media)
            if (item.localId == localId) replacement else item,
        ],
      ),
    );
  }

  AdoptionChatDraftMedia? _findMedia(String localId) {
    for (final item in state.draft.media) {
      if (item.localId == localId) return item;
    }
    return null;
  }

  Future<AdoptionChatDraft> _restoreMedia(AdoptionChatDraft draft) async {
    final restored = <AdoptionChatDraftMedia>[];
    for (final item in draft.media) {
      final exists = await File(item.path).exists();
      restored.add(
        exists
            ? item
            : item.copyWith(
                status: AdoptionChatUploadStatus.failed,
                errorMessage: 'Tệp không còn trên thiết bị. Vui lòng chọn lại.',
              ),
      );
    }
    return draft.copyWith(media: List.unmodifiable(restored));
  }

  Future<void> _persist(AdoptionChatDraft draft) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _draftStore.saveChatDraft(
        userId: userId,
        threadId: threadId,
        draft: draft,
      );
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        draftPersistenceWarning:
            'Chưa thể lưu bản nháp trên thiết bị. Đừng đóng màn hình này.',
      );
    }
  }

  static List<AdoptionChatMessage> _mergeMessages(
    Iterable<AdoptionChatMessage> messages,
  ) {
    final byId = <String, AdoptionChatMessage>{};
    for (final message in messages) {
      byId[message.messageId] = message;
    }
    final result = byId.values.toList(growable: false);
    result.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime != 0 ? byTime : left.messageId.compareTo(right.messageId);
    });
    return result;
  }

  static String _messageFor(Object error) {
    if (error is AdoptionApiException) {
      if (error.isAuthRequired) {
        return 'Phiên đăng nhập đã hết hạn. Nội dung chưa gửi vẫn được giữ.';
      }
      if (error.code == 'ADOPTION_008') {
        return 'Cuộc trò chuyện đã đóng. Nội dung chưa gửi vẫn được giữ.';
      }
      if (error.code == 'ADOPTION_007') {
        return 'Không tìm thấy cuộc trò chuyện hoặc bạn không có quyền truy cập.';
      }
      if (error.isOffline) {
        return 'Không thể kết nối. Bản nháp vẫn được giữ để thử lại.';
      }
      return error.message;
    }
    return 'Không thể hoàn tất thao tác. Bản nháp vẫn được giữ.';
  }
}

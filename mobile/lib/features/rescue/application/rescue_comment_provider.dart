import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/rescue_comment_api.dart';
import '../domain/rescue_comment_models.dart';
import '../domain/rescue_draft_models.dart';

enum RescueCommentLoadStatus { initial, loading, ready, error }

@immutable
class RescueCommentState {
  const RescueCommentState({
    this.status = RescueCommentLoadStatus.initial,
    this.comments = const [],
    this.draftText = '',
    this.media = const [],
    this.isSending = false,
    this.commentsClosed = false,
    this.isStale = false,
    this.errorMessage,
    this.lastLoadedAt,
    this.pendingSendKey,
    this.replyToCommentId,
    this.replyToDisplayName,
  });

  final RescueCommentLoadStatus status;
  final List<RescueComment> comments;
  final String draftText;
  final List<RescueCommentDraftMedia> media;
  final bool isSending;
  final bool commentsClosed;
  final bool isStale;
  final String? errorMessage;
  final DateTime? lastLoadedAt;

  /// Retained after a failed send so retrying the exact payload reuses the
  /// same idempotency key. Editing the payload clears it.
  final String? pendingSendKey;
  final String? replyToCommentId;
  final String? replyToDisplayName;

  bool get hasDraft => draftText.isNotEmpty || media.isNotEmpty;
  bool get hasPendingUpload => media.any(
    (item) =>
        item.status == RescueCommentUploadStatus.pending ||
        item.status == RescueCommentUploadStatus.uploading,
  );
  bool get hasFailedUpload =>
      media.any((item) => item.status == RescueCommentUploadStatus.failed);
  bool get canSend =>
      !commentsClosed &&
      !isSending &&
      draftText.trim().isNotEmpty &&
      draftText.trim().length <= 500 &&
      !hasPendingUpload &&
      !hasFailedUpload &&
      media.every((item) => item.uploaded);

  RescueCommentState copyWith({
    RescueCommentLoadStatus? status,
    List<RescueComment>? comments,
    String? draftText,
    List<RescueCommentDraftMedia>? media,
    bool? isSending,
    bool? commentsClosed,
    bool? isStale,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastLoadedAt,
    String? pendingSendKey,
    bool clearPendingSendKey = false,
    String? replyToCommentId,
    String? replyToDisplayName,
    bool clearReplyTarget = false,
  }) => RescueCommentState(
    status: status ?? this.status,
    comments: comments ?? this.comments,
    draftText: draftText ?? this.draftText,
    media: media ?? this.media,
    isSending: isSending ?? this.isSending,
    commentsClosed: commentsClosed ?? this.commentsClosed,
    isStale: isStale ?? this.isStale,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
    pendingSendKey: clearPendingSendKey
        ? null
        : (pendingSendKey ?? this.pendingSendKey),
    replyToCommentId: clearReplyTarget
        ? null
        : (replyToCommentId ?? this.replyToCommentId),
    replyToDisplayName: clearReplyTarget
        ? null
        : (replyToDisplayName ?? this.replyToDisplayName),
  );
}

final rescueCommentClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final rescueCommentProvider =
    StateNotifierProvider.family<
      RescueCommentNotifier,
      RescueCommentState,
      String
    >((ref, caseId) {
      final notifier = RescueCommentNotifier(
        caseId: caseId,
        source: ref.watch(rescueCommentSourceProvider),
        accessToken: () => ref.read(authAccessTokenProvider.future),
        now: ref.watch(rescueCommentClockProvider),
      );
      ref.listen<int>(authSessionRevisionProvider, (previous, next) {
        if (previous != null && previous != next) {
          notifier.resetForSessionChange();
        }
      });
      return notifier;
    });

class RescueCommentNotifier extends StateNotifier<RescueCommentState> {
  RescueCommentNotifier({
    required this.caseId,
    required RescueCommentSource source,
    required Future<String?> Function() accessToken,
    required DateTime Function() now,
  }) : _source = source,
       _accessToken = accessToken,
       _now = now,
       super(const RescueCommentState());

  final String caseId;
  final RescueCommentSource _source;
  final Future<String?> Function() _accessToken;
  final DateTime Function() _now;
  var _sequence = 0;
  var _sessionGeneration = 0;

  Future<void> load({bool force = false}) async {
    if (!force &&
        (state.status == RescueCommentLoadStatus.loading ||
            state.status == RescueCommentLoadStatus.ready)) {
      return;
    }
    final generation = _sessionGeneration;
    final token = await _requireAccessToken(generation);
    if (token == null) return;
    state = state.copyWith(
      status: RescueCommentLoadStatus.loading,
      clearError: true,
    );
    try {
      final page = await _source.listComments(
        accessToken: token,
        caseId: caseId,
      );
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        status: RescueCommentLoadStatus.ready,
        comments: _ordered(page.items),
        isStale: false,
        lastLoadedAt: _now().toUtc(),
        clearError: true,
      );
    } on RescueCommentApiException catch (error) {
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        status: state.comments.isEmpty
            ? RescueCommentLoadStatus.error
            : RescueCommentLoadStatus.ready,
        isStale: state.comments.isNotEmpty,
        commentsClosed: state.commentsClosed || error.commentsClosed,
        errorMessage: _safeMessage(error),
      );
    } catch (_) {
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        status: state.comments.isEmpty
            ? RescueCommentLoadStatus.error
            : RescueCommentLoadStatus.ready,
        isStale: state.comments.isNotEmpty,
        errorMessage:
            'Không tải được bình luận. Nội dung chưa gửi vẫn được giữ.',
      );
    }
  }

  void setDraftText(String value) {
    if (value == state.draftText) return;
    state = state.copyWith(
      draftText: value,
      clearError: true,
      clearPendingSendKey: true,
    );
  }

  void setReplyTarget(RescueComment comment) {
    if (comment.moderationState == RescueCommentModerationState.hidden) return;
    state = state.copyWith(
      replyToCommentId: comment.commentId,
      replyToDisplayName: comment.author.displayName,
      clearError: true,
      clearPendingSendKey: true,
    );
  }

  void clearReplyTarget() {
    state = state.copyWith(
      clearReplyTarget: true,
      clearPendingSendKey: true,
      clearError: true,
    );
  }

  void markClosed() {
    state = state.copyWith(
      commentsClosed: true,
      isSending: false,
      clearPendingSendKey: true,
    );
  }

  Future<void> pickImage(ImagePicker picker) async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) await addMediaFile(file);
  }

  Future<void> pickVideo(ImagePicker picker) async {
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) await addMediaFile(file);
  }

  @visibleForTesting
  Future<void> addMediaFile(XFile file) async {
    final mimeType = _mimeType(file.path);
    final size = await file.length();
    if (mimeType == null ||
        !RescueCommentDraftMedia.isSupported(mimeType) ||
        size > RescueMediaPolicy.maxBytesFor(mimeType)) {
      state = state.copyWith(
        errorMessage: mimeType == 'video/mp4'
            ? 'Video phải là MP4 và không quá 50 MB.'
            : 'Ảnh phải là JPEG, PNG hoặc WebP và không quá 10 MB.',
      );
      return;
    }
    if (state.media.length >= RescueMediaPolicy.maxItems) {
      state = state.copyWith(
        errorMessage: 'Mỗi bình luận chỉ được tối đa 5 ảnh/video.',
      );
      return;
    }
    final item = RescueCommentDraftMedia(
      localId: 'comment-media-${_now().microsecondsSinceEpoch}-${_sequence++}',
      path: file.path,
      mimeType: mimeType,
      sizeBytes: size,
    );
    state = state.copyWith(
      media: [...state.media, item],
      clearError: true,
      clearPendingSendKey: true,
    );
    await retryMedia(item.localId);
  }

  Future<void> retryMedia(String localId) async {
    final index = state.media.indexWhere((item) => item.localId == localId);
    if (index < 0) return;
    final generation = _sessionGeneration;
    final token = await _requireAccessToken(generation);
    if (token == null) {
      if (generation != _sessionGeneration) return;
      _replaceMedia(
        localId,
        state.media[index].copyWith(
          status: RescueCommentUploadStatus.failed,
          errorMessage: 'Bạn cần đăng nhập lại để tải tệp.',
        ),
      );
      return;
    }
    final uploading = state.media[index].copyWith(
      status: RescueCommentUploadStatus.uploading,
      progress: 0,
      clearError: true,
      clearMediaId: true,
    );
    _replaceMedia(localId, uploading);
    try {
      final uploaded = await _source.uploadMedia(
        accessToken: token,
        media: uploading,
        onProgress: (progress) {
          if (generation != _sessionGeneration) return;
          final current = _findMedia(localId);
          if (current == null ||
              current.status != RescueCommentUploadStatus.uploading) {
            return;
          }
          _replaceMedia(
            localId,
            current.copyWith(progress: progress.clamp(0, 1)),
          );
        },
      );
      if (generation != _sessionGeneration) return;
      _replaceMedia(localId, uploaded);
      state = state.copyWith(clearError: true);
    } on RescueCommentApiException catch (error) {
      if (generation != _sessionGeneration) return;
      final current = _findMedia(localId) ?? uploading;
      _replaceMedia(
        localId,
        current.copyWith(
          status: RescueCommentUploadStatus.failed,
          errorMessage: _safeMessage(error),
        ),
      );
      state = state.copyWith(errorMessage: _safeMessage(error));
    } catch (_) {
      if (generation != _sessionGeneration) return;
      final current = _findMedia(localId) ?? uploading;
      _replaceMedia(
        localId,
        current.copyWith(
          status: RescueCommentUploadStatus.failed,
          errorMessage: 'Tải tệp thất bại. Chạm để thử lại.',
        ),
      );
      state = state.copyWith(
        errorMessage: 'Tải tệp thất bại. Nội dung bình luận vẫn được giữ.',
      );
    }
  }

  void removeMedia(String localId) {
    state = state.copyWith(
      media: [
        for (final item in state.media)
          if (item.localId != localId) item,
      ],
      clearError: true,
      clearPendingSendKey: true,
    );
  }

  Future<bool> send() async {
    final body = state.draftText.trim();
    if (body.isEmpty || body.length > 500) {
      state = state.copyWith(
        errorMessage: body.isEmpty
            ? 'Vui lòng nhập nội dung bình luận.'
            : 'Bình luận không được vượt quá 500 ký tự.',
      );
      return false;
    }
    if (state.commentsClosed) {
      state = state.copyWith(
        errorMessage:
            'Ca cứu hộ đã đóng bình luận. Nội dung chưa gửi vẫn được giữ.',
      );
      return false;
    }
    if (state.hasPendingUpload || state.hasFailedUpload) {
      state = state.copyWith(
        errorMessage:
            'Hãy đợi tệp tải xong hoặc thử lại tệp bị lỗi trước khi gửi.',
      );
      return false;
    }
    final generation = _sessionGeneration;
    final token = await _requireAccessToken(generation);
    if (token == null) return false;
    final idempotencyKey =
        state.pendingSendKey ??
        'pawmate-day45-comment-${_now().microsecondsSinceEpoch}-${_sequence++}';
    final optimisticId = 'local-$idempotencyKey';
    final optimistic = RescueComment(
      commentId: optimisticId,
      caseId: caseId,
      author: const RescueCommentAuthor(displayName: 'Bạn'),
      body: body,
      media: const [],
      createdAt: _now().toUtc(),
      updatedAt: _now().toUtc(),
      moderationState: RescueCommentModerationState.pending,
      replyToCommentId: state.replyToCommentId,
      isOptimistic: true,
      optimisticMediaCount: state.media.length,
    );
    state = state.copyWith(
      comments: _ordered([...state.comments, optimistic]),
      isSending: true,
      pendingSendKey: idempotencyKey,
      clearError: true,
    );
    try {
      final persisted = await _source.sendComment(
        accessToken: token,
        caseId: caseId,
        body: body,
        mediaIds: [for (final item in state.media) item.mediaId!],
        idempotencyKey: idempotencyKey,
        replyToCommentId: state.replyToCommentId,
      );
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        comments: _ordered([
          for (final item in state.comments)
            if (item.commentId == optimisticId) persisted else item,
        ]),
        draftText: '',
        media: const [],
        isSending: false,
        clearError: true,
        clearPendingSendKey: true,
        clearReplyTarget: true,
      );
      return true;
    } on RescueCommentApiException catch (error) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        comments: [
          for (final item in state.comments)
            if (item.commentId != optimisticId) item,
        ],
        isSending: false,
        commentsClosed: state.commentsClosed || error.commentsClosed,
        errorMessage: _safeMessage(error),
      );
      return false;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        comments: [
          for (final item in state.comments)
            if (item.commentId != optimisticId) item,
        ],
        isSending: false,
        errorMessage:
            'Không thể gửi bình luận. Nội dung vẫn được giữ để thử lại.',
      );
      return false;
    }
  }

  void resetForSessionChange() {
    _sessionGeneration += 1;
    state = const RescueCommentState();
  }

  Future<String?> _requireAccessToken(int generation) async {
    final token = await _accessToken();
    if (generation != _sessionGeneration) return null;
    if (token == null || token.trim().isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Phiên đăng nhập đã hết hạn. Nội dung chưa gửi vẫn được giữ trong phiên này.',
      );
      return null;
    }
    return token.trim();
  }

  void _replaceMedia(String localId, RescueCommentDraftMedia replacement) {
    state = state.copyWith(
      media: [
        for (final item in state.media)
          if (item.localId == localId) replacement else item,
      ],
    );
  }

  RescueCommentDraftMedia? _findMedia(String localId) {
    for (final item in state.media) {
      if (item.localId == localId) return item;
    }
    return null;
  }

  static List<RescueComment> _ordered(Iterable<RescueComment> comments) {
    final result = [...comments];
    result.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime != 0 ? byTime : left.commentId.compareTo(right.commentId);
    });
    return result;
  }

  static String _safeMessage(RescueCommentApiException error) {
    if (error.commentsClosed) {
      return 'Ca cứu hộ đã đóng bình luận. Nội dung chưa gửi vẫn được giữ.';
    }
    if (error.authRequired) {
      return 'Phiên đăng nhập đã hết hạn. Nội dung chưa gửi vẫn được giữ.';
    }
    return error.message;
  }

  static String? _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return null;
  }
}

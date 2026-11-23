import 'package:flutter/foundation.dart';

import 'rescue_draft_models.dart';

enum RescueCommentModerationState { visible, pending, hidden }

extension RescueCommentModerationStateLabel on RescueCommentModerationState {
  String get label => switch (this) {
    RescueCommentModerationState.visible => 'Đã đăng',
    RescueCommentModerationState.pending => 'Đang kiểm duyệt',
    RescueCommentModerationState.hidden => 'Đã ẩn',
  };
}

@immutable
class RescueCommentAuthor {
  const RescueCommentAuthor({required this.displayName, this.avatarUrl});

  final String displayName;
  final Uri? avatarUrl;

  factory RescueCommentAuthor.fromJson(Map<String, dynamic> json) =>
      RescueCommentAuthor(
        displayName: _requiredString(json, 'displayName'),
        avatarUrl: _optionalUri(json['avatarUrl']),
      );
}

@immutable
class RescueCommentMedia {
  const RescueCommentMedia({
    required this.mediaId,
    required this.mimeType,
    required this.publicUrl,
    this.width,
    this.height,
    this.durationSeconds,
  });

  final String mediaId;
  final String mimeType;
  final Uri publicUrl;
  final int? width;
  final int? height;
  final int? durationSeconds;

  bool get isVideo => mimeType == 'video/mp4';

  factory RescueCommentMedia.fromJson(Map<String, dynamic> json) =>
      RescueCommentMedia(
        mediaId: _requiredString(json, 'mediaId'),
        mimeType: _requiredString(json, 'mimeType'),
        publicUrl: _requiredUri(json, 'publicUrl'),
        width: _optionalInt(json['width']),
        height: _optionalInt(json['height']),
        durationSeconds: _optionalInt(json['durationSeconds']),
      );
}

@immutable
class RescueComment {
  const RescueComment({
    required this.commentId,
    required this.caseId,
    required this.author,
    required this.body,
    required this.media,
    required this.createdAt,
    required this.updatedAt,
    required this.moderationState,
    this.replyToCommentId,
    this.isOptimistic = false,
    this.optimisticMediaCount = 0,
  });

  final String commentId;
  final String caseId;
  final RescueCommentAuthor author;
  final String body;
  final List<RescueCommentMedia> media;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RescueCommentModerationState moderationState;
  final String? replyToCommentId;
  final bool isOptimistic;
  final int optimisticMediaCount;

  factory RescueComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final media = json['media'];
    return RescueComment(
      commentId: _requiredString(json, 'commentId'),
      caseId: _requiredString(json, 'caseId'),
      author: RescueCommentAuthor.fromJson(
        Map<String, dynamic>.from(_requiredMap(author, 'author')),
      ),
      body: _requiredString(json, 'body'),
      media: media is List
          ? [
              for (final item in media)
                if (item is Map)
                  RescueCommentMedia.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      moderationState: switch (json['moderationState']) {
        'pending' => RescueCommentModerationState.pending,
        'hidden' => RescueCommentModerationState.hidden,
        _ => RescueCommentModerationState.visible,
      },
      replyToCommentId: _optionalString(json['replyToCommentId']),
    );
  }
}

@immutable
class RescueCommentPage {
  const RescueCommentPage({required this.items, this.nextCursor});

  final List<RescueComment> items;
  final String? nextCursor;
}

enum RescueCommentUploadStatus { pending, uploading, uploaded, failed }

@immutable
class RescueCommentDraftMedia {
  const RescueCommentDraftMedia({
    required this.localId,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    this.mediaId,
    this.status = RescueCommentUploadStatus.pending,
    this.progress = 0,
    this.errorMessage,
  });

  final String localId;
  final String path;
  final String mimeType;
  final int sizeBytes;
  final String? mediaId;
  final RescueCommentUploadStatus status;
  final double progress;
  final String? errorMessage;

  bool get uploaded =>
      status == RescueCommentUploadStatus.uploaded && mediaId != null;
  bool get isVideo => mimeType == 'video/mp4';

  RescueCommentDraftMedia copyWith({
    String? mediaId,
    bool clearMediaId = false,
    RescueCommentUploadStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) => RescueCommentDraftMedia(
    localId: localId,
    path: path,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    mediaId: clearMediaId ? null : (mediaId ?? this.mediaId),
    status: status ?? this.status,
    progress: progress ?? this.progress,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );

  static bool isSupported(String mimeType) =>
      RescueMediaPolicy.isSupported(mimeType);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Invalid $key');
}

String? _optionalString(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

Map<dynamic, dynamic> _requiredMap(dynamic value, String key) {
  if (value is Map) return value;
  throw FormatException('Invalid $key');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  throw FormatException('Invalid $key');
}

Uri _requiredUri(Map<String, dynamic> json, String key) {
  final value = _optionalUri(json[key]);
  if (value != null) return value;
  throw FormatException('Invalid $key');
}

Uri? _optionalUri(dynamic value) {
  if (value is! String) return null;
  final parsed = Uri.tryParse(value);
  return parsed != null && parsed.hasScheme ? parsed : null;
}

int? _optionalInt(dynamic value) =>
    value is num && value >= 0 ? value.toInt() : null;

import 'package:flutter/foundation.dart';

import 'adoption_models.dart';

enum AdoptionRequestStatus {
  submitted,
  reviewing,
  approved,
  rejected,
  cancelled;

  String get label => switch (this) {
    AdoptionRequestStatus.submitted => 'Đã gửi',
    AdoptionRequestStatus.reviewing => 'Đang xem xét',
    AdoptionRequestStatus.approved => 'Đã chấp thuận',
    AdoptionRequestStatus.rejected => 'Không phù hợp',
    AdoptionRequestStatus.cancelled => 'Đã hủy',
  };

  static AdoptionRequestStatus fromJson(dynamic value) => switch (value) {
    'submitted' => AdoptionRequestStatus.submitted,
    'reviewing' => AdoptionRequestStatus.reviewing,
    'approved' => AdoptionRequestStatus.approved,
    'rejected' => AdoptionRequestStatus.rejected,
    'cancelled' => AdoptionRequestStatus.cancelled,
    _ => throw const FormatException('Invalid Adoption request status.'),
  };
}

enum AdoptionRequestListingAvailability {
  available,
  unavailable,
  expired,
  deleted;

  String get label => switch (this) {
    AdoptionRequestListingAvailability.available => 'Hồ sơ đang hoạt động',
    AdoptionRequestListingAvailability.unavailable =>
      'Hồ sơ hiện không nhận thêm yêu cầu',
    AdoptionRequestListingAvailability.expired =>
      'Tin nhận nuôi đã hết hiệu lực',
    AdoptionRequestListingAvailability.deleted => 'Hồ sơ đã bị xóa',
  };

  bool get canOpenProfile =>
      this == AdoptionRequestListingAvailability.available ||
      this == AdoptionRequestListingAvailability.unavailable;

  static AdoptionRequestListingAvailability fromJson(dynamic value) =>
      switch (value) {
        'available' => AdoptionRequestListingAvailability.available,
        'unavailable' => AdoptionRequestListingAvailability.unavailable,
        'expired' => AdoptionRequestListingAvailability.expired,
        'deleted' => AdoptionRequestListingAvailability.deleted,
        _ => throw const FormatException(
          'Invalid Adoption request listing availability.',
        ),
      };
}

@immutable
class AdoptionRequestSummary {
  const AdoptionRequestSummary({
    required this.requestId,
    required this.listingId,
    required this.petName,
    required this.status,
    required this.listingAvailability,
    required this.createdAt,
    required this.updatedAt,
    this.threadId,
  });

  factory AdoptionRequestSummary.fromJson(Map<String, dynamic> json) {
    return AdoptionRequestSummary(
      requestId: _requiredString(json, 'requestId'),
      listingId: _requiredString(json, 'listingId'),
      petName: _requiredString(json, 'petName'),
      status: AdoptionRequestStatus.fromJson(json['status']),
      listingAvailability: AdoptionRequestListingAvailability.fromJson(
        json['listingAvailability'],
      ),
      threadId: _optionalString(json['threadId']),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  final String requestId;
  final String listingId;
  final String petName;
  final AdoptionRequestStatus status;
  final AdoptionRequestListingAvailability listingAvailability;
  final String? threadId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class AdoptionRequestDraft {
  const AdoptionRequestDraft({
    this.livingCondition = '',
    this.petExperience = '',
    this.carePlan = '',
    this.note = '',
    this.commitmentAccepted = false,
    this.pendingSubmitKey,
  });

  factory AdoptionRequestDraft.fromJson(Map<String, dynamic> json) {
    return AdoptionRequestDraft(
      livingCondition: json['livingCondition']?.toString() ?? '',
      petExperience: json['petExperience']?.toString() ?? '',
      carePlan: json['carePlan']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      commitmentAccepted: json['commitmentAccepted'] == true,
      pendingSubmitKey: _optionalString(json['pendingSubmitKey']),
    );
  }

  final String livingCondition;
  final String petExperience;
  final String carePlan;
  final String note;
  final bool commitmentAccepted;
  final String? pendingSubmitKey;

  bool get isValid =>
      _isBounded(livingCondition, 500) &&
      _isBounded(petExperience, 500) &&
      _isBounded(carePlan, 500) &&
      note.trim().length <= 1000 &&
      commitmentAccepted;

  AdoptionRequestDraft copyWith({
    String? livingCondition,
    String? petExperience,
    String? carePlan,
    String? note,
    bool? commitmentAccepted,
    String? pendingSubmitKey,
    bool clearPendingSubmitKey = false,
  }) {
    return AdoptionRequestDraft(
      livingCondition: livingCondition ?? this.livingCondition,
      petExperience: petExperience ?? this.petExperience,
      carePlan: carePlan ?? this.carePlan,
      note: note ?? this.note,
      commitmentAccepted: commitmentAccepted ?? this.commitmentAccepted,
      pendingSubmitKey: clearPendingSubmitKey
          ? null
          : pendingSubmitKey ?? this.pendingSubmitKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'livingCondition': livingCondition,
    'petExperience': petExperience,
    'carePlan': carePlan,
    'note': note,
    'commitmentAccepted': commitmentAccepted,
    if (pendingSubmitKey != null) 'pendingSubmitKey': pendingSubmitKey,
  };

  Map<String, dynamic> toRequestJson() => {
    'livingCondition': livingCondition.trim(),
    'petExperience': petExperience.trim(),
    'carePlan': carePlan.trim(),
    'commitmentAccepted': true,
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };

  static bool _isBounded(String value, int maximum) {
    final normalized = value.trim();
    return normalized.isNotEmpty && normalized.length <= maximum;
  }
}

@immutable
class AdoptionRequestResult {
  const AdoptionRequestResult({
    required this.requestId,
    required this.listingId,
    required this.adopterUserId,
    required this.shelterId,
    required this.livingCondition,
    required this.petExperience,
    required this.carePlan,
    required this.commitmentAccepted,
    required this.status,
    required this.threadId,
    required this.createdAt,
    this.updatedAt,
    this.note,
  });

  factory AdoptionRequestResult.fromJson(Map<String, dynamic> json) {
    if (json['commitmentAccepted'] != true) {
      throw const FormatException('Invalid Adoption request commitment.');
    }
    return AdoptionRequestResult(
      requestId: _requiredString(json, 'requestId'),
      listingId: _requiredString(json, 'listingId'),
      adopterUserId: _requiredString(json, 'adopterUserId'),
      shelterId: _requiredString(json, 'shelterId'),
      livingCondition: _requiredString(json, 'livingCondition'),
      petExperience: _requiredString(json, 'petExperience'),
      carePlan: _requiredString(json, 'carePlan'),
      commitmentAccepted: true,
      status: AdoptionRequestStatus.fromJson(json['status']),
      threadId: _requiredString(json, 'threadId'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt']),
      note: _optionalString(json['note']),
    );
  }

  final String requestId;
  final String listingId;
  final String adopterUserId;
  final String shelterId;
  final String livingCondition;
  final String petExperience;
  final String carePlan;
  final bool commitmentAccepted;
  final AdoptionRequestStatus status;
  final String threadId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? note;
}

enum AdoptionChatParticipantRole {
  adopter,
  shelter;

  String get label => switch (this) {
    AdoptionChatParticipantRole.adopter => 'Người nhận nuôi',
    AdoptionChatParticipantRole.shelter => 'Mái ấm',
  };

  static AdoptionChatParticipantRole fromJson(dynamic value) => switch (value) {
    'adopter' => AdoptionChatParticipantRole.adopter,
    'shelter' => AdoptionChatParticipantRole.shelter,
    _ => throw const FormatException('Invalid Adoption chat role.'),
  };
}

@immutable
class AdoptionChatMedia {
  const AdoptionChatMedia({
    required this.mediaId,
    required this.ownerUserId,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.status,
    required this.createdAt,
    this.downloadPath,
    this.publicUrl,
    this.width,
    this.height,
    this.durationSeconds,
  });

  factory AdoptionChatMedia.fromJson(Map<String, dynamic> json) {
    final purpose = _requiredString(json, 'purpose');
    if (purpose != 'adoption_chat') {
      throw const FormatException('Invalid Adoption chat media purpose.');
    }
    final mediaId = _requiredString(json, 'mediaId');
    final rawDownloadPath = _optionalString(json['downloadPath']);
    if (rawDownloadPath != null) {
      final path = Uri.tryParse(rawDownloadPath);
      final segments = path?.pathSegments;
      if (path == null ||
          path.hasScheme ||
          path.hasAuthority ||
          path.hasQuery ||
          path.hasFragment ||
          segments == null ||
          segments.length != 5 ||
          segments[0] != 'adoption' ||
          segments[1] != 'chat' ||
          segments[2].isEmpty ||
          segments[3] != 'media' ||
          segments[4] != mediaId) {
        throw const FormatException(
          'Invalid private Adoption chat media path.',
        );
      }
    }
    final rawUrl = _optionalString(json['publicUrl']);
    final publicUrl = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (rawUrl != null &&
        (publicUrl == null ||
            !publicUrl.hasScheme ||
            !const {'http', 'https'}.contains(publicUrl.scheme))) {
      throw const FormatException('Invalid Adoption chat media URL.');
    }
    return AdoptionChatMedia(
      mediaId: mediaId,
      ownerUserId: _requiredString(json, 'ownerUserId'),
      mimeType: _requiredString(json, 'mimeType'),
      sizeBytes: _requiredInt(json, 'sizeBytes'),
      sha256: _requiredString(json, 'sha256'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      downloadPath: rawDownloadPath,
      publicUrl: publicUrl,
      width: _optionalInt(json['width']),
      height: _optionalInt(json['height']),
      durationSeconds: _optionalDouble(json['durationSeconds']),
    );
  }

  final String mediaId;
  final String ownerUserId;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String status;
  final DateTime createdAt;

  /// Relative API path only. The client builds its own authenticated request.
  final String? downloadPath;
  final Uri? publicUrl;
  final int? width;
  final int? height;
  final double? durationSeconds;
}

@immutable
class AdoptionChatMessage {
  const AdoptionChatMessage({
    required this.messageId,
    required this.threadId,
    required this.senderUserId,
    required this.body,
    required this.media,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdoptionChatMessage.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    if (rawMedia is! List) {
      throw const FormatException('Invalid Adoption chat media list.');
    }
    final threadId = _requiredString(json, 'threadId');
    final media = List<AdoptionChatMedia>.unmodifiable(
      rawMedia.map((item) => AdoptionChatMedia.fromJson(_readMap(item))),
    );
    for (final attachment in media) {
      final path = attachment.downloadPath;
      if (path != null && Uri.parse(path).pathSegments[2] != threadId) {
        throw const FormatException('Invalid Adoption chat media thread.');
      }
    }
    return AdoptionChatMessage(
      messageId: _requiredString(json, 'messageId'),
      threadId: threadId,
      senderUserId: _requiredString(json, 'senderUserId'),
      body: _requiredString(json, 'body'),
      media: media,
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt']),
    );
  }

  final String messageId;
  final String threadId;
  final String senderUserId;
  final String body;
  final List<AdoptionChatMedia> media;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

@immutable
class AdoptionChatThread {
  const AdoptionChatThread({
    required this.threadId,
    required this.requestId,
    required this.participantRole,
    required this.lastReadAt,
    required this.unreadCount,
    this.closedAt,
  });

  factory AdoptionChatThread.fromJson(Map<String, dynamic> json) {
    return AdoptionChatThread(
      threadId: _requiredString(json, 'threadId'),
      requestId: _requiredString(json, 'requestId'),
      participantRole: AdoptionChatParticipantRole.fromJson(
        json['participantRole'],
      ),
      lastReadAt: _requiredDateTime(json, 'lastReadAt'),
      unreadCount: _requiredInt(json, 'unreadCount'),
      closedAt: _optionalDateTime(json['closedAt']),
    );
  }

  final String threadId;
  final String requestId;
  final AdoptionChatParticipantRole participantRole;
  final DateTime lastReadAt;
  final int unreadCount;
  final DateTime? closedAt;

  bool get isClosed => closedAt != null;

  AdoptionChatThread copyWith({DateTime? lastReadAt, int? unreadCount}) {
    return AdoptionChatThread(
      threadId: threadId,
      requestId: requestId,
      participantRole: participantRole,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      unreadCount: unreadCount ?? this.unreadCount,
      closedAt: closedAt,
    );
  }
}

@immutable
class AdoptionChatPage {
  const AdoptionChatPage({
    required this.messages,
    required this.thread,
    required this.hasMore,
    required this.limit,
    this.nextCursor,
  });

  factory AdoptionChatPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['data'];
    if (rawItems is! List) {
      throw const FormatException('Invalid Adoption chat message list.');
    }
    final pageInfo = _requiredMap(json, 'pageInfo');
    return AdoptionChatPage(
      messages: List.unmodifiable(
        rawItems.map((item) => AdoptionChatMessage.fromJson(_readMap(item))),
      ),
      thread: AdoptionChatThread.fromJson(_requiredMap(json, 'thread')),
      nextCursor: _optionalString(pageInfo['nextCursor']),
      hasMore: pageInfo['hasMore'] == true,
      limit: _requiredInt(pageInfo, 'limit'),
    );
  }

  final List<AdoptionChatMessage> messages;
  final AdoptionChatThread thread;
  final String? nextCursor;
  final bool hasMore;
  final int limit;
}

@immutable
class AdoptionChatReadState {
  const AdoptionChatReadState({
    required this.threadId,
    required this.lastReadAt,
    required this.unreadCount,
  });

  factory AdoptionChatReadState.fromJson(Map<String, dynamic> json) {
    return AdoptionChatReadState(
      threadId: _requiredString(json, 'threadId'),
      lastReadAt: _requiredDateTime(json, 'lastReadAt'),
      unreadCount: _requiredInt(json, 'unreadCount'),
    );
  }

  final String threadId;
  final DateTime lastReadAt;
  final int unreadCount;
}

enum AdoptionChatUploadStatus { pending, uploading, uploaded, failed }

abstract final class AdoptionChatMediaPolicy {
  static const maxImageBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxItems = 5;

  static bool isSupported(String mimeType) =>
      mimeType == 'image/jpeg' ||
      mimeType == 'image/png' ||
      mimeType == 'image/webp' ||
      mimeType == 'video/mp4';

  static int maxBytesFor(String mimeType) =>
      mimeType == 'video/mp4' ? maxVideoBytes : maxImageBytes;
}

@immutable
class AdoptionChatDraftMedia {
  const AdoptionChatDraftMedia({
    required this.localId,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    this.mediaId,
    this.status = AdoptionChatUploadStatus.pending,
    this.progress = 0,
    this.errorMessage,
  });

  factory AdoptionChatDraftMedia.fromJson(Map<String, dynamic> json) {
    return AdoptionChatDraftMedia(
      localId: _requiredString(json, 'localId'),
      path: _requiredString(json, 'path'),
      mimeType: _requiredString(json, 'mimeType'),
      sizeBytes: _requiredInt(json, 'sizeBytes'),
      mediaId: _optionalString(json['mediaId']),
      status: AdoptionChatUploadStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => AdoptionChatUploadStatus.pending,
      ),
      progress: _optionalDouble(json['progress']) ?? 0,
      errorMessage: _optionalString(json['errorMessage']),
    );
  }

  final String localId;
  final String path;
  final String mimeType;
  final int sizeBytes;
  final String? mediaId;
  final AdoptionChatUploadStatus status;
  final double progress;
  final String? errorMessage;

  AdoptionChatDraftMedia copyWith({
    String? mediaId,
    AdoptionChatUploadStatus? status,
    double? progress,
    String? errorMessage,
    bool clearMediaId = false,
    bool clearError = false,
  }) {
    return AdoptionChatDraftMedia(
      localId: localId,
      path: path,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      mediaId: clearMediaId ? null : mediaId ?? this.mediaId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'path': path,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    if (mediaId != null) 'mediaId': mediaId,
    'status': status.name,
    'progress': progress,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };
}

@immutable
class AdoptionChatDraft {
  const AdoptionChatDraft({
    this.body = '',
    this.media = const [],
    this.pendingSendKey,
  });

  factory AdoptionChatDraft.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];
    return AdoptionChatDraft(
      body: json['body']?.toString() ?? '',
      media: rawMedia is List
          ? List.unmodifiable(
              rawMedia.map(
                (item) => AdoptionChatDraftMedia.fromJson(_readMap(item)),
              ),
            )
          : const [],
      pendingSendKey: _optionalString(json['pendingSendKey']),
    );
  }

  final String body;
  final List<AdoptionChatDraftMedia> media;
  final String? pendingSendKey;

  AdoptionChatDraft copyWith({
    String? body,
    List<AdoptionChatDraftMedia>? media,
    String? pendingSendKey,
    bool clearPendingSendKey = false,
  }) {
    return AdoptionChatDraft(
      body: body ?? this.body,
      media: media ?? this.media,
      pendingSendKey: clearPendingSendKey
          ? null
          : pendingSendKey ?? this.pendingSendKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'body': body,
    'media': media.map((item) => item.toJson()).toList(growable: false),
    if (pendingSendKey != null) 'pendingSendKey': pendingSendKey,
  };
}

@immutable
class AdoptionChatContext {
  const AdoptionChatContext({
    required this.listingId,
    required this.petName,
    required this.shelterId,
    this.heroMediaUrl,
  });

  factory AdoptionChatContext.fromJson(Map<String, dynamic> json) {
    final rawUrl = _optionalString(json['heroMediaUrl']);
    return AdoptionChatContext(
      listingId: _requiredString(json, 'listingId'),
      petName: _requiredString(json, 'petName'),
      shelterId: _requiredString(json, 'shelterId'),
      heroMediaUrl: rawUrl == null ? null : Uri.tryParse(rawUrl),
    );
  }

  factory AdoptionChatContext.fromListing(AdoptionListingDetail listing) {
    return AdoptionChatContext(
      listingId: listing.listingId,
      petName: listing.petName,
      shelterId: listing.shelterId,
      heroMediaUrl: listing.heroMedia.publicUrl,
    );
  }

  final String listingId;
  final String petName;
  final String shelterId;
  final Uri? heroMediaUrl;

  Map<String, dynamic> toJson() => {
    'listingId': listingId,
    'petName': petName,
    'shelterId': shelterId,
    if (heroMediaUrl != null) 'heroMediaUrl': heroMediaUrl.toString(),
  };
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid Adoption request/chat object.');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! Map) {
    throw FormatException('Missing Adoption request/chat field: $field.');
  }
  return _readMap(value);
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = _optionalString(json[field]);
  if (value == null) {
    throw FormatException('Missing Adoption request/chat field: $field.');
  }
  return value;
}

String? _optionalString(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid Adoption request/chat date: $field.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateTime(dynamic value) {
  final normalized = _optionalString(value);
  if (normalized == null) return null;
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) {
    throw const FormatException('Invalid Adoption request/chat date.');
  }
  return parsed.toUtc();
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = _optionalInt(json[field]);
  if (value == null) {
    throw FormatException('Missing Adoption request/chat field: $field.');
  }
  return value;
}

int? _optionalInt(dynamic value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return null;
}

double? _optionalDouble(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

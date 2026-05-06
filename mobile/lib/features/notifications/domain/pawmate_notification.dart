class PawMateNotification {
  const PawMateNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.petId,
    this.reminderId,
    this.readAt,
    this.deliveredAt,
    this.dismissedAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? petId;
  final String? reminderId;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final DateTime? dismissedAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory PawMateNotification.fromJson(Map<String, dynamic> json) {
    return PawMateNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      title: json['title']?.toString() ?? 'Thong bao',
      body: json['body']?.toString() ?? '',
      petId: _readOptionalString(json['petId']),
      reminderId: _readOptionalString(json['reminderId']),
      readAt: _parseDateTime(json['readAt']),
      deliveredAt: _parseDateTime(json['deliveredAt']),
      dismissedAt: _parseDateTime(json['dismissedAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class NotificationListResult {
  const NotificationListResult({
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.limit,
    this.nextCursor,
  });

  final List<PawMateNotification> items;
  final int total;
  final int unreadCount;
  final int limit;
  final String? nextCursor;

  factory NotificationListResult.fromJson(Map<String, dynamic> json) {
    return NotificationListResult(
      items: _readNotificationList(json['items']),
      total: _readInt(json['total']) ?? 0,
      unreadCount: _readInt(json['unreadCount']) ?? 0,
      limit: _readInt(json['limit']) ?? 20,
      nextCursor: _readOptionalString(json['nextCursor']),
    );
  }
}

List<PawMateNotification> _readNotificationList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => PawMateNotification.fromJson(_readMap(item)))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _readMap(Map<dynamic, dynamic> value) {
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
}

DateTime? _parseDateTime(dynamic value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toLocal();
}

String? _readOptionalString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

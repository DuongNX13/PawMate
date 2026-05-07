enum ReminderRepeatRule { none, daily, weekly, monthly }

enum ReminderStatus { scheduled, sent, cancelled, done }

extension ReminderRepeatRuleValue on ReminderRepeatRule {
  String get apiValue {
    switch (this) {
      case ReminderRepeatRule.none:
        return 'none';
      case ReminderRepeatRule.daily:
        return 'daily';
      case ReminderRepeatRule.weekly:
        return 'weekly';
      case ReminderRepeatRule.monthly:
        return 'monthly';
    }
  }

  String get label {
    switch (this) {
      case ReminderRepeatRule.none:
        return 'Khong lap';
      case ReminderRepeatRule.daily:
        return 'Hang ngay';
      case ReminderRepeatRule.weekly:
        return 'Hang tuan';
      case ReminderRepeatRule.monthly:
        return 'Hang thang';
    }
  }
}

ReminderRepeatRule reminderRepeatRuleFromApi(String value) {
  final normalized = value.trim().toLowerCase();
  for (final rule in ReminderRepeatRule.values) {
    if (rule.apiValue == normalized) {
      return rule;
    }
  }
  return ReminderRepeatRule.none;
}

ReminderStatus reminderStatusFromApi(String value) {
  final normalized = value.trim().toLowerCase();
  for (final status in ReminderStatus.values) {
    if (status.name == normalized) {
      return status;
    }
  }
  return ReminderStatus.scheduled;
}

class Reminder {
  const Reminder({
    required this.id,
    required this.petId,
    required this.title,
    required this.reminderAt,
    required this.repeatRule,
    required this.timezone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.nextTriggerAt,
    this.lastTriggeredAt,
    this.completedAt,
    this.cancelledAt,
    this.snoozedUntil,
  });

  final String id;
  final String petId;
  final String title;
  final String? note;
  final DateTime reminderAt;
  final DateTime? nextTriggerAt;
  final DateTime? lastTriggeredAt;
  final ReminderRepeatRule repeatRule;
  final String timezone;
  final ReminderStatus status;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? snoozedUntil;
  final String createdAt;
  final String updatedAt;

  DateTime get dueAt => nextTriggerAt ?? reminderAt;

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id']?.toString() ?? '',
      petId: json['petId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Reminder',
      note: _readOptionalString(json['note']),
      reminderAt: _parseDateTime(json['reminderAt']) ?? DateTime.now(),
      nextTriggerAt: _parseDateTime(json['nextTriggerAt']),
      lastTriggeredAt: _parseDateTime(json['lastTriggeredAt']),
      repeatRule: reminderRepeatRuleFromApi(
        json['repeatRule']?.toString() ?? 'none',
      ),
      timezone: json['timezone']?.toString() ?? 'Asia/Bangkok',
      status: reminderStatusFromApi(json['status']?.toString() ?? 'scheduled'),
      completedAt: _parseDateTime(json['completedAt']),
      cancelledAt: _parseDateTime(json['cancelledAt']),
      snoozedUntil: _parseDateTime(json['snoozedUntil']),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class ReminderListQuery {
  const ReminderListQuery({
    required this.petId,
    this.limit = 20,
    this.cursor,
    this.from,
    this.to,
    this.includeDone = false,
  });

  final String petId;
  final int limit;
  final String? cursor;
  final DateTime? from;
  final DateTime? to;
  final bool includeDone;

  Map<String, dynamic> toQueryParameters() {
    return {
      'limit': limit,
      if (cursor != null && cursor!.trim().isNotEmpty) 'cursor': cursor,
      if (from != null) 'from': from!.toUtc().toIso8601String(),
      if (to != null) 'to': to!.toUtc().toIso8601String(),
      if (includeDone) 'includeDone': true,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderListQuery &&
        other.petId == petId &&
        other.limit == limit &&
        other.cursor == cursor &&
        other.from == from &&
        other.to == to &&
        other.includeDone == includeDone;
  }

  @override
  int get hashCode => Object.hash(petId, limit, cursor, from, to, includeDone);
}

class ReminderListResult {
  const ReminderListResult({
    required this.items,
    required this.total,
    required this.limit,
    this.nextCursor,
  });

  final List<Reminder> items;
  final int total;
  final int limit;
  final String? nextCursor;

  factory ReminderListResult.fromJson(Map<String, dynamic> json) {
    return ReminderListResult(
      items: _readReminderList(json['items']),
      total: _readInt(json['total']) ?? 0,
      limit: _readInt(json['limit']) ?? 20,
      nextCursor: _readOptionalString(json['nextCursor']),
    );
  }
}

class CreateReminderInput {
  const CreateReminderInput({
    required this.title,
    required this.reminderAt,
    this.note,
    this.repeatRule = ReminderRepeatRule.none,
    this.timezone = 'Asia/Bangkok',
  });

  final String title;
  final DateTime reminderAt;
  final String? note;
  final ReminderRepeatRule repeatRule;
  final String timezone;

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'reminderAt': reminderAt.toUtc().toIso8601String(),
      'repeatRule': repeatRule.apiValue,
      'timezone': timezone,
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }
}

List<Reminder> _readReminderList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Reminder.fromJson(_readMap(item)))
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

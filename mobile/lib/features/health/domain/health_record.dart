enum HealthRecordType {
  vaccination,
  checkup,
  deworming,
  grooming,
  medication,
  allergy,
  note,
}

extension HealthRecordTypeValue on HealthRecordType {
  String get apiValue {
    switch (this) {
      case HealthRecordType.vaccination:
        return 'vaccination';
      case HealthRecordType.checkup:
        return 'checkup';
      case HealthRecordType.deworming:
        return 'deworming';
      case HealthRecordType.grooming:
        return 'grooming';
      case HealthRecordType.medication:
        return 'medication';
      case HealthRecordType.allergy:
        return 'allergy';
      case HealthRecordType.note:
        return 'note';
    }
  }

  String get label {
    switch (this) {
      case HealthRecordType.vaccination:
        return 'Tiêm phòng';
      case HealthRecordType.checkup:
        return 'Khám bệnh';
      case HealthRecordType.deworming:
        return 'Tẩy giun';
      case HealthRecordType.grooming:
        return 'Grooming';
      case HealthRecordType.medication:
        return 'Thuốc';
      case HealthRecordType.allergy:
        return 'Dị ứng';
      case HealthRecordType.note:
        return 'Ghi chú';
    }
  }

  String get defaultTitle {
    switch (this) {
      case HealthRecordType.vaccination:
        return 'Tiêm phòng';
      case HealthRecordType.checkup:
        return 'Khám tổng quát';
      case HealthRecordType.deworming:
        return 'Tẩy giun định kỳ';
      case HealthRecordType.grooming:
        return 'Chăm sóc lông';
      case HealthRecordType.medication:
        return 'Uống thuốc';
      case HealthRecordType.allergy:
        return 'Theo dõi dị ứng';
      case HealthRecordType.note:
        return 'Ghi chú sức khỏe';
    }
  }
}

HealthRecordType healthRecordTypeFromApi(String value) {
  final normalized = value.trim().toLowerCase();
  for (final type in HealthRecordType.values) {
    if (type.apiValue == normalized) {
      return type;
    }
  }
  return HealthRecordType.note;
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.date,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.note,
    this.vetId,
  });

  final String id;
  final String petId;
  final HealthRecordType type;
  final String date;
  final String? title;
  final String? note;
  final String? vetId;
  final List<String> attachments;
  final String createdAt;
  final String updatedAt;

  DateTime get occurredAt => _parseApiDate(date) ?? DateTime.now();

  String get displayTitle {
    final cleanTitle = title?.trim();
    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      return cleanTitle;
    }
    return type.defaultTitle;
  }

  String get displayNote {
    final cleanNote = note?.trim();
    if (cleanNote != null && cleanNote.isNotEmpty) {
      return cleanNote;
    }
    return 'Chưa có ghi chú bổ sung.';
  }

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    final rawDate =
        json['date']?.toString() ?? json['recordDate']?.toString() ?? '';
    final normalizedDate = rawDate.length >= 10
        ? rawDate.substring(0, 10)
        : rawDate;

    return HealthRecord(
      id: json['id']?.toString() ?? '',
      petId: json['petId']?.toString() ?? '',
      type: healthRecordTypeFromApi(
        json['type']?.toString() ?? json['recordType']?.toString() ?? 'note',
      ),
      date: normalizedDate.isEmpty
          ? _formatApiDate(DateTime.now())
          : normalizedDate,
      title: _readOptionalString(json['title']),
      note: _readOptionalString(json['note'] ?? json['notes']),
      vetId: _readOptionalString(json['vetId']),
      attachments: _readStringList(json['attachments']),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

class HealthRecordListQuery {
  const HealthRecordListQuery({
    required this.petId,
    this.type,
    this.limit = 20,
    this.cursor,
  });

  final String petId;
  final HealthRecordType? type;
  final int limit;
  final String? cursor;

  Map<String, dynamic> toQueryParameters() {
    return {
      'limit': limit,
      if (cursor != null && cursor!.trim().isNotEmpty) 'cursor': cursor,
      if (type != null) 'type': type!.apiValue,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is HealthRecordListQuery &&
        other.petId == petId &&
        other.type == type &&
        other.limit == limit &&
        other.cursor == cursor;
  }

  @override
  int get hashCode => Object.hash(petId, type, limit, cursor);
}

class HealthRecordListResult {
  const HealthRecordListResult({
    required this.items,
    required this.total,
    required this.limit,
    this.nextCursor,
  });

  final List<HealthRecord> items;
  final int total;
  final int limit;
  final String? nextCursor;

  factory HealthRecordListResult.fromJson(Map<String, dynamic> json) {
    return HealthRecordListResult(
      items: _readRecordList(json['items']),
      total: _readInt(json['total']) ?? 0,
      limit: _readInt(json['limit']) ?? 20,
      nextCursor: _readOptionalString(json['nextCursor']),
    );
  }
}

class CreateHealthRecordInput {
  const CreateHealthRecordInput({
    required this.type,
    required this.date,
    required this.title,
    this.note,
    this.vetId,
    this.attachments = const [],
  });

  final HealthRecordType type;
  final DateTime date;
  final String title;
  final String? note;
  final String? vetId;
  final List<String> attachments;

  Map<String, dynamic> toJson() {
    return {
      'type': type.apiValue,
      'date': _formatApiDate(date),
      'title': title.trim(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      if (vetId != null && vetId!.trim().isNotEmpty) 'vetId': vetId!.trim(),
      if (attachments.isNotEmpty) 'attachments': attachments,
    };
  }
}

List<HealthRecord> _readRecordList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => HealthRecord.fromJson(_readMap(item)))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _readMap(Map<dynamic, dynamic> value) {
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  return const [];
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

DateTime? _parseApiDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    return DateTime.tryParse(value);
  }

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

String _formatApiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

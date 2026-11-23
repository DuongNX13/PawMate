class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    required this.version,
    required this.nearbyLostCases,
    required this.chatMessages,
    required this.adoptionUpdates,
    required this.quietHoursEnabled,
    required this.updatedAt,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final userId = _requiredString(json, 'userId');
    final version = _requiredPositiveInt(json, 'version');
    final quietHoursEnabled = _requiredBool(json, 'quietHoursEnabled');
    final quietHoursStart = _optionalTime(json, 'quietHoursStart');
    final quietHoursEnd = _optionalTime(json, 'quietHoursEnd');
    if (quietHoursEnabled &&
        (quietHoursStart == null ||
            quietHoursEnd == null ||
            quietHoursStart == quietHoursEnd)) {
      throw const FormatException('Invalid quiet-hours preference.');
    }
    if (!quietHoursEnabled &&
        (quietHoursStart != null || quietHoursEnd != null)) {
      throw const FormatException(
        'Disabled quiet hours must not include time.',
      );
    }
    return NotificationPreferences(
      userId: userId,
      version: version,
      nearbyLostCases: _requiredBool(json, 'nearbyLostCases'),
      chatMessages: _requiredBool(json, 'chatMessages'),
      adoptionUpdates: _requiredBool(json, 'adoptionUpdates'),
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  final String userId;
  final int version;
  final bool nearbyLostCases;
  final bool chatMessages;
  final bool adoptionUpdates;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final DateTime updatedAt;

  NotificationPreferences copyWith({
    bool? nearbyLostCases,
    bool? chatMessages,
    bool? adoptionUpdates,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool clearQuietHours = false,
  }) {
    return NotificationPreferences(
      userId: userId,
      version: version,
      nearbyLostCases: nearbyLostCases ?? this.nearbyLostCases,
      chatMessages: chatMessages ?? this.chatMessages,
      adoptionUpdates: adoptionUpdates ?? this.adoptionUpdates,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: clearQuietHours
          ? null
          : quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: clearQuietHours
          ? null
          : quietHoursEnd ?? this.quietHoursEnd,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'expectedVersion': version,
    'nearbyLostCases': nearbyLostCases,
    'chatMessages': chatMessages,
    'adoptionUpdates': adoptionUpdates,
    'quietHoursEnabled': quietHoursEnabled,
    if (quietHoursEnabled) 'quietHoursStart': quietHoursStart,
    if (quietHoursEnabled) 'quietHoursEnd': quietHoursEnd,
  };
}

class PrivacyDefaults {
  const PrivacyDefaults({
    required this.userId,
    required this.version,
    required this.hideHouseNumber,
    required this.hidePhoneByDefault,
    required this.reviewMediaBeforePublish,
    required this.updatedAt,
  });

  factory PrivacyDefaults.fromJson(Map<String, dynamic> json) {
    return PrivacyDefaults(
      userId: _requiredString(json, 'userId'),
      version: _requiredPositiveInt(json, 'version'),
      hideHouseNumber: _requiredBool(json, 'hideHouseNumber'),
      hidePhoneByDefault: _requiredBool(json, 'hidePhoneByDefault'),
      reviewMediaBeforePublish: _requiredBool(json, 'reviewMediaBeforePublish'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  final String userId;
  final int version;
  final bool hideHouseNumber;
  final bool hidePhoneByDefault;
  final bool reviewMediaBeforePublish;
  final DateTime updatedAt;

  PrivacyDefaults copyWith({
    bool? hideHouseNumber,
    bool? hidePhoneByDefault,
    bool? reviewMediaBeforePublish,
  }) {
    return PrivacyDefaults(
      userId: userId,
      version: version,
      hideHouseNumber: hideHouseNumber ?? this.hideHouseNumber,
      hidePhoneByDefault: hidePhoneByDefault ?? this.hidePhoneByDefault,
      reviewMediaBeforePublish:
          reviewMediaBeforePublish ?? this.reviewMediaBeforePublish,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'expectedVersion': version,
    'hideHouseNumber': hideHouseNumber,
    'hidePhoneByDefault': hidePhoneByDefault,
    'reviewMediaBeforePublish': reviewMediaBeforePublish,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key.');
  return value;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) throw FormatException('Invalid $key.');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid $key.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $key.');
  return parsed.toUtc();
}

String? _optionalTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String ||
      !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

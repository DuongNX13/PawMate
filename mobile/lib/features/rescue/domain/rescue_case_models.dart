import 'package:flutter/foundation.dart';

enum RescueSpecies {
  dog,
  cat,
  other;

  static RescueSpecies fromWire(String value) => switch (value) {
    'dog' => RescueSpecies.dog,
    'cat' => RescueSpecies.cat,
    'other' => RescueSpecies.other,
    _ => throw FormatException('Unsupported Rescue species: $value'),
  };

  String get wireValue => name;

  String get label => switch (this) {
    RescueSpecies.dog => 'Chó',
    RescueSpecies.cat => 'Mèo',
    RescueSpecies.other => 'Khác',
  };
}

enum RescueCaseStatus {
  missing,
  found;

  static RescueCaseStatus fromWire(String value) => switch (value) {
    'missing' => RescueCaseStatus.missing,
    'found' => RescueCaseStatus.found,
    _ => throw FormatException('Unsupported Rescue status: $value'),
  };

  String get wireValue => name;

  String get label => switch (this) {
    RescueCaseStatus.missing => 'Chưa thấy',
    RescueCaseStatus.found => 'Đã thấy',
  };
}

@immutable
class RescuePublicLocation {
  const RescuePublicLocation({
    required this.areaLabel,
    required this.approximateLatitude,
    required this.approximateLongitude,
    required this.privacyRadiusMeters,
  });

  factory RescuePublicLocation.fromJson(Map<String, dynamic> json) {
    return RescuePublicLocation(
      areaLabel: _requiredString(json, 'areaLabel'),
      approximateLatitude: _requiredDouble(
        json,
        'approximateLatitude',
        min: -90,
        max: 90,
      ),
      approximateLongitude: _requiredDouble(
        json,
        'approximateLongitude',
        min: -180,
        max: 180,
      ),
      privacyRadiusMeters: _requiredInt(json, 'privacyRadiusMeters', min: 100),
    );
  }

  final String areaLabel;
  final double approximateLatitude;
  final double approximateLongitude;
  final int privacyRadiusMeters;
}

@immutable
class RescuePublicMedia {
  const RescuePublicMedia({
    required this.mediaId,
    required this.mimeType,
    required this.publicUrl,
    required this.createdAt,
    this.width,
    this.height,
    this.durationSeconds,
  });

  factory RescuePublicMedia.fromJson(Map<String, dynamic> json) {
    final publicUrl = Uri.tryParse(_requiredString(json, 'publicUrl'));
    if (publicUrl == null ||
        !publicUrl.hasScheme ||
        (publicUrl.scheme != 'https' && publicUrl.scheme != 'http')) {
      throw const FormatException('Invalid Rescue publicUrl.');
    }

    return RescuePublicMedia(
      mediaId: _requiredString(json, 'mediaId'),
      mimeType: _requiredString(json, 'mimeType'),
      publicUrl: publicUrl,
      createdAt: _requiredDateTime(json, 'createdAt'),
      width: _optionalInt(json, 'width', min: 1),
      height: _optionalInt(json, 'height', min: 1),
      durationSeconds: _optionalDouble(json, 'durationSeconds', min: 0),
    );
  }

  final String mediaId;
  final String mimeType;
  final Uri publicUrl;
  final DateTime createdAt;
  final int? width;
  final int? height;
  final double? durationSeconds;

  bool get isImage => mimeType.startsWith('image/');
}

@immutable
class RescueCaseSummary {
  const RescueCaseSummary({
    required this.caseId,
    required this.petName,
    required this.species,
    required this.status,
    required this.lostAt,
    required this.publicLocation,
    required this.media,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
    this.breedOrColor,
    this.ageLabel,
    this.distanceMeters,
  });

  factory RescueCaseSummary.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'];
    if (mediaJson is! List) {
      throw const FormatException('Invalid Rescue media list.');
    }

    return RescueCaseSummary(
      caseId: _requiredString(json, 'caseId'),
      petName: _requiredString(json, 'petName'),
      species: RescueSpecies.fromWire(_requiredString(json, 'species')),
      status: RescueCaseStatus.fromWire(_requiredString(json, 'status')),
      lostAt: _requiredDateTime(json, 'lostAt'),
      publicLocation: RescuePublicLocation.fromJson(
        _requiredMap(json, 'publicLocation'),
      ),
      media: mediaJson
          .map((item) => RescuePublicMedia.fromJson(_asMap(item, 'media')))
          .toList(growable: false),
      commentCount: _requiredInt(json, 'commentCount', min: 0),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      breedOrColor: _optionalString(json, 'breedOrColor'),
      ageLabel: _optionalString(json, 'ageLabel'),
      distanceMeters: _optionalInt(json, 'distanceMeters', min: 0),
    );
  }

  final String caseId;
  final String petName;
  final RescueSpecies species;
  final RescueCaseStatus status;
  final DateTime lostAt;
  final RescuePublicLocation publicLocation;
  final List<RescuePublicMedia> media;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? breedOrColor;
  final String? ageLabel;
  final int? distanceMeters;

  RescuePublicMedia? get primaryImage {
    for (final item in media) {
      if (item.isImage) return item;
    }
    return null;
  }
}

@immutable
class RescuePageInfo {
  const RescuePageInfo({
    required this.hasMore,
    required this.limit,
    this.nextCursor,
  });

  factory RescuePageInfo.fromJson(Map<String, dynamic> json) {
    final hasMore = json['hasMore'];
    if (hasMore is! bool) {
      throw const FormatException('Invalid Rescue pageInfo.hasMore.');
    }
    final nextCursor = _optionalString(json, 'nextCursor');
    if (hasMore && nextCursor == null) {
      throw const FormatException(
        'Rescue pageInfo.nextCursor is required when hasMore is true.',
      );
    }
    return RescuePageInfo(
      hasMore: hasMore,
      limit: _requiredInt(json, 'limit', min: 1, max: 50),
      nextCursor: nextCursor,
    );
  }

  final bool hasMore;
  final int limit;
  final String? nextCursor;
}

@immutable
class RescueCasePage {
  const RescueCasePage({required this.items, required this.pageInfo});

  factory RescueCasePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('Invalid Rescue data list.');
    }
    return RescueCasePage(
      items: data
          .map((item) => RescueCaseSummary.fromJson(_asMap(item, 'data')))
          .toList(growable: false),
      pageInfo: RescuePageInfo.fromJson(_requiredMap(json, 'pageInfo')),
    );
  }

  final List<RescueCaseSummary> items;
  final RescuePageInfo pageInfo;
}

@immutable
class RescueCaseQuery {
  const RescueCaseQuery({
    this.status,
    this.species,
    this.lostFrom,
    this.lostTo,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.sort = RescueCaseSort.recent,
    this.cursor,
    this.limit = 5,
  }) : assert((latitude == null) == (longitude == null)),
       assert(radiusMeters == null || latitude != null),
       assert(sort != RescueCaseSort.distance || latitude != null),
       assert(limit >= 1 && limit <= 50);

  final RescueCaseStatus? status;
  final RescueSpecies? species;
  final DateTime? lostFrom;
  final DateTime? lostTo;
  final double? latitude;
  final double? longitude;
  final int? radiusMeters;
  final RescueCaseSort sort;
  final String? cursor;
  final int limit;

  Map<String, dynamic> toQueryParameters() => {
    if (status != null) 'status': status!.wireValue,
    if (species != null) 'species': species!.wireValue,
    if (lostFrom != null) 'lostFrom': lostFrom!.toUtc().toIso8601String(),
    if (lostTo != null) 'lostTo': lostTo!.toUtc().toIso8601String(),
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lng': longitude,
    if (radiusMeters != null) 'radiusMeters': radiusMeters,
    'sort': sort.wireValue,
    if (cursor != null && cursor!.trim().isNotEmpty) 'cursor': cursor,
    'limit': limit,
  };
}

enum RescueCaseSort {
  recent,
  distance;

  String get wireValue => name;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String field) {
  return _asMap(json[field], field);
}

Map<String, dynamic> _asMap(dynamic value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('Invalid Rescue $field.');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid Rescue $field.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid Rescue $field.');
  }
  return value.trim();
}

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = DateTime.tryParse(_requiredString(json, field));
  if (value == null) {
    throw FormatException('Invalid Rescue $field.');
  }
  return value.toUtc();
}

int _requiredInt(
  Map<String, dynamic> json,
  String field, {
  int? min,
  int? max,
}) {
  final value = json[field];
  if (value is! num || value.toInt() != value) {
    throw FormatException('Invalid Rescue $field.');
  }
  final parsed = value.toInt();
  if ((min != null && parsed < min) || (max != null && parsed > max)) {
    throw FormatException('Invalid Rescue $field.');
  }
  return parsed;
}

int? _optionalInt(
  Map<String, dynamic> json,
  String field, {
  int? min,
  int? max,
}) {
  if (json[field] == null) return null;
  return _requiredInt(json, field, min: min, max: max);
}

double _requiredDouble(
  Map<String, dynamic> json,
  String field, {
  double? min,
  double? max,
}) {
  final value = json[field];
  if (value is! num) {
    throw FormatException('Invalid Rescue $field.');
  }
  final parsed = value.toDouble();
  if (!parsed.isFinite ||
      (min != null && parsed < min) ||
      (max != null && parsed > max)) {
    throw FormatException('Invalid Rescue $field.');
  }
  return parsed;
}

double? _optionalDouble(
  Map<String, dynamic> json,
  String field, {
  double? min,
  double? max,
}) {
  if (json[field] == null) return null;
  return _requiredDouble(json, field, min: min, max: max);
}

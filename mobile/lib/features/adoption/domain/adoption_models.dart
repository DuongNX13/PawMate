import 'package:flutter/foundation.dart';

enum AdoptionSpecies {
  dog,
  cat,
  other;

  String get wireValue => name;

  String get label => switch (this) {
    AdoptionSpecies.dog => 'Chó',
    AdoptionSpecies.cat => 'Mèo',
    AdoptionSpecies.other => 'Khác',
  };

  static AdoptionSpecies fromJson(dynamic value) => switch (value) {
    'dog' => AdoptionSpecies.dog,
    'cat' => AdoptionSpecies.cat,
    'other' => AdoptionSpecies.other,
    _ => throw const FormatException('Invalid Adoption species.'),
  };
}

enum AdoptionListingStatus {
  available,
  pending,
  adopted,
  closed;

  String get wireValue => name;

  String get label => switch (this) {
    AdoptionListingStatus.available => 'Đang tìm nhà',
    AdoptionListingStatus.pending => 'Đang xem xét',
    AdoptionListingStatus.adopted => 'Đã có gia đình',
    AdoptionListingStatus.closed => 'Đã đóng',
  };

  bool get isAvailable => this == AdoptionListingStatus.available;

  static AdoptionListingStatus fromJson(dynamic value) => switch (value) {
    'available' => AdoptionListingStatus.available,
    'pending' => AdoptionListingStatus.pending,
    'adopted' => AdoptionListingStatus.adopted,
    'closed' => AdoptionListingStatus.closed,
    _ => throw const FormatException('Invalid Adoption listing status.'),
  };
}

enum AdoptionDecision {
  skip,
  like;

  String get wireValue => name;

  static AdoptionDecision fromJson(dynamic value) => switch (value) {
    'skip' => AdoptionDecision.skip,
    'like' => AdoptionDecision.like,
    _ => throw const FormatException('Invalid Adoption decision.'),
  };
}

enum AdoptionReadSort {
  curated,
  distance;

  String get wireValue => name;
}

enum AdoptionAgeGroup {
  underOne,
  oneToThree,
  overThree;

  String get wireValue => switch (this) {
    AdoptionAgeGroup.underOne => 'under_1',
    AdoptionAgeGroup.oneToThree => 'one_to_three',
    AdoptionAgeGroup.overThree => 'over_three',
  };

  String get label => switch (this) {
    AdoptionAgeGroup.underOne => 'Dưới 1 tuổi',
    AdoptionAgeGroup.oneToThree => '1–3 tuổi',
    AdoptionAgeGroup.overThree => 'Trên 3 tuổi',
  };
}

@immutable
class AdoptionCoordinates {
  const AdoptionCoordinates({required this.latitude, required this.longitude})
    : assert(latitude >= -90 && latitude <= 90),
      assert(longitude >= -180 && longitude <= 180);

  final double latitude;
  final double longitude;
}

@immutable
class AdoptionMedia {
  const AdoptionMedia({
    required this.mediaId,
    required this.ownerUserId,
    required this.purpose,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.status,
    required this.createdAt,
    this.publicUrl,
    this.width,
    this.height,
    this.durationSeconds,
  });

  factory AdoptionMedia.fromJson(Map<String, dynamic> json) {
    final publicUrlValue = _optionalString(json['publicUrl']);
    final publicUrl = publicUrlValue == null
        ? null
        : Uri.tryParse(publicUrlValue);
    if (publicUrlValue != null &&
        (publicUrl == null ||
            !publicUrl.hasScheme ||
            (publicUrl.scheme != 'https' && publicUrl.scheme != 'http'))) {
      throw const FormatException('Invalid Adoption media publicUrl.');
    }
    return AdoptionMedia(
      mediaId: _requiredString(json, 'mediaId'),
      ownerUserId: _requiredString(json, 'ownerUserId'),
      purpose: _requiredString(json, 'purpose'),
      mimeType: _requiredString(json, 'mimeType'),
      sizeBytes: _requiredInt(json, 'sizeBytes'),
      sha256: _requiredString(json, 'sha256'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      publicUrl: publicUrl,
      width: _optionalInt(json['width']),
      height: _optionalInt(json['height']),
      durationSeconds: _optionalDouble(json['durationSeconds']),
    );
  }

  final String mediaId;
  final String ownerUserId;
  final String purpose;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String status;
  final DateTime createdAt;
  final Uri? publicUrl;
  final int? width;
  final int? height;
  final double? durationSeconds;
}

@immutable
class AdoptionListingSummary {
  const AdoptionListingSummary({
    required this.listingId,
    required this.petName,
    required this.species,
    required this.ageLabel,
    required this.status,
    required this.shelterId,
    required this.heroMedia,
    required this.traits,
    required this.createdAt,
    this.breed,
    this.distanceKm,
    this.healthBadges = const [],
    this.verificationBadges = const [],
  });

  factory AdoptionListingSummary.fromJson(Map<String, dynamic> json) {
    return AdoptionListingSummary(
      listingId: _requiredString(json, 'listingId'),
      petName: _requiredString(json, 'petName'),
      species: AdoptionSpecies.fromJson(json['species']),
      ageLabel: _requiredString(json, 'ageLabel'),
      status: AdoptionListingStatus.fromJson(json['status']),
      shelterId: _requiredString(json, 'shelterId'),
      heroMedia: AdoptionMedia.fromJson(_requiredMap(json, 'heroMedia')),
      traits: _stringList(json['traits']),
      createdAt: _requiredDateTime(json, 'createdAt'),
      breed: _optionalString(json['breed']),
      distanceKm: _optionalDouble(json['distanceKm']),
      healthBadges: _stringList(json['healthBadges']),
      verificationBadges: _stringList(json['verificationBadges']),
    );
  }

  final String listingId;
  final String petName;
  final AdoptionSpecies species;
  final String ageLabel;
  final AdoptionListingStatus status;
  final String shelterId;
  final AdoptionMedia heroMedia;
  final List<String> traits;
  final DateTime createdAt;
  final String? breed;
  final double? distanceKm;
  final List<String> healthBadges;
  final List<String> verificationBadges;
}

@immutable
class AdoptionViewerPermissions {
  const AdoptionViewerPermissions({
    required this.canLike,
    required this.canRequest,
    required this.canManageListing,
  });

  const AdoptionViewerPermissions.none()
    : canLike = false,
      canRequest = false,
      canManageListing = false;

  factory AdoptionViewerPermissions.fromJson(dynamic value) {
    if (value is! Map) return const AdoptionViewerPermissions.none();
    final json = _readMap(value);
    return AdoptionViewerPermissions(
      canLike: json['canLike'] == true,
      canRequest: json['canRequest'] == true,
      canManageListing: json['canManageListing'] == true,
    );
  }

  final bool canLike;
  final bool canRequest;
  final bool canManageListing;
}

@immutable
class AdoptionListingDetail {
  const AdoptionListingDetail({
    required this.listingId,
    required this.petName,
    required this.species,
    required this.ageLabel,
    required this.status,
    required this.shelterId,
    required this.heroMedia,
    required this.traits,
    required this.healthBadges,
    required this.verificationBadges,
    required this.viewerPermissions,
    required this.createdAt,
    this.breed,
    this.distanceKm,
    this.description,
  });

  factory AdoptionListingDetail.fromJson(Map<String, dynamic> json) {
    return AdoptionListingDetail(
      listingId: _requiredString(json, 'listingId'),
      petName: _requiredString(json, 'petName'),
      species: AdoptionSpecies.fromJson(json['species']),
      ageLabel: _requiredString(json, 'ageLabel'),
      status: AdoptionListingStatus.fromJson(json['status']),
      shelterId: _requiredString(json, 'shelterId'),
      heroMedia: AdoptionMedia.fromJson(_requiredMap(json, 'heroMedia')),
      traits: _stringList(json['traits']),
      healthBadges: _stringList(json['healthBadges']),
      verificationBadges: _stringList(json['verificationBadges']),
      viewerPermissions: AdoptionViewerPermissions.fromJson(
        json['viewerPermissions'],
      ),
      createdAt: _requiredDateTime(json, 'createdAt'),
      breed: _optionalString(json['breed']),
      distanceKm: _optionalDouble(json['distanceKm']),
      description: _optionalString(json['description']),
    );
  }

  final String listingId;
  final String petName;
  final AdoptionSpecies species;
  final String ageLabel;
  final AdoptionListingStatus status;
  final String shelterId;
  final AdoptionMedia heroMedia;
  final List<String> traits;
  final List<String> healthBadges;
  final List<String> verificationBadges;
  final AdoptionViewerPermissions viewerPermissions;
  final DateTime createdAt;
  final String? breed;
  final double? distanceKm;
  final String? description;
}

@immutable
class AdoptionPageInfo {
  const AdoptionPageInfo({
    required this.hasMore,
    required this.limit,
    this.nextCursor,
  });

  factory AdoptionPageInfo.fromJson(Map<String, dynamic> json) {
    return AdoptionPageInfo(
      nextCursor: _optionalString(json['nextCursor']),
      hasMore: json['hasMore'] == true,
      limit: _requiredInt(json, 'limit'),
    );
  }

  final String? nextCursor;
  final bool hasMore;
  final int limit;
}

@immutable
class AdoptionListingPage {
  const AdoptionListingPage({required this.items, required this.pageInfo});

  factory AdoptionListingPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('Invalid Adoption listing data.');
    }
    return AdoptionListingPage(
      items: [
        for (final item in data)
          AdoptionListingSummary.fromJson(_readMap(item)),
      ],
      pageInfo: AdoptionPageInfo.fromJson(_requiredMap(json, 'pageInfo')),
    );
  }

  final List<AdoptionListingSummary> items;
  final AdoptionPageInfo pageInfo;
}

@immutable
class AdoptionListQuery {
  const AdoptionListQuery({
    this.species,
    this.ageGroup,
    this.coordinates,
    this.distanceKm,
    this.sort = AdoptionReadSort.curated,
    this.cursor,
    this.limit = 20,
  }) : assert(limit >= 1 && limit <= 50),
       assert(distanceKm == null || (distanceKm >= 1 && distanceKm <= 100)),
       assert(
         coordinates != null ||
             (distanceKm == null && sort == AdoptionReadSort.curated),
       );

  final AdoptionSpecies? species;
  final AdoptionAgeGroup? ageGroup;
  final AdoptionCoordinates? coordinates;
  final double? distanceKm;
  final AdoptionReadSort sort;
  final String? cursor;
  final int limit;

  Map<String, dynamic> toQueryParameters() => {
    if (species != null) 'species': species!.wireValue,
    if (ageGroup != null) 'ageGroup': ageGroup!.wireValue,
    if (coordinates != null) ...{
      'lat': coordinates!.latitude,
      'lng': coordinates!.longitude,
    },
    if (distanceKm != null) 'distanceKm': distanceKm,
    'sort': sort.wireValue,
    if (cursor != null) 'cursor': cursor,
    'limit': limit,
  };
}

@immutable
class AdoptionDecisionResult {
  const AdoptionDecisionResult({
    required this.listingId,
    required this.adopterUserId,
    required this.decision,
    required this.createdAt,
  });

  factory AdoptionDecisionResult.fromJson(Map<String, dynamic> json) {
    return AdoptionDecisionResult(
      listingId: _requiredString(json, 'listingId'),
      adopterUserId: _requiredString(json, 'adopterUserId'),
      decision: AdoptionDecision.fromJson(json['decision']),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }

  final String listingId;
  final String adopterUserId;
  final AdoptionDecision decision;
  final DateTime createdAt;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid Adoption object.');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! Map) {
    throw FormatException('Missing Adoption field: $field.');
  }
  return _readMap(value);
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = _optionalString(json[field]);
  if (value == null) {
    throw FormatException('Missing Adoption field: $field.');
  }
  return value;
}

String? _optionalString(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = _optionalInt(json[field]);
  if (value == null) {
    throw FormatException('Missing Adoption field: $field.');
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

DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid Adoption date: $field.');
  }
  return parsed.toUtc();
}

List<String> _stringList(dynamic value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Invalid Adoption string list.');
  }
  return List.unmodifiable(value.map(_optionalString).whereType<String>());
}

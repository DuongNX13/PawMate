import 'package:flutter/foundation.dart';

enum RescueDraftSpecies { dog, cat, other }

abstract final class RescueMediaPolicy {
  static const maxImagesBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxItems = 5;

  static bool isSupported(String mimeType) =>
      mimeType == 'image/jpeg' ||
      mimeType == 'image/png' ||
      mimeType == 'image/webp' ||
      mimeType == 'video/mp4';

  static int maxBytesFor(String mimeType) =>
      mimeType == 'video/mp4' ? maxVideoBytes : maxImagesBytes;
}

extension RescueDraftSpeciesApi on RescueDraftSpecies {
  String get apiValue => name;

  String get label => switch (this) {
    RescueDraftSpecies.dog => 'Chó',
    RescueDraftSpecies.cat => 'Mèo',
    RescueDraftSpecies.other => 'Khác',
  };
}

enum RescueContactPreference { inApp, phoneWithConsent }

extension RescueContactPreferenceApi on RescueContactPreference {
  String get apiValue => switch (this) {
    RescueContactPreference.inApp => 'in_app',
    RescueContactPreference.phoneWithConsent => 'phone_with_consent',
  };
}

@immutable
class RescueDraftLocation {
  const RescueDraftLocation({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
  });

  final double latitude;
  final double longitude;
  final String? formattedAddress;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (formattedAddress != null && formattedAddress!.trim().isNotEmpty)
      'formattedAddress': formattedAddress!.trim(),
  };
}

@immutable
class RescueDraftMedia {
  const RescueDraftMedia({
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    this.mediaId,
    this.uploaded = false,
  });

  final String path;
  final String mimeType;
  final int sizeBytes;
  final String? mediaId;
  final bool uploaded;

  RescueDraftMedia copyWith({String? mediaId, bool? uploaded}) =>
      RescueDraftMedia(
        path: path,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        mediaId: mediaId ?? this.mediaId,
        uploaded: uploaded ?? this.uploaded,
      );
}

@immutable
class RescueDraft {
  const RescueDraft({
    this.draftId,
    this.version,
    this.petName = '',
    this.species = RescueDraftSpecies.dog,
    this.breedOrColor = '',
    this.lostAt,
    this.exactLocation,
    this.identifyingFeatures = '',
    this.behaviorHint = '',
    this.contactPreference = RescueContactPreference.inApp,
    this.media = const [],
  });

  final String? draftId;
  final int? version;
  final String petName;
  final RescueDraftSpecies species;
  final String breedOrColor;
  final DateTime? lostAt;

  /// This exact location is held only by the authenticated draft flow. It is
  /// never rendered on public Rescue surfaces.
  final RescueDraftLocation? exactLocation;
  final String identifyingFeatures;
  final String behaviorHint;
  final RescueContactPreference contactPreference;
  final List<RescueDraftMedia> media;

  RescueDraft copyWith({
    String? draftId,
    int? version,
    String? petName,
    RescueDraftSpecies? species,
    String? breedOrColor,
    DateTime? lostAt,
    bool clearLostAt = false,
    RescueDraftLocation? exactLocation,
    bool clearExactLocation = false,
    String? identifyingFeatures,
    String? behaviorHint,
    RescueContactPreference? contactPreference,
    List<RescueDraftMedia>? media,
  }) => RescueDraft(
    draftId: draftId ?? this.draftId,
    version: version ?? this.version,
    petName: petName ?? this.petName,
    species: species ?? this.species,
    breedOrColor: breedOrColor ?? this.breedOrColor,
    lostAt: clearLostAt ? null : (lostAt ?? this.lostAt),
    exactLocation: clearExactLocation
        ? null
        : (exactLocation ?? this.exactLocation),
    identifyingFeatures: identifyingFeatures ?? this.identifyingFeatures,
    behaviorHint: behaviorHint ?? this.behaviorHint,
    contactPreference: contactPreference ?? this.contactPreference,
    media: media ?? this.media,
  );

  List<String> validateStepOne() {
    final errors = <String>[];
    if (petName.trim().isEmpty || petName.trim().length > 50) {
      errors.add('petName');
    }
    if (breedOrColor.trim().isEmpty || breedOrColor.trim().length > 100) {
      errors.add('breedOrColor');
    }
    if (lostAt == null) errors.add('lostAt');
    if (exactLocation == null) errors.add('exactLocation');
    return errors;
  }

  List<String> validateStepTwo() {
    final errors = <String>[];
    final features = identifyingFeatures.trim();
    if (features.isEmpty || features.length > 500) {
      errors.add('identifyingFeatures');
    }
    if (behaviorHint.trim().length > 500) errors.add('behaviorHint');
    if (media.isEmpty) {
      errors.add('media');
    }
    return errors;
  }

  Map<String, Object?> toPatchJson() => {
    'petName': petName.trim(),
    'species': species.apiValue,
    'breedOrColor': breedOrColor.trim(),
    if (lostAt != null) 'lostAt': lostAt!.toUtc().toIso8601String(),
    if (exactLocation != null) 'exactLocation': exactLocation!.toJson(),
    'identifyingFeatures': identifyingFeatures.trim(),
    'behaviorHint': behaviorHint.trim(),
    'contactPreference': contactPreference.apiValue,
    'mediaIds': [
      for (final item in media)
        if (item.mediaId != null) item.mediaId!,
    ],
  };

  Map<String, Object?> toStepOnePatchJson() => {
    'petName': petName.trim(),
    'species': species.apiValue,
    'breedOrColor': breedOrColor.trim(),
    if (lostAt != null) 'lostAt': lostAt!.toUtc().toIso8601String(),
    if (exactLocation != null) 'exactLocation': exactLocation!.toJson(),
  };

  Map<String, Object?> toStepTwoPatchJson() => {
    'identifyingFeatures': identifyingFeatures.trim(),
    'behaviorHint': behaviorHint.trim(),
    'contactPreference': contactPreference.apiValue,
    'mediaIds': [
      for (final item in media)
        if (item.mediaId != null) item.mediaId!,
    ],
  };

  factory RescueDraft.fromJson(Map<String, dynamic> json) {
    RescueDraftSpecies parseSpecies(dynamic value) => switch (value) {
      'cat' => RescueDraftSpecies.cat,
      'other' => RescueDraftSpecies.other,
      _ => RescueDraftSpecies.dog,
    };
    RescueContactPreference parseContact(dynamic value) =>
        value == 'phone_with_consent'
        ? RescueContactPreference.phoneWithConsent
        : RescueContactPreference.inApp;
    DateTime? parseDate(dynamic value) =>
        value is String ? DateTime.tryParse(value) : null;
    RescueDraftLocation? parseLocation(dynamic value) {
      if (value is! Map) return null;
      final latitude = (value['latitude'] as num?)?.toDouble();
      final longitude = (value['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) return null;
      return RescueDraftLocation(
        latitude: latitude,
        longitude: longitude,
        formattedAddress: value['formattedAddress']?.toString(),
      );
    }

    return RescueDraft(
      draftId: json['draftId']?.toString(),
      version: (json['version'] as num?)?.toInt(),
      petName: json['petName']?.toString() ?? '',
      species: parseSpecies(json['species']),
      breedOrColor: json['breedOrColor']?.toString() ?? '',
      lostAt: parseDate(json['lostAt']),
      exactLocation: parseLocation(json['exactLocation']),
      identifyingFeatures: json['identifyingFeatures']?.toString() ?? '',
      behaviorHint: json['behaviorHint']?.toString() ?? '',
      contactPreference: parseContact(json['contactPreference']),
    );
  }
}

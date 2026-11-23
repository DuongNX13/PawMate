import 'package:flutter/foundation.dart';

import 'rescue_case_models.dart';

enum RescueMapLoadStatus { idle, loading, ready, empty, error }

enum RescueLocationStatus {
  unknown,
  loading,
  ready,
  permissionDenied,
  serviceDisabled,
  timeout,
  error,
}

enum RescueTimeFilter {
  all,
  last24Hours,
  last7Days;

  String get label => switch (this) {
    RescueTimeFilter.all => 'Mọi thời điểm',
    RescueTimeFilter.last24Hours => '24 giờ qua',
    RescueTimeFilter.last7Days => '7 ngày qua',
  };

  Duration? get duration => switch (this) {
    RescueTimeFilter.all => null,
    RescueTimeFilter.last24Hours => const Duration(hours: 24),
    RescueTimeFilter.last7Days => const Duration(days: 7),
  };
}

@immutable
class RescueMapFilters {
  const RescueMapFilters({
    this.status,
    this.species,
    this.time = RescueTimeFilter.all,
  });

  final RescueCaseStatus? status;
  final RescueSpecies? species;
  final RescueTimeFilter time;

  RescueMapFilters copyWith({
    RescueCaseStatus? status,
    bool clearStatus = false,
    RescueSpecies? species,
    bool clearSpecies = false,
    RescueTimeFilter? time,
  }) {
    return RescueMapFilters(
      status: clearStatus ? null : (status ?? this.status),
      species: clearSpecies ? null : (species ?? this.species),
      time: time ?? this.time,
    );
  }

  RescueCaseQuery toQuery({
    required DateTime now,
    RescueMapLocation? center,
    bool includeLocation = false,
    int radiusMeters = 5000,
    int limit = 50,
  }) {
    final duration = time.duration;
    return RescueCaseQuery(
      status: status,
      species: species,
      lostFrom: duration == null ? null : now.toUtc().subtract(duration),
      latitude: includeLocation ? center?.latitude : null,
      longitude: includeLocation ? center?.longitude : null,
      radiusMeters: includeLocation && center != null ? radiusMeters : null,
      sort: includeLocation && center != null
          ? RescueCaseSort.distance
          : RescueCaseSort.recent,
      limit: limit,
    );
  }

  String get semanticsLabel {
    final parts = <String>[
      status?.label ?? 'Tất cả trạng thái',
      species?.label ?? 'mọi loài',
      time.label,
    ];
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RescueMapFilters &&
          other.status == status &&
          other.species == species &&
          other.time == time;

  @override
  int get hashCode => Object.hash(status, species, time);
}

@immutable
class RescueMapLocation {
  const RescueMapLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

@immutable
class RescueMapState {
  const RescueMapState({
    this.status = RescueMapLoadStatus.idle,
    this.items = const [],
    this.filters = const RescueMapFilters(),
    this.locationStatus = RescueLocationStatus.unknown,
    this.center,
    this.usesNearbyQuery = false,
    this.selectedCaseId,
    this.isRefreshing = false,
    this.isStale = false,
    this.mapUnavailable = false,
    this.mapReloadToken = 0,
    this.lastUpdatedAt,
    this.message,
  });

  final RescueMapLoadStatus status;
  final List<RescueCaseSummary> items;
  final RescueMapFilters filters;
  final RescueLocationStatus locationStatus;
  final RescueMapLocation? center;
  final bool usesNearbyQuery;
  final String? selectedCaseId;
  final bool isRefreshing;
  final bool isStale;
  final bool mapUnavailable;
  final int mapReloadToken;
  final DateTime? lastUpdatedAt;
  final String? message;

  RescueCaseSummary? get selectedCase => items
      .cast<RescueCaseSummary?>()
      .firstWhere((item) => item?.caseId == selectedCaseId, orElse: () => null);

  RescueMapState copyWith({
    RescueMapLoadStatus? status,
    List<RescueCaseSummary>? items,
    RescueMapFilters? filters,
    RescueLocationStatus? locationStatus,
    RescueMapLocation? center,
    bool clearCenter = false,
    bool? usesNearbyQuery,
    String? selectedCaseId,
    bool clearSelectedCase = false,
    bool? isRefreshing,
    bool? isStale,
    bool? mapUnavailable,
    int? mapReloadToken,
    DateTime? lastUpdatedAt,
    bool clearLastUpdatedAt = false,
    String? message,
    bool clearMessage = false,
  }) {
    return RescueMapState(
      status: status ?? this.status,
      items: items ?? this.items,
      filters: filters ?? this.filters,
      locationStatus: locationStatus ?? this.locationStatus,
      center: clearCenter ? null : (center ?? this.center),
      usesNearbyQuery: usesNearbyQuery ?? this.usesNearbyQuery,
      selectedCaseId: clearSelectedCase
          ? null
          : (selectedCaseId ?? this.selectedCaseId),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isStale: isStale ?? this.isStale,
      mapUnavailable: mapUnavailable ?? this.mapUnavailable,
      mapReloadToken: mapReloadToken ?? this.mapReloadToken,
      lastUpdatedAt: clearLastUpdatedAt
          ? null
          : (lastUpdatedAt ?? this.lastUpdatedAt),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

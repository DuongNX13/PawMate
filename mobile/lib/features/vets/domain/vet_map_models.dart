import 'vet_models.dart';

enum VetMapStatus {
  idle,
  loading,
  permissionDenied,
  locationServicesDisabled,
  empty,
  ready,
  error,
}

class VetMapLocation {
  const VetMapLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class VetMapState {
  const VetMapState({
    this.status = VetMapStatus.idle,
    this.center,
    this.items = const [],
    this.radiusMeters = 3000,
    this.only24h = false,
    this.openNow = false,
    this.minRating,
    this.message,
    this.hasLoadedAtLeastOnce = false,
    this.mapUnavailable = false,
    this.mapReloadToken = 0,
    this.datasetRevision = 0,
  });

  final VetMapStatus status;
  final VetMapLocation? center;
  final List<VetSummary> items;
  final int radiusMeters;
  final bool only24h;
  final bool openNow;
  final double? minRating;
  final String? message;
  final bool hasLoadedAtLeastOnce;
  final bool mapUnavailable;
  final int mapReloadToken;
  final int datasetRevision;

  VetMapState copyWith({
    VetMapStatus? status,
    VetMapLocation? center,
    List<VetSummary>? items,
    int? radiusMeters,
    bool? only24h,
    bool? openNow,
    double? minRating,
    bool clearMinRating = false,
    String? message,
    bool clearMessage = false,
    bool clearItems = false,
    bool? hasLoadedAtLeastOnce,
    bool? mapUnavailable,
    int? mapReloadToken,
    int? datasetRevision,
  }) {
    return VetMapState(
      status: status ?? this.status,
      center: center ?? this.center,
      items: clearItems ? const [] : (items ?? this.items),
      radiusMeters: radiusMeters ?? this.radiusMeters,
      only24h: only24h ?? this.only24h,
      openNow: openNow ?? this.openNow,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      message: clearMessage ? null : (message ?? this.message),
      hasLoadedAtLeastOnce: hasLoadedAtLeastOnce ?? this.hasLoadedAtLeastOnce,
      mapUnavailable: mapUnavailable ?? this.mapUnavailable,
      mapReloadToken: mapReloadToken ?? this.mapReloadToken,
      datasetRevision: datasetRevision ?? this.datasetRevision,
    );
  }
}

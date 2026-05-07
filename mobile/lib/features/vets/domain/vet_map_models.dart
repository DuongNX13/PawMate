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
    this.message,
    this.hasLoadedAtLeastOnce = false,
  });

  final VetMapStatus status;
  final VetMapLocation? center;
  final List<VetSummary> items;
  final int radiusMeters;
  final String? message;
  final bool hasLoadedAtLeastOnce;

  VetMapState copyWith({
    VetMapStatus? status,
    VetMapLocation? center,
    List<VetSummary>? items,
    int? radiusMeters,
    String? message,
    bool clearMessage = false,
    bool clearItems = false,
    bool? hasLoadedAtLeastOnce,
  }) {
    return VetMapState(
      status: status ?? this.status,
      center: center ?? this.center,
      items: clearItems ? const [] : (items ?? this.items),
      radiusMeters: radiusMeters ?? this.radiusMeters,
      message: clearMessage ? null : (message ?? this.message),
      hasLoadedAtLeastOnce: hasLoadedAtLeastOnce ?? true,
    );
  }
}

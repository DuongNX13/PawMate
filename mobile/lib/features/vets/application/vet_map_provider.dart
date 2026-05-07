import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vet_api.dart';
import '../data/vet_location_service.dart';
import '../domain/vet_map_models.dart';
import '../domain/vet_models.dart';

final vetMapProvider =
    NotifierProvider.autoDispose<VetMapNotifier, VetMapState>(
      VetMapNotifier.new,
    );

class VetMapNotifier extends Notifier<VetMapState> {
  @override
  VetMapState build() {
    return const VetMapState();
  }

  Future<void> initialize() async {
    if (state.status == VetMapStatus.loading || state.hasLoadedAtLeastOnce) {
      return;
    }

    await refresh();
  }

  Future<void> refresh({bool forceLocationRefresh = false}) async {
    final currentCenter = state.center;
    state = state.copyWith(status: VetMapStatus.loading, clearMessage: true);

    VetMapLocation center =
        currentCenter ?? const VetMapLocation(latitude: 0, longitude: 0);

    if (forceLocationRefresh || currentCenter == null) {
      try {
        center = await ref
            .read(vetLocationServiceProvider)
            .resolveCurrentLocation();
      } on VetLocationException catch (error) {
        state = state.copyWith(
          status: switch (error.type) {
            VetLocationFailureType.permissionDenied =>
              VetMapStatus.permissionDenied,
            VetLocationFailureType.serviceDisabled =>
              VetMapStatus.locationServicesDisabled,
            VetLocationFailureType.timeout => VetMapStatus.error,
            VetLocationFailureType.unknown => VetMapStatus.error,
          },
          message: error.message,
          clearItems: true,
        );
        return;
      } catch (_) {
        state = state.copyWith(
          status: VetMapStatus.error,
          message: 'Không lấy được vị trí hiện tại của bạn.',
          clearItems: true,
        );
        return;
      }
    }

    try {
      final result = await ref
          .read(vetApiProvider)
          .nearby(
            VetNearbyRequest(
              latitude: center.latitude,
              longitude: center.longitude,
              radiusMeters: state.radiusMeters,
            ),
          );

      state = state.copyWith(
        center: center,
        items: result.items,
        status: result.items.isEmpty ? VetMapStatus.empty : VetMapStatus.ready,
        clearMessage: true,
      );
    } on VetApiException catch (error) {
      state = state.copyWith(
        center: center,
        status: VetMapStatus.error,
        message: error.message,
        clearItems: true,
      );
    } catch (_) {
      state = state.copyWith(
        center: center,
        status: VetMapStatus.error,
        message: 'Không tải được danh sách phòng khám gần bạn.',
        clearItems: true,
      );
    }
  }

  Future<void> selectRadius(int radiusMeters) async {
    if (state.radiusMeters == radiusMeters) {
      return;
    }

    state = state.copyWith(radiusMeters: radiusMeters);
    await refresh();
  }
}

import 'dart:async';

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
  static const _fallbackCenter = VetMapLocation(
    latitude: 21.0278,
    longitude: 105.8342,
  );
  static const _locationLookupTimeout = Duration(seconds: 10);

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
            .resolveCurrentLocation()
            .timeout(_locationLookupTimeout);
      } on TimeoutException {
        center = currentCenter ?? _fallbackCenter;
      } on VetLocationException catch (error) {
        if (error.type == VetLocationFailureType.timeout ||
            error.type == VetLocationFailureType.unknown) {
          center = currentCenter ?? _fallbackCenter;
        } else {
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
        }
      } catch (_) {
        center = currentCenter ?? _fallbackCenter;
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
              only24h: state.only24h,
              openNow: state.openNow,
              minRating: state.minRating,
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

  Future<void> toggleOnly24h() async {
    state = state.copyWith(only24h: !state.only24h);
    await refresh();
  }

  Future<void> toggleOpenNow() async {
    state = state.copyWith(openNow: !state.openNow);
    await refresh();
  }

  Future<void> toggleRating4Plus() async {
    final isSelected = state.minRating == 4;
    state = state.copyWith(
      minRating: isSelected ? null : 4,
      clearMinRating: isSelected,
    );
    await refresh();
  }
}

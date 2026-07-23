import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vet_api.dart';
import '../data/vet_location_service.dart';
import '../domain/vet_map_models.dart';
import '../domain/vet_models.dart';
import 'vet_finder_session_provider.dart';

final vetMapProvider = NotifierProvider<VetMapNotifier, VetMapState>(
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
    final finder = ref.read(vetFinderSessionProvider);
    return VetMapState(
      radiusMeters: finder.radiusMeters,
      only24h: finder.only24h,
      openNow: finder.openNow,
      minRating: finder.minRating,
    );
  }

  Future<void> initialize() async {
    final finder = ref.read(vetFinderSessionProvider);
    if (finder.datasetRevision > state.datasetRevision && finder.hasDataset) {
      state = state.copyWith(
        center: finder.mapCenter ?? state.center ?? _fallbackCenter,
        items: finder.items,
        status: finder.items.isEmpty ? VetMapStatus.empty : VetMapStatus.ready,
        radiusMeters: finder.radiusMeters,
        only24h: finder.only24h,
        openNow: finder.openNow,
        minRating: finder.minRating,
        clearMinRating: finder.minRating == null,
        datasetRevision: finder.datasetRevision,
        hasLoadedAtLeastOnce: true,
        clearMessage: true,
      );
      return;
    }

    if (state.status == VetMapStatus.loading || state.hasLoadedAtLeastOnce) {
      return;
    }

    await refresh();
  }

  Future<void> refresh({bool forceLocationRefresh = false}) async {
    final currentCenter = state.center;
    final finder = ref.read(vetFinderSessionProvider);
    state = state.copyWith(
      status: VetMapStatus.loading,
      radiusMeters: finder.radiusMeters,
      only24h: finder.only24h,
      openNow: finder.openNow,
      minRating: finder.minRating,
      clearMinRating: finder.minRating == null,
      mapUnavailable: false,
      hasLoadedAtLeastOnce: true,
      clearMessage: true,
    );

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

      ref
          .read(vetFinderSessionProvider.notifier)
          .storeDataset(
            items: result.items,
            total: result.total,
            nextCursor: result.nextCursor,
            source: VetFinderDatasetSource.nearby,
            mapCenter: center,
          );
      final datasetRevision = ref
          .read(vetFinderSessionProvider)
          .datasetRevision;
      state = state.copyWith(
        center: center,
        items: result.items,
        status: result.items.isEmpty ? VetMapStatus.empty : VetMapStatus.ready,
        datasetRevision: datasetRevision,
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

    ref.read(vetFinderSessionProvider.notifier).setRadius(radiusMeters);
    state = state.copyWith(radiusMeters: radiusMeters);
    await refresh();
  }

  Future<void> toggleOnly24h() async {
    ref.read(vetFinderSessionProvider.notifier).toggleOnly24h();
    state = state.copyWith(only24h: !state.only24h);
    await refresh();
  }

  Future<void> toggleOpenNow() async {
    ref.read(vetFinderSessionProvider.notifier).toggleOpenNow();
    state = state.copyWith(openNow: !state.openNow);
    await refresh();
  }

  Future<void> toggleRating4Plus() async {
    final isSelected = state.minRating == 4;
    ref.read(vetFinderSessionProvider.notifier).toggleRating4Plus();
    state = state.copyWith(
      minRating: isSelected ? null : 4,
      clearMinRating: isSelected,
    );
    await refresh();
  }

  void markMapUnavailable([Object? error]) {
    if (state.mapUnavailable) {
      return;
    }
    state = state.copyWith(
      mapUnavailable: true,
      message: 'Dịch vụ bản đồ đang tạm gián đoạn.',
    );
  }

  void retryMap() {
    state = state.copyWith(
      mapUnavailable: false,
      mapReloadToken: state.mapReloadToken + 1,
      clearMessage: true,
    );
  }
}

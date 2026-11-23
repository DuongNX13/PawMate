import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rescue_api.dart';
import '../data/rescue_location_service.dart';
import '../domain/rescue_case_models.dart';
import '../domain/rescue_map_models.dart';
import 'rescue_home_provider.dart';

final rescueMapProvider =
    NotifierProvider.autoDispose<RescueMapNotifier, RescueMapState>(
      RescueMapNotifier.new,
    );

class RescueMapNotifier extends Notifier<RescueMapState> {
  static const _fallbackCenter = RescueMapLocation(
    latitude: 10.7769,
    longitude: 106.7009,
  );
  static const _radiusMeters = 5000;
  int _requestGeneration = 0;
  bool _locationResolved = false;

  @override
  RescueMapState build() {
    ref.onDispose(() => _requestGeneration++);
    return const RescueMapState();
  }

  Future<void> initialize() async {
    if (state.status == RescueMapLoadStatus.loading ||
        state.status == RescueMapLoadStatus.ready ||
        state.status == RescueMapLoadStatus.empty) {
      return;
    }
    await refresh(resolveLocation: true);
  }

  Future<void> refresh({bool resolveLocation = false}) async {
    final generation = ++_requestGeneration;
    final keepItems = state.items.isNotEmpty;
    state = state.copyWith(
      status: keepItems
          ? RescueMapLoadStatus.ready
          : RescueMapLoadStatus.loading,
      isRefreshing: keepItems,
      isStale: false,
      mapUnavailable: false,
      clearMessage: true,
      locationStatus: resolveLocation
          ? RescueLocationStatus.loading
          : state.locationStatus,
    );

    if (resolveLocation) {
      await _resolveLocation(generation);
      if (generation != _requestGeneration) return;
    }

    final clock = ref.read(rescueClockProvider);
    final page = await _loadPage(clock());
    if (generation != _requestGeneration) return;

    if (page == null) {
      state = state.copyWith(
        status: keepItems
            ? RescueMapLoadStatus.ready
            : RescueMapLoadStatus.error,
        isRefreshing: false,
        isStale: keepItems,
      );
      return;
    }

    final selectedStillExists = state.selectedCaseId == null
        ? null
        : page.items.any((item) => item.caseId == state.selectedCaseId)
        ? state.selectedCaseId
        : null;
    state = state.copyWith(
      status: page.items.isEmpty
          ? RescueMapLoadStatus.empty
          : RescueMapLoadStatus.ready,
      items: page.items,
      selectedCaseId: selectedStillExists,
      clearSelectedCase: selectedStillExists == null,
      isRefreshing: false,
      isStale: false,
      lastUpdatedAt: clock(),
      clearMessage: true,
    );
  }

  Future<void> applyFilters(RescueMapFilters filters) async {
    if (filters == state.filters) return;
    state = state.copyWith(filters: filters, clearSelectedCase: true);
    await refresh();
  }

  Future<void> selectStatus(RescueCaseStatus? status) async {
    await applyFilters(
      state.filters.copyWith(status: status, clearStatus: status == null),
    );
  }

  Future<void> selectSpecies(RescueSpecies? species) async {
    await applyFilters(
      state.filters.copyWith(species: species, clearSpecies: species == null),
    );
  }

  Future<void> selectTime(RescueTimeFilter time) async {
    await applyFilters(state.filters.copyWith(time: time));
  }

  void selectCase(String caseId) {
    if (state.items.any((item) => item.caseId == caseId)) {
      state = state.copyWith(selectedCaseId: caseId);
    }
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedCase: true);
  }

  void applyStatusUpdate(RescueCaseDetail detail) {
    final updatedItems = [
      for (final item in state.items)
        if (item.caseId == detail.caseId)
          item.copyWith(status: detail.status, updatedAt: detail.updatedAt)
        else
          item,
    ];
    final filteredItems =
        state.filters.status == null || state.filters.status == detail.status
        ? updatedItems
        : [
            for (final item in updatedItems)
              if (item.caseId != detail.caseId) item,
          ];
    state = state.copyWith(
      items: filteredItems,
      status: filteredItems.isEmpty
          ? RescueMapLoadStatus.empty
          : RescueMapLoadStatus.ready,
      clearSelectedCase: !filteredItems.any(
        (item) => item.caseId == state.selectedCaseId,
      ),
      lastUpdatedAt: detail.updatedAt,
      clearMessage: true,
    );
  }

  void markMapUnavailable([Object? error]) {
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

  Future<void> retryLocation() => refresh(resolveLocation: true);

  Future<RescueCasePage?> _loadPage(DateTime now) async {
    try {
      return await ref
          .read(rescueApiProvider)
          .listCases(
            state.filters.toQuery(
              now: now,
              center: state.center,
              includeLocation: _locationResolved,
              radiusMeters: _radiusMeters,
              limit: 50,
            ),
          );
    } on RescueApiException catch (error) {
      state = state.copyWith(
        message: error.message,
        isRefreshing: false,
        isStale: state.items.isNotEmpty,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        message: 'Không tải được dữ liệu bản đồ cứu hộ. Vui lòng thử lại.',
        isRefreshing: false,
        isStale: state.items.isNotEmpty,
      );
      return null;
    }
  }

  Future<void> _resolveLocation(int generation) async {
    try {
      final location = await ref
          .read(rescueLocationServiceProvider)
          .resolveCurrentLocation();
      if (generation != _requestGeneration) return;
      _locationResolved = true;
      state = state.copyWith(
        center: location,
        usesNearbyQuery: true,
        locationStatus: RescueLocationStatus.ready,
      );
    } on RescueLocationException catch (error) {
      if (generation != _requestGeneration) return;
      _locationResolved = false;
      state = state.copyWith(
        center: state.center ?? _fallbackCenter,
        usesNearbyQuery: false,
        locationStatus: switch (error.type) {
          RescueLocationFailureType.permissionDenied =>
            RescueLocationStatus.permissionDenied,
          RescueLocationFailureType.serviceDisabled =>
            RescueLocationStatus.serviceDisabled,
          RescueLocationFailureType.timeout => RescueLocationStatus.timeout,
          RescueLocationFailureType.unknown => RescueLocationStatus.error,
        },
        message: error.message,
      );
    }
  }
}

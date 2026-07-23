import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vet_map_models.dart';
import '../domain/vet_models.dart';

enum VetFinderDatasetSource { none, nearby, search }

class VetFinderSessionState {
  const VetFinderSessionState({
    this.query = '',
    this.selectedCity = 'Tất cả',
    this.only24h = false,
    this.openNow = false,
    this.minRating,
    this.sort = VetSortOption.curated,
    this.radiusMeters = 3000,
    this.items = const [],
    this.nextCursor,
    this.total = 0,
    this.datasetSource = VetFinderDatasetSource.none,
    this.datasetRevision = 0,
    this.mapCenter,
    this.selectedVetId,
    this.listScrollOffset = 0,
  });

  final String query;
  final String selectedCity;
  final bool only24h;
  final bool openNow;
  final double? minRating;
  final VetSortOption sort;
  final int radiusMeters;
  final List<VetSummary> items;
  final String? nextCursor;
  final int total;
  final VetFinderDatasetSource datasetSource;
  final int datasetRevision;
  final VetMapLocation? mapCenter;
  final String? selectedVetId;
  final double listScrollOffset;

  bool get rating4Plus => minRating == 4;
  bool get hasDataset => datasetSource != VetFinderDatasetSource.none;
  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      selectedCity != 'Tất cả' ||
      only24h ||
      openNow ||
      minRating != null ||
      sort != VetSortOption.curated ||
      radiusMeters != 3000;

  VetSearchRequest buildSearchRequest({String? cursor}) {
    return VetSearchRequest(
      keyword: query.trim(),
      city: selectedCity == 'Tất cả' ? null : selectedCity,
      only24h: only24h,
      openNow: openNow,
      minRating: minRating,
      sort: sort,
      cursor: cursor,
    );
  }

  VetFinderSessionState copyWith({
    String? query,
    String? selectedCity,
    bool? only24h,
    bool? openNow,
    double? minRating,
    bool clearMinRating = false,
    VetSortOption? sort,
    int? radiusMeters,
    List<VetSummary>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    int? total,
    VetFinderDatasetSource? datasetSource,
    int? datasetRevision,
    VetMapLocation? mapCenter,
    String? selectedVetId,
    bool clearSelectedVetId = false,
    double? listScrollOffset,
  }) {
    return VetFinderSessionState(
      query: query ?? this.query,
      selectedCity: selectedCity ?? this.selectedCity,
      only24h: only24h ?? this.only24h,
      openNow: openNow ?? this.openNow,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      sort: sort ?? this.sort,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      total: total ?? this.total,
      datasetSource: datasetSource ?? this.datasetSource,
      datasetRevision: datasetRevision ?? this.datasetRevision,
      mapCenter: mapCenter ?? this.mapCenter,
      selectedVetId: clearSelectedVetId
          ? null
          : (selectedVetId ?? this.selectedVetId),
      listScrollOffset: listScrollOffset ?? this.listScrollOffset,
    );
  }
}

final vetFinderSessionProvider =
    NotifierProvider<VetFinderSessionNotifier, VetFinderSessionState>(
      VetFinderSessionNotifier.new,
    );

class VetFinderSessionNotifier extends Notifier<VetFinderSessionState> {
  @override
  VetFinderSessionState build() => const VetFinderSessionState();

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void setCity(String value) {
    state = state.copyWith(selectedCity: value);
  }

  void setSort(VetSortOption value) {
    state = state.copyWith(sort: value);
  }

  void toggleOnly24h() {
    state = state.copyWith(only24h: !state.only24h);
  }

  void toggleOpenNow() {
    state = state.copyWith(openNow: !state.openNow);
  }

  void toggleRating4Plus() {
    state = state.copyWith(
      minRating: state.rating4Plus ? null : 4,
      clearMinRating: state.rating4Plus,
    );
  }

  void setRadius(int radiusMeters) {
    state = state.copyWith(radiusMeters: radiusMeters);
  }

  void resetFilters() {
    state = state.copyWith(
      query: '',
      selectedCity: 'Tất cả',
      only24h: false,
      openNow: false,
      clearMinRating: true,
      sort: VetSortOption.curated,
      radiusMeters: 3000,
    );
  }

  void storeDataset({
    required List<VetSummary> items,
    required int total,
    required VetFinderDatasetSource source,
    String? nextCursor,
    VetMapLocation? mapCenter,
  }) {
    final selectedStillExists =
        state.selectedVetId != null &&
        items.any((item) => item.vetId == state.selectedVetId);
    state = state.copyWith(
      items: List.unmodifiable(items),
      total: total,
      nextCursor: nextCursor,
      clearNextCursor: nextCursor == null,
      datasetSource: source,
      datasetRevision: state.datasetRevision + 1,
      mapCenter: mapCenter,
      clearSelectedVetId: !selectedStillExists,
    );
  }

  void appendSearchPage(VetSearchResult result) {
    final merged = <String, VetSummary>{
      for (final item in state.items) item.vetId: item,
      for (final item in result.items) item.vetId: item,
    };
    state = state.copyWith(
      items: List.unmodifiable(merged.values),
      total: result.total,
      nextCursor: result.nextCursor,
      clearNextCursor: result.nextCursor == null,
      datasetSource: VetFinderDatasetSource.search,
      datasetRevision: state.datasetRevision + 1,
    );
  }

  void selectVet(String? vetId) {
    state = state.copyWith(
      selectedVetId: vetId,
      clearSelectedVetId: vetId == null,
    );
  }

  void rememberListScrollOffset(double offset) {
    state = state.copyWith(listScrollOffset: offset < 0 ? 0 : offset);
  }
}

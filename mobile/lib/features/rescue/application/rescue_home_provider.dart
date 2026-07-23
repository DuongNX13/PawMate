import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rescue_api.dart';
import '../domain/rescue_case_models.dart';

typedef RescueClock = DateTime Function();

final rescueClockProvider = Provider<RescueClock>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

enum RescueHomeLoadStatus { initial, loading, ready, empty, error }

enum RescueHomeFilter {
  all,
  missing,
  found,
  dogs,
  cats;

  String get label => switch (this) {
    RescueHomeFilter.all => 'Tất cả',
    RescueHomeFilter.missing => 'Chưa thấy',
    RescueHomeFilter.found => 'Đã thấy',
    RescueHomeFilter.dogs => 'Chó',
    RescueHomeFilter.cats => 'Mèo',
  };

  RescueCaseStatus? get status => switch (this) {
    RescueHomeFilter.missing => RescueCaseStatus.missing,
    RescueHomeFilter.found => RescueCaseStatus.found,
    _ => null,
  };

  RescueSpecies? get species => switch (this) {
    RescueHomeFilter.dogs => RescueSpecies.dog,
    RescueHomeFilter.cats => RescueSpecies.cat,
    _ => null,
  };
}

@immutable
class RescueHomeState {
  const RescueHomeState({
    this.status = RescueHomeLoadStatus.initial,
    this.items = const [],
    this.filter = RescueHomeFilter.all,
    this.nextCursor,
    this.hasMore = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isStale = false,
    this.lastUpdatedAt,
    this.message,
  });

  final RescueHomeLoadStatus status;
  final List<RescueCaseSummary> items;
  final RescueHomeFilter filter;
  final String? nextCursor;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isStale;
  final DateTime? lastUpdatedAt;
  final String? message;

  RescueHomeState copyWith({
    RescueHomeLoadStatus? status,
    List<RescueCaseSummary>? items,
    RescueHomeFilter? filter,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isStale,
    DateTime? lastUpdatedAt,
    bool clearLastUpdatedAt = false,
    String? message,
    bool clearMessage = false,
  }) {
    return RescueHomeState(
      status: status ?? this.status,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isStale: isStale ?? this.isStale,
      lastUpdatedAt: clearLastUpdatedAt
          ? null
          : (lastUpdatedAt ?? this.lastUpdatedAt),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

final rescueHomeProvider =
    NotifierProvider.autoDispose<RescueHomeNotifier, RescueHomeState>(
      RescueHomeNotifier.new,
    );

class RescueHomeNotifier extends Notifier<RescueHomeState> {
  static const pageSize = 5;
  int _requestGeneration = 0;

  @override
  RescueHomeState build() {
    ref.onDispose(() => _requestGeneration++);
    return const RescueHomeState();
  }

  Future<void> initialize() async {
    if (state.status != RescueHomeLoadStatus.initial) return;
    await refresh(clearItems: true);
  }

  Future<void> refresh({bool clearItems = false}) async {
    final generation = ++_requestGeneration;
    final hadItems = state.items.isNotEmpty && !clearItems;
    state = state.copyWith(
      status: hadItems
          ? RescueHomeLoadStatus.ready
          : RescueHomeLoadStatus.loading,
      items: clearItems ? const [] : null,
      clearNextCursor: clearItems,
      hasMore: clearItems ? false : null,
      isRefreshing: hadItems,
      isLoadingMore: false,
      isStale: false,
      clearMessage: true,
    );

    try {
      final page = await ref
          .read(rescueApiProvider)
          .listCases(_queryFor(state.filter));
      if (generation != _requestGeneration) return;
      state = state.copyWith(
        status: page.items.isEmpty
            ? RescueHomeLoadStatus.empty
            : RescueHomeLoadStatus.ready,
        items: page.items,
        nextCursor: page.pageInfo.nextCursor,
        clearNextCursor: page.pageInfo.nextCursor == null,
        hasMore: page.pageInfo.hasMore,
        isRefreshing: false,
        isLoadingMore: false,
        isStale: false,
        lastUpdatedAt: ref.read(rescueClockProvider)(),
        clearMessage: true,
      );
    } on RescueApiException catch (error) {
      if (generation != _requestGeneration) return;
      _setFailure(error.message, retainItems: hadItems);
    } catch (_) {
      if (generation != _requestGeneration) return;
      _setFailure(
        'Không tải được các ca cứu hộ. Vui lòng thử lại.',
        retainItems: hadItems,
      );
    }
  }

  Future<void> applyFilter(RescueHomeFilter filter) async {
    if (filter == state.filter && state.status != RescueHomeLoadStatus.error) {
      return;
    }
    ++_requestGeneration;
    state = RescueHomeState(filter: filter);
    await refresh(clearItems: true);
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (!state.hasMore ||
        cursor == null ||
        state.isLoadingMore ||
        state.status != RescueHomeLoadStatus.ready) {
      return;
    }

    final generation = ++_requestGeneration;
    state = state.copyWith(
      isLoadingMore: true,
      isRefreshing: false,
      clearMessage: true,
    );
    try {
      final page = await ref
          .read(rescueApiProvider)
          .listCases(_queryFor(state.filter, cursor: cursor));
      if (generation != _requestGeneration) return;
      final seen = state.items.map((item) => item.caseId).toSet();
      final merged = [
        ...state.items,
        for (final item in page.items)
          if (seen.add(item.caseId)) item,
      ];
      state = state.copyWith(
        items: merged,
        nextCursor: page.pageInfo.nextCursor,
        clearNextCursor: page.pageInfo.nextCursor == null,
        hasMore: page.pageInfo.hasMore,
        isLoadingMore: false,
        lastUpdatedAt: ref.read(rescueClockProvider)(),
        clearMessage: true,
      );
    } on RescueApiException catch (error) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(isLoadingMore: false, message: error.message);
    } catch (_) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(
        isLoadingMore: false,
        message: 'Không tải được trang tiếp theo. Vui lòng thử lại.',
      );
    }
  }

  void clear() {
    ++_requestGeneration;
    state = const RescueHomeState();
  }

  RescueCaseQuery _queryFor(RescueHomeFilter filter, {String? cursor}) {
    return RescueCaseQuery(
      status: filter.status,
      species: filter.species,
      sort: RescueCaseSort.recent,
      cursor: cursor,
      limit: pageSize,
    );
  }

  void _setFailure(String message, {required bool retainItems}) {
    state = state.copyWith(
      status: retainItems
          ? RescueHomeLoadStatus.ready
          : RescueHomeLoadStatus.error,
      isRefreshing: false,
      isLoadingMore: false,
      isStale: retainItems,
      message: message,
    );
  }
}

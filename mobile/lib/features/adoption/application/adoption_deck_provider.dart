import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adoption_api.dart';
import '../data/adoption_location_service.dart';
import '../domain/adoption_models.dart';
import 'adoption_runtime_providers.dart';

final adoptionDeckProvider =
    NotifierProvider<AdoptionDeckNotifier, AdoptionDeckState>(
      AdoptionDeckNotifier.new,
    );

enum AdoptionDeckStatus { initial, loading, ready, empty, exhausted, error }

@immutable
class AdoptionDeckFilter {
  const AdoptionDeckFilter({
    this.species,
    this.ageGroup,
    this.coordinates,
    this.distanceKm,
  });

  final AdoptionSpecies? species;
  final AdoptionAgeGroup? ageGroup;
  final AdoptionCoordinates? coordinates;
  final double? distanceKm;

  bool get isNearby => coordinates != null;

  AdoptionListQuery toQuery({String? cursor, int limit = 20}) {
    return AdoptionListQuery(
      species: species,
      ageGroup: ageGroup,
      coordinates: coordinates,
      distanceKm: coordinates == null ? null : distanceKm,
      sort: coordinates == null
          ? AdoptionReadSort.curated
          : AdoptionReadSort.distance,
      cursor: cursor,
      limit: limit,
    );
  }

  AdoptionDeckFilter copyWith({
    AdoptionSpecies? species,
    bool clearSpecies = false,
    AdoptionAgeGroup? ageGroup,
    bool clearAgeGroup = false,
    AdoptionCoordinates? coordinates,
    bool clearCoordinates = false,
    double? distanceKm,
    bool clearDistance = false,
  }) {
    return AdoptionDeckFilter(
      species: clearSpecies ? null : species ?? this.species,
      ageGroup: clearAgeGroup ? null : ageGroup ?? this.ageGroup,
      coordinates: clearCoordinates ? null : coordinates ?? this.coordinates,
      distanceKm: clearDistance ? null : distanceKm ?? this.distanceKm,
    );
  }
}

@immutable
class AdoptionPendingSkip {
  const AdoptionPendingSkip({
    required this.listing,
    required this.originalIndex,
    required this.idempotencyKey,
  });

  final AdoptionListingSummary listing;
  final int originalIndex;
  final String idempotencyKey;
}

@immutable
class AdoptionDeckState {
  const AdoptionDeckState({
    this.status = AdoptionDeckStatus.initial,
    this.items = const [],
    this.filter = const AdoptionDeckFilter(),
    this.nextCursor,
    this.hasMore = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isLocating = false,
    this.isDecisionPending = false,
    this.isStale = false,
    this.pendingSkip,
    this.message,
    this.error,
  });

  final AdoptionDeckStatus status;
  final List<AdoptionListingSummary> items;
  final AdoptionDeckFilter filter;
  final String? nextCursor;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isLocating;
  final bool isDecisionPending;
  final bool isStale;
  final AdoptionPendingSkip? pendingSkip;
  final String? message;
  final Object? error;

  AdoptionListingSummary? get currentListing =>
      items.isEmpty ? null : items.first;

  bool get isListingRequestPending =>
      status == AdoptionDeckStatus.loading || isRefreshing || isLoadingMore;

  bool get isInteractionLocked =>
      isListingRequestPending ||
      isLocating ||
      isDecisionPending ||
      pendingSkip != null;

  AdoptionDeckState copyWith({
    AdoptionDeckStatus? status,
    List<AdoptionListingSummary>? items,
    AdoptionDeckFilter? filter,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isLocating,
    bool? isDecisionPending,
    bool? isStale,
    AdoptionPendingSkip? pendingSkip,
    bool clearPendingSkip = false,
    String? message,
    bool clearMessage = false,
    Object? error,
    bool clearError = false,
  }) {
    return AdoptionDeckState(
      status: status ?? this.status,
      items: items == null ? this.items : List.unmodifiable(items),
      filter: filter ?? this.filter,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLocating: isLocating ?? this.isLocating,
      isDecisionPending: isDecisionPending ?? this.isDecisionPending,
      isStale: isStale ?? this.isStale,
      pendingSkip: clearPendingSkip ? null : pendingSkip ?? this.pendingSkip,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AdoptionDeckNotifier extends Notifier<AdoptionDeckState> {
  static const _pageSize = 20;

  int _requestGeneration = 0;
  int _locationGeneration = 0;
  int _buildRevision = 0;
  int _idempotencySequence = 0;
  AdoptionCancelScheduled? _cancelPendingCommit;
  final Map<String, String> _retryIdempotencyKeys = {};
  final Set<String> _hiddenListingIds = {};

  @override
  AdoptionDeckState build() {
    ref.watch(adoptionSessionRevisionProvider);
    _buildRevision += 1;
    _requestGeneration += 1;
    _locationGeneration += 1;
    _cancelScheduledCommit();
    _retryIdempotencyKeys.clear();
    _hiddenListingIds.clear();
    ref.onDispose(_cancelScheduledCommit);
    return const AdoptionDeckState();
  }

  Future<void> initialize() async {
    if (state.status != AdoptionDeckStatus.initial) return;
    await refresh(clearItems: true);
  }

  Future<void> refresh({bool clearItems = false}) async {
    if (state.pendingSkip != null ||
        state.isDecisionPending ||
        state.isLoadingMore ||
        state.isLocating) {
      return;
    }

    final generation = ++_requestGeneration;
    final existingItems = clearItems
        ? const <AdoptionListingSummary>[]
        : state.items;
    state = state.copyWith(
      status: existingItems.isEmpty
          ? AdoptionDeckStatus.loading
          : AdoptionDeckStatus.ready,
      items: existingItems,
      isRefreshing: existingItems.isNotEmpty,
      isLoadingMore: false,
      isStale: false,
      clearNextCursor: clearItems,
      hasMore: clearItems ? false : state.hasMore,
      clearMessage: true,
      clearError: true,
    );

    try {
      final page = await ref
          .read(adoptionSourceProvider)
          .listListings(
            state.filter.toQuery(limit: _pageSize),
            accessToken: await _requireAccessToken(),
          );
      if (generation != _requestGeneration) return;

      final visibleItems = page.items
          .where((item) => !_hiddenListingIds.contains(item.listingId))
          .toList(growable: false);
      state = state.copyWith(
        status: visibleItems.isEmpty && !page.pageInfo.hasMore
            ? AdoptionDeckStatus.empty
            : AdoptionDeckStatus.ready,
        items: visibleItems,
        nextCursor: page.pageInfo.nextCursor,
        clearNextCursor: page.pageInfo.nextCursor == null,
        hasMore: page.pageInfo.hasMore,
        isRefreshing: false,
        isStale: false,
        clearMessage: true,
        clearError: true,
      );
      if (visibleItems.isEmpty && page.pageInfo.hasMore) {
        await loadMore();
      }
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      final hasFallback = existingItems.isNotEmpty;
      state = state.copyWith(
        status: hasFallback
            ? AdoptionDeckStatus.ready
            : AdoptionDeckStatus.error,
        items: existingItems,
        isRefreshing: false,
        isStale: hasFallback,
        message: _messageFor(error),
        error: error,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursor == null ||
        state.isDecisionPending) {
      return;
    }
    final generation = _requestGeneration;
    state = state.copyWith(
      isLoadingMore: true,
      clearMessage: true,
      clearError: true,
    );
    try {
      final page = await ref
          .read(adoptionSourceProvider)
          .listListings(
            state.filter.toQuery(cursor: state.nextCursor, limit: _pageSize),
            accessToken: await _requireAccessToken(),
          );
      if (generation != _requestGeneration) return;

      final seen = state.items.map((item) => item.listingId).toSet();
      final pendingListingId = state.pendingSkip?.listing.listingId;
      if (pendingListingId != null) {
        seen.add(pendingListingId);
      }
      final merged = <AdoptionListingSummary>[
        ...state.items,
        for (final item in page.items)
          if (!_hiddenListingIds.contains(item.listingId) &&
              seen.add(item.listingId))
            item,
      ];
      state = state.copyWith(
        status: merged.isEmpty
            ? AdoptionDeckStatus.empty
            : AdoptionDeckStatus.ready,
        items: merged,
        nextCursor: page.pageInfo.nextCursor,
        clearNextCursor: page.pageInfo.nextCursor == null,
        hasMore: page.pageInfo.hasMore,
        isLoadingMore: false,
        isStale: false,
      );
      if (merged.isEmpty && page.pageInfo.hasMore) {
        await loadMore();
      }
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(
        status: state.items.isEmpty
            ? AdoptionDeckStatus.error
            : AdoptionDeckStatus.ready,
        isLoadingMore: false,
        isStale: state.items.isNotEmpty,
        message: _messageFor(error),
        error: error,
      );
    }
  }

  Future<void> applySpeciesFilter(AdoptionSpecies? species) async {
    if (state.filter.species == species) return;
    if (state.pendingSkip != null ||
        state.isDecisionPending ||
        state.isListingRequestPending) {
      return;
    }
    _locationGeneration += 1;
    state = state.copyWith(
      filter: state.filter.copyWith(
        species: species,
        clearSpecies: species == null,
      ),
      items: const [],
      status: AdoptionDeckStatus.initial,
      hasMore: false,
      isLocating: false,
      clearNextCursor: true,
    );
    await refresh(clearItems: true);
  }

  Future<bool> applyFilterDraft({
    AdoptionSpecies? species,
    AdoptionAgeGroup? ageGroup,
    double? distanceKm,
  }) async {
    if (state.isInteractionLocked) return false;

    final current = state.filter;
    AdoptionCoordinates? coordinates;
    final locationGeneration = ++_locationGeneration;
    if (distanceKm != null) {
      coordinates = current.coordinates;
      if (coordinates == null) {
        state = state.copyWith(
          isLocating: true,
          clearMessage: true,
          clearError: true,
        );
        try {
          coordinates = await ref
              .read(adoptionLocationSourceProvider)
              .resolveCurrentLocation();
        } on Object catch (error) {
          if (locationGeneration != _locationGeneration) return false;
          state = state.copyWith(
            isLocating: false,
            message: _messageFor(error),
            error: error,
          );
          return false;
        }
        if (locationGeneration != _locationGeneration) return false;
      }
    }

    final unchanged =
        current.species == species &&
        current.ageGroup == ageGroup &&
        current.distanceKm == distanceKm &&
        ((distanceKm == null && current.coordinates == null) ||
            (distanceKm != null && current.coordinates == coordinates));
    if (unchanged) {
      if (state.isLocating) state = state.copyWith(isLocating: false);
      return true;
    }

    state = state.copyWith(
      filter: AdoptionDeckFilter(
        species: species,
        ageGroup: ageGroup,
        coordinates: distanceKm == null ? null : coordinates,
        distanceKm: distanceKm,
      ),
      items: const [],
      status: AdoptionDeckStatus.initial,
      hasMore: false,
      isLocating: false,
      clearNextCursor: true,
      clearMessage: true,
      clearError: true,
    );
    await refresh(clearItems: true);
    return true;
  }

  Future<void> enableNearby({double distanceKm = 5}) async {
    if (state.isInteractionLocked) return;

    final locationGeneration = ++_locationGeneration;
    state = state.copyWith(
      isLocating: true,
      clearMessage: true,
      clearError: true,
    );
    try {
      final coordinates = await ref
          .read(adoptionLocationSourceProvider)
          .resolveCurrentLocation();
      if (locationGeneration != _locationGeneration) return;
      state = state.copyWith(
        filter: state.filter.copyWith(
          coordinates: coordinates,
          distanceKm: distanceKm,
        ),
        isLocating: false,
        items: const [],
        status: AdoptionDeckStatus.initial,
        hasMore: false,
        clearNextCursor: true,
      );
      await refresh(clearItems: true);
    } on Object catch (error) {
      if (locationGeneration != _locationGeneration) return;
      state = state.copyWith(
        isLocating: false,
        message: _messageFor(error),
        error: error,
      );
    }
  }

  Future<void> clearNearby() async {
    if (state.isDecisionPending ||
        state.isListingRequestPending ||
        state.pendingSkip != null) {
      return;
    }
    final wasLocating = state.isLocating;
    if (wasLocating) {
      _locationGeneration += 1;
      state = state.copyWith(isLocating: false);
    }
    if (!state.filter.isNearby) return;
    state = state.copyWith(
      filter: state.filter.copyWith(
        clearCoordinates: true,
        clearDistance: true,
      ),
      items: const [],
      status: AdoptionDeckStatus.initial,
      hasMore: false,
      clearNextCursor: true,
    );
    await refresh(clearItems: true);
  }

  Future<void> clearFilters() async {
    if (state.pendingSkip != null ||
        state.isDecisionPending ||
        state.isListingRequestPending) {
      return;
    }
    _locationGeneration += 1;
    state = state.copyWith(
      filter: const AdoptionDeckFilter(),
      items: const [],
      status: AdoptionDeckStatus.initial,
      hasMore: false,
      isLocating: false,
      clearNextCursor: true,
      clearMessage: true,
      clearError: true,
    );
    await refresh(clearItems: true);
  }

  Future<bool> skipCurrentWithUndo() async {
    if (state.isInteractionLocked) return false;

    final listing = state.currentListing;
    if (listing == null) return false;
    final idempotencyKey = _idempotencyKeyFor(
      AdoptionDecision.skip,
      listing.listingId,
    );
    _hiddenListingIds.add(listing.listingId);
    final nextItems = state.items.skip(1).toList(growable: false);
    state = state.copyWith(
      items: nextItems,
      status: _statusAfterDecision(nextItems),
      pendingSkip: AdoptionPendingSkip(
        listing: listing,
        originalIndex: 0,
        idempotencyKey: idempotencyKey,
      ),
      clearMessage: true,
      clearError: true,
    );
    _cancelPendingCommit = ref.read(adoptionDecisionSchedulerProvider)(
      ref.read(adoptionUndoDurationProvider),
      commitPendingSkip,
    );
    if (nextItems.isEmpty && state.hasMore) {
      await loadMore();
    }
    return true;
  }

  bool undoLastSkip() {
    final pending = state.pendingSkip;
    if (pending == null || state.isDecisionPending) return false;
    _cancelScheduledCommit();

    final restored = [...state.items];
    restored.insert(
      math.min(pending.originalIndex, restored.length),
      pending.listing,
    );
    _retryIdempotencyKeys.remove(
      _decisionKey(AdoptionDecision.skip, pending.listing.listingId),
    );
    _hiddenListingIds.remove(pending.listing.listingId);
    state = state.copyWith(
      status: AdoptionDeckStatus.ready,
      items: restored,
      clearPendingSkip: true,
      clearMessage: true,
      clearError: true,
    );
    return true;
  }

  Future<bool> commitPendingSkip() async {
    final pending = state.pendingSkip;
    if (pending == null) return true;
    if (state.isDecisionPending) return false;

    _cancelScheduledCommit();
    final buildRevision = _buildRevision;
    state = state.copyWith(
      isDecisionPending: true,
      clearMessage: true,
      clearError: true,
    );
    try {
      await ref
          .read(adoptionSourceProvider)
          .recordDecision(
            pending.listing.listingId,
            AdoptionDecision.skip,
            accessToken: await _requireAccessToken(),
            idempotencyKey: pending.idempotencyKey,
          );
      if (buildRevision != _buildRevision) return false;

      _retryIdempotencyKeys.remove(
        _decisionKey(AdoptionDecision.skip, pending.listing.listingId),
      );
      state = state.copyWith(
        isDecisionPending: false,
        clearPendingSkip: true,
        clearMessage: true,
        clearError: true,
      );
      return true;
    } on Object catch (error) {
      if (buildRevision != _buildRevision) return false;
      _hiddenListingIds.remove(pending.listing.listingId);
      final restored = [...state.items];
      restored.insert(
        math.min(pending.originalIndex, restored.length),
        pending.listing,
      );
      state = state.copyWith(
        status: AdoptionDeckStatus.ready,
        items: restored,
        isDecisionPending: false,
        clearPendingSkip: true,
        message: _messageFor(error),
        error: error,
      );
      return false;
    }
  }

  Future<AdoptionListingSummary?> likeCurrent() async {
    if (state.isInteractionLocked) return null;

    final listing = state.currentListing;
    if (listing == null) return null;
    final buildRevision = _buildRevision;
    final idempotencyKey = _idempotencyKeyFor(
      AdoptionDecision.like,
      listing.listingId,
    );
    state = state.copyWith(
      isDecisionPending: true,
      clearMessage: true,
      clearError: true,
    );
    try {
      await ref
          .read(adoptionSourceProvider)
          .recordDecision(
            listing.listingId,
            AdoptionDecision.like,
            accessToken: await _requireAccessToken(),
            idempotencyKey: idempotencyKey,
          );
      if (buildRevision != _buildRevision) return null;

      _retryIdempotencyKeys.remove(
        _decisionKey(AdoptionDecision.like, listing.listingId),
      );
      _hiddenListingIds.add(listing.listingId);
      final remaining = state.items
          .where((item) => item.listingId != listing.listingId)
          .toList(growable: false);
      state = state.copyWith(
        status: _statusAfterDecision(remaining),
        items: remaining,
        isDecisionPending: false,
        clearMessage: true,
        clearError: true,
      );
      if (remaining.isEmpty && state.hasMore) {
        await loadMore();
      }
      return listing;
    } on Object catch (error) {
      if (buildRevision != _buildRevision) return null;
      state = state.copyWith(
        isDecisionPending: false,
        message: _messageFor(error),
        error: error,
      );
      return null;
    }
  }

  AdoptionDeckStatus _statusAfterDecision(
    List<AdoptionListingSummary> remaining,
  ) {
    if (remaining.isNotEmpty || state.hasMore) {
      return AdoptionDeckStatus.ready;
    }
    return AdoptionDeckStatus.exhausted;
  }

  String _idempotencyKeyFor(AdoptionDecision decision, String listingId) {
    final decisionKey = _decisionKey(decision, listingId);
    return _retryIdempotencyKeys.putIfAbsent(decisionKey, () {
      _idempotencySequence += 1;
      return ref.read(adoptionIdempotencyKeyFactoryProvider)(
        decision,
        listingId,
        ref.read(adoptionClockProvider)(),
        _idempotencySequence,
      );
    });
  }

  String _decisionKey(AdoptionDecision decision, String listingId) {
    return '${decision.wireValue}:$listingId';
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await ref.read(adoptionAccessTokenProvider);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const AdoptionApiException(
        'Bạn cần đăng nhập để sử dụng tính năng nhận nuôi.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    return accessToken.trim();
  }

  String _messageFor(Object error) {
    if (error is AdoptionApiException) return error.message;
    if (error is AdoptionLocationException) return error.message;
    return 'Không tải được dữ liệu nhận nuôi. Vui lòng thử lại.';
  }

  void _cancelScheduledCommit() {
    _cancelPendingCommit?.call();
    _cancelPendingCommit = null;
  }
}

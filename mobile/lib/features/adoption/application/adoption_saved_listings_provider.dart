import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adoption_saved_listing_store.dart';

final adoptionSavedListingsProvider =
    AsyncNotifierProvider<AdoptionSavedListingsNotifier, Set<String>>(
      AdoptionSavedListingsNotifier.new,
    );

final _adoptionSavedListingPendingIdsProvider =
    NotifierProvider<_AdoptionSavedListingPendingIdsNotifier, Set<String>>(
      _AdoptionSavedListingPendingIdsNotifier.new,
    );

final adoptionSavedListingPendingProvider = Provider.family<bool, String>((
  ref,
  listingId,
) {
  final normalizedId = listingId.trim();
  return ref.watch(
    _adoptionSavedListingPendingIdsProvider.select(
      (pendingIds) => pendingIds.contains(normalizedId),
    ),
  );
});

class AdoptionSavedListingsNotifier extends AsyncNotifier<Set<String>> {
  late Future<Set<String>> _initialLoad;
  final Map<String, Future<bool>> _pendingOperations = {};
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<Set<String>> build() {
    _initialLoad = ref
        .watch(adoptionSavedListingStoreProvider)
        .readAll()
        .then(Set.unmodifiable);
    return _initialLoad;
  }

  bool isSaved(String listingId) {
    return state.hasValue && state.requireValue.contains(listingId);
  }

  Future<bool> toggle(String listingId) {
    final normalizedId = listingId.trim();
    if (normalizedId.isEmpty) {
      return Future<bool>.error(
        ArgumentError.value(listingId, 'listingId', 'Must not be empty.'),
      );
    }

    final pendingOperation = _pendingOperations[normalizedId];
    if (pendingOperation != null) return pendingOperation;

    final previousWrite = _writeTail;
    final operation = () async {
      await previousWrite;
      return _toggleSerialized(normalizedId);
    }();
    _pendingOperations[normalizedId] = operation;
    _setPending(normalizedId, pending: true);
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    operation.then<void>(
      (_) => _finishOperation(normalizedId, operation),
      onError: (Object _, StackTrace _) =>
          _finishOperation(normalizedId, operation),
    );
    return operation;
  }

  Future<bool> _toggleSerialized(String normalizedId) async {
    final previous = state.hasValue ? state.requireValue : await _initialLoad;
    final next = Set<String>.from(previous);
    final saved = next.contains(normalizedId);
    if (saved) {
      next.remove(normalizedId);
    } else {
      next.add(normalizedId);
    }
    final immutableNext = Set<String>.unmodifiable(next);
    state = AsyncData(immutableNext);

    try {
      await ref.read(adoptionSavedListingStoreProvider).writeAll(immutableNext);
      return !saved;
    } on Object {
      state = AsyncData(previous);
      rethrow;
    }
  }

  void _finishOperation(String listingId, Future<bool> operation) {
    if (!identical(_pendingOperations[listingId], operation)) return;
    _pendingOperations.remove(listingId);
    _setPending(listingId, pending: false);
  }

  void _setPending(String listingId, {required bool pending}) {
    ref
        .read(_adoptionSavedListingPendingIdsProvider.notifier)
        .setPending(listingId, pending: pending);
  }
}

class _AdoptionSavedListingPendingIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void setPending(String listingId, {required bool pending}) {
    final next = Set<String>.from(state);
    if (pending) {
      next.add(listingId);
    } else {
      next.remove(listingId);
    }
    state = Set<String>.unmodifiable(next);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final adoptionSavedListingStoreProvider = Provider<AdoptionSavedListingStore>((
  ref,
) {
  return SharedPreferencesAdoptionSavedListingStore();
});

/// Device-local saved listings.
///
/// The backend has no adoption-favorite endpoint in the frozen Day 54
/// contract. This store deliberately makes no cross-device or account-sync
/// promise.
abstract interface class AdoptionSavedListingStore {
  Future<Set<String>> readAll();

  Future<void> writeAll(Set<String> listingIds);
}

class SharedPreferencesAdoptionSavedListingStore
    implements AdoptionSavedListingStore {
  static const storageKey = 'pawmate.adoption.savedListingIds.v1';

  @override
  Future<Set<String>> readAll() async {
    final preferences = await SharedPreferences.getInstance();
    return Set.unmodifiable(
      (preferences.getStringList(storageKey) ?? const <String>[])
          .map((listingId) => listingId.trim())
          .where((listingId) => listingId.isNotEmpty),
    );
  }

  @override
  Future<void> writeAll(Set<String> listingIds) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized =
        listingIds
            .map((listingId) => listingId.trim())
            .where((listingId) => listingId.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final saved = await preferences.setStringList(storageKey, normalized);
    if (!saved) {
      throw StateError('Unable to persist saved adoption listings.');
    }
  }
}

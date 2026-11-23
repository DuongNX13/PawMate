import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_profile_provider.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_saved_listings_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adoption_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile provider loads exact listing with access token', () async {
    final source = _ProfileSource();
    final container = ProviderContainer(
      overrides: [
        adoptionSourceProvider.overrideWith((ref) => source),
        adoptionAccessTokenProvider.overrideWith(
          (ref) => Future<String?>.value('profile-token'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final profile = adoptionProfileProvider('listing-42');
    final subscription = container.listen(profile, (_, _) {});
    addTearDown(subscription.close);

    final detail = await container.read(profile.future);

    expect(detail.listingId, 'listing-42');
    expect(source.detailListingId, 'listing-42');
    expect(source.detailAccessToken, 'profile-token');
  });

  test(
    'profile provider fails typed and does not call API without auth',
    () async {
      final source = _ProfileSource();
      final container = ProviderContainer(
        overrides: [
          adoptionSourceProvider.overrideWith((ref) => source),
          adoptionAccessTokenProvider.overrideWith(
            (ref) => Future<String?>.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      final profile = adoptionProfileProvider('listing-42');
      final errorState = Completer<AsyncValue<AdoptionListingDetail>>();
      final subscription = container.listen(profile, (_, next) {
        if (next.hasError && !errorState.isCompleted) {
          errorState.complete(next);
        }
      });
      addTearDown(subscription.close);

      final result = await errorState.future;
      expect(
        result.error,
        isA<AdoptionApiException>()
            .having((error) => error.code, 'code', 'AUTH_REQUIRED')
            .having((error) => error.isAuthRequired, 'auth', isTrue),
      );
      expect(source.detailListingId, isNull);
    },
  );

  test(
    'SharedPreferences store normalizes, deduplicates, and sorts ids',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAdoptionSavedListingStore();

      await store.writeAll({' listing-b ', 'listing-a', '', ' listing-a '});

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getStringList(
          SharedPreferencesAdoptionSavedListingStore.storageKey,
        ),
        ['listing-a', 'listing-b'],
      );
      expect(await store.readAll(), {'listing-a', 'listing-b'});
    },
  );

  test('saved listing provider persists only on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final firstContainer = ProviderContainer();
    addTearDown(firstContainer.dispose);
    expect(
      await firstContainer.read(adoptionSavedListingsProvider.future),
      isEmpty,
    );

    final isNowSaved = await firstContainer
        .read(adoptionSavedListingsProvider.notifier)
        .toggle('listing-1');
    expect(isNowSaved, isTrue);
    expect(firstContainer.read(adoptionSavedListingsProvider).requireValue, {
      'listing-1',
    });

    final restartedContainer = ProviderContainer();
    addTearDown(restartedContainer.dispose);
    expect(
      await restartedContainer.read(adoptionSavedListingsProvider.future),
      {'listing-1'},
    );
  });

  test('saved listing write failure rolls optimistic state back', () async {
    final store = _FailingSavedStore();
    final container = ProviderContainer(
      overrides: [
        adoptionSavedListingStoreProvider.overrideWith((ref) => store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(adoptionSavedListingsProvider.future);

    await expectLater(
      container
          .read(adoptionSavedListingsProvider.notifier)
          .toggle('listing-1'),
      throwsStateError,
    );

    expect(container.read(adoptionSavedListingsProvider).requireValue, isEmpty);
  });

  test(
    'saved listing writes serialize and duplicate pending toggle reuses one operation',
    () async {
      final store = _DeferredSavedStore();
      final container = ProviderContainer(
        overrides: [
          adoptionSavedListingStoreProvider.overrideWith((ref) => store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(adoptionSavedListingsProvider.future);
      final notifier = container.read(adoptionSavedListingsProvider.notifier);

      final first = notifier.toggle('listing-1');
      final duplicate = notifier.toggle('listing-1');
      final second = notifier.toggle('listing-2');
      expect(identical(first, duplicate), isTrue);
      expect(
        container.read(adoptionSavedListingPendingProvider('listing-1')),
        isTrue,
      );
      expect(
        container.read(adoptionSavedListingPendingProvider('listing-2')),
        isTrue,
      );

      await Future<void>.delayed(Duration.zero);
      expect(store.writes, [
        {'listing-1'},
      ]);
      expect(container.read(adoptionSavedListingsProvider).requireValue, {
        'listing-1',
      });

      final firstError = expectLater(first, throwsStateError);
      final duplicateError = expectLater(duplicate, throwsStateError);
      store.firstWrite.completeError(StateError('disk full'));
      await Future.wait([firstError, duplicateError]);
      await Future<void>.delayed(Duration.zero);

      expect(store.writes, [
        {'listing-1'},
        {'listing-2'},
      ]);
      expect(container.read(adoptionSavedListingsProvider).requireValue, {
        'listing-2',
      });
      store.secondWrite.complete();
      expect(await second, isTrue);
      expect(
        container.read(adoptionSavedListingPendingProvider('listing-1')),
        isFalse,
      );
      expect(
        container.read(adoptionSavedListingPendingProvider('listing-2')),
        isFalse,
      );
      expect(container.read(adoptionSavedListingsProvider).requireValue, {
        'listing-2',
      });
    },
  );
}

class _ProfileSource implements AdoptionSource {
  String? detailListingId;
  String? detailAccessToken;

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) async {
    detailListingId = listingId;
    detailAccessToken = accessToken;
    return adoptionDetail(listingId: listingId);
  }

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }
}

class _FailingSavedStore implements AdoptionSavedListingStore {
  @override
  Future<Set<String>> readAll() async => const {};

  @override
  Future<void> writeAll(Set<String> listingIds) {
    throw StateError('disk full');
  }
}

class _DeferredSavedStore implements AdoptionSavedListingStore {
  final Completer<void> firstWrite = Completer<void>();
  final Completer<void> secondWrite = Completer<void>();
  final List<Set<String>> writes = [];

  @override
  Future<Set<String>> readAll() async => const {};

  @override
  Future<void> writeAll(Set<String> listingIds) {
    writes.add(Set<String>.unmodifiable(listingIds));
    return switch (writes.length) {
      1 => firstWrite.future,
      2 => secondWrite.future,
      _ => throw StateError('Unexpected extra local-save write.'),
    };
  }
}

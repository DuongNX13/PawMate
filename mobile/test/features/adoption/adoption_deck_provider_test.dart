import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_deck_provider.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_location_service.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';

import 'adoption_test_fixtures.dart';

void main() {
  test('initialize loads curated page without requesting location', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(
          items: [
            adoptionSummary(listingId: 'listing-1'),
            adoptionSummary(listingId: 'listing-2', petName: 'Lulu'),
          ],
          nextCursor: 'opaque-next',
          hasMore: true,
        ),
      ],
    );
    final location = _FakeAdoptionLocation();
    final container = _container(source: source, location: location);
    addTearDown(container.dispose);

    await container.read(adoptionDeckProvider.notifier).initialize();

    final state = container.read(adoptionDeckProvider);
    expect(state.status, AdoptionDeckStatus.ready);
    expect(state.items, hasLength(2));
    expect(state.currentListing?.listingId, 'listing-1');
    expect(state.nextCursor, 'opaque-next');
    expect(state.hasMore, isTrue);
    expect(source.queries.single.sort, AdoptionReadSort.curated);
    expect(source.queries.single.coordinates, isNull);
    expect(location.calls, 0);
  });

  test('loadMore preserves opaque cursor and deduplicates listings', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(
          items: [adoptionSummary(listingId: 'listing-1')],
          nextCursor: 'opaque-next',
          hasMore: true,
        ),
        adoptionPage(
          items: [
            adoptionSummary(listingId: 'listing-1'),
            adoptionSummary(listingId: 'listing-2'),
          ],
        ),
      ],
    );
    final container = _container(source: source);
    addTearDown(container.dispose);

    await container.read(adoptionDeckProvider.notifier).initialize();
    await container.read(adoptionDeckProvider.notifier).loadMore();

    expect(source.queries.last.cursor, 'opaque-next');
    expect(
      container
          .read(adoptionDeckProvider)
          .items
          .map((listing) => listing.listingId),
      ['listing-1', 'listing-2'],
    );
  });

  test(
    'loadMore failure preserves cards and reports an empty-deck retry',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(
            items: [adoptionSummary(listingId: 'listing-1')],
            nextCursor: 'opaque-next',
            hasMore: true,
          ),
        ],
      );
      final container = _container(source: source);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();
      source.listError = const AdoptionApiException('Phân trang gián đoạn.');

      await notifier.loadMore();

      var state = container.read(adoptionDeckProvider);
      expect(state.status, AdoptionDeckStatus.ready);
      expect(state.isStale, isTrue);
      expect(state.currentListing?.listingId, 'listing-1');

      await notifier.skipCurrentWithUndo();

      state = container.read(adoptionDeckProvider);
      expect(state.status, AdoptionDeckStatus.error);
      expect(state.items, isEmpty);
      expect(state.pendingSkip, isNotNull);
      expect(state.message, 'Phân trang gián đoạn.');
    },
  );

  test('skip undo removes locally but never writes a decision', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
    );
    final scheduler = _FakeDecisionScheduler();
    final container = _container(source: source, scheduler: scheduler);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    expect(await notifier.skipCurrentWithUndo(), isTrue);
    expect(
      container.read(adoptionDeckProvider).status,
      AdoptionDeckStatus.exhausted,
    );
    expect(source.decisionCalls, isEmpty);
    expect(notifier.undoLastSkip(), isTrue);
    await scheduler.fireAll();

    expect(source.decisionCalls, isEmpty);
    expect(
      container.read(adoptionDeckProvider).currentListing?.listingId,
      'listing-1',
    );
    expect(container.read(adoptionDeckProvider).pendingSkip, isNull);
  });

  test(
    'undo window blocks conflicting transitions and keeps skip local',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(
            items: [
              adoptionSummary(listingId: 'listing-1'),
              adoptionSummary(listingId: 'listing-2'),
            ],
          ),
        ],
      );
      final scheduler = _FakeDecisionScheduler();
      final container = _container(source: source, scheduler: scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();

      expect(await notifier.skipCurrentWithUndo(), isTrue);
      await notifier.refresh();
      await notifier.applySpeciesFilter(AdoptionSpecies.cat);
      await notifier.enableNearby();
      expect(await notifier.likeCurrent(), isNull);
      expect(await notifier.skipCurrentWithUndo(), isFalse);

      expect(source.queries, hasLength(1));
      expect(source.decisionCalls, isEmpty);
      expect(container.read(adoptionDeckProvider).pendingSkip, isNotNull);
      expect(notifier.undoLastSkip(), isTrue);
      expect(
        container
            .read(adoptionDeckProvider)
            .items
            .map((listing) => listing.listingId),
        ['listing-1', 'listing-2'],
      );
      await scheduler.fireAll();
      expect(source.decisionCalls, isEmpty);
    },
  );

  test('expired undo commits skip exactly once', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
    );
    final scheduler = _FakeDecisionScheduler();
    final container = _container(source: source, scheduler: scheduler);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    await notifier.skipCurrentWithUndo();
    await scheduler.fireLatest();

    expect(source.decisionCalls, hasLength(1));
    expect(source.decisionCalls.single.decision, AdoptionDecision.skip);
    expect(source.decisionCalls.single.idempotencyKey, 'skip-listing-1-key');
    expect(container.read(adoptionDeckProvider).pendingSkip, isNull);
    expect(container.read(adoptionDeckProvider).isDecisionPending, isFalse);
  });

  test(
    'skip preloads the next cursor while preserving the undo window',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(
            items: [adoptionSummary(listingId: 'listing-1')],
            nextCursor: 'opaque-next',
            hasMore: true,
          ),
          adoptionPage(items: [adoptionSummary(listingId: 'listing-2')]),
        ],
      );
      final scheduler = _FakeDecisionScheduler();
      final container = _container(source: source, scheduler: scheduler);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();

      await notifier.skipCurrentWithUndo();

      expect(source.queries.last.cursor, 'opaque-next');
      expect(source.decisionCalls, isEmpty);
      expect(
        container.read(adoptionDeckProvider).currentListing?.listingId,
        'listing-2',
      );
      expect(container.read(adoptionDeckProvider).pendingSkip, isNotNull);

      expect(notifier.undoLastSkip(), isTrue);
      expect(
        container
            .read(adoptionDeckProvider)
            .items
            .map((listing) => listing.listingId),
        ['listing-1', 'listing-2'],
      );
    },
  );

  test('failed skip restores card and retry reuses idempotency key', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
      decisionErrors: [
        const AdoptionApiException('Mạng đang gián đoạn.'),
        null,
      ],
    );
    final scheduler = _FakeDecisionScheduler();
    final container = _container(source: source, scheduler: scheduler);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    await notifier.skipCurrentWithUndo();
    await scheduler.fireLatest();

    expect(
      container.read(adoptionDeckProvider).currentListing?.listingId,
      'listing-1',
    );
    expect(
      container.read(adoptionDeckProvider).message,
      'Mạng đang gián đoạn.',
    );

    await notifier.skipCurrentWithUndo();
    await scheduler.fireLatest();

    expect(source.decisionCalls, hasLength(2));
    expect(source.decisionCalls.map((call) => call.idempotencyKey).toSet(), {
      'skip-listing-1-key',
    });
    expect(container.read(adoptionDeckProvider).items, isEmpty);
  });

  test('like writes immediately and advances the deck', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(
          items: [
            adoptionSummary(listingId: 'listing-1'),
            adoptionSummary(listingId: 'listing-2'),
          ],
        ),
      ],
    );
    final container = _container(source: source);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    final liked = await notifier.likeCurrent();

    expect(liked?.listingId, 'listing-1');
    expect(source.decisionCalls.single.decision, AdoptionDecision.like);
    expect(source.decisionCalls.single.idempotencyKey, 'like-listing-1-key');
    expect(
      container.read(adoptionDeckProvider).currentListing?.listingId,
      'listing-2',
    );
  });

  test(
    'failed like keeps the current card and exposes the safe message',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
        ],
        decisionErrors: [
          const AdoptionApiException('Chưa thể ghi nhận quan tâm.'),
        ],
      );
      final container = _container(source: source);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();

      expect(await notifier.likeCurrent(), isNull);

      final state = container.read(adoptionDeckProvider);
      expect(state.currentListing?.listingId, 'listing-1');
      expect(state.isDecisionPending, isFalse);
      expect(state.message, 'Chưa thể ghi nhận quan tâm.');
    },
  );

  test(
    'like preloads the next cursor when the visible page is empty',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(
            items: [adoptionSummary(listingId: 'listing-1')],
            nextCursor: 'opaque-next',
            hasMore: true,
          ),
          adoptionPage(items: [adoptionSummary(listingId: 'listing-2')]),
        ],
      );
      final container = _container(source: source);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();

      await notifier.likeCurrent();

      expect(source.queries.last.cursor, 'opaque-next');
      expect(
        container.read(adoptionDeckProvider).currentListing?.listingId,
        'listing-2',
      );
      expect(
        container.read(adoptionDeckProvider).status,
        AdoptionDeckStatus.ready,
      );
    },
  );

  test('two concurrent likes produce only one backend write', () async {
    final decisionGate = Completer<void>();
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
      decisionGate: decisionGate,
    );
    final container = _container(source: source);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    final firstLike = notifier.likeCurrent();
    await Future<void>.delayed(Duration.zero);
    final secondLike = await notifier.likeCurrent();

    expect(secondLike, isNull);
    expect(source.decisionCalls, hasLength(1));
    decisionGate.complete();
    expect((await firstLike)?.listingId, 'listing-1');
    expect(source.decisionCalls, hasLength(1));
  });

  test('pending refresh serializes like and skip decisions', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
    );
    final container = _container(source: source);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();
    final refreshGate = Completer<AdoptionListingPage>();
    source._pendingPages.add(refreshGate);

    final refresh = notifier.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(adoptionDeckProvider).isRefreshing, isTrue);

    expect(await notifier.likeCurrent(), isNull);
    expect(await notifier.skipCurrentWithUndo(), isFalse);
    expect(source.decisionCalls, isEmpty);

    refreshGate.complete(
      adoptionPage(items: [adoptionSummary(listingId: 'listing-latest')]),
    );
    await refresh;
    expect(
      container.read(adoptionDeckProvider).currentListing?.listingId,
      'listing-latest',
    );
  });

  test('nearby is explicit and sends coordinates only after opt-in', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
        adoptionPage(
          items: [
            AdoptionListingSummary.fromJson(
              adoptionSummaryJson(listingId: 'listing-nearby', distanceKm: 1.2),
            ),
          ],
        ),
      ],
    );
    final location = _FakeAdoptionLocation();
    final container = _container(source: source, location: location);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);

    await notifier.initialize();
    expect(location.calls, 0);
    expect(source.queries.single.coordinates, isNull);

    await notifier.enableNearby(distanceKm: 10);

    expect(location.calls, 1);
    expect(source.queries.last.sort, AdoptionReadSort.distance);
    expect(source.queries.last.coordinates?.latitude, 10.7769);
    expect(source.queries.last.coordinates?.longitude, 106.7009);
    expect(source.queries.last.distanceKm, 10);
  });

  test('typed location failure leaves the curated deck usable', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
    );
    final location = _FakeAdoptionLocation(
      error: const AdoptionLocationException(
        AdoptionLocationFailureType.permissionDenied,
        'Chưa có quyền vị trí.',
      ),
    );
    final container = _container(source: source, location: location);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    await notifier.enableNearby();

    final state = container.read(adoptionDeckProvider);
    expect(state.currentListing?.listingId, 'listing-1');
    expect(state.filter.isNearby, isFalse);
    expect(state.isLocating, isFalse);
    expect(state.message, 'Chưa có quyền vị trí.');
  });

  test(
    'clearNearby removes coordinates and refreshes curated results',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
          adoptionPage(items: [adoptionSummary(listingId: 'listing-nearby')]),
          adoptionPage(items: [adoptionSummary(listingId: 'listing-curated')]),
        ],
      );
      final container = _container(source: source);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();
      await notifier.enableNearby();

      await notifier.clearNearby();

      final state = container.read(adoptionDeckProvider);
      expect(state.filter.isNearby, isFalse);
      expect(source.queries.last.coordinates, isNull);
      expect(source.queries.last.sort, AdoptionReadSort.curated);
      expect(state.currentListing?.listingId, 'listing-curated');
    },
  );

  test(
    'a stale location result cannot overwrite a newer species filter',
    () async {
      final locationGate = Completer<AdoptionCoordinates>();
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
          adoptionPage(items: [adoptionSummary(listingId: 'listing-cat')]),
        ],
      );
      final location = _FakeAdoptionLocation(gate: locationGate);
      final container = _container(source: source, location: location);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();

      final nearby = notifier.enableNearby();
      await Future<void>.delayed(Duration.zero);
      await notifier.applySpeciesFilter(AdoptionSpecies.cat);
      locationGate.complete(
        const AdoptionCoordinates(latitude: 10.7, longitude: 106.6),
      );
      await nearby;

      final state = container.read(adoptionDeckProvider);
      expect(state.filter.species, AdoptionSpecies.cat);
      expect(state.filter.coordinates, isNull);
      expect(state.isLocating, isFalse);
      expect(source.queries, hasLength(2));
      expect(source.queries.last.species, AdoptionSpecies.cat);
      expect(source.queries.last.sort, AdoptionReadSort.curated);
    },
  );

  test('clearNearby cancels an in-flight location result', () async {
    final locationGate = Completer<AdoptionCoordinates>();
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
    );
    final location = _FakeAdoptionLocation(gate: locationGate);
    final container = _container(source: source, location: location);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();

    final nearby = notifier.enableNearby();
    await Future<void>.delayed(Duration.zero);
    await notifier.clearNearby();
    locationGate.complete(
      const AdoptionCoordinates(latitude: 10.7, longitude: 106.6),
    );
    await nearby;

    expect(container.read(adoptionDeckProvider).filter.isNearby, isFalse);
    expect(container.read(adoptionDeckProvider).isLocating, isFalse);
    expect(source.queries, hasLength(1));
  });

  test('clearFilters resets species and nearby with one refresh', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
        adoptionPage(items: [adoptionSummary(listingId: 'listing-dog')]),
        adoptionPage(items: [adoptionSummary(listingId: 'listing-nearby')]),
        adoptionPage(items: [adoptionSummary(listingId: 'listing-reset')]),
      ],
    );
    final container = _container(source: source);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();
    await notifier.applySpeciesFilter(AdoptionSpecies.dog);
    await notifier.enableNearby();
    final callsBeforeReset = source.queries.length;

    await notifier.clearFilters();

    expect(source.queries.length, callsBeforeReset + 1);
    expect(source.queries.last.species, isNull);
    expect(source.queries.last.coordinates, isNull);
    expect(source.queries.last.sort, AdoptionReadSort.curated);
    expect(container.read(adoptionDeckProvider).filter.species, isNull);
    expect(container.read(adoptionDeckProvider).filter.isNearby, isFalse);
    expect(
      container.read(adoptionDeckProvider).currentListing?.listingId,
      'listing-reset',
    );
  });

  test(
    'Day108 applies species age and distance atomically after one location resolution',
    () async {
      final source = _FakeAdoptionSource(
        pages: [
          adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
          adoptionPage(items: [adoptionSummary(listingId: 'listing-filtered')]),
        ],
      );
      final location = _FakeAdoptionLocation();
      final container = _container(source: source, location: location);
      addTearDown(container.dispose);
      final notifier = container.read(adoptionDeckProvider.notifier);
      await notifier.initialize();

      expect(source.queries, hasLength(1));
      final applied = await notifier.applyFilterDraft(
        species: AdoptionSpecies.cat,
        ageGroup: AdoptionAgeGroup.oneToThree,
        distanceKm: 10,
      );

      expect(applied, isTrue);
      expect(location.calls, 1);
      expect(source.queries, hasLength(2));
      expect(source.queries.last.species, AdoptionSpecies.cat);
      expect(source.queries.last.ageGroup, AdoptionAgeGroup.oneToThree);
      expect(source.queries.last.distanceKm, 10);
      expect(source.queries.last.sort, AdoptionReadSort.distance);
    },
  );

  test('refresh failure retains existing cards as stale fallback', () async {
    final source = _FakeAdoptionSource(
      pages: [
        adoptionPage(items: [adoptionSummary(listingId: 'listing-1')]),
      ],
    );
    final container = _container(source: source);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);
    await notifier.initialize();
    source.listError = const AdoptionApiException('Không thể làm mới.');

    await notifier.refresh();

    final state = container.read(adoptionDeckProvider);
    expect(state.status, AdoptionDeckStatus.ready);
    expect(state.currentListing?.listingId, 'listing-1');
    expect(state.isStale, isTrue);
    expect(state.message, 'Không thể làm mới.');
    expect(state.error, isA<AdoptionApiException>());
  });

  test('an older refresh response cannot replace the latest page', () async {
    final oldPage = Completer<AdoptionListingPage>();
    final latestPage = Completer<AdoptionListingPage>();
    final source = _FakeAdoptionSource(
      pages: const [],
      pendingPages: [oldPage, latestPage],
    );
    final container = _container(source: source);
    addTearDown(container.dispose);
    final notifier = container.read(adoptionDeckProvider.notifier);

    final oldRefresh = notifier.refresh(clearItems: true);
    await Future<void>.delayed(Duration.zero);
    final latestRefresh = notifier.refresh(clearItems: true);
    await Future<void>.delayed(Duration.zero);

    latestPage.complete(
      adoptionPage(items: [adoptionSummary(listingId: 'listing-latest')]),
    );
    await latestRefresh;
    oldPage.complete(
      adoptionPage(items: [adoptionSummary(listingId: 'listing-old')]),
    );
    await oldRefresh;

    expect(
      container.read(adoptionDeckProvider).currentListing?.listingId,
      'listing-latest',
    );
  });
}

ProviderContainer _container({
  required _FakeAdoptionSource source,
  _FakeDecisionScheduler? scheduler,
  _FakeAdoptionLocation? location,
}) {
  return ProviderContainer(
    overrides: [
      adoptionSourceProvider.overrideWith((ref) => source),
      adoptionAccessTokenProvider.overrideWith(
        (ref) => Future<String?>.value('test-token'),
      ),
      adoptionLocationSourceProvider.overrideWith(
        (ref) => location ?? _FakeAdoptionLocation(),
      ),
      adoptionDecisionSchedulerProvider.overrideWith(
        (ref) => (scheduler ?? _FakeDecisionScheduler()).schedule,
      ),
      adoptionIdempotencyKeyFactoryProvider.overrideWith(
        (ref) => (decision, listingId, timestamp, sequence) {
          return '${decision.wireValue}-$listingId-key';
        },
      ),
      adoptionClockProvider.overrideWith(
        (ref) =>
            () => DateTime.utc(2026, 7, 28, 4),
      ),
    ],
  );
}

class _DecisionCall {
  const _DecisionCall({
    required this.listingId,
    required this.decision,
    required this.accessToken,
    required this.idempotencyKey,
  });

  final String listingId;
  final AdoptionDecision decision;
  final String accessToken;
  final String idempotencyKey;
}

class _FakeAdoptionSource implements AdoptionSource {
  _FakeAdoptionSource({
    required List<AdoptionListingPage> pages,
    List<Object?> decisionErrors = const [],
    List<Completer<AdoptionListingPage>> pendingPages = const [],
    this.decisionGate,
  }) : _pages = [...pages],
       _decisionErrors = [...decisionErrors],
       _pendingPages = [...pendingPages];

  final List<AdoptionListingPage> _pages;
  final List<Object?> _decisionErrors;
  final List<Completer<AdoptionListingPage>> _pendingPages;
  final Completer<void>? decisionGate;
  final List<AdoptionListQuery> queries = [];
  final List<_DecisionCall> decisionCalls = [];
  Object? listError;

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) async {
    queries.add(query);
    if (listError != null) throw listError!;
    if (_pendingPages.isNotEmpty) {
      return _pendingPages.removeAt(0).future;
    }
    if (_pages.isEmpty) return adoptionPage(items: const []);
    return _pages.removeAt(0);
  }

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) async {
    return adoptionDetail(listingId: listingId);
  }

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) async {
    decisionCalls.add(
      _DecisionCall(
        listingId: listingId,
        decision: decision,
        accessToken: accessToken,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (_decisionErrors.isNotEmpty) {
      final error = _decisionErrors.removeAt(0);
      if (error != null) throw error;
    }
    if (decisionGate != null) {
      await decisionGate!.future;
    }
    return adoptionDecisionResult(listingId: listingId, decision: decision);
  }
}

class _FakeAdoptionLocation implements AdoptionLocationSource {
  _FakeAdoptionLocation({this.gate, this.error});

  final Completer<AdoptionCoordinates>? gate;
  final Object? error;
  int calls = 0;

  @override
  Future<AdoptionCoordinates> resolveCurrentLocation() async {
    calls += 1;
    if (error != null) throw error!;
    if (gate != null) return gate!.future;
    return const AdoptionCoordinates(latitude: 10.7769, longitude: 106.7009);
  }
}

class _ScheduledDecision {
  _ScheduledDecision(this.action);

  final Future<void> Function() action;
  bool cancelled = false;
}

class _FakeDecisionScheduler {
  final List<_ScheduledDecision> tasks = [];

  AdoptionCancelScheduled schedule(
    Duration delay,
    Future<void> Function() action,
  ) {
    final task = _ScheduledDecision(action);
    tasks.add(task);
    return () => task.cancelled = true;
  }

  Future<void> fireLatest() async {
    final task = tasks.last;
    if (!task.cancelled) await task.action();
  }

  Future<void> fireAll() async {
    for (final task in tasks) {
      if (!task.cancelled) await task.action();
    }
  }
}

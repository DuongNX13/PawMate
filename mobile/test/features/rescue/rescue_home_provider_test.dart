import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';

import 'rescue_test_fixtures.dart';

void main() {
  test(
    'loads exactly five recent cases and retains opaque pagination',
    () async {
      final source = FakeRescueSource(
        pages: [
          samplePage(
            items: sampleCases(),
            nextCursor: 'opaque-cursor',
            hasMore: true,
          ),
          samplePage(
            items: [
              sampleCases().first,
              rescueCase(
                caseId: '55555555-5555-4555-8555-555555555555',
                petName: 'Nâu',
                species: RescueSpecies.dog,
                status: RescueCaseStatus.missing,
                areaLabel: 'Q. 1',
                breedOrColor: 'Corgi',
              ),
            ],
          ),
        ],
      );
      final container = _container(source);
      addTearDown(container.dispose);

      final notifier = container.read(rescueHomeProvider.notifier);
      await notifier.initialize();
      expect(container.read(rescueHomeProvider).items, hasLength(3));
      expect(source.queries.single.limit, 5);
      expect(source.queries.single.sort, RescueCaseSort.recent);

      await notifier.loadMore();
      final state = container.read(rescueHomeProvider);
      expect(state.items.map((item) => item.petName), [
        'LuLu',
        'Mực',
        'Bông',
        'Nâu',
      ]);
      expect(source.queries[1].cursor, 'opaque-cursor');
    },
  );

  test('filter invalidates cursor and sends the exact new filter', () async {
    final source = FakeRescueSource(
      pages: [
        samplePage(nextCursor: 'old-cursor', hasMore: true),
        samplePage(items: [sampleCases()[1]]),
      ],
    );
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(rescueHomeProvider.notifier);

    await notifier.initialize();
    await notifier.applyFilter(RescueHomeFilter.cats);

    final state = container.read(rescueHomeProvider);
    expect(state.filter, RescueHomeFilter.cats);
    expect(state.items.single.petName, 'Mực');
    expect(source.queries.last.species, RescueSpecies.cat);
    expect(source.queries.last.cursor, isNull);
  });

  test('refresh failure keeps rendered cases and marks them stale', () async {
    final source = _FailAfterFirstSource(samplePage());
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(rescueHomeProvider.notifier);

    await notifier.initialize();
    await notifier.refresh();

    final state = container.read(rescueHomeProvider);
    expect(state.status, RescueHomeLoadStatus.ready);
    expect(state.isStale, isTrue);
    expect(state.items, hasLength(3));
    expect(state.message, contains('Mạng'));
  });

  test('late response from an older request generation is ignored', () async {
    final first = Completer<RescueCasePage>();
    final source = _GenerationSource(first);
    final container = _container(source);
    addTearDown(container.dispose);
    final notifier = container.read(rescueHomeProvider.notifier);

    final initial = notifier.initialize();
    await Future<void>.delayed(Duration.zero);
    final filtered = notifier.applyFilter(RescueHomeFilter.found);
    await filtered;
    expect(container.read(rescueHomeProvider).items.single.petName, 'Bông');

    first.complete(samplePage(items: [sampleCases().first]));
    await initial;
    expect(container.read(rescueHomeProvider).items.single.petName, 'Bông');
  });
}

ProviderContainer _container(RescueCaseSource source) {
  final container = ProviderContainer(
    overrides: [
      rescueApiProvider.overrideWithValue(source),
      rescueClockProvider.overrideWithValue(fixedRescueClock()),
    ],
  );
  container.listen(rescueHomeProvider, (_, _) {});
  return container;
}

class _FailAfterFirstSource implements RescueCaseSource {
  _FailAfterFirstSource(this.page);

  final RescueCasePage page;
  int calls = 0;

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    calls += 1;
    if (calls == 1) return page;
    throw const RescueApiException('Mạng tạm thời không ổn định.');
  }
}

class _GenerationSource implements RescueCaseSource {
  _GenerationSource(this.first);

  final Completer<RescueCasePage> first;
  int calls = 0;

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) {
    calls += 1;
    if (calls == 1) return first.future;
    return Future.value(samplePage(items: [sampleCases()[2]]));
  }
}

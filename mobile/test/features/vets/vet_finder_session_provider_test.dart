import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/features/vets/application/vet_finder_session_provider.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';

void main() {
  const vet = VetSummary(
    id: 'vet-1',
    name: 'PetCare Elite',
    city: 'TP Hồ Chí Minh',
    district: 'Quận 1',
    address: '128 Nguyễn Huệ',
    phone: '0903111222',
    services: ['Cấp cứu 24/7'],
    seedRank: 1,
    averageRating: 4.9,
    reviewCount: 124,
    is24h: true,
    isOpen: true,
    readyForMap: true,
    latitude: 10.778,
    longitude: 106.701,
  );

  test('keeps the shared search contract and presentation state together', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(vetFinderSessionProvider.notifier);

    notifier.setQuery('PetCare');
    notifier.setCity('TP Hồ Chí Minh');
    notifier.toggleOnly24h();
    notifier.toggleRating4Plus();
    notifier.storeDataset(
      items: const [vet],
      total: 1,
      source: VetFinderDatasetSource.search,
      nextCursor: 'next',
    );
    notifier.selectVet(vet.vetId);
    notifier.rememberListScrollOffset(420);

    final state = container.read(vetFinderSessionProvider);
    final request = state.buildSearchRequest();
    expect(request.keyword, 'PetCare');
    expect(request.city, 'TP Hồ Chí Minh');
    expect(request.only24h, isTrue);
    expect(request.minRating, 4);
    expect(state.items.single.vetId, vet.vetId);
    expect(state.nextCursor, 'next');
    expect(state.selectedVetId, vet.vetId);
    expect(state.listScrollOffset, 420);
  });

  test('appends a search page without losing the selected clinic', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(vetFinderSessionProvider.notifier);
    notifier.storeDataset(
      items: const [vet],
      total: 2,
      source: VetFinderDatasetSource.search,
    );
    notifier.selectVet(vet.vetId);

    notifier.appendSearchPage(
      const VetSearchResult(
        items: [
          VetSummary(
            id: 'vet-2',
            name: 'Happy Paws',
            city: 'Hà Nội',
            district: 'Ba Đình',
            address: '12 Tràng Thi',
            phone: '0903222333',
            services: ['Khám tổng quát'],
            seedRank: 2,
            averageRating: 4.7,
            reviewCount: 80,
            isOpen: true,
            readyForMap: true,
          ),
        ],
        nextCursor: null,
        total: 2,
        limit: 20,
      ),
    );

    final state = container.read(vetFinderSessionProvider);
    expect(
      state.items.map((item) => item.vetId),
      containsAll(['vet-1', 'vet-2']),
    );
    expect(state.selectedVetId, 'vet-1');
    expect(state.nextCursor, isNull);
  });
}

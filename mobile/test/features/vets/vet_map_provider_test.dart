import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';

void main() {
  test(
    'returns permission denied state when location permission is missing',
    () async {
      final container = ProviderContainer(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi()),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.permissionDenied(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(vetMapProvider.notifier)
          .refresh(forceLocationRefresh: true);

      final state = container.read(vetMapProvider);
      expect(state.status, VetMapStatus.permissionDenied);
      expect(state.message, contains('quyền vị trí'));
    },
  );

  test('returns location disabled state when device location is off', () async {
    final container = ProviderContainer(
      overrides: [
        vetApiProvider.overrideWith((ref) => _FakeVetApi()),
        vetLocationServiceProvider.overrideWith(
          (ref) => _FakeLocationService.serviceDisabled(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(vetMapProvider.notifier)
        .refresh(forceLocationRefresh: true);

    final state = container.read(vetMapProvider);
    expect(state.status, VetMapStatus.locationServicesDisabled);
    expect(state.message, contains('dịch vụ vị trí'));
  });

  test('returns empty state when nearby API has no clinics', () async {
    final container = ProviderContainer(
      overrides: [
        vetApiProvider.overrideWith(
          (ref) => _FakeVetApi(nearbyItems: const []),
        ),
        vetLocationServiceProvider.overrideWith(
          (ref) => _FakeLocationService.success(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(vetMapProvider.notifier)
        .refresh(forceLocationRefresh: true);

    final state = container.read(vetMapProvider);
    expect(state.status, VetMapStatus.empty);
    expect(state.center?.latitude, 10.7769);
    expect(state.items, isEmpty);
  });

  test('loads nearby clinics and updates radius on selection', () async {
    final fakeApi = _FakeVetApi(
      nearbyItems: const [
        VetSummary(
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
          distanceMeters: 180,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        vetApiProvider.overrideWith((ref) => fakeApi),
        vetLocationServiceProvider.overrideWith(
          (ref) => _FakeLocationService.success(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(vetMapProvider.notifier)
        .refresh(forceLocationRefresh: true);
    await container.read(vetMapProvider.notifier).selectRadius(5000);

    final state = container.read(vetMapProvider);
    expect(state.status, VetMapStatus.ready);
    expect(state.items, hasLength(1));
    expect(fakeApi.nearbyRequests.first.radiusMeters, 3000);
    expect(fakeApi.nearbyRequests.last.radiusMeters, 5000);
  });

  test('returns error state when nearby API throws', () async {
    final container = ProviderContainer(
      overrides: [
        vetApiProvider.overrideWith(
          (ref) => _FakeVetApi(
            nearbyError: const VetApiException('Nearby service failed'),
          ),
        ),
        vetLocationServiceProvider.overrideWith(
          (ref) => _FakeLocationService.success(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(vetMapProvider.notifier)
        .refresh(forceLocationRefresh: true);

    final state = container.read(vetMapProvider);
    expect(state.status, VetMapStatus.error);
    expect(state.message, 'Nearby service failed');
  });
}

class _FakeVetApi extends VetApi {
  _FakeVetApi({this.nearbyItems = const [], this.nearbyError}) : super(Dio());

  final List<VetSummary> nearbyItems;
  final VetApiException? nearbyError;
  final List<VetNearbyRequest> nearbyRequests = [];

  @override
  Future<VetNearbyResult> nearby(VetNearbyRequest request) async {
    nearbyRequests.add(request);
    if (nearbyError != null) {
      throw nearbyError!;
    }

    return VetNearbyResult(
      items: nearbyItems,
      total: nearbyItems.length,
      limit: request.limit,
    );
  }
}

class _FakeLocationService implements VetLocationService {
  _FakeLocationService._({required this.location, required this.error});

  factory _FakeLocationService.success() {
    return _FakeLocationService._(
      location: const VetMapLocation(latitude: 10.7769, longitude: 106.7009),
      error: null,
    );
  }

  factory _FakeLocationService.permissionDenied() {
    return _FakeLocationService._(
      location: null,
      error: const VetLocationException(
        VetLocationFailureType.permissionDenied,
        'PawMate chưa được cấp quyền vị trí.',
      ),
    );
  }

  factory _FakeLocationService.serviceDisabled() {
    return _FakeLocationService._(
      location: null,
      error: const VetLocationException(
        VetLocationFailureType.serviceDisabled,
        'Thiết bị đang tắt dịch vụ vị trí.',
      ),
    );
  }

  final VetMapLocation? location;
  final VetLocationException? error;

  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    if (error != null) {
      throw error!;
    }
    return location!;
  }
}

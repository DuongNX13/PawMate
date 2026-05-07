import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_preview_sheet.dart';

void main() {
  testWidgets('shows permission denied state on map screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi()),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.permissionDenied(),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
    expect(find.textContaining('quyền vị trí'), findsWidgets);
  });

  testWidgets('shows location disabled state on map screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi()),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.serviceDisabled(),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thiết bị đang tắt định vị'), findsOneWidget);
    expect(find.textContaining('dịch vụ vị trí'), findsWidgets);
  });

  testWidgets('opens preview sheet when marker is tapped', (tester) async {
    final items = const [
      VetSummary(
        id: 'vet-1',
        name: 'PetCare Elite',
        city: 'TP Hồ Chí Minh',
        district: 'Quận 1',
        address: '128 Nguyễn Huệ',
        phone: '0903111222',
        services: ['Cấp cứu 24/7', 'Tiêm phòng'],
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
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi(nearbyItems: items)),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.success(),
          ),
          vetMapCanvasBuilderProvider.overrideWith(
            (ref) =>
                (
                  VetMapLocation center,
                  List<VetSummary> vets,
                  VetMapStyle mapStyle,
                  ValueChanged<String> onMarkerTap,
                ) {
                  return Column(
                    children: [
                      Text('fake-map:${vets.length}'),
                      for (final vet in vets)
                        TextButton(
                          key: Key('marker-${vet.id}'),
                          onPressed: () => onMarkerTap(vet.id),
                          child: Text(vet.name),
                        ),
                    ],
                  );
                },
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fake-map:1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('marker-vet-1')));
    await tester.pumpAndSettle();

    expect(find.text('Xem chi tiết'), findsOneWidget);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expect(find.text('Chỉ đường'), findsOneWidget);
    expect(find.text('PetCare Elite'), findsWidgets);
    expect(find.text('180 m'), findsOneWidget);
  });

  testWidgets('shows empty nearby state with map canvas', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi()),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.success(),
          ),
          vetMapCanvasBuilderProvider.overrideWith(
            (ref) =>
                (
                  VetMapLocation center,
                  List<VetSummary> vets,
                  VetMapStyle mapStyle,
                  ValueChanged<String> onMarkerTap,
                ) => Text('fake-map:${vets.length}'),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fake-map:0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Empty'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('shows API error state when nearby request fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith(
            (ref) => _FakeVetApi(
              nearbyError: const VetApiException('Nearby failed'),
            ),
          ),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.success(),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nearby failed'), findsOneWidget);
  });

  testWidgets('updates radius and forwards map type to map canvas', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => fakeApi),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.success(),
          ),
          vetMapCanvasBuilderProvider.overrideWith(
            (ref) =>
                (
                  VetMapLocation center,
                  List<VetSummary> vets,
                  VetMapStyle mapStyle,
                  ValueChanged<String> onMarkerTap,
                ) => Text('fake-map-style:${mapStyle.name}'),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fake-map-style:standard'), findsOneWidget);
    expect(fakeApi.nearbyRequests.single.radiusMeters, 3000);

    await tester.tap(find.text('5 km'));
    await tester.pumpAndSettle();

    expect(fakeApi.nearbyRequests.last.radiusMeters, 5000);

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();

    expect(find.text('fake-map-style:night'), findsOneWidget);
  });

  testWidgets('preview sheet action callbacks are individually tappable', (
    tester,
  ) async {
    var detailTapped = false;
    var directionsTapped = false;
    var callTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VetPreviewSheet(
            vet: const VetSummary(
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
            onViewDetail: () => detailTapped = true,
            onGetDirections: () => directionsTapped = true,
            onCallNow: () => callTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Xem chi tiết'));
    await tester.tap(find.text('Chỉ đường'));
    await tester.tap(find.text('Gọi ngay'));

    expect(detailTapped, isTrue);
    expect(directionsTapped, isTrue);
    expect(callTapped, isTrue);
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

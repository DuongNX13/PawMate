import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_preview_sheet.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('shows permission denied state on map screen', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));

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
    await setTestViewport(tester, size: const Size(390, 844));

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
    await setTestViewport(tester, size: const Size(390, 844));

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
                  ValueChanged<Object> onMapUnavailable,
                ) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('fake-map:${vets.length}'),
                        for (final vet in vets)
                          TextButton(
                            key: Key('marker-${vet.id}'),
                            onPressed: () => onMarkerTap(vet.id),
                            child: Text(vet.name),
                          ),
                      ],
                    ),
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
    expect(find.text('Gọi ngay'), findsWidgets);
    expect(find.text('Chỉ đường'), findsWidgets);
    expect(find.text('PetCare Elite'), findsWidgets);
    expect(find.text('180 m'), findsWidgets);
  });

  testWidgets('shows empty nearby state with map canvas', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));

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
                  ValueChanged<Object> onMapUnavailable,
                ) => Text('fake-map:${vets.length}'),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fake-map:0'), findsOneWidget);
    expect(find.text('Trống'), findsOneWidget);
  });

  testWidgets('shows API error state when nearby request fails', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

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

  testWidgets('falls back to Hanoi when location lookup times out', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

    final fakeApi = _FakeVetApi(
      nearbyItems: const [
        VetSummary(
          id: 'vet-1',
          name: 'PetCare Elite',
          city: 'Hà Nội',
          district: 'Tây Hồ',
          address: '83 Nghi Tàm',
          phone: '02471069906',
          services: ['Khám tổng quát'],
          seedRank: 1,
          averageRating: 4.6,
          reviewCount: 42,
          is24h: false,
          isOpen: true,
          readyForMap: true,
          latitude: 21.05,
          longitude: 105.83,
          distanceMeters: 900,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => fakeApi),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.timeout(),
          ),
          vetMapCanvasBuilderProvider.overrideWith(
            (ref) =>
                (
                  VetMapLocation center,
                  List<VetSummary> vets,
                  VetMapStyle mapStyle,
                  ValueChanged<String> onMarkerTap,
                  ValueChanged<Object> onMapUnavailable,
                ) => Text(
                  'fake-map:${center.latitude},${center.longitude}:${vets.length}',
                ),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fake-map:21.0278,105.8342:1'), findsOneWidget);
    expect(fakeApi.nearbyRequests.single.latitude, 21.0278);
    expect(fakeApi.nearbyRequests.single.longitude, 105.8342);
  });

  testWidgets('updates radius and forwards map type to map canvas', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(600, 900));

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
                  ValueChanged<Object> onMapUnavailable,
                ) => Text('fake-map-style:${mapStyle.name}'),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fake-map-style:standard'), findsOneWidget);
    expect(fakeApi.nearbyRequests.single.radiusMeters, 3000);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-180, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('vet-map-filter-5km')));
    await tester.pumpAndSettle();

    expect(fakeApi.nearbyRequests.last.radiusMeters, 5000);

    await tester.tap(find.byKey(const Key('vet-map-style-toggle-button')));
    await tester.pumpAndSettle();

    expect(find.text('fake-map-style:night'), findsOneWidget);
  });

  testWidgets('nearby map filter chips update API query flags', (tester) async {
    await setTestViewport(tester, size: const Size(600, 900));

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
                  ValueChanged<Object> onMapUnavailable,
                ) => Text('fake-map:${vets.length}'),
          ),
        ],
        child: const MaterialApp(home: VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeApi.nearbyRequests.single.only24h, isFalse);
    expect(fakeApi.nearbyRequests.single.openNow, isFalse);
    expect(fakeApi.nearbyRequests.single.minRating, isNull);
    expect(find.textContaining('Day 3'), findsNothing);

    await tester.tap(find.byKey(const Key('vet-map-filter-24h')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vet-map-filter-open-now')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-500, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('vet-map-filter-rating-4')));
    await tester.pumpAndSettle();

    final lastRequest = fakeApi.nearbyRequests.last;
    expect(lastRequest.only24h, isTrue);
    expect(lastRequest.openNow, isTrue);
    expect(lastRequest.minRating, 4);
  });

  testWidgets(
    'shows map unavailable state while keeping list fallback visible',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vetApiProvider.overrideWith(
              (ref) => _FakeVetApi(nearbyItems: const []),
            ),
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
                    ValueChanged<Object> onMapUnavailable,
                  ) => TextButton(
                    key: const Key('fake-map-unavailable'),
                    onPressed: () => onMapUnavailable(Exception('tile error')),
                    child: const Text('fake-map-fail'),
                  ),
            ),
          ],
          child: const MaterialApp(home: VetMapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fake-map-unavailable')));
      await tester.pumpAndSettle();

      expect(find.text('Bản đồ đang tạm gián đoạn'), findsOneWidget);
      expect(find.text('Không hiển thị được bản đồ'), findsOneWidget);
      expect(find.text('Xem dạng danh sách'), findsOneWidget);
    },
  );

  testWidgets('renders compact Chocomint map shell without clipped filters', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

    final items = const [
      VetSummary(
        id: 'vet-long',
        name: 'PetHome Q7 Phòng khám thú y chăm sóc toàn diện',
        city: 'TP Hồ Chí Minh',
        district: 'Quận 7',
        address: '120 Nguyễn Lương Bằng, Phú Mỹ, Quận 7',
        phone: '0903111222',
        services: ['Cấp cứu 24/7', 'Tiêm phòng'],
        seedRank: 1,
        averageRating: 4.8,
        reviewCount: 120,
        is24h: true,
        isOpen: true,
        readyForMap: true,
        latitude: 10.778,
        longitude: 106.701,
        distanceMeters: 1200,
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
                  ValueChanged<Object> onMapUnavailable,
                ) => const ColoredBox(
                  color: Color(0xFFEDE6DA),
                  child: Center(child: Text('fake-map-proof')),
                ),
          ),
        ],
        child: MaterialApp(
          builder: testTextScaleBuilder(1.1),
          home: const VetMapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PawMate'), findsOneWidget);
    expect(find.text('Tìm phòng khám, bác sĩ...'), findsOneWidget);
    expect(find.text('Gần nhất'), findsOneWidget);
    expect(find.byKey(const Key('vet-map-filter-5km')), findsNothing);
    expect(find.byKey(const Key('vet-map-filter-rating-4')), findsNothing);
    expect(find.text('Bật định vị để tìm phòng khám gần nhất'), findsOneWidget);
    final enableLocation = find.widgetWithText(TextButton, 'Bật ngay');
    expect(enableLocation, findsOneWidget);
    expect(tester.getSize(enableLocation).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Ảnh đại diện thú cưng Kem'), findsOneWidget);
    expect(find.textContaining('PetHome Q7'), findsOneWidget);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expect(find.text('Chỉ đường'), findsOneWidget);
    expect(find.text('Chi tiết'), findsOneWidget);
    for (final label in [
      'Cấp cứu 24/7',
      'Tiêm phòng',
      'Gọi ngay',
      'Chỉ đường',
      'Chi tiết',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(label).first,
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label must remain fully legible on the compact map sheet',
      );
    }
    expect(find.text('Vet'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('preview sheet action callbacks are individually tappable', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

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

  factory _FakeLocationService.timeout() {
    return _FakeLocationService._(
      location: null,
      error: const VetLocationException(
        VetLocationFailureType.timeout,
        'Location timed out.',
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

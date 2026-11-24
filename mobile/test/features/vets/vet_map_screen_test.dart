import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_preview_sheet.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day115_capture.dart';

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
        child: MaterialApp(theme: AppTheme.light(), home: const VetMapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
    expect(find.textContaining('quyền vị trí'), findsWidgets);
    await captureDay115(tester, 'ST-15');
    await tester.tap(find.widgetWithText(TextButton, 'Bật ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
  });

  // D122-TB-P2-004/007: on a 360x800 phone at 2x text the banner covered the
  // first card and the denied panel clipped "Xem dạng danh sách".
  testWidgets('D124 denied map at 360x800 text 2 uses the scroll flow', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vetApiProvider.overrideWith((ref) => _FakeVetApi()),
          vetLocationServiceProvider.overrideWith(
            (ref) => _FakeLocationService.permissionDenied(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: const VetMapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vet-map-accessible-flow')), findsOneWidget);
    final listAction = find.text('Xem dạng danh sách').first;
    await tester.ensureVisible(listAction);
    await tester.pumpAndSettle();
    expect(listAction.hitTestable(), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  // D122-VIS-003: the map-unavailable title was squeezed to ~9px in the 160pt
  // map strip on a 360x800 phone at 2x text.
  testWidgets('D124 unavailable map strip stays decorative at text 2', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
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
                ) => const ColoredBox(color: Color(0xFFEDE6DA)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: const VetMapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(VetMapScreen)),
    ).read(vetMapProvider.notifier).markMapUnavailable();
    await tester.pumpAndSettle();

    final titles = find.text('Bản đồ đang tạm gián đoạn', skipOffstage: false);
    for (final element in titles.evaluate()) {
      final box = element.renderObject! as RenderBox;
      expect(box.size.height, greaterThan(20));
    }
    expectNoFlutterOverflow(tester);
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

  testWidgets('keeps the default map radius and forwards map type to canvas', (
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

    expect(find.byKey(const Key('vet-map-filter-5km')), findsNothing);
    expect(fakeApi.nearbyRequests.last.radiusMeters, 3000);

    await tester.tap(find.byKey(const Key('vet-map-style-toggle-button')));
    await tester.pumpAndSettle();

    expect(find.text('fake-map-style:night'), findsOneWidget);
  });

  testWidgets('approved map anchor omits advanced filters', (tester) async {
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

    expect(find.byKey(const Key('vet-map-filter-24h')), findsNothing);
    expect(find.byKey(const Key('vet-map-filter-open-now')), findsNothing);
    expect(find.byKey(const Key('vet-map-filter-rating-4')), findsNothing);
    expect(fakeApi.nearbyRequests, hasLength(1));
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

  testWidgets(
    'ST-23 keeps map-unavailable recovery actions reachable at text scale 2.0',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));

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
                  ) => const ColoredBox(color: Color(0xFFEDE6DA)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const VetMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(VetMapScreen)),
      );
      providerContainer.read(vetMapProvider.notifier).markMapUnavailable();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('map-unavailable')),
        220,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('vet-map-accessible-flow')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
      await tester.ensureVisible(find.text('Tải lại bản đồ'));
      await tester.ensureVisible(find.text('Xem dạng danh sách'));
      expect(
        tester.getSize(find.text('Tải lại bản đồ')).height,
        greaterThan(0),
      );
      await captureDay115(tester, 'ST-23');
      await tester.ensureVisible(find.text('Tải lại bản đồ'));
      await tester.pumpAndSettle();
      expect(find.text('Tải lại bản đồ').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Tải lại bản đồ'));
      await tester.pumpAndSettle();
      expect(providerContainer.read(vetMapProvider).mapUnavailable, isFalse);
      expect(providerContainer.read(vetMapProvider).mapReloadToken, 1);
      expectNoFlutterOverflow(tester);
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
    expect(find.text('Gần nhất'), findsNothing);
    expect(find.byKey(const Key('vet-map-filter-5km')), findsNothing);
    expect(find.byKey(const Key('vet-map-filter-rating-4')), findsNothing);
    expect(find.text('Bật định vị để tìm phòng khám gần nhất'), findsOneWidget);
    final searchShell = tester.getSize(
      find.byKey(const Key('vet-map-search-shell')),
    );
    expect(searchShell.height, greaterThanOrEqualTo(48));
    expect(searchShell.height, lessThanOrEqualTo(52));
    final enableLocation = find.widgetWithText(TextButton, 'Bật ngay');
    expect(enableLocation, findsOneWidget);
    expect(tester.getSize(enableLocation).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Ảnh đại diện thú cưng Kem'), findsOneWidget);
    expect(find.textContaining('PetHome Q7'), findsOneWidget);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expect(find.text('Chỉ đường'), findsOneWidget);
    expect(find.byKey(const Key('vet-map-info-button')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Hình minh họa phòng khám thú y'),
      findsOneWidget,
    );
    for (final label in ['Gọi ngay', 'Chỉ đường']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(label).first,
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label must remain fully legible on the compact map sheet',
      );
    }
    expect(find.byTooltip('Vet'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'compact clinic card remains readable at accessibility text scale',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await setTestViewport(tester, size: const Size(390, 844));

      const items = [
        VetSummary(
          id: 'vet-accessible-chip',
          name: 'PetHome Q7',
          city: 'TP Hồ Chí Minh',
          district: 'Quận 7',
          address: '120 Nguyễn Lương Bằng',
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
            vetApiProvider.overrideWith(
              (ref) => _FakeVetApi(nearbyItems: items),
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
                  ) => const ColoredBox(color: Color(0xFFEDE6DA)),
            ),
          ],
          child: MaterialApp(
            builder: testTextScaleBuilder(2),
            home: const VetMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('PawMate'), findsOneWidget);
      final locationBannerText = find.text(
        'Bật định vị để tìm phòng khám gần nhất',
      );
      expect(locationBannerText, findsOneWidget);
      expect(
        tester
            .renderObject<RenderParagraph>(locationBannerText)
            .didExceedMaxLines,
        isFalse,
        reason:
            'location-permission guidance must not be truncated at accessibility text sizes',
      );
      final locationBanner = find.byKey(const Key('vet-map-location-banner'));
      final enableLocation = find.widgetWithText(TextButton, 'Bật ngay');
      expect(tester.getSize(enableLocation).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getRect(locationBanner)
            .contains(tester.getRect(enableLocation).center),
        isTrue,
      );
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('00:00–24:00'), findsOneWidget);
      expect(find.byKey(const Key('vet-map-info-button')), findsOneWidget);
      expect(find.text('Gọi ngay'), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);
      expectNoFlutterOverflow(tester);
      semantics.dispose();
    },
  );

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

  testWidgets(
    'preview sheet keeps long clinic details and actions readable at text scale 2.0',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));

      const longService =
          'Diagnostics, inpatient treatment, and 24-hour emergency pet care service';
      var directionsTapped = false;
      var callTapped = false;

      const clinicName = 'Bệnh viện thú y chăm sóc thú cưng chuyên sâu Sài Gòn';
      const clinicAddress =
          '123 Đường Nguyễn Văn Linh, Phường Tân Phong, Quận 7, Thành phố Hồ Chí Minh';

      await tester.pumpWidget(
        MaterialApp(
          builder: testTextScaleBuilder(2),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => VetPreviewSheet(
                      vet: const VetSummary(
                        id: 'vet-long',
                        name: clinicName,
                        city: 'Thành phố Hồ Chí Minh',
                        district: 'Quận 7',
                        address: clinicAddress,
                        phone: '0903111222',
                        services: <String>[
                          longService,
                          'Khám nội tổng quát',
                          'Tiêm phòng định kỳ',
                          'Cấp cứu thú cưng 24/7',
                        ],
                        seedRank: 1,
                        averageRating: 4.9,
                        reviewCount: 124,
                        is24h: true,
                        isOpen: true,
                        readyForMap: true,
                      ),
                      onViewDetail: () {},
                      onGetDirections: () => directionsTapped = true,
                      onCallNow: () => callTapped = true,
                    ),
                  ),
                  child: const Text('Mở xem nhanh'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở xem nhanh'));
      await tester.pumpAndSettle();

      for (final text in [clinicName, clinicAddress]) {
        final finder = find.text(text);
        expect(finder, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
          reason: 'Long clinic data must remain readable at text scale 2.0.',
        );
      }

      final serviceChip = find.text(longService);
      expect(serviceChip, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(serviceChip).didExceedMaxLines,
        isTrue,
        reason: 'A non-action tag may truncate visually inside its chip.',
      );
      expect(find.bySemanticsLabel(longService), findsOneWidget);

      await tester.scrollUntilVisible(find.bySemanticsLabel('Chỉ đường'), 240);
      final directionsButton = find.bySemanticsLabel('Chỉ đường');
      final callButton = find.bySemanticsLabel('Gọi ngay');
      expect(tester.getSize(directionsButton).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(callButton).height, greaterThanOrEqualTo(48));
      await tester.tap(directionsButton);
      await tester.tap(callButton);
      expect(directionsTapped, isTrue);
      expect(callTapped, isTrue);

      expectNoFlutterOverflow(tester);
    },
  );
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

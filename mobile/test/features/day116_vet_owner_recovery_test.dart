import 'dart:ui' show SemanticsAction;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/vets/application/vet_finder_session_provider.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    final suffix = scale.toString().replaceAll('.', '-');
    for (final family in ['P1-08', 'P1-09']) {
      testWidgets(
        'D116 R16 ST-02 $family text$scale real retry restores query',
        (tester) async {
          final api = _VetSource()..fail = true;
          final location = _Location();
          final container = _container(api, location);
          addTearDown(container.dispose);
          final filters = container.read(vetFinderSessionProvider.notifier);
          filters.setQuery('phòng khám');
          filters.toggleOnly24h();
          filters.toggleRating4Plus();
          final map = family == 'P1-08';
          final router = _router(map ? '/vets/map' : '/vets/list');
          addTearDown(router.dispose);
          await _pump(tester, scale, container, router);
          final retry = map
              ? find.widgetWithText(PawMateButton, 'Thử lại')
              : find.byKey(const Key('vet-list-retry-button'));
          await _touch(tester, retry);
          expect(map ? api.nearbyCalls.length : api.searchCalls.length, 1);
          expect(find.text('Gọi ngay'), findsNothing);
          await captureDay116(tester, 'R16-ST02-$family-error-text$suffix');
          api.fail = false;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(map ? api.nearbyCalls.length : api.searchCalls.length, 2);
          expect(retry, findsNothing);
          if (map) {
            final calls = api.nearbyCalls;
            expect(
              calls.map(
                (q) => [
                  q.latitude,
                  q.longitude,
                  q.radiusMeters,
                  q.only24h,
                  q.minRating,
                ],
              ),
              everyElement([10.7769, 106.7009, 3000, true, 4.0]),
            );
            expect(location.calls, 2);
            expect(container.read(vetMapProvider).status, VetMapStatus.ready);
            expect(
              container.read(vetFinderSessionProvider).items.single.vetId,
              'r16-vet',
            );
            expect(find.text('PetHome QA'), findsOneWidget);
          } else {
            expect(api.searchCalls[0], api.searchCalls[1]);
            expect(api.searchCalls.last.keyword, 'phòng khám');
            expect(api.searchCalls.last.only24h, isTrue);
            expect(api.searchCalls.last.minRating, 4);
            expect(location.calls, 0);
            await _reach(tester, find.text('PetHome QA'));
          }
          await captureDay116(tester, 'R16-ST02-$family-ready-text$suffix');
          expectNoFlutterOverflow(tester);
        },
      );
    }
    for (final state in ['ST-06', 'UX-28']) {
      testWidgets(
        'D116 R16 $state P1-08 text$scale clear filters removes stale actions',
        (tester) async {
          final api = _VetSource();
          final location = _Location();
          final container = _container(api, location);
          addTearDown(container.dispose);
          final router = _router('/vets/map');
          addTearDown(router.dispose);
          await _pump(tester, scale, container, router);
          expect(container.read(vetMapProvider).items.single.vetId, 'r16-vet');
          container
              .read(vetFinderSessionProvider.notifier)
              .selectVet('r16-vet');
          api.emptyFiltered = true;
          final filters = container.read(vetFinderSessionProvider.notifier);
          filters.toggleOnly24h();
          filters.toggleOpenNow();
          filters.toggleRating4Plus();
          filters.setRadius(5000);
          await container.read(vetMapProvider.notifier).refresh();
          await tester.pumpAndSettle();
          expect(container.read(vetMapProvider).status, VetMapStatus.empty);
          expect(
            container.read(vetFinderSessionProvider).selectedVetId,
            isNull,
          );
          expect(find.text('PetHome QA'), findsNothing);
          expect(find.text('Gọi ngay'), findsNothing);
          expect(find.text('Chỉ đường'), findsNothing);
          expect(find.text('Xem thêm'), findsNothing);
          final clear = find.widgetWithText(PawMateButton, 'Xóa bộ lọc');
          // At text2 the production accessibility ListView builds this panel
          // lazily; reach the real scroll region before asserting its child.
          await _reach(tester, clear);
          await captureDay116(tester, 'R16-$state-P108-empty-text$suffix');
          expect(clear, findsOneWidget);
          await _touch(tester, clear);
          await tester.tap(clear);
          await tester.pumpAndSettle();
          expect(api.nearbyCalls.length, 3);
          final last = api.nearbyCalls.last;
          expect(
            [
              last.only24h,
              last.openNow,
              last.minRating,
              last.radiusMeters,
              last.cursor,
            ],
            [false, false, null, 3000, null],
          );
          expect([last.latitude, last.longitude], [10.7769, 106.7009]);
          expect(location.calls, 1);
          expect(container.read(vetMapProvider).status, VetMapStatus.ready);
          expect(
            container.read(vetFinderSessionProvider).items.single.vetId,
            'r16-vet',
          );
          expect(clear, findsNothing);
          expect(find.text('PetHome QA'), findsOneWidget);
          await captureDay116(tester, 'R16-$state-P108-restored-text$suffix');
          expectNoFlutterOverflow(tester);
        },
      );
    }
  }
}

ProviderContainer _container(_VetSource api, _Location location) =>
    ProviderContainer(
      overrides: [
        vetApiProvider.overrideWithValue(api),
        vetLocationServiceProvider.overrideWithValue(location),
        vetMapCanvasBuilderProvider.overrideWith(
          (ref) =>
              (center, vets, style, onMarkerTap, onMapUnavailable) =>
                  const ColoredBox(color: Color(0xffF8F3EA)),
        ),
      ],
    );

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/vets/map', builder: (_, _) => const VetMapScreen()),
    GoRoute(path: '/vets/list', builder: (_, _) => const VetListScreen()),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  double scale,
  ProviderContainer container,
  GoRouter router,
) async {
  await setTestViewport(tester, size: const Size(320, 568));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reach(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      130,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _touch(WidgetTester tester, Finder target) async {
  await _reach(tester, target);
  expect(target.hitTestable(), findsOneWidget);
  expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
  expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final semantics = tester.getSemantics(target).getSemanticsData();
    expect(semantics.label.trim(), isNotEmpty);
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
  } finally {
    handle.dispose();
  }
}

class _Location implements VetLocationService {
  int calls = 0;
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    calls++;
    return const VetMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

class _VetSource extends VetApi {
  _VetSource() : super(Dio());
  bool fail = false, emptyFiltered = false;
  final nearbyCalls = <VetNearbyRequest>[];
  final searchCalls = <VetSearchRequest>[];
  static const item = VetSummary(
    id: 'r16-vet',
    name: 'PetHome QA',
    city: 'Hà Nội',
    district: 'Quận 1',
    address: 'Địa chỉ fixture',
    phone: '',
    services: ['Khám tổng quát'],
    seedRank: 1,
    reviewCount: 0,
    readyForMap: true,
    latitude: 10.7769,
    longitude: 106.7009,
    distanceMeters: 200,
  );
  @override
  Future<VetNearbyResult> nearby(VetNearbyRequest request) async {
    nearbyCalls.add(request);
    if (fail) {
      throw const VetApiException('Fixture503', statusCode: 503);
    }
    final empty =
        emptyFiltered &&
        (request.only24h || request.openNow || request.minRating != null);
    return VetNearbyResult(
      items: empty ? [] : [item],
      total: empty ? 0 : 1,
      limit: 20,
    );
  }

  @override
  Future<VetSearchResult> search(VetSearchRequest request) async {
    searchCalls.add(request);
    if (fail) {
      throw const VetApiException('Fixture503', statusCode: 503);
    }
    return const VetSearchResult(items: [item], total: 1, limit: 20);
  }
}

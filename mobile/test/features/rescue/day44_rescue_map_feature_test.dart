import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/router/app_feature_availability.dart';
import 'package:pawmate_mobile/app/router/app_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_map_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_canvas.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  test(
    'permission denied keeps public list usable without geo query',
    () async {
      final source = FakeRescueSource(
        pages: [samplePage(items: sampleCasesWithoutImages())],
      );
      final container = ProviderContainer(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
          rescueLocationServiceProvider.overrideWithValue(
            _FakeRescueLocation.permissionDenied(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(rescueMapProvider.notifier).initialize();

      final state = container.read(rescueMapProvider);
      expect(state.status, RescueMapLoadStatus.ready);
      expect(state.locationStatus, RescueLocationStatus.permissionDenied);
      expect(state.items, hasLength(3));
      expect(source.queries.single.latitude, isNull);
      expect(source.queries.single.sort, RescueCaseSort.recent);
    },
  );

  test(
    'location and composite filters are encoded in the same list query',
    () async {
      final source = FakeRescueSource(
        pages: [
          samplePage(items: sampleCasesWithoutImages()),
          samplePage(items: [sampleCasesWithoutImages()[0]]),
          samplePage(items: [sampleCasesWithoutImages()[1]]),
          samplePage(items: [sampleCasesWithoutImages()[0]]),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
          rescueLocationServiceProvider.overrideWithValue(
            _FakeRescueLocation.success(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rescueMapProvider.notifier);
      await notifier.initialize();
      expect(source.queries.first.sort, RescueCaseSort.distance);
      expect(source.queries.first.latitude, 10.7769);
      expect(source.queries.first.radiusMeters, 5000);

      await notifier.selectStatus(RescueCaseStatus.missing);
      await notifier.selectSpecies(RescueSpecies.cat);
      await notifier.selectTime(RescueTimeFilter.last24Hours);

      final query = source.queries.last;
      expect(query.status, RescueCaseStatus.missing);
      expect(query.species, RescueSpecies.cat);
      expect(query.lostFrom, DateTime.utc(2026, 7, 22, 10));
      expect(query.lostTo, isNull);
      expect(query.sort, RescueCaseSort.distance);
    },
  );

  testWidgets('markers and bottom sheet share selected case state', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      pages: [samplePage(items: sampleCasesWithoutImages())],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
          rescueLocationServiceProvider.overrideWithValue(
            _FakeRescueLocation.success(),
          ),
          rescueMapCanvasBuilderProvider.overrideWithValue(
            (
              RescueMapLocation center,
              List<RescueCaseSummary> items,
              ValueChanged<String> onMarkerTap,
              ValueChanged<Object> onMapUnavailable,
            ) => ColoredBox(
              color: const Color(0xFFE9F5DB),
              child: Stack(
                children: [
                  Text('deterministic-map:${items.length}'),
                  for (var index = 0; index < items.length; index++)
                    Positioned(
                      left: 24.0 + (index * 82),
                      top: 250.0 + (index.isOdd ? 52 : 0),
                      child: TextButton(
                        key: ValueKey('marker-${items[index].caseId}'),
                        onPressed: () => onMarkerTap(items[index].caseId),
                        child: Text('Khu vực ${items[index].petName}'),
                      ),
                    ),
                  Positioned(
                    right: 16,
                    top: 370,
                    child: TextButton(
                      key: const Key('fake-map-unavailable'),
                      onPressed: () => onMapUnavailable('fixture'),
                      child: const Text('map unavailable'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const RescueMapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('deterministic-map:3'), findsOneWidget);
    expect(find.text('Gần bạn nhất (3)'), findsOneWidget);
    expect(
      find.byKey(
        const Key('rescue-marker-card-11111111-1111-4111-8111-111111111111'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('10.8'), findsNothing);

    await tester.tap(find.byKey(const Key('rescue-map-layers-button')));
    await tester.pumpAndSettle();
    expect(find.text('Lớp bản đồ'), findsOneWidget);
    expect(find.textContaining('bán kính riêng tư'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('marker-22222222-2222-4222-8222-222222222222')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đang chọn Mực'), findsOneWidget);
    expect(find.byKey(const Key('rescue-map-clear-selection')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fake-map-unavailable')));
    await tester.pumpAndSettle();
    expect(find.text('Bản đồ đang tạm gián đoạn'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'map sheet stays readable at compact viewport and large text scale',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final source = FakeRescueSource(
        pages: [samplePage(items: sampleCasesWithoutImages())],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ProviderScope(
            overrides: [
              rescueApiProvider.overrideWithValue(source),
              rescueClockProvider.overrideWithValue(fixedRescueClock()),
              rescueLocationServiceProvider.overrideWithValue(
                _FakeRescueLocation.permissionDenied(),
              ),
              rescueMapCanvasBuilderProvider.overrideWithValue(
                (
                  RescueMapLocation center,
                  List<RescueCaseSummary> items,
                  ValueChanged<String> onMarkerTap,
                  ValueChanged<Object> onMapUnavailable,
                ) => const ColoredBox(color: Color(0xFFE9F5DB)),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const RescueMapScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
      expect(find.byKey(const Key('rescue-map-sheet-scroll')), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('production router renders P2-05 when browse flag is enabled', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      pages: [samplePage(items: sampleCasesWithoutImages())],
    );
    final container = ProviderContainer(
      overrides: [
        appFeatureAvailabilityProvider.overrideWithValue(
          const AppFeatureAvailability(rescueBrowse: true, rescueCreate: true),
        ),
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue<AuthSession?>.data(_session),
        ),
        rescueApiProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
        rescueLocationServiceProvider.overrideWithValue(
          _FakeRescueLocation.success(),
        ),
        rescueMapCanvasBuilderProvider.overrideWithValue(
          (
            RescueMapLocation center,
            List<RescueCaseSummary> items,
            ValueChanged<String> onMarkerTap,
            ValueChanged<Object> onMapUnavailable,
          ) => ColoredBox(
            color: const Color(0xFFE9F5DB),
            child: Center(child: Text('route-map:${items.length}')),
          ),
        ),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    router.go('/rescue/map');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/rescue/map');
    expect(find.text('Bản đồ cứu hộ'), findsOneWidget);
    expect(find.text('route-map:3'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.tap(
      find.byKey(
        const Key('rescue-marker-select-11111111-1111-4111-8111-111111111111'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/rescue/11111111-1111-4111-8111-111111111111',
    );
    expect(find.text('Chi tiết tin báo'), findsOneWidget);
  });

  testWidgets('real map marker announces only an approximate public area', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 500));
    final item = sampleCasesWithoutImages().first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RescueRasterMapCanvas(
            center: const RescueMapLocation(
              latitude: 10.7769,
              longitude: 106.7009,
            ),
            items: [item],
            onMarkerTap: (_) {},
            onMapUnavailable: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final marker = find.bySemanticsLabel(
      'Khu vực ước tính của LuLu, Chưa thấy, Q. Tân Bình',
    );
    expect(marker, findsOneWidget);
    expect(tester.getSize(marker).width, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(RegExp(r'10\.|106\.')), findsNothing);
  });
}

const _session = AuthSession(
  user: AuthUser(
    id: 'day44-user',
    email: 'day44@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'day44-test-access',
  refreshToken: 'day44-test-refresh',
  accessTokenExpiresAt: '2026-07-28T00:00:00.000Z',
  refreshTokenExpiresAt: '2026-08-27T00:00:00.000Z',
);

class _FakeRescueLocation implements RescueLocationService {
  const _FakeRescueLocation._(this.error);

  final RescueLocationException? error;

  factory _FakeRescueLocation.success() => const _FakeRescueLocation._(null);

  factory _FakeRescueLocation.permissionDenied() => const _FakeRescueLocation._(
    RescueLocationException(
      RescueLocationFailureType.permissionDenied,
      'Chưa có quyền vị trí. Danh sách công khai vẫn dùng được.',
    ),
  );

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    if (error != null) throw error!;
    return const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

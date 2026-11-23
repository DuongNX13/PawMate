import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_map_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_canvas.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 R22 ST-15 P2-01 home map entry retry text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final location = _ControlledLocation(
        failure: RescueLocationFailureType.permissionDenied,
      );
      final source = FakeRescueSource(
        pages: List.generate(
          3,
          (_) => samplePage(items: sampleCasesWithoutImages()),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
          rescueLocationServiceProvider.overrideWithValue(location),
          rescueMapCanvasBuilderProvider.overrideWithValue(
            (center, items, onMarkerTap, onMapUnavailable) =>
                const ColoredBox(color: Color(0xFFE9F5DB)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/rescue',
        routes: [
          GoRoute(
            path: '/rescue',
            builder: (_, _) => const RescueHomeScreen(
              browseEnabled: true,
              createEnabled: true,
            ),
          ),
          GoRoute(
            path: '/rescue/map',
            builder: (_, _) => const RescueMapScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RescueHomeScreen), findsOneWidget);
      expect(container.read(rescueHomeProvider).items, hasLength(3));
      expect(
        location.calls,
        0,
        reason: 'Home preview must not request device location.',
      );
      // Tap the visible map-opening label, avoiding selectable marker children
      // and the center of a preview taller than the available viewport.
      final preview = find.text('Xem bản đồ');
      await tester.scrollUntilVisible(
        preview,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await captureDay116(tester, 'R22-ST15-P201-entry-text${scale.toString().replaceAll('.', '-')}');
      expect(preview.hitTestable(), findsOneWidget);
      await tester.tap(preview, warnIfMissed: true);
      await tester.pumpAndSettle();
      expect(find.byType(RescueMapScreen), findsOneWidget);
      expect(location.calls, 1);
      expect(container.read(rescueMapProvider).items, hasLength(3));
      expect(source.queries.last.latitude, isNull);
      final retry = find.byKey(const Key('rescue-map-location-retry'));
      expect(retry.hitTestable(), findsOneWidget);
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      await captureDay116(
        tester,
        'R22-ST15-P201-denied-text${scale.toString().replaceAll('.', '-')}',
      );
      location.denied = false;
      final previousCalls = source.callCount;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(location.calls, 2);
      expect(source.callCount, previousCalls + 1);
      expect(source.queries.last.latitude, 10.7769);
      expect(source.queries.last.longitude, 106.7009);
      expect(source.queries.last.sort, RescueCaseSort.distance);
      expect(
        container.read(rescueMapProvider).locationStatus,
        RescueLocationStatus.ready,
      );
      expect(container.read(rescueMapProvider).items, hasLength(3));
      expect(retry, findsNothing);
      await captureDay116(
        tester,
        'R22-ST15-P201-recovered-text${scale.toString().replaceAll('.', '-')}',
      );
      expectNoFlutterOverflow(tester);
    });
  }
  for (final scenario in [
    (
      RescueLocationFailureType.permissionDenied,
      'Chưa có quyền vị trí',
      const Size(320, 568),
      'permission',
    ),
    (
      RescueLocationFailureType.permissionDenied,
      'Chưa có quyền vị trí',
      const Size(390, 844),
      'permission-safe',
    ),
    (
      RescueLocationFailureType.serviceDisabled,
      'Thiết bị đang tắt định vị',
      const Size(390, 844),
      'service-safe',
    ),
    (
      RescueLocationFailureType.timeout,
      'Vị trí phản hồi chậm',
      const Size(390, 844),
      'timeout-safe',
    ),
    (
      RescueLocationFailureType.unknown,
      'Không xác định được vị trí',
      const Size(390, 844),
      'error-safe',
    ),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('D116 ST-15 P2-05 ${scenario.$4} retry text$scale', (
        tester,
      ) async {
        await setTestViewport(tester, size: scenario.$3);
        if (scenario.$3.width == 390) {
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
        }
        final location = _ControlledLocation(failure: scenario.$1);
        final source = FakeRescueSource(
          pages: [
            samplePage(items: sampleCasesWithoutImages()),
            samplePage(items: sampleCasesWithoutImages()),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            rescueApiProvider.overrideWithValue(source),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
            rescueLocationServiceProvider.overrideWithValue(location),
            rescueMapCanvasBuilderProvider.overrideWithValue(
              (
                RescueMapLocation center,
                List<RescueCaseSummary> items,
                ValueChanged<String> onMarkerTap,
                ValueChanged<Object> onMapUnavailable,
              ) => const ColoredBox(color: Color(0xFFE9F5DB)),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              home: const RescueMapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(scenario.$2), findsOneWidget);
        expect(location.calls, 1);
        expect(source.callCount, 1);
        expect(source.queries.single.latitude, isNull);
        expect(source.queries.single.longitude, isNull);
        expect(source.queries.single.sort, RescueCaseSort.recent);
        expect(container.read(rescueMapProvider).items, hasLength(3));
        final banner = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              (w.properties.label ?? '').startsWith(scenario.$2),
        );
        expect(banner, findsOneWidget);
        final retry = find.byKey(const Key('rescue-map-location-retry'));
        // Capture the actual blocked control before the assertion. This is
        // diagnostic-only: the reachable-control oracle remains unchanged.
        final currentLocation = find.byKey(
          const Key('rescue-map-current-location-button'),
        );
        debugPrint(
          'D116 map control bounds scale=$scale '
          'bannerRetry=${tester.getRect(retry)} '
          'currentLocation=${currentLocation.evaluate().isEmpty ? 'absent' : tester.getRect(currentLocation)}',
        );
        await captureDay116(
          tester,
          'D116-ST15-P205-${scenario.$4}-text${scale.toString().replaceAll('.', '-')}',
        );
        expect(retry.hitTestable(), findsOneWidget);
        expect(tester.getSize(retry).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
        expect(currentLocation, findsNothing);
        final layers = find.byKey(const Key('rescue-map-layers-button'));
        expect(layers.hitTestable(), findsOneWidget);
        expect(tester.getRect(retry).overlaps(tester.getRect(layers)), isFalse);
        await tester.tap(layers);
        await tester.pumpAndSettle();
        expect(find.text('Lớp bản đồ'), findsOneWidget);
        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
        location.denied = false;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(location.calls, 2);
        expect(source.callCount, 2);
        expect(source.queries.last.latitude, 10.7769);
        expect(source.queries.last.longitude, 106.7009);
        expect(source.queries.last.sort, RescueCaseSort.distance);
        expect(
          container.read(rescueMapProvider).locationStatus,
          RescueLocationStatus.ready,
        );
        expect(container.read(rescueMapProvider).items, hasLength(3));
        expect(find.text(scenario.$2), findsNothing);
        expect(currentLocation.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(currentLocation).overlaps(tester.getRect(layers)),
          isFalse,
        );
        expect(
          tester.getRect(layers).bottom,
          lessThanOrEqualTo(
            scenario.$3.height - (scenario.$3.width == 390 ? 34 : 0),
          ),
        );
        expectNoFlutterOverflow(tester);
      });
    }
  }
}

class _ControlledLocation implements RescueLocationService {
  _ControlledLocation({required this.failure});
  final RescueLocationFailureType failure;
  bool denied = true;
  int calls = 0;

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    calls++;
    if (denied) {
      throw RescueLocationException(
        failure,
        'Chưa có quyền vị trí. Danh sách công khai vẫn dùng được.',
      );
    }
    return const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

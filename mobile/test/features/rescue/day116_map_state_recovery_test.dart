import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_map_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_canvas.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_screen.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final state in ['ST-02', 'ST-05', 'ST-23', 'filtered-empty']) {
      testWidgets('D116 R19 $state P2-05 recovery text$scale', (tester) async {
        final source = _Source(state);
        final location = _Location();
        ValueChanged<Object>? mapError;
        ValueChanged<String>? markerTap;
        var canvasBuilds = 0;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            rescueApiProvider.overrideWithValue(source),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
            rescueLocationServiceProvider.overrideWithValue(location),
            authSessionSnapshotProvider.overrideWithValue(
              const AsyncData<AuthSession?>(null),
            ),
            authAccessTokenProvider.overrideWith((ref) async => null),
            rescueMapCanvasBuilderProvider.overrideWithValue((
              center,
              items,
              onMarkerTap,
              onMapUnavailable,
            ) {
              canvasBuilds++;
              markerTap = onMarkerTap;
              mapError = onMapUnavailable;
              return const ColoredBox(color: Color(0xffE9F5DB));
            }),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/rescue/map',
          routes: [
            GoRoute(
              path: '/rescue/map',
              builder: (_, _) => const RescueMapScreen(),
            ),
            GoRoute(
              path: '/rescue/create',
              builder: (_, _) => const RescueCreateScreen(),
            ),
            GoRoute(
              path: '/rescue/:id',
              builder: (_, s) =>
                  RescueCaseDetailScreen(caseId: s.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(router.dispose);
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
        expect(source.callCount, 1);
        expect(location.calls, 1);
        final suffix = scale.toString().replaceAll('.', '-');
        if (state == 'ST-05') {
          expect(
            container.read(rescueMapProvider).status,
            RescueMapLoadStatus.empty,
          );
          expect(find.byKey(const Key('rescue-map-view-all')), findsNothing);
          expect(
            find.widgetWithText(PawMateButton, 'Xóa bộ lọc'),
            findsNothing,
          );
          final report = find.widgetWithText(PawMateButton, 'Báo mất');
          // SRS State_Coverage ST05 and 05_Rescue_Map!R89 require this
          // recovery, not a no-op Clear button on already-default filters.
          expect(report, findsOneWidget);
          await _touch(tester, report);
          await captureDay116(tester, 'R19-ST05-P205-empty-text$suffix');
          await tester.tap(report);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            '/rescue/create',
          );
          expect(find.byType(RescueCreateScreen), findsOneWidget);
          expect(
            find.byKey(const Key('rescue-create-continue-cta')),
            findsOneWidget,
          );
          expect(source.callCount, 1);
          await captureDay116(tester, 'R19-ST05-P205-create-text$suffix');
        } else if (state == 'ST-02') {
          expect(
            container.read(rescueMapProvider).status,
            RescueMapLoadStatus.error,
          );
          expect(find.byKey(const Key('rescue-map-view-all')), findsNothing);
          final retry = find.widgetWithText(PawMateButton, 'Thử lại');
          await _touch(tester, retry);
          await captureDay116(tester, 'R19-ST02-P205-error-text$suffix');
          source.fail = false;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(source.callCount, 2);
          expect(location.calls, 1);
          expect(
            source.queries[1].toQueryParameters(),
            source.queries[0].toQueryParameters(),
          );
          expect(
            container.read(rescueMapProvider).status,
            RescueMapLoadStatus.ready,
          );
          expect(container.read(rescueMapProvider).items, hasLength(3));
          expect(retry, findsNothing);
          await captureDay116(tester, 'R19-ST02-P205-ready-text$suffix');
        } else if (state == 'filtered-empty') {
          final dogFilter = find.byKey(const Key('rescue-map-filter-dogs'));
          await tester.ensureVisible(dogFilter);
          await tester.pumpAndSettle();
          await tester.tap(dogFilter);
          await tester.pumpAndSettle();
          expect(source.callCount, 2);
          expect(source.queries.last.species, RescueSpecies.dog);
          expect(
            container.read(rescueMapProvider).status,
            RescueMapLoadStatus.empty,
          );
          final clear = find.widgetWithText(PawMateButton, 'Xóa bộ lọc');
          await _touch(tester, clear);
          await captureDay116(tester, 'R19-filtered-P205-empty-text$suffix');
          await tester.tap(clear);
          await tester.pumpAndSettle();
          expect(source.callCount, 3);
          expect(location.calls, 1);
          expect(source.queries.last.species, isNull);
          expect(container.read(rescueMapProvider).items, hasLength(3));
          expect(
            container.read(rescueMapProvider).status,
            RescueMapLoadStatus.ready,
          );
          expect(clear, findsNothing);
          await captureDay116(tester, 'R19-filtered-P205-ready-text$suffix');
        } else {
          final first = sampleCasesWithoutImages().first;
          markerTap!(first.caseId);
          await tester.pumpAndSettle();
          mapError!(StateError('Declared platform canvas failure fixture'));
          await tester.pumpAndSettle();
          expect(container.read(rescueMapProvider).mapUnavailable, isTrue);
          expect(
            container.read(rescueMapProvider).selectedCaseId,
            first.caseId,
          );
          expect(container.read(rescueMapProvider).items, hasLength(3));
          final retry = find.widgetWithText(PawMateButton, 'Tải lại bản đồ');
          await _touch(tester, retry);
          await captureDay116(tester, 'R19-ST23-P205-unavailable-text$suffix');
          final before = canvasBuilds;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(canvasBuilds, greaterThan(before));
          expect(container.read(rescueMapProvider).mapUnavailable, isFalse);
          expect(container.read(rescueMapProvider).mapReloadToken, 1);
          expect(
            container.read(rescueMapProvider).selectedCaseId,
            first.caseId,
          );
          expect(source.callCount, 1);
          expect(location.calls, 1);
          expect(retry, findsNothing);
          final card = find.byKey(
            ValueKey('rescue-marker-select-${first.caseId}'),
          );
          await _touch(tester, card);
          await captureDay116(tester, 'R19-ST23-P205-list-text$suffix');
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(find.byType(RescueCaseDetailScreen), findsOneWidget);
          expect(source.detailCaseIds, [first.caseId]);
          expect(
            router.routeInformationProvider.value.uri.path,
            '/rescue/${first.caseId}',
          );
          await captureDay116(tester, 'R19-ST23-P205-detail-text$suffix');
        }
        expectNoFlutterOverflow(tester);
      });
    }
  }
}

Future<void> _touch(WidgetTester tester, Finder target) async {
  final scroll = find
      .descendant(
        of: find.byKey(const Key('rescue-map-sheet-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 100, scrollable: scroll);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final data = tester.getSemantics(target).getSemanticsData();
    expect('${data.label} ${data.tooltip}'.trim(), isNotEmpty);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  } finally {
    handle.dispose();
  }
}

class _Source extends FakeRescueSource {
  _Source(this.scenario) : fail = scenario == 'ST-02';
  final String scenario;
  bool fail;
  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    queries.add(query);
    callCount++;
    if (fail) {
      throw const RescueApiException('Fixture503', statusCode: 503);
    }
    return scenario == 'ST-05' ||
            (scenario == 'filtered-empty' && query.species != null)
        ? emptyPage()
        : samplePage(items: sampleCasesWithoutImages());
  }
}

class _Location implements RescueLocationService {
  int calls = 0;
  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    calls++;
    return const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

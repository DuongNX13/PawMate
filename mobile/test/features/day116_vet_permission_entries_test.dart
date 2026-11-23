import 'dart:ui' show SemanticsAction;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
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
  setUpAll(() => GoRouter.optionURLReflectsImperativeAPIs = true);
  tearDownAll(() => GoRouter.optionURLReflectsImperativeAPIs = false);
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final home in [true, false]) {
      final owner = home ? 'P1-07' : 'P1-09';
      testWidgets(
        'D116 R18 ST-15 $owner text$scale actual map entry permission fallback retry',
        (tester) async {
          final location = _Location();
          final api = _Vets();
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              authSessionSnapshotProvider.overrideWithValue(
                const AsyncData<AuthSession?>(null),
              ),
              petBackendListProvider.overrideWith((ref) async => [_pet]),
              upcomingRemindersProvider.overrideWith((ref) async => []),
              vetApiProvider.overrideWithValue(api),
              vetLocationServiceProvider.overrideWithValue(location),
              vetMapCanvasBuilderProvider.overrideWith(
                (ref) =>
                    (center, vets, style, onMarkerTap, onMapUnavailable) =>
                        const ColoredBox(color: Color(0xffF8F3EA)),
              ),
            ],
          );
          addTearDown(container.dispose);
          final router = GoRouter(
            initialLocation: home ? '/pets' : '/vets/list',
            routes: [
              GoRoute(path: '/pets', builder: (_, _) => const PetHomeScreen()),
              GoRoute(
                path: '/vets/list',
                builder: (_, _) => const VetListScreen(),
              ),
              GoRoute(
                path: '/vets/map',
                builder: (_, _) => const VetMapScreen(),
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
          expect(location.calls, 0);
          final entry = home
              ? find.byKey(const Key('home-find-vet-shortcut'))
              : find.ancestor(
                  of: find.text('Xem trên bản đồ'),
                  matching: find.byType(InkWell),
                );
          await _touch(tester, entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/vets/map');
          if (!home) {
            // List -> map correctly reuses its dataset; permission is requested
            // only by the user's real current-location control, not a fake state.
            expect(location.calls, 0);
            final current = find.byKey(
              const Key('vet-map-current-location-button'),
            );
            await _touch(tester, current);
            await tester.tap(current);
            await tester.pumpAndSettle();
          }
          expect(location.calls, 1);
          expect(api.nearbyCalls, isEmpty);
          expect(
            container.read(vetMapProvider).status,
            VetMapStatus.permissionDenied,
          );
          final fallback = find.widgetWithText(
            PawMateButton,
            'Xem dạng danh sách',
          );
          await _touch(tester, fallback);
          await captureDay116(
            tester,
            'R18-ST15-$owner-denied-text${scale.toString().replaceAll('.', '-')}',
          );
          await tester.tap(fallback);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/vets/list');
          expect(find.byType(VetListScreen), findsOneWidget);
          await _reach(tester, find.text('Phòng khám QA'));
          expect(find.text('Phòng khám QA').hitTestable(), findsOneWidget);
          expect(location.calls, 1);
          expect(api.searchCalls, isNotEmpty);
          await captureDay116(
            tester,
            'R18-ST15-$owner-list-text${scale.toString().replaceAll('.', '-')}',
          );
          final map = find.ancestor(
            of: find.text('Xem trên bản đồ'),
            matching: find.byType(InkWell),
          );
          await _touch(tester, map, delta: -160);
          await tester.tap(map);
          await tester.pumpAndSettle();
          location.denied = false;
          final current = find.byKey(
            const Key('vet-map-current-location-button'),
          );
          await _touch(tester, current);
          await tester.tap(current);
          await tester.pumpAndSettle();
          expect(location.calls, 2);
          expect(api.nearbyCalls.length, 1);
          final request = api.nearbyCalls.single;
          expect([request.latitude, request.longitude], [10.7769, 106.7009]);
          expect(container.read(vetMapProvider).status, VetMapStatus.ready);
          expect(find.text('Chưa có quyền vị trí'), findsNothing);
          await _reach(tester, find.text('Phòng khám QA'));
          await captureDay116(
            tester,
            'R18-ST15-$owner-ready-text${scale.toString().replaceAll('.', '-')}',
          );
          expectNoFlutterOverflow(tester);
        },
      );
    }
  }
}

Future<void> _reach(
  WidgetTester tester,
  Finder target, {
  double delta = 160,
}) async {
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _touch(
  WidgetTester tester,
  Finder target, {
  double delta = 160,
}) async {
  await _reach(tester, target, delta: delta);
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

class _Location implements VetLocationService {
  int calls = 0;
  bool denied = true;
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    calls++;
    if (denied) {
      throw const VetLocationException(
        VetLocationFailureType.permissionDenied,
        'Quyền vị trí bị từ chối trong fixture',
      );
    }
    return const VetMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

class _Vets extends VetApi {
  _Vets() : super(Dio());
  final nearbyCalls = <VetNearbyRequest>[];
  final searchCalls = <VetSearchRequest>[];
  static const item = VetSummary(
    id: 'r18-vet',
    name: 'Phòng khám QA',
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
    return const VetNearbyResult(items: [item], total: 1, limit: 20);
  }

  @override
  Future<VetSearchResult> search(VetSearchRequest request) async {
    searchCalls.add(request);
    return const VetSearchResult(items: [item], total: 1, limit: 20);
  }
}

final _pet = PetProfile(
  id: 'r18-mochi',
  name: 'Mochi',
  species: 'dog',
  breed: 'Poodle',
  gender: 'unknown',
  dateOfBirth: null,
  weightKg: null,
  healthStatus: 'healthy',
  avatarPath: 'assets/images/pets/p1_05_mochi.png',
  color: 'Vàng kem',
);

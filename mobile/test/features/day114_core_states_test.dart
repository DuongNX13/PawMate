import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_skeleton.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_state_view.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/domain/health_record.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/vets/application/vet_finder_session_provider.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';

import '../test_support/ui_test_helpers.dart';
import '../test_support/day114_capture.dart';
import '../test_support/day115_capture.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'rescue/rescue_test_fixtures.dart';

void main() {
  testWidgets(
    'D114 ST-01 offline owner retry returns data without losing nav',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      var requests = 0;
      var offline = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async {
              requests += 1;
              if (offline) {
                throw const PetApiException(
                  'Không thể kết nối tới máy chủ hồ sơ thú cưng.',
                );
              }
              return [];
            }),
            upcomingRemindersProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PetHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PawMateStateView>(find.byType(PawMateStateView)).type,
        PawMateStateType.offline,
      );
      final nav = tester.getRect(find.byType(PawMateBottomNav));
      await captureDay114(tester, 'ST-01');
      final requestsBeforeRetry = requests;
      offline = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(requests, greaterThan(requestsBeforeRetry));
      expect(find.text('Chưa có thú cưng nào'), findsOneWidget);
      expect(tester.getRect(find.byType(PawMateBottomNav)), nav);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'D114 ST-05 empty nearby rescue keeps report and refresh reachable',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = FakeRescueSource(pages: [emptyPage()]);
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
            path: '/rescue/create',
            builder: (_, _) => const Scaffold(body: Text('Report target')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(source),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rescue-empty-state')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('rescue-empty-state')));
      await captureDay114(tester, 'ST-05');
      final report = find.byKey(const Key('rescue-create-entry'));
      await tester.ensureVisible(report);
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(find.text('Report target'), findsOneWidget);
      expect(source.callCount, 1);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('D114 ST-02 Home server rejection is error, not offline', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    var unavailable = true;
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async {
            requests += 1;
            if (unavailable) {
              throw const PetApiException(
                'Máy chủ tạm thời chưa sẵn sàng.',
                statusCode: 503,
              );
            }
            return [];
          }),
          upcomingRemindersProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PetHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PawMateStateView>(find.byType(PawMateStateView)).type,
      PawMateStateType.error,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    await captureDay114(tester, 'ST-02');
    final beforeRetry = requests;
    unavailable = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(requests, greaterThan(beforeRetry));
    expect(find.text('Chưa có thú cưng nào'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('D114 ST-04 Health without pets creates a pet, not an event', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (_, _) => const HealthTimelineScreen(),
        ),
        GoRoute(
          path: '/pets/create',
          builder: (_, _) => const Scaffold(body: Text('Create pet target')),
        ),
        GoRoute(
          path: '/health/events/new',
          builder: (_, _) => const Scaffold(body: Text('Wrong event target')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => []),
          upcomingRemindersProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final add = find.text('Thêm hồ sơ thú cưng');
    expect(add, findsOneWidget);
    await tester.ensureVisible(add);
    await captureDay114(tester, 'ST-04');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Create pet target'), findsOneWidget);
    expect(find.text('Wrong event target'), findsNothing);
  });

  testWidgets(
    'D114 ST-03 Health uses skeleton while request is pending; nav stays fixed',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final pending = Completer<HealthRecordListResult>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async => [_pet]),
            healthRecordListProvider.overrideWith(
              (ref, query) => pending.future,
            ),
            upcomingRemindersProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HealthTimelineScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PawMateSkeleton), findsWidgets);
      final navBefore = tester.getRect(find.byType(PawMateBottomNav));
      await captureDay114(tester, 'ST-03');
      pending.complete(
        const HealthRecordListResult(items: [], total: 0, limit: 20),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có sự kiện'), findsOneWidget);
      expect(tester.getRect(find.byType(PawMateBottomNav)), navBefore);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'D114 ST-06 Vet empty recovery clears actual filters and refetches',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final api = _EmptyVetApi();
      final container = ProviderContainer(
        overrides: [vetApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.read(vetFinderSessionProvider.notifier)
        ..setQuery('Không có')
        ..toggleOnly24h();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const VetListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có phòng khám phù hợp'), findsOneWidget);
      final clear = find.byKey(const Key('vet-list-clear-empty-filters'));
      expect(clear, findsOneWidget);
      await tester.ensureVisible(clear);
      await captureDay114(tester, 'ST-06');
      await captureDay115(tester, 'UX-28');
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        container.read(vetFinderSessionProvider).hasActiveFilters,
        isFalse,
      );
      expect(api.requests.length, 2);
      expect(api.requests.last.keyword, '');
      expect(api.requests.last.only24h, isFalse);
      expectNoFlutterOverflow(tester);
    },
  );
}

final _pet = PetProfile(
  id: 'day114-pet',
  name: 'Mochi',
  species: 'dog',
  breed: 'Golden',
  gender: 'unknown',
  dateOfBirth: DateTime(2022),
  weightKg: 12,
  healthStatus: 'healthy',
  color: 'Vàng',
);

class _EmptyVetApi extends VetApi {
  _EmptyVetApi() : super(Dio());
  final requests = <VetSearchRequest>[];
  @override
  Future<VetSearchResult> search(VetSearchRequest request) async {
    requests.add(request);
    return const VetSearchResult(items: [], total: 0, limit: 20);
  }
}

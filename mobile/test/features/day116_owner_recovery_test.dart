import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_state_view.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/data/health_record_api.dart';
import 'package:pawmate_mobile/features/health/domain/health_record.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import '../test_support/ui_test_helpers.dart';
import '../test_support/day116_capture.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final id in ['ST-01', 'ST-02', 'ST-03', 'ST-04']) {
      testWidgets('D116 $id P1-05 text$scale real recovery and no stale CTA', (
        tester,
      ) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final pending = Completer<List<PetProfile>>();
        var attempts = 0;
        var fail = true;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            petBackendListProvider.overrideWith((ref) async {
              attempts++;
              if (id == 'ST-03') return pending.future;
              if (id == 'ST-04') return [];
              if (fail) {
                throw PetApiException(
                  id == 'ST-01'
                      ? 'Không thể kết nối tới máy chủ hồ sơ thú cưng.'
                      : 'Máy chủ tạm thời chưa sẵn sàng.',
                  statusCode: id == 'ST-02' ? 503 : null,
                );
              }
              return [];
            }),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/pets/list',
          routes: [
            GoRoute(
              path: '/pets/list',
              builder: (_, _) => const PetListScreen(),
            ),
            GoRoute(
              path: '/pets/create',
              builder: (_, _) =>
                  const Scaffold(body: Text('D116 Create pet target')),
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
        if (id == 'ST-03') {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
        } else {
          await tester.pumpAndSettle();
        }
        if (id == 'ST-01' || id == 'ST-02') {
          final state = tester.widget<PawMateStateView>(
            find.byType(PawMateStateView),
          );
          expect(
            state.type,
            id == 'ST-01' ? PawMateStateType.offline : PawMateStateType.error,
          );
          final retry = find.text('Thử lại');
          await tester.ensureVisible(retry);
          await tester.pump();
          expect(retry.hitTestable(), findsOneWidget);
          await captureDay116(
            tester,
            '$id-P1-05-text${scale.toString().replaceAll('.', '-')}',
          );
          fail = false;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(attempts, 2);
          expect(find.byKey(const Key('pet-list-error-state')), findsNothing);
          expect(
            find.byKey(const Key('pet-list-empty-create-button')),
            findsOneWidget,
          );
        } else if (id == 'ST-03') {
          expect(
            find.byKey(const Key('pet-list-loading-state')),
            findsOneWidget,
          );
          await captureDay116(
            tester,
            '$id-P1-05-text${scale.toString().replaceAll('.', '-')}',
          );
          pending.complete([]);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('pet-list-loading-state')), findsNothing);
          expect(attempts, 1);
        } else {
          final add = find.byKey(const Key('pet-list-empty-create-button'));
          await tester.ensureVisible(add);
          await tester.pump();
          expect(add.hitTestable(), findsOneWidget);
          await captureDay116(
            tester,
            '$id-P1-05-text${scale.toString().replaceAll('.', '-')}',
          );
          await tester.tap(add);
          await tester.pumpAndSettle();
          // context.push opens an imperative route without replacing the base
          // RouteInformation URI. Assert the visible destination/back stack.
          expect(router.canPop(), isTrue);
          expect(find.text('D116 Create pet target'), findsOneWidget);
          expect(attempts, 1);
        }
        expectNoFlutterOverflow(tester);
      });
    }
    for (final id in ['ST-01', 'ST-02']) {
      testWidgets(
        'D116 $id P1-12 text$scale retry preserves selected pet and nav',
        (tester) async {
          await setTestViewport(tester, size: const Size(320, 568));
          var fail = true;
          var attempts = 0;
          final queries = <String>[];
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              petBackendListProvider.overrideWith((ref) async => [_pet]),
              upcomingRemindersProvider.overrideWith((ref) async => []),
              healthRecordListProvider.overrideWith((ref, query) async {
                attempts++;
                queries.add(query.petId);
                if (fail) {
                  throw HealthRecordApiException(
                    id == 'ST-01'
                        ? 'Không thể kết nối tới máy chủ hồ sơ sức khỏe.'
                        : 'Máy chủ tạm thời chưa sẵn sàng.',
                    statusCode: id == 'ST-02' ? 503 : null,
                  );
                }
                return const HealthRecordListResult(
                  items: [],
                  total: 0,
                  limit: 20,
                );
              }),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: testTextScaleBuilder(scale),
                home: const HealthTimelineScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final navBefore = tester.getRect(find.byType(PawMateBottomNav));
          // ListView lazily builds children. At 2x text the state can be below
          // the initial viewport; navigate there rather than assuming it exists.
          await tester.scrollUntilVisible(
            find.text('Chưa đồng bộ được'),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Chưa đồng bộ được'), findsOneWidget);
          final retry = find.text('Thử lại');
          await tester.ensureVisible(retry);
          await tester.pump();
          expect(retry.hitTestable(), findsOneWidget);
          await captureDay116(
            tester,
            '$id-P1-12-text${scale.toString().replaceAll('.', '-')}',
          );
          fail = false;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(attempts, 2);
          expect(queries, [_pet.id, _pet.id]);
          expect(find.text('Chưa đồng bộ được'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Chưa có sự kiện'),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Chưa có sự kiện'), findsOneWidget);
          expect(tester.getRect(find.byType(PawMateBottomNav)), navBefore);
          expectNoFlutterOverflow(tester);
        },
      );
    }
  }
}

final _pet = PetProfile(
  id: 'day116-pet',
  name: 'Mochi',
  species: 'dog',
  breed: 'Golden',
  gender: 'unknown',
  dateOfBirth: DateTime(2022),
  weightKg: 12,
  healthStatus: 'healthy',
  color: 'Vàng',
);

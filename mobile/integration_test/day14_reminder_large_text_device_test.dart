import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/pawmate_scroll_behavior.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders and opens Day 14 reminder sheet on Android at text scale 2',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/health/reminders',
        routes: [
          GoRoute(
            path: '/health/reminders',
            builder: (context, state) => const ReminderCalendarScreen(),
          ),
          _targetRoute('/health', 'Health target'),
          _targetRoute('/pets', 'Pets target'),
          _targetRoute('/vets/list', 'Vets target'),
          _targetRoute('/profile', 'Profile target'),
          _targetRoute('/notifications', 'Notifications target'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
            reminderAccessTokenProvider.overrideWith(
              (ref) async => 'day14-test-token',
            ),
            reminderApiProvider.overrideWithValue(_FakeReminderApi()),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            scrollBehavior: const PawMateScrollBehavior(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lịch nhắc nhở'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Thêm lịch nhắc'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('reminder-create-time-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reminder-create-time-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

GoRoute _targetRoute(String path, String label) => GoRoute(
  path: path,
  builder: (context, state) => Scaffold(body: Center(child: Text(label))),
);

PetProfile _samplePet() => PetProfile(
  id: 'day14-pet',
  name: 'Mochi',
  species: 'dog',
  breed: 'Golden Retriever',
  gender: 'male',
  dateOfBirth: DateTime(2022, 5, 11),
  weightKg: 12.4,
  healthStatus: 'healthy',
);

class _FakeReminderApi extends ReminderApi {
  _FakeReminderApi() : super(Dio());

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async => ReminderListResult(items: const [], total: 0, limit: query.limit);
}

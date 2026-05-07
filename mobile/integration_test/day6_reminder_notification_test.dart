import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = String.fromEnvironment(
  'PAWMATE_E2E_EMAIL',
  defaultValue: 'mobile-e2e-owner@pawmate.test',
);
const _password = String.fromEnvironment(
  'PAWMATE_E2E_PASSWORD',
  defaultValue: 'Pawmate123',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'creates a reminder, shows it on calendar, syncs due notification, and marks all read',
    (tester) async {
      final dio = Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: const {'Accept': 'application/json'},
        ),
      );
      final authApi = AuthApi(dio);
      final petApi = PetApi(dio);
      final reminderApi = ReminderApi(dio);
      final session = await authApi.login(email: _email, password: _password);
      final runId = DateTime.now().millisecondsSinceEpoch;
      final pet = await petApi.createPet(
        CreatePetProfileInput(
          name: 'Day6 Pet $runId',
          species: 'dog',
          breed: 'Golden Retriever',
          gender: 'male',
          dateOfBirth: DateTime(2022, 4, 12),
          weightKg: 12.4,
          healthStatus: 'healthy',
          isNeutered: true,
        ),
        accessToken: session.accessToken,
      );

      final calendarTitle = 'Day6 calendar reminder $runId';
      await _pumpReminderScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );
      expect(find.text(pet.name), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Them lich'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, calendarTitle);
      await tester.tap(find.text('Luu lich nhac'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text(calendarTitle), findsOneWidget);

      final dueTitle = 'Day6 due notification $runId';
      await reminderApi.createReminder(
        pet.id,
        CreateReminderInput(
          title: dueTitle,
          reminderAt: DateTime.now().subtract(const Duration(minutes: 5)),
          note: 'Integration test due reminder',
        ),
        accessToken: session.accessToken,
      );

      await _pumpNotificationScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );
      expect(find.text(dueTitle), findsOneWidget);
      expect(find.textContaining('thong bao chua doc'), findsWidgets);

      await tester.tap(find.text('Doc het'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Tat ca da doc'), findsOneWidget);

      await _pumpNotificationScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );
      expect(find.text(dueTitle), findsOneWidget);
      expect(find.text('Tat ca da doc'), findsOneWidget);
    },
  );
}

Future<void> _pumpReminderScreen(
  WidgetTester tester, {
  required Dio dio,
  required String accessToken,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith((ref) => dio),
        petAccessTokenProvider.overrideWith((ref) async => accessToken),
        reminderAccessTokenProvider.overrideWith((ref) async => accessToken),
        notificationAccessTokenProvider.overrideWith(
          (ref) async => accessToken,
        ),
      ],
      child: MaterialApp.router(
        theme: _testTheme(),
        routerConfig: _router('/health/reminders'),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _pumpNotificationScreen(
  WidgetTester tester, {
  required Dio dio,
  required String accessToken,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith((ref) => dio),
        petAccessTokenProvider.overrideWith((ref) async => accessToken),
        reminderAccessTokenProvider.overrideWith((ref) async => accessToken),
        notificationAccessTokenProvider.overrideWith(
          (ref) async => accessToken,
        ),
      ],
      child: MaterialApp.router(
        theme: _testTheme(),
        routerConfig: _router('/notifications'),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

ThemeData _testTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFFFF8A5B),
  );
}

GoRouter _router(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthTimelineScreen(),
      ),
      GoRoute(
        path: '/health/reminders',
        builder: (context, state) => const ReminderCalendarScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
    ],
  );
}

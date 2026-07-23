import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
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
          color: 'Vàng kem',
          gender: 'male',
          dateOfBirth: DateTime(2022, 4, 12),
          weightKg: 12.4,
          healthStatus: 'healthy',
          isNeutered: true,
        ),
        accessToken: session.accessToken,
      );
      addTearDown(() async {
        await petApi.deletePet(pet.id, accessToken: session.accessToken);
      });

      final calendarTitle = 'Day6 calendar reminder $runId';
      await _pumpReminderScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );
      expect(find.text(pet.name), findsAtLeastNWidgets(1));

      // The QA account can contain pets from earlier runs. Select the pet
      // created by this journey before creating the reminder so the UI and
      // the API read-back use the same shared selected-pet state.
      final petDropdown = find.byType(DropdownButton<String>);
      expect(petDropdown, findsOneWidget);
      await tester.tap(petDropdown);
      await tester.pumpAndSettle();
      final createdPetOption = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem<String> && widget.value == pet.id,
      );
      expect(createdPetOption, findsOneWidget);
      await tester.tap(createdPetOption);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<String>>(petDropdown).value, pet.id);

      await tester.tap(find.byTooltip('Thêm lịch'));
      await tester.pumpAndSettle();
      final titleField = find.byKey(
        const ValueKey('reminder-create-title-field'),
      );
      expect(titleField, findsOneWidget);
      // Batched Android integration files can retain an IME connection from a
      // previous APK session. Widget tests cover keyboard entry; this journey
      // writes through the bound controller so persistence is deterministic.
      final titleController = tester.widget<TextField>(titleField).controller!;
      titleController.value = TextEditingValue(
        text: calendarTitle,
        selection: TextSelection.collapsed(offset: calendarTitle.length),
      );
      await tester.pump();
      expect(titleController.text, calendarTitle);
      await tester.tap(
        find.byKey(const ValueKey('reminder-create-save-button')),
      );
      await _waitUntilGone(tester, find.text('Thêm lịch nhắc'));
      expect(find.byType(ReminderCalendarScreen), findsOneWidget);
      final reminderQuery = ReminderListQuery(
        petId: pet.id,
        from: DateTime.now().subtract(const Duration(days: 1)),
        to: DateTime.now().add(const Duration(days: 2)),
        includeDone: true,
      );
      late ReminderListResult persistedReminders;
      for (var attempt = 0; attempt < 5; attempt++) {
        persistedReminders = await reminderApi.listReminders(
          reminderQuery,
          accessToken: session.accessToken,
        );
        if (persistedReminders.items.any(
          (reminder) => reminder.title == calendarTitle,
        )) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(
        persistedReminders.items.any(
          (reminder) => reminder.title == calendarTitle,
        ),
        isTrue,
      );

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
      expect(find.textContaining('thông báo chưa đọc'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('notification-mark-all-read-button')),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(
        find.byKey(const ValueKey('notification-unread-banner')),
        findsNothing,
      );

      await _pumpNotificationScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );
      expect(find.text(dueTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notification-unread-banner')),
        findsNothing,
      );
    },
  );
}

Future<void> _waitUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
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
        authenticatedDioProvider.overrideWith((ref) => dio),
        petAccessTokenProvider.overrideWith((ref) async => accessToken),
        reminderAccessTokenProvider.overrideWith((ref) async => accessToken),
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
        authenticatedDioProvider.overrideWith((ref) => dio),
        petAccessTokenProvider.overrideWith((ref) async => accessToken),
        reminderAccessTokenProvider.overrideWith((ref) async => accessToken),
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

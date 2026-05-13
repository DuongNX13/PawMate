import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('reminder calendar keeps a long selected pet name on one line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longPetName = 'Day8 Smoke 20260511045925 Long Selected Pet Name';
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Health target'))),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pets target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vets target'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Notifications target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: longPetName)],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => _FakeReminderApi()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(longPetName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reminder create sheet stays usable with keyboard open', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final fakeApi = _FakeReminderApi();
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Health target'))),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pets target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vets target'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Milo')],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.3),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await setKeyboardInset(tester, bottom: 300);
    await tester.enterText(
      find.byType(TextField).last,
      'Keyboard open reminder note remains scrollable.',
    );
    await tester.ensureVisible(find.byType(FilledButton).last);
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(fakeApi.createdPetId, 'day8-pet');
    expect(fakeApi.createdAccessToken, 'token');
    expect(
      fakeApi.createdInput?.note,
      'Keyboard open reminder note remains scrollable.',
    );
  });
}

class _FakeReminderApi extends ReminderApi {
  _FakeReminderApi() : super(Dio());

  String? createdPetId;
  String? createdAccessToken;
  CreateReminderInput? createdInput;

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    return const ReminderListResult(items: [], total: 0, limit: 20);
  }

  @override
  Future<Reminder> createReminder(
    String petId,
    CreateReminderInput input, {
    required String accessToken,
  }) async {
    createdPetId = petId;
    createdAccessToken = accessToken;
    createdInput = input;

    return Reminder(
      id: 'created-reminder',
      petId: petId,
      title: input.title,
      note: input.note,
      reminderAt: input.reminderAt,
      repeatRule: input.repeatRule,
      timezone: input.timezone,
      status: ReminderStatus.scheduled,
      createdAt: '2026-05-13T00:00:00.000Z',
      updatedAt: '2026-05-13T00:00:00.000Z',
    );
  }
}

PetProfile _samplePet({required String name}) {
  return PetProfile(
    id: 'day8-pet',
    name: name,
    species: 'dog',
    breed: 'QA Mix',
    gender: 'male',
    dateOfBirth: DateTime(2022, 5, 11),
    weightKg: 9.8,
    healthStatus: 'healthy',
  );
}

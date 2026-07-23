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

  testWidgets('renders v0.27 reminder calendar shell without mobile overflow', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final fakeApi = _FakeReminderApi(
      reminders: [
        _sampleReminder(
          id: 'overdue',
          title: 'Tiêm nhắc lại (Overdue)',
          dueAt: DateTime.now().subtract(const Duration(hours: 2)),
          petId: 'mochi',
        ),
        _sampleReminder(
          id: 'rabies',
          title: 'Tiêm phòng dại',
          dueAt: DateTime.now().add(const Duration(hours: 3)),
          petId: 'kem',
        ),
      ],
    );
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
            (ref) async => [
              _samplePet(id: 'mochi', name: 'Mochi'),
              _samplePet(id: 'kem', name: 'Kem'),
            ],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.1),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch nhắc nhở'), findsOneWidget);
    expect(find.textContaining('Bật thông báo'), findsOneWidget);
    expect(find.text('BẬT'), findsOneWidget);
    expect(find.textContaining('Tháng'), findsOneWidget);
    expect(find.text('Lịch hôm nay'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget);
    for (final key in [
      'reminder-back-button',
      'reminder-filter-button',
      'reminder-notification-enable-button',
    ]) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
    final addFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addFab.isExtended, isFalse);
    expect(
      tester.getSize(find.byType(FloatingActionButton)).width,
      lessThanOrEqualTo(56),
    );
    expectNoFlutterOverflow(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(find.text('Tiêm nhắc lại (Overdue)'), findsOneWidget);
    expect(find.text('TRỄ HẠN'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('Tiêm phòng dại'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Day 28 filters overdue reminders and syncs snooze/done', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeReminderApi(
      reminders: [
        _sampleReminder(
          id: 'overdue-day28',
          title: 'Lịch trễ Day 28',
          dueAt: DateTime.now().subtract(const Duration(hours: 2)),
          petId: 'day8-pet',
        ),
        _sampleReminder(
          id: 'upcoming-day28',
          title: 'Lịch sắp tới Day 28',
          dueAt: DateTime.now().add(const Duration(hours: 3)),
          petId: 'day8-pet',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) => const Scaffold(body: Text('Health')),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) => const Scaffold(body: Text('Pets')),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) => const Scaffold(body: Text('Vets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Text('Notifications')),
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
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reminder-active-filter-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-filter-overdue')));
    await tester.pumpAndSettle();

    expect(find.text('Lịch trễ Day 28'), findsOneWidget);
    expect(find.text('Lịch sắp tới Day 28'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('reminder-menu-overdue-day28')),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-menu-overdue-day28')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhắc lại sau 1 giờ'));
    await tester.pumpAndSettle();

    expect(fakeApi.snoozedIds, ['overdue-day28']);
    expect(find.text('Lịch trễ Day 28'), findsNothing);

    final activeFilterChip = find.byKey(
      const ValueKey('reminder-active-filter-chip'),
    );
    await tester.ensureVisible(activeFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(activeFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-filter-upcoming')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reminder-menu-overdue-day28')),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-menu-overdue-day28')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();

    expect(fakeApi.doneIds, ['overdue-day28']);
    expect(find.text('Lịch trễ Day 28'), findsNothing);
    expectNoFlutterOverflow(tester);
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
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byKey(const ValueKey('reminder-create-date-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reminder-create-time-button')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
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
  _FakeReminderApi({List<Reminder> reminders = const []})
    : reminders = [...reminders],
      super(Dio());

  final List<Reminder> reminders;
  String? createdPetId;
  String? createdAccessToken;
  CreateReminderInput? createdInput;
  final List<String> snoozedIds = [];
  final List<String> doneIds = [];

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    return ReminderListResult(
      items: reminders,
      total: reminders.length,
      limit: query.limit,
    );
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

    final reminder = Reminder(
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
    reminders.insert(0, reminder);
    return reminder;
  }

  @override
  Future<Reminder> snoozeReminder(
    String petId,
    String reminderId,
    DateTime snoozedUntil, {
    required String accessToken,
  }) async {
    snoozedIds.add(reminderId);
    final index = reminders.indexWhere((item) => item.id == reminderId);
    final updated = _copyReminder(
      reminders[index],
      nextTriggerAt: snoozedUntil,
      snoozedUntil: snoozedUntil,
    );
    reminders[index] = updated;
    return updated;
  }

  @override
  Future<Reminder> markDone(
    String petId,
    String reminderId, {
    required String accessToken,
  }) async {
    doneIds.add(reminderId);
    final index = reminders.indexWhere((item) => item.id == reminderId);
    final updated = _copyReminder(
      reminders[index],
      status: ReminderStatus.done,
      completedAt: DateTime.now(),
    );
    reminders[index] = updated;
    return updated;
  }
}

PetProfile _samplePet({String id = 'day8-pet', required String name}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'QA Mix',
    gender: 'male',
    dateOfBirth: DateTime(2022, 5, 11),
    weightKg: 9.8,
    healthStatus: 'healthy',
  );
}

Reminder _sampleReminder({
  required String id,
  required String title,
  required DateTime dueAt,
  required String petId,
}) {
  return Reminder(
    id: id,
    petId: petId,
    title: title,
    reminderAt: dueAt,
    nextTriggerAt: dueAt,
    repeatRule: ReminderRepeatRule.none,
    timezone: 'Asia/Bangkok',
    status: ReminderStatus.scheduled,
    createdAt: '2026-05-13T00:00:00.000Z',
    updatedAt: '2026-05-13T00:00:00.000Z',
  );
}

Reminder _copyReminder(
  Reminder source, {
  DateTime? nextTriggerAt,
  DateTime? snoozedUntil,
  DateTime? completedAt,
  ReminderStatus? status,
}) {
  return Reminder(
    id: source.id,
    petId: source.petId,
    title: source.title,
    note: source.note,
    reminderAt: source.reminderAt,
    nextTriggerAt: nextTriggerAt ?? source.nextTriggerAt,
    lastTriggeredAt: source.lastTriggeredAt,
    repeatRule: source.repeatRule,
    timezone: source.timezone,
    status: status ?? source.status,
    completedAt: completedAt ?? source.completedAt,
    cancelledAt: source.cancelledAt,
    snoozedUntil: snoozedUntil ?? source.snoozedUntil,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
  );
}

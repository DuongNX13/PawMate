import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/notifications/data/notification_api.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day28-reminder-notification-golden-root');
const _reminderExtraViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];
const _notificationExtraViewports = <Size>[Size(360, 844), Size(430, 932)];
final _goldenNow = DateTime(2026, 7, 20, 18, 34);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-14 Reminder Calendar golden at 390x844', (tester) async {
    await _pumpDay28Screen(
      tester,
      ReminderCalendarScreen(now: () => _goldenNow),
      reminderApi: _GoldenReminderApi(),
    );

    expect(find.text('Lịch nhắc nhở'), findsOneWidget);
    expect(find.text('TRỄ HẠN'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day28/p1-14-reminder-calendar-390x844.png'),
    );
  });

  testWidgets('P1-15 Notification Center golden at 390x844', (tester) async {
    await _pumpDay28Screen(
      tester,
      NotificationCenterScreen(now: () => _goldenNow),
      notificationApi: _GoldenNotificationApi(),
    );

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day28/p1-15-notification-center-390x844.png'),
    );
  });

  for (final viewport in _reminderExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-14 Reminder Calendar responsive golden at $tag', (
      tester,
    ) async {
      await _pumpDay28Screen(
        tester,
        ReminderCalendarScreen(now: () => _goldenNow),
        reminderApi: _GoldenReminderApi(),
        viewport: viewport,
      );

      expect(find.text('Lịch nhắc nhở'), findsOneWidget);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day28/p1-14-reminder-calendar-$tag.png'),
      );
    });
  }

  for (final viewport in _notificationExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-15 Notification Center responsive golden at $tag', (
      tester,
    ) async {
      await _pumpDay28Screen(
        tester,
        NotificationCenterScreen(now: () => _goldenNow),
        notificationApi: _GoldenNotificationApi(),
        viewport: viewport,
      );

      expect(find.text('Thông báo'), findsOneWidget);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day28/p1-15-notification-center-$tag.png'),
      );
    });
  }
}

Future<void> _pumpDay28Screen(
  WidgetTester tester,
  Widget screen, {
  ReminderApi? reminderApi,
  NotificationApi? notificationApi,
  Size viewport = const Size(390, 844),
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWith((ref) async => [_pet]),
        reminderAccessTokenProvider.overrideWith((ref) async => 'day28-token'),
        if (reminderApi != null)
          reminderApiProvider.overrideWith((ref) => reminderApi),
        if (notificationApi != null)
          notificationApiProvider.overrideWith((ref) => notificationApi),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _pet = PetProfile(
  id: 'mochi',
  name: 'Mochi',
  species: 'cat',
  breed: 'Mèo Anh lông ngắn',
  gender: 'female',
  dateOfBirth: DateTime(2022, 4, 12),
  weightKg: 4.8,
  healthStatus: 'healthy',
);

class _GoldenReminderApi extends ReminderApi {
  _GoldenReminderApi() : super(Dio());

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    final now = _goldenNow;
    final reminders = [
      Reminder(
        id: 'day28-overdue',
        petId: 'mochi',
        title: 'Tiêm nhắc lại',
        reminderAt: now.subtract(const Duration(hours: 2)),
        nextTriggerAt: now.subtract(const Duration(hours: 2)),
        repeatRule: ReminderRepeatRule.none,
        timezone: 'Asia/Bangkok',
        status: ReminderStatus.scheduled,
        createdAt: '2026-07-17T08:00:00.000Z',
        updatedAt: '2026-07-17T08:00:00.000Z',
      ),
      Reminder(
        id: 'day28-upcoming',
        petId: 'mochi',
        title: 'Uống thuốc',
        note: 'Dùng sau bữa ăn.',
        reminderAt: now.add(const Duration(hours: 3)),
        nextTriggerAt: now.add(const Duration(hours: 3)),
        repeatRule: ReminderRepeatRule.daily,
        timezone: 'Asia/Bangkok',
        status: ReminderStatus.scheduled,
        createdAt: '2026-07-17T08:00:00.000Z',
        updatedAt: '2026-07-17T08:00:00.000Z',
      ),
    ];
    return ReminderListResult(
      items: reminders,
      total: reminders.length,
      limit: query.limit,
    );
  }
}

class _GoldenNotificationApi extends NotificationApi {
  _GoldenNotificationApi() : super(Dio());

  @override
  Future<int> processDueReminders({required String accessToken}) async => 0;

  @override
  Future<NotificationListResult> listNotifications({
    required String accessToken,
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async {
    final now = _goldenNow;
    final items = [
      PawMateNotification(
        id: 'day28-unread',
        type: 'reminder_due',
        title: 'Đến giờ uống thuốc của Mochi',
        body: 'Mở lịch nhắc để kiểm tra liều dùng và đánh dấu hoàn thành.',
        reminderId: 'day28-upcoming',
        createdAt: DateTime(now.year, now.month, now.day, 9, 15),
      ),
      PawMateNotification(
        id: 'day28-read',
        type: 'vet_appointment_confirmed',
        title: 'Phòng khám đã xác nhận lịch hẹn',
        body: 'Lịch khám ngày mai đã được xác nhận.',
        readAt: DateTime(now.year, now.month, now.day, 8),
        createdAt: DateTime(now.year, now.month, now.day - 1, 16, 30),
      ),
    ];
    return NotificationListResult(
      items: items,
      total: items.length,
      unreadCount: 1,
      limit: limit,
    );
  }
}

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
final _goldenNow = DateTime(2023, 10, 24, 10);

Future<void> pumpDay120Reminder(WidgetTester tester, Size size) async {
  await pumpDay118Calendar(tester, size);
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

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
    expect(find.text('Tháng 10, 2023'), findsOneWidget);
    expect(find.text('Lịch hôm nay'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('reminder-notification-prompt')))
          .height,
      80,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('reminder-day-2023-10-24')))
          .height,
      72,
    );
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
    expect(
      find.byKey(const ValueKey('notification-unread-count')),
      findsOneWidget,
    );
    expect(find.text('Đọc hết'), findsOneWidget);
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

Future<void> pumpDay118Calendar(WidgetTester tester, Size viewport) =>
    _pumpDay28Screen(
      tester,
      ReminderCalendarScreen(now: () => _goldenNow),
      reminderApi: _GoldenReminderApi(),
      viewport: viewport,
    );

Future<void> pumpDay118Notifications(WidgetTester tester, Size viewport) =>
    _pumpDay28Screen(
      tester,
      NotificationCenterScreen(now: () => _goldenNow),
      notificationApi: _GoldenNotificationApi(),
      viewport: viewport,
    );

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
        petBackendListProvider.overrideWith((ref) async => [_pet, _secondPet]),
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
  await tester.pump();
  final context = tester.element(find.byKey(_goldenKey));
  for (final asset in const [
    'assets/images/pets/p1_05_mochi.png',
    'assets/images/pets/p1_05_kem.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
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
  avatarPath: 'assets/images/pets/p1_05_mochi.png',
);

final _secondPet = PetProfile(
  id: 'kem',
  name: 'Kem',
  species: 'dog',
  breed: 'Poodle',
  gender: 'male',
  dateOfBirth: DateTime(2023, 2, 8),
  weightKg: 6.1,
  healthStatus: 'healthy',
  avatarPath: 'assets/images/pets/p1_05_kem.png',
);

class _GoldenReminderApi extends ReminderApi {
  _GoldenReminderApi() : super(Dio());

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    final reminders = [
      Reminder(
        id: 'day28-overdue',
        petId: 'mochi',
        title: 'Tiêm nhắc lại (Overdue)',
        reminderAt: DateTime(2023, 10, 24, 9),
        nextTriggerAt: DateTime(2023, 10, 24, 9),
        repeatRule: ReminderRepeatRule.none,
        timezone: 'Asia/Bangkok',
        status: ReminderStatus.scheduled,
        createdAt: '2023-10-20T08:00:00.000Z',
        updatedAt: '2023-10-20T08:00:00.000Z',
      ),
      Reminder(
        id: 'day28-rabies',
        petId: 'kem',
        title: 'Tiêm phòng dại',
        reminderAt: DateTime(2023, 10, 24, 10, 30),
        nextTriggerAt: DateTime(2023, 10, 24, 10, 30),
        repeatRule: ReminderRepeatRule.none,
        timezone: 'Asia/Bangkok',
        status: ReminderStatus.scheduled,
        createdAt: '2023-10-20T08:00:00.000Z',
        updatedAt: '2023-10-20T08:00:00.000Z',
      ),
      Reminder(
        id: 'day28-medicine',
        petId: 'mochi',
        title: 'Uống thuốc bổ khớp',
        reminderAt: DateTime(2023, 10, 24, 14),
        nextTriggerAt: DateTime(2023, 10, 24, 14),
        repeatRule: ReminderRepeatRule.daily,
        timezone: 'Asia/Bangkok',
        status: ReminderStatus.scheduled,
        createdAt: '2023-10-20T08:00:00.000Z',
        updatedAt: '2023-10-20T08:00:00.000Z',
      ),
      Reminder(
        id: 'day28-deworming',
        petId: 'kem',
        title: 'Tẩy giun định kỳ',
        reminderAt: DateTime(2023, 10, 24, 16),
        nextTriggerAt: DateTime(2023, 10, 24, 16),
        repeatRule: ReminderRepeatRule.none,
        timezone: 'Asia/Bangkok',
        status: ReminderStatus.scheduled,
        createdAt: '2023-10-20T08:00:00.000Z',
        updatedAt: '2023-10-20T08:00:00.000Z',
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
        id: 'day28-health',
        type: 'reminder_due',
        title: 'Nhắc nhở tiêm chủng cho Mochi vào ngày mai',
        body:
            'Đừng quên lịch hẹn tiêm phòng dại định kỳ cho bé cưng tại VetCare Hub.',
        reminderId: 'day28-rabies',
        createdAt: DateTime(now.year, now.month, now.day, 10, 45),
      ),
      PawMateNotification(
        id: 'day28-rescue',
        type: 'rescue_case_nearby',
        title: 'Có tin báo mất thú cưng mới gần bạn',
        body:
            'Một bé Poodle màu nâu vừa bị lạc cách vị trí của bạn 500m. Hãy cùng giúp đỡ nhé!',
        createdAt: DateTime(now.year, now.month, now.day, 8, 20),
      ),
      PawMateNotification(
        id: 'day28-read',
        type: 'vet_appointment_confirmed',
        title: 'Bác sĩ Minh Trần đã xác nhận lịch hẹn',
        body: 'Lịch khám ngày mai đã được xác nhận.',
        readAt: DateTime(now.year, now.month, now.day, 8),
        createdAt: DateTime(now.year, now.month, now.day - 1, 16, 30),
      ),
    ];
    return NotificationListResult(
      items: items,
      total: items.length,
      unreadCount: 2,
      limit: limit,
    );
  }
}

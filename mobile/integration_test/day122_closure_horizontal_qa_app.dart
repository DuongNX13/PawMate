import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// Test-only direct entry points; the matching fixture payload is verified
// against Day28 before the offline build. Uses real Android viewport/insets.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWith((ref) async => [_pet, _secondPet]),
        reminderAccessTokenProvider.overrideWith((ref) async => 'day28-token'),
        reminderApiProvider.overrideWith((ref) => _GoldenReminderApi()),
        notificationApiProvider.overrideWith((ref) => _GoldenNotificationApi()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _QaLauncher(),
      ),
    ),
  );
}

class _QaLauncher extends StatelessWidget {
  const _QaLauncher();

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) {
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () =>
                    open(ReminderCalendarScreen(now: () => _goldenNow)),
                child: const Text('QA_OPEN_CALENDAR'),
              ),
              TextButton(
                onPressed: () =>
                    open(NotificationCenterScreen(now: () => _goldenNow)),
                child: const Text('QA_OPEN_NOTIFICATIONS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _goldenNow = DateTime(2023, 10, 24, 10);

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

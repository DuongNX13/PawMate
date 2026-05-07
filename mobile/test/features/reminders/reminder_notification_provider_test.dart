import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/data/notification_api.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';

void main() {
  test(
    'upcomingRemindersProvider aggregates backend reminders by due date',
    () async {
      final fakeReminderApi = _FakeReminderApi({
        'pet-a': [
          _sampleReminder(
            id: 'later',
            petId: 'pet-a',
            title: 'Later',
            dueAt: DateTime.now().add(const Duration(days: 4)),
          ),
        ],
        'pet-b': [
          _sampleReminder(
            id: 'soon',
            petId: 'pet-b',
            title: 'Soon',
            dueAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      });
      final container = ProviderContainer(
        overrides: [
          reminderAccessTokenProvider.overrideWith(
            (ref) async => 'reminder-token',
          ),
          reminderApiProvider.overrideWith((ref) => fakeReminderApi),
          petBackendListProvider.overrideWith(
            (ref) async => [
              _samplePet(id: 'pet-a', name: 'Bap'),
              _samplePet(id: 'pet-b', name: 'Mochi'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final reminders = await container.read(upcomingRemindersProvider.future);

      expect(fakeReminderApi.accessTokens, [
        'reminder-token',
        'reminder-token',
      ]);
      expect(reminders.map((reminder) => reminder.id), ['soon', 'later']);
    },
  );

  test('notificationListProvider loads unread count from backend', () async {
    final fakeNotificationApi = _FakeNotificationApi(
      NotificationListResult(
        items: [
          PawMateNotification(
            id: 'notification-1',
            type: 'reminder_due',
            title: 'Sap den lich tiem',
            body: 'Bap co lich tiem luc 09:30.',
            createdAt: DateTime(2026, 5, 5),
          ),
        ],
        total: 1,
        unreadCount: 1,
        limit: 20,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        notificationAccessTokenProvider.overrideWith(
          (ref) async => 'notification-token',
        ),
        notificationApiProvider.overrideWith((ref) => fakeNotificationApi),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(notificationListProvider.future);

    expect(fakeNotificationApi.listAccessToken, 'notification-token');
    expect(fakeNotificationApi.processAccessToken, 'notification-token');
    expect(result.unreadCount, 1);
    expect(result.items.single.title, 'Sap den lich tiem');
  });
}

class _FakeReminderApi extends ReminderApi {
  _FakeReminderApi(this.remindersByPet) : super(Dio());

  final Map<String, List<Reminder>> remindersByPet;
  final List<String> accessTokens = [];

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    accessTokens.add(accessToken);
    final reminders = remindersByPet[query.petId] ?? const <Reminder>[];
    return ReminderListResult(
      items: reminders,
      total: reminders.length,
      limit: query.limit,
    );
  }
}

class _FakeNotificationApi extends NotificationApi {
  _FakeNotificationApi(this.result) : super(Dio());

  final NotificationListResult result;
  String? listAccessToken;
  String? processAccessToken;

  @override
  Future<int> processDueReminders({required String accessToken}) async {
    processAccessToken = accessToken;
    return 1;
  }

  @override
  Future<NotificationListResult> listNotifications({
    required String accessToken,
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async {
    listAccessToken = accessToken;
    return result;
  }
}

PetProfile _samplePet({required String id, required String name}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Golden Retriever',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
  );
}

Reminder _sampleReminder({
  required String id,
  required String petId,
  required String title,
  required DateTime dueAt,
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
    createdAt: dueAt.toIso8601String(),
    updatedAt: dueAt.toIso8601String(),
  );
}

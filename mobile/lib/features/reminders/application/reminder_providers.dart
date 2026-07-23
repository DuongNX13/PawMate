import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../../pets/application/pet_list_provider.dart';
import '../data/reminder_api.dart';
import '../domain/reminder.dart';

final reminderAccessTokenProvider = authAccessTokenProvider;

final reminderListProvider =
    FutureProvider.family<ReminderListResult, ReminderListQuery>((
      ref,
      query,
    ) async {
      final accessToken = await ref.watch(reminderAccessTokenProvider.future);
      if (accessToken == null) {
        throw const ReminderApiException(
          'Bạn cần đăng nhập để đồng bộ lịch nhắc.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }

      return ref
          .watch(reminderApiProvider)
          .listReminders(query, accessToken: accessToken);
    });

final upcomingRemindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final accessToken = await ref.watch(reminderAccessTokenProvider.future);
  if (accessToken == null) {
    return const [];
  }

  final pets = await ref.watch(petBackendListProvider.future);
  final now = DateTime.now();
  final sevenDaysLater = now.add(const Duration(days: 7));
  final lists = await Future.wait(
    pets.map(
      (pet) => ref
          .watch(reminderApiProvider)
          .listReminders(
            ReminderListQuery(
              petId: pet.id,
              from: now,
              to: sevenDaysLater,
              limit: 10,
            ),
            accessToken: accessToken,
          ),
    ),
  );
  final reminders = lists.expand((result) => result.items).toList()
    ..sort((left, right) => left.dueAt.compareTo(right.dueAt));
  return reminders.take(5).toList();
});

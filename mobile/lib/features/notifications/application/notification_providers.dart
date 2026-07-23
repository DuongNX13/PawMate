import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/notification_api.dart';
import '../domain/pawmate_notification.dart';

final notificationDueSyncTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 6);
});

final notificationAccessTokenProvider = authAccessTokenProvider;

final notificationListProvider = FutureProvider<NotificationListResult>((
  ref,
) async {
  final accessToken = await ref.watch(notificationAccessTokenProvider.future);
  if (accessToken == null) {
    throw const NotificationApiException(
      'Bạn cần đăng nhập để xem thông báo.',
      code: 'AUTH_REQUIRED',
      statusCode: 401,
    );
  }

  final api = ref.watch(notificationApiProvider);
  final dueSyncTimeout = ref.watch(notificationDueSyncTimeoutProvider);
  try {
    await api
        .processDueReminders(accessToken: accessToken)
        .timeout(dueSyncTimeout);
  } on Object {
    // Keep the notification center usable even if due-reminder sync is slow.
  }
  return api.listNotifications(accessToken: accessToken);
});

final notificationUnreadCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(notificationListProvider)
      .whenData((result) => result.unreadCount);
});

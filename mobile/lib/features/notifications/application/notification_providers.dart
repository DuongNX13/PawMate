import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_session_store.dart';
import '../data/notification_api.dart';
import '../domain/pawmate_notification.dart';

final notificationAccessTokenProvider = FutureProvider<String?>((ref) async {
  final session = await ref.watch(authSessionStoreProvider).read();
  final token = session?.accessToken.trim();
  return token == null || token.isEmpty ? null : token;
});

final notificationListProvider = FutureProvider<NotificationListResult>((
  ref,
) async {
  final accessToken = await ref.watch(notificationAccessTokenProvider.future);
  if (accessToken == null) {
    throw const NotificationApiException(
      'Ban can dang nhap de xem thong bao.',
      code: 'AUTH_REQUIRED',
      statusCode: 401,
    );
  }

  final api = ref.watch(notificationApiProvider);
  await api.processDueReminders(accessToken: accessToken);
  return api.listNotifications(accessToken: accessToken);
});

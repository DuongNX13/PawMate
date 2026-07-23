import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/data/notification_api.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'P1-15 notification center renders v0.27 shell and groups items',
    (tester) async {
      final api = _FakeNotificationApi(
        NotificationListResult(
          items: [
            _notification(
              id: 'health-today',
              type: 'reminder_due',
              title: 'Nhắc nhở tiêm chủng cho Mochi vào ngày mai',
              body: 'Đừng quên lịch hẹn tiêm phòng định kỳ cho bé cưng.',
              createdAt: DateTime.now(),
            ),
            _notification(
              id: 'rescue-today',
              type: 'rescue_case_nearby',
              title: 'Có tin báo mất thú cưng mới gần bạn',
              body:
                  'Một bé Poodle màu nâu vừa bị lạc cách vị trí của bạn 500m.',
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
            _notification(
              id: 'vet-before',
              type: 'vet_appointment_confirmed',
              title: 'Bác sĩ Minh Trần đã xác nhận lịch hẹn',
              body: 'Lịch khám của Mochi đã được xác nhận.',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
              readAt: DateTime.now().subtract(const Duration(hours: 8)),
            ),
          ],
          total: 3,
          unreadCount: 2,
          limit: 20,
        ),
      );

      await _pumpNotificationCenter(tester, api);

      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Sức khỏe'), findsOneWidget);
      expect(find.text('Thú y'), findsOneWidget);
      expect(find.text('Cứu hộ'), findsOneWidget);
      expect(find.text('Đang trong giờ nghỉ (22:00 - 07:00)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notification-unread-banner')),
        findsOneWidget,
      );
      expect(find.text('2 thông báo chưa đọc'), findsOneWidget);
      expect(find.text('HÔM NAY'), findsOneWidget);
      expect(find.textContaining('Nhắc nhở tiêm chủng'), findsOneWidget);
      for (final key in [
        'notification-back-button',
        'notification-settings-button',
        'notification-filter-all',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      expectNoFlutterOverflow(tester);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();

      expect(find.textContaining('Có tin báo mất'), findsOneWidget);
      expectNoFlutterOverflow(tester);

      await tester.scrollUntilVisible(
        find.text('TRƯỚC ĐÓ'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('TRƯỚC ĐÓ'), findsOneWidget);
      expect(find.textContaining('Bác sĩ Minh Trần'), findsOneWidget);
      expect(
        tester
            .widget<PawMateBottomNav>(find.byType(PawMateBottomNav))
            .currentRoute,
        '/profile',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('P1-15 filters notification items by category', (tester) async {
    final api = _FakeNotificationApi(
      NotificationListResult(
        items: [
          _notification(
            id: 'health-today',
            type: 'reminder_due',
            title: 'Nhắc nhở tiêm chủng cho Mochi vào ngày mai',
            body: 'Đừng quên lịch hẹn tiêm phòng định kỳ cho bé cưng.',
            createdAt: DateTime.now(),
          ),
          _notification(
            id: 'rescue-today',
            type: 'rescue_case_nearby',
            title: 'Có tin báo mất thú cưng mới gần bạn',
            body: 'Một bé Poodle màu nâu vừa bị lạc cách vị trí của bạn 500m.',
            createdAt: DateTime.now(),
          ),
        ],
        total: 2,
        unreadCount: 2,
        limit: 20,
      ),
    );

    await _pumpNotificationCenter(tester, api);
    final rescueFilter = find.byKey(const Key('notification-filter-rescue'));
    await tester.ensureVisible(rescueFilter);
    await tester.pumpAndSettle();
    await tester.tap(rescueFilter);
    await tester.pumpAndSettle();

    expect(find.textContaining('Có tin báo mất'), findsOneWidget);
    expect(find.textContaining('Nhắc nhở tiêm chủng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P1-15 taps notification, marks read, and routes to target', (
    tester,
  ) async {
    final api = _FakeNotificationApi(
      NotificationListResult(
        items: [
          _notification(
            id: 'health-today',
            type: 'reminder_due',
            reminderId: 'reminder-1',
            title: 'Nhắc nhở tiêm chủng cho Mochi vào ngày mai',
            body: 'Đừng quên lịch hẹn tiêm phòng định kỳ cho bé cưng.',
            createdAt: DateTime.now(),
          ),
        ],
        total: 1,
        unreadCount: 1,
        limit: 20,
      ),
    );

    final router = await _pumpNotificationCenter(tester, api);

    await tester.tap(
      find.byKey(const ValueKey('notification-card-health-today')),
    );
    await tester.pumpAndSettle();

    expect(api.markReadIds, ['health-today']);
    expect(router.routeInformationProvider.value.uri.path, '/health/reminders');
  });

  testWidgets('Day 28 marks all previous notifications read and clears badge', (
    tester,
  ) async {
    final api = _FakeNotificationApi(
      NotificationListResult(
        items: [
          _notification(
            id: 'previous-unread',
            type: 'vet_appointment_confirmed',
            title: 'Lịch hẹn hôm qua',
            body: 'Lịch khám đã được xác nhận.',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
        total: 1,
        unreadCount: 1,
        limit: 20,
      ),
    );

    await _pumpNotificationCenter(tester, api);

    expect(find.text('HÔM NAY'), findsNothing);
    expect(find.text('TRƯỚC ĐÓ'), findsOneWidget);
    expect(find.text('1 thông báo chưa đọc'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('notification-mark-all-read-button')),
    );
    await tester.pumpAndSettle();

    expect(api.markAllReadCount, 1);
    expect(
      find.byKey(const ValueKey('notification-unread-banner')),
      findsNothing,
    );
    expect(find.text('Đã đọc tất cả thông báo.'), findsOneWidget);
  });

  testWidgets('Day 28 keeps target deep-link when mark-read is offline', (
    tester,
  ) async {
    final api = _FakeNotificationApi(
      NotificationListResult(
        items: [
          _notification(
            id: 'offline-reminder',
            type: 'reminder_due',
            reminderId: 'reminder-offline',
            title: 'Nhắc lịch khi mạng chập chờn',
            body: 'Chi tiết lịch nhắc vẫn phải mở được.',
            createdAt: DateTime.now(),
          ),
        ],
        total: 1,
        unreadCount: 1,
        limit: 20,
      ),
      failMarkRead: true,
    );

    final router = await _pumpNotificationCenter(tester, api);
    await tester.tap(
      find.byKey(const ValueKey('notification-card-offline-reminder')),
    );
    await tester.pumpAndSettle();

    expect(api.markReadIds, ['offline-reminder']);
    expect(router.routeInformationProvider.value.uri.path, '/health/reminders');
  });

  testWidgets('Day 28 dismisses an item and refreshes the notification list', (
    tester,
  ) async {
    final api = _FakeNotificationApi(
      NotificationListResult(
        items: [
          _notification(
            id: 'dismiss-day28',
            type: 'rescue_case_nearby',
            title: 'Tin cứu hộ đã xử lý',
            body: 'Có thể ẩn cập nhật này khỏi trung tâm thông báo.',
            createdAt: DateTime.now(),
          ),
        ],
        total: 1,
        unreadCount: 1,
        limit: 20,
      ),
    );

    await _pumpNotificationCenter(tester, api);
    await tester.tap(
      find.byKey(const ValueKey('notification-dismiss-dismiss-day28')),
    );
    await tester.pumpAndSettle();

    expect(api.dismissIds, ['dismiss-day28']);
    expect(find.text('Chưa có thông báo mới'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread-banner')),
      findsNothing,
    );
  });

  testWidgets('P1-15 empty state follows ST-24 recovery actions', (
    tester,
  ) async {
    final api = _FakeNotificationApi(
      const NotificationListResult(
        items: [],
        total: 0,
        unreadCount: 0,
        limit: 20,
      ),
    );

    final router = await _pumpNotificationCenter(tester, api);

    expect(find.text('Chưa có thông báo mới'), findsOneWidget);
    expect(find.text('Quản lý thông báo'), findsOneWidget);
    expect(find.text('Về trang cá nhân'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-empty-profile-button')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('notification-empty-profile-button')),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/profile');
  });
}

Future<GoRouter> _pumpNotificationCenter(
  WidgetTester tester,
  _FakeNotificationApi api,
) async {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationCenterScreen(
          returnPath: state.uri.queryParameters['returnTo'] ?? '/profile',
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Profile target'))),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Health target'))),
      ),
      GoRoute(
        path: '/health/reminders',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Reminder target'))),
      ),
      GoRoute(
        path: '/rescue',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Rescue target'))),
      ),
      GoRoute(
        path: '/vets/list',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Vet target'))),
      ),
      GoRoute(
        path: '/pets/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Pet target'))),
      ),
    ],
  );

  await setTestViewport(tester, size: const Size(360, 800));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationAccessTokenProvider.overrideWith(
          (ref) async => 'notification-token',
        ),
        notificationApiProvider.overrideWith((ref) => api),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

PawMateNotification _notification({
  required String id,
  required String type,
  required String title,
  required String body,
  required DateTime createdAt,
  String? reminderId,
  DateTime? readAt,
}) {
  return PawMateNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    reminderId: reminderId,
    createdAt: createdAt,
    readAt: readAt,
  );
}

class _FakeNotificationApi extends NotificationApi {
  _FakeNotificationApi(this.result, {this.failMarkRead = false}) : super(Dio());

  NotificationListResult result;
  final bool failMarkRead;
  final List<String> markReadIds = [];
  final List<String> dismissIds = [];
  int markAllReadCount = 0;
  String? listAccessToken;
  String? processAccessToken;

  @override
  Future<int> processDueReminders({required String accessToken}) async {
    processAccessToken = accessToken;
    return 0;
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

  @override
  Future<PawMateNotification> markRead(
    String notificationId, {
    required String accessToken,
  }) async {
    markReadIds.add(notificationId);
    if (failMarkRead) {
      throw const NotificationApiException(
        'Không thể kết nối tới máy chủ thông báo.',
      );
    }
    final updatedItems = result.items
        .map(
          (notification) => notification.id == notificationId
              ? _copyNotification(notification, readAt: DateTime.now())
              : notification,
        )
        .toList();
    result = NotificationListResult(
      items: updatedItems,
      total: result.total,
      unreadCount: updatedItems.where((item) => item.isUnread).length,
      limit: result.limit,
      nextCursor: result.nextCursor,
    );
    return updatedItems.firstWhere((item) => item.id == notificationId);
  }

  @override
  Future<int> markAllRead({required String accessToken}) async {
    markAllReadCount += 1;
    final previousUnreadCount = result.unreadCount;
    result = NotificationListResult(
      items: result.items
          .map(
            (notification) => notification.isUnread
                ? _copyNotification(notification, readAt: DateTime.now())
                : notification,
          )
          .toList(),
      total: result.total,
      unreadCount: 0,
      limit: result.limit,
      nextCursor: result.nextCursor,
    );
    return previousUnreadCount;
  }

  @override
  Future<PawMateNotification> dismiss(
    String notificationId, {
    required String accessToken,
  }) async {
    dismissIds.add(notificationId);
    final dismissed = result.items.firstWhere(
      (notification) => notification.id == notificationId,
    );
    final remaining = result.items
        .where((notification) => notification.id != notificationId)
        .toList();
    result = NotificationListResult(
      items: remaining,
      total: remaining.length,
      unreadCount: remaining.where((item) => item.isUnread).length,
      limit: result.limit,
      nextCursor: result.nextCursor,
    );
    return _copyNotification(dismissed, dismissedAt: DateTime.now());
  }
}

PawMateNotification _copyNotification(
  PawMateNotification source, {
  DateTime? readAt,
  DateTime? dismissedAt,
}) {
  return PawMateNotification(
    id: source.id,
    type: source.type,
    title: source.title,
    body: source.body,
    petId: source.petId,
    reminderId: source.reminderId,
    readAt: readAt ?? source.readAt,
    deliveredAt: source.deliveredAt,
    dismissedAt: dismissedAt ?? source.dismissedAt,
    createdAt: source.createdAt,
  );
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/pawmate_scroll_behavior.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/data/notification_api.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> prepareScreenshot() async {
    try {
      await binding.convertFlutterSurfaceToImage();
      return true;
    } on MissingPluginException catch (error) {
      debugPrint('ANDROID_SCREENSHOT_SKIPPED: $error');
      return false;
    }
  }

  testWidgets(
    'renders Day 15 notification at Android large text without overflow',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationAccessTokenProvider.overrideWith(
              (ref) async => 'day15-test-token',
            ),
            notificationApiProvider.overrideWithValue(_FakeNotificationApi()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            scrollBehavior: const PawMateScrollBehavior(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const NotificationCenterScreen(),
          ),
        ),
      );
      final canTakeScreenshot = await prepareScreenshot();
      await tester.pumpAndSettle();

      expect(find.textContaining('Nhắc nhở tiêm chủng'), findsOneWidget);
      final quietHoursPolicy = tester.widget<Text>(
        find.text(
          'Thông báo sẽ được chuyển đến im lặng để tránh làm phiền bạn.',
        ),
      );
      expect(quietHoursPolicy.maxLines, isNull);
      expect(quietHoursPolicy.overflow, isNull);
      expect(tester.takeException(), isNull);
      if (canTakeScreenshot) {
        await binding.takeScreenshot('day15-notification-large-text-android');
      }
      semantics.dispose();
    },
  );
}

class _FakeNotificationApi extends NotificationApi {
  _FakeNotificationApi() : super(Dio());

  @override
  Future<int> processDueReminders({required String accessToken}) async => 0;

  @override
  Future<NotificationListResult> listNotifications({
    required String accessToken,
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async => NotificationListResult(
    items: [
      PawMateNotification(
        id: 'large-text',
        type: 'reminder_due',
        title: 'Nhắc nhở tiêm chủng cho Mochi vào ngày mai',
        body:
            'Đừng quên lịch hẹn tiêm phòng định kỳ cho bé cưng. Hãy chuẩn bị sổ sức khỏe trước khi đến phòng khám.',
        createdAt: DateTime.utc(2026, 8, 4, 8),
      ),
    ],
    total: 1,
    unreadCount: 1,
    limit: limit,
  );
}

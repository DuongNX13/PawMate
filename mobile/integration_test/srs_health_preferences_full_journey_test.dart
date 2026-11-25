import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/notification_preferences_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/privacy_defaults_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_controls_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = 'mobile-e2e-owner@pawmate.test';
const _password = 'Pawmate123';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SRS P2-13..P2-16 health hub and persisted preference controls', (
    tester,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final session = await AuthApi(
      dio,
    ).login(email: _email, password: _password);
    final preferenceApi = PreferenceApi(dio);
    final originalNotifications = await preferenceApi
        .getNotificationPreferences(accessToken: session.accessToken);
    final originalPrivacy = await preferenceApi.getPrivacyDefaults(
      accessToken: session.accessToken,
    );
    addTearDown(() async {
      await _restoreNotifications(
        preferenceApi,
        session.accessToken,
        originalNotifications,
      );
      await _restorePrivacy(
        preferenceApi,
        session.accessToken,
        originalPrivacy,
      );
    });

    final router = GoRouter(
      initialLocation: '/health/knowledge',
      routes: [
        GoRoute(
          path: '/health/knowledge',
          builder: (context, state) => const HealthHubScreen(),
        ),
        GoRoute(
          path: '/profile/controls',
          builder: (context, state) => const ProfileControlsScreen(),
        ),
        GoRoute(
          path: '/profile/notifications',
          builder: (context, state) => const NotificationPreferencesScreen(),
        ),
        GoRoute(
          path: '/profile/privacy',
          builder: (context, state) => const PrivacyDefaultsScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) => const Scaffold(body: Text('Health')),
        ),
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const Scaffold(body: Text('Reminders')),
        ),
        GoRoute(
          path: '/vets/map',
          builder: (context, state) => const Scaffold(body: Text('Vets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWith((ref) => dio),
          authenticatedDioProvider.overrideWith((ref) => dio),
          authSessionSnapshotProvider.overrideWith((ref) async => session),
          authAccessTokenProvider.overrideWith(
            (ref) async => session.accessToken,
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await _waitFor(tester, find.byKey(const Key('health-hub-scroll')));
    expect(find.text('Công cụ & Tiện ích'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Hướng dẫn & Kiến thức'),
      find.byKey(const Key('health-hub-scroll')),
      const Offset(0, -400),
    );
    expect(find.text('Hướng dẫn & Kiến thức'), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go('/profile/controls');
    await _waitFor(tester, find.byKey(const Key('profile-controls-screen')));
    await _waitFor(
      tester,
      find.byKey(const Key('profile-controls-global-notifications')),
    );
    expect(find.byKey(const Key('profile-controls-privacy')), findsOneWidget);

    router.go('/profile/notifications');
    await _waitFor(
      tester,
      find.byKey(const Key('notification-preferences-scroll')),
    );
    await tester.tap(find.byKey(const Key('preference-chat-messages')));
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await _waitFor(tester, find.text('Đã lưu cài đặt thông báo.'));
    final updatedNotifications = await preferenceApi.getNotificationPreferences(
      accessToken: session.accessToken,
    );
    expect(
      updatedNotifications.chatMessages,
      isNot(originalNotifications.chatMessages),
    );
    expect(
      updatedNotifications.version,
      greaterThan(originalNotifications.version),
    );

    router.go('/profile/privacy');
    await _waitFor(tester, find.byKey(const Key('privacy-defaults-scroll')));
    await tester.tap(find.byKey(const Key('privacy-hide-house-number')));
    await tester.pump();
    // D125: the outgoing notification screen keeps its own save button until
    // the route transition ends, so wait for a single match before tapping.
    await _waitFor(
      tester,
      find.byKey(const Key('notification-preferences-scroll')),
      absent: true,
    );
    await tester.tap(find.text('Lưu thay đổi'));
    await _waitFor(tester, find.text('Đã lưu cài đặt quyền riêng tư.'));
    final updatedPrivacy = await preferenceApi.getPrivacyDefaults(
      accessToken: session.accessToken,
    );
    expect(
      updatedPrivacy.hideHouseNumber,
      isNot(originalPrivacy.hideHouseNumber),
    );
    expect(updatedPrivacy.version, greaterThan(originalPrivacy.version));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _restoreNotifications(
  PreferenceApi api,
  String token,
  NotificationPreferences original,
) async {
  final current = await api.getNotificationPreferences(accessToken: token);
  if (current.nearbyLostCases == original.nearbyLostCases &&
      current.chatMessages == original.chatMessages &&
      current.adoptionUpdates == original.adoptionUpdates &&
      current.quietHoursEnabled == original.quietHoursEnabled &&
      current.quietHoursStart == original.quietHoursStart &&
      current.quietHoursEnd == original.quietHoursEnd) {
    return;
  }
  await api.updateNotificationPreferences(
    current.copyWith(
      nearbyLostCases: original.nearbyLostCases,
      chatMessages: original.chatMessages,
      adoptionUpdates: original.adoptionUpdates,
      quietHoursEnabled: original.quietHoursEnabled,
      quietHoursStart: original.quietHoursStart,
      quietHoursEnd: original.quietHoursEnd,
      clearQuietHours: !original.quietHoursEnabled,
    ),
    accessToken: token,
  );
}

Future<void> _restorePrivacy(
  PreferenceApi api,
  String token,
  PrivacyDefaults original,
) async {
  final current = await api.getPrivacyDefaults(accessToken: token);
  if (current.hideHouseNumber == original.hideHouseNumber &&
      current.hidePhoneByDefault == original.hidePhoneByDefault &&
      current.reviewMediaBeforePublish == original.reviewMediaBeforePublish) {
    return;
  }
  await api.updatePrivacyDefaults(
    current.copyWith(
      hideHouseNumber: original.hideHouseNumber,
      hidePhoneByDefault: original.hidePhoneByDefault,
      reviewMediaBeforePublish: original.reviewMediaBeforePublish,
    ),
    accessToken: token,
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  bool absent = false,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty != absent) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, absent ? findsNothing : findsAtLeastNWidgets(1));
}

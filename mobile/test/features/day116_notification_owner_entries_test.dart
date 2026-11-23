import 'dart:ui' show SemanticsAction;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/notifications/data/notification_api.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_controls_screen.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  setUpAll(() => GoRouter.optionURLReflectsImperativeAPIs = true);
  tearDownAll(() => GoRouter.optionURLReflectsImperativeAPIs = false);
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final owner in ['P1-14', 'P1-16', 'P2-16']) {
      final reminder = owner == 'P1-14';
      final controls = owner == 'P2-16';
      testWidgets(
        'D116 R18 ST-24 $owner text$scale actual notification entry empty back and profile',
        (tester) async {
          final api = _EmptyNotifications();
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              authSessionSnapshotProvider.overrideWithValue(
                const AsyncData<AuthSession?>(_session),
              ),
              authAccessTokenProvider.overrideWith(
                (ref) async => 'fixture-token',
              ),
              petBackendListProvider.overrideWith((ref) async => const []),
              notificationApiProvider.overrideWithValue(api),
              preferenceSourceProvider.overrideWithValue(_Preferences()),
            ],
          );
          addTearDown(container.dispose);
          final initial = reminder ? '/health/reminders' : '/profile';
          final router = GoRouter(
            initialLocation: controls ? '/profile/controls' : initial,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/profile/controls',
                builder: (_, _) => const ProfileControlsScreen(),
              ),
              GoRoute(
                path: '/health/reminders',
                builder: (_, _) => ReminderCalendarScreen(
                  now: () => DateTime(2026, 10, 15, 9),
                ),
              ),
              GoRoute(
                path: '/notifications',
                builder: (_, state) => NotificationCenterScreen(
                  returnPath:
                      state.uri.queryParameters['returnTo'] ?? '/profile',
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await setTestViewport(tester, size: const Size(320, 568));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(api.listCalls, 0);
          if (controls) {
            expect(find.byType(ProfileControlsScreen), findsOneWidget);
            final back = find.byTooltip('Quay lại');
            await _reachable(tester, back);
            await tester.tap(back);
            await tester.pumpAndSettle();
            expect(find.byType(ProfileScreen), findsOneWidget);
            expect(api.listCalls, 0);
          }
          final entry = reminder
              ? find.byKey(
                  const ValueKey('reminder-notification-enable-button'),
                )
              : find.byTooltip('Thông báo');
          await _reachable(tester, entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(
            router.routeInformationProvider.value.uri.path,
            '/notifications',
          );
          expect(
            router
                .routeInformationProvider
                .value
                .uri
                .queryParameters['returnTo'],
            initial,
          );
          expect(api.listCalls, 1);
          expect(api.syncCalls, 1);
          final empty = find.text('Chưa có thông báo mới');
          await tester.scrollUntilVisible(
            empty,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(empty.hitTestable(), findsOneWidget);
          expect(
            find.byKey(const ValueKey('notification-unread-count')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('notification-mark-all-read-button')),
            findsNothing,
          );
          final profile = find.byKey(
            const ValueKey('notification-empty-profile-button'),
          );
          final manage = find.byKey(
            const ValueKey('notification-empty-manage-button'),
          );
          await _reachable(tester, manage);
          await _reachable(tester, profile);
          await captureDay116(
            tester,
            'R18-ST24-$owner-empty-text${scale.toString().replaceAll('.', '-')}',
          );
          // Back uses the owning entry's encoded returnTo, not a target stub.
          final back = find.byKey(const ValueKey('notification-back-button'));
          await _reachable(tester, back, scrollDelta: -160);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, initial);
          expect(
            find.byType(reminder ? ReminderCalendarScreen : ProfileScreen),
            findsOneWidget,
          );
          await _reachable(tester, entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          await _reachable(tester, profile);
          await tester.tap(profile);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/profile');
          expect(find.byType(ProfileScreen), findsOneWidget);
          expect(api.mutations, 0);
          expect(
            container.read(authSessionSnapshotProvider).value!.user.id,
            _session.user.id,
          );
          await captureDay116(
            tester,
            'R18-ST24-$owner-returned-text${scale.toString().replaceAll('.', '-')}',
          );
          expectNoFlutterOverflow(tester);
        },
      );
    }
  }
}

Future<void> _reachable(
  WidgetTester tester,
  Finder finder, {
  double scrollDelta = 160,
}) async {
  await tester.scrollUntilVisible(
    finder,
    scrollDelta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final data = tester.getSemantics(finder).getSemanticsData();
    expect('${data.label} ${data.tooltip}'.trim(), isNotEmpty);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  } finally {
    handle.dispose();
  }
}

class _EmptyNotifications extends NotificationApi {
  _EmptyNotifications() : super(Dio());
  int listCalls = 0, syncCalls = 0, mutations = 0;
  @override
  Future<int> processDueReminders({required String accessToken}) async {
    expect(accessToken, 'fixture-token');
    syncCalls++;
    return 0;
  }

  @override
  Future<NotificationListResult> listNotifications({
    required String accessToken,
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async {
    expect(accessToken, 'fixture-token');
    expect(limit, 20);
    expect(cursor, isNull);
    expect(unreadOnly, isFalse);
    listCalls++;
    return const NotificationListResult(
      items: [],
      total: 0,
      unreadCount: 0,
      limit: 20,
    );
  }

  @override
  Future<PawMateNotification> markRead(
    String notificationId, {
    required String accessToken,
  }) async {
    mutations++;
    throw StateError('Empty collection has no markRead target');
  }

  @override
  Future<int> markAllRead({required String accessToken}) async {
    mutations++;
    throw StateError('Empty collection must not mark all read');
  }

  @override
  Future<PawMateNotification> dismiss(
    String notificationId, {
    required String accessToken,
  }) async {
    mutations++;
    throw StateError('Empty collection has no dismiss target');
  }
}

class _Preferences implements PreferenceSource {
  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => NotificationPreferences(
    userId: _session.user.id,
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: DateTime.utc(2026, 10, 19),
  );
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: _session.user.id,
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 19),
  );
  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences value, {
    required String accessToken,
  }) async => throw StateError('Read-only owner entry proof');
  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults value, {
    required String accessToken,
  }) async => throw StateError('Read-only owner entry proof');
}

const _session = AuthSession(
  user: AuthUser(
    id: 'r18-owner',
    email: 'fixture@example.test',
    authProvider: 'email',
    emailVerified: true,
    displayName: 'Chủ nuôi kiểm thử',
  ),
  accessToken: 'fixture-token',
  refreshToken: 'fixture-refresh',
  accessTokenExpiresAt: '2099-01-01T00:00:00Z',
  refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
);

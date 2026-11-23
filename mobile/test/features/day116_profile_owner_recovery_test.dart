import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_controls_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  setUpAll(() => GoRouter.optionURLReflectsImperativeAPIs = true);
  tearDownAll(() => GoRouter.optionURLReflectsImperativeAPIs = false);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R17 ST-11 ST-12 P1-16 text$scale profile settings entry failure retry persists',
      (tester) async {
        final source = _Preferences();
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
            preferenceSourceProvider.overrideWithValue(source),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(
              path: '/profile/controls',
              builder: (_, _) => const ProfileControlsScreen(),
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
        final settings = find.byTooltip('Cài đặt');
        expect(settings.hitTestable(), findsOneWidget);
        expect(tester.getSize(settings).shortestSide, greaterThanOrEqualTo(48));
        await tester.tap(settings);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/profile/controls',
        );
        expect(
          find.byKey(const Key('profile-controls-screen')),
          findsOneWidget,
        );
        final tile = find.byKey(
          const Key('profile-controls-global-notifications'),
        );
        await tester.scrollUntilVisible(
          tile,
          160,
          scrollable: find.byType(Scrollable).last,
        );
        final toggle = find.descendant(of: tile, matching: find.byType(Switch));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(toggle.hitTestable(), findsOneWidget);
        expect(tester.getSize(toggle).shortestSide, greaterThanOrEqualTo(48));
        final before = source.stored.toUpdateJson();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(source.payloads, hasLength(1));
        expect(source.commits, 0);
        expect(source.stored.toUpdateJson(), before);
        expect(tester.widget<Switch>(toggle).value, isTrue);
        expect(
          find.text('Không thể kết nối. Mức trước đó vẫn được giữ.'),
          findsOneWidget,
        );
        expect(
          container.read(notificationPreferencesProvider).hasError,
          isTrue,
        );
        expect(
          container
              .read(notificationPreferencesProvider.notifier)
              .lastSuccessful!
              .toUpdateJson(),
          before,
        );
        await captureDay116(
          tester,
          'R17-ST12-P116-error-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(toggle.hitTestable(), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(source.payloads, hasLength(2));
        expect(source.payloads[1], source.payloads[0]);
        expect(source.commits, 1);
        expect(source.stored.nearbyLostCases, isFalse);
        expect(source.stored.chatMessages, isFalse);
        expect(source.stored.adoptionUpdates, isFalse);
        expect(source.stored.quietHoursEnabled, isFalse);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        expect(
          container.read(notificationPreferencesProvider).value!.toUpdateJson(),
          source.stored.toUpdateJson(),
        );
        expect(find.text('Đã cập nhật cài đặt thông báo.'), findsOneWidget);
        await captureDay116(
          tester,
          'R17-ST11-P116-saved-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        final back = find.byTooltip('Quay lại').last;
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/profile');
        await tester.tap(find.byTooltip('Cài đặt'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          tile,
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(toggle).value, isFalse);
        expect(source.commits, 1);
        final handle = tester.ensureSemantics();
        try {
          await tester.pump();
          expect(
            tester
                .getSemantics(toggle)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
          );
        } finally {
          handle.dispose();
        }
        expectNoFlutterOverflow(tester);
      },
    );
  }
}

class _Preferences implements PreferenceSource {
  NotificationPreferences stored = NotificationPreferences(
    userId: 'r17-owner',
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: DateTime.utc(2026, 10, 15),
  );
  int commits = 0;
  final payloads = <Map<String, dynamic>>[];
  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    return stored;
  }

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: 'r17-owner',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 15),
  );
  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences value, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    payloads.add(value.toUpdateJson());
    if (payloads.length == 1) {
      throw const PreferenceApiException(
        'Fixture offline',
        code: 'NETWORK_OFFLINE',
      );
    }
    commits++;
    stored = value;
    return stored;
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async => throw StateError('Unexpected privacy mutation');
}

const _session = AuthSession(
  user: AuthUser(
    id: 'r17-owner',
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

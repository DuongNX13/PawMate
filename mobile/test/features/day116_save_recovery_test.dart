import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_controls_screen.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_status_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_status_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_status_screen.dart';
import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';
import 'rescue/rescue_test_fixtures.dart';

const _session = AuthSession(
  user: AuthUser(
    id: 'r10-owner',
    email: 'fixture@example.test',
    authProvider: 'email',
    emailVerified: true,
    displayName: 'Owner fixture',
  ),
  accessToken: 'fixture-token',
  refreshToken: 'fixture-refresh',
  accessTokenExpiresAt: '2099-01-01T00:00:00Z',
  refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
);
void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R10 ST-11 ST-12 P2-16 text$scale real toggle failure and save retry',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _PreferenceSource();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferenceSourceProvider.overrideWithValue(source),
              authAccessTokenProvider.overrideWith(
                (ref) async => 'fixture-token',
              ),
              authSessionSnapshotProvider.overrideWithValue(
                const AsyncValue<AuthSession?>.data(_session),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              home: const ProfileControlsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tile = find.byKey(
          const Key('profile-controls-global-notifications'),
        );
        final toggle = find.descendant(of: tile, matching: find.byType(Switch));
        await tester.scrollUntilVisible(
          tile,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(toggle.hitTestable(), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(source.payloads.length, 1);
        expect(source.commits, 0);
        expect(source.stored.nearbyLostCases, isTrue);
        expect(source.stored.chatMessages, isTrue);
        expect(source.stored.adoptionUpdates, isTrue);
        expect(tester.widget<Switch>(toggle).value, isTrue);
        final error = find.text(
          'Không thể kết nối. Mức trước đó vẫn được giữ.',
        );
        expect(error, findsOneWidget);
        await captureDay116(
          tester,
          'R10-ST12-P2-16-text${scale.toString().replaceAll('.', '-')}',
        );
        expect(tester.getRect(error).bottom, lessThanOrEqualTo(568));
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(toggle.hitTestable(), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(source.payloads.length, 2);
        expect(source.payloads[1], source.payloads[0]);
        expect(source.commits, 1);
        expect(source.stored.nearbyLostCases, isFalse);
        expect(source.stored.chatMessages, isFalse);
        expect(source.stored.adoptionUpdates, isFalse);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        expect(find.text('Đã cập nhật cài đặt thông báo.'), findsOneWidget);
        await captureDay116(
          tester,
          'R10-ST11-P2-16-text${scale.toString().replaceAll('.', '-')}',
        );
        expectNoFlutterOverflow(tester);
      },
    );
    testWidgets(
      'D116 R10 ST-11 ST-12 P2-07 text$scale retry retains confirmation and write key',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final cases = _CaseSource();
        final source = _StatusSource(cases);
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            authAccessTokenProvider.overrideWith(
              (ref) async => 'fixture-token',
            ),
            rescueApiProvider.overrideWithValue(cases),
            rescueStatusSourceProvider.overrideWithValue(source),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/rescue/r10-case/status',
          routes: [
            GoRoute(
              path: '/rescue/:caseId/status',
              builder: (_, state) =>
                  RescueStatusScreen(caseId: state.pathParameters['caseId']!),
            ),
            GoRoute(
              path: '/rescue/:caseId',
              builder: (_, state) => Scaffold(
                body: Text('target:${state.pathParameters['caseId']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
              builder: testTextScaleBuilder(scale),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final confirm = find.byKey(const Key('rescue-status-confirm-safe'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(confirm.hitTestable(), findsOneWidget);
        await tester.tap(confirm);
        await tester.pump();
        final save = find.text('Lưu trạng thái');
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final state = container.read(rescueStatusProvider('r10-case'));
        expect(state.submitState, RescueStatusSubmitState.error);
        expect(state.confirmedSafe, isTrue);
        expect(state.pendingIdempotencyKey, isNotNull);
        expect(source.keys.length, 1);
        expect(source.commits, 0);
        expect(cases.stored.status, RescueCaseStatus.missing);
        expect(tester.widget<CheckboxListTile>(confirm).value, isTrue);
        final error = find.text(state.errorMessage!);
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        expect(error.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(error).bottom,
          lessThanOrEqualTo(tester.getRect(save).top),
        );
        await captureDay116(
          tester,
          'R10-ST12-P2-07-text${scale.toString().replaceAll('.', '-')}',
        );
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.keys.length, 2);
        expect(source.keys[1], source.keys[0]);
        expect(source.versions, [2, 2]);
        expect(source.commits, 1);
        expect(cases.stored.status, RescueCaseStatus.found);
        expect(cases.stored.version, 3);
        expect(
          container.read(rescueStatusProvider('r10-case')).submitState,
          RescueStatusSubmitState.success,
        );
        final open = find.text('Về bài đăng');
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        expect(open.hitTestable(), findsOneWidget);
        await captureDay116(
          tester,
          'R10-ST11-P2-07-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/rescue/r10-case',
        );
        expect(find.text('target:r10-case'), findsOneWidget);
        expectNoFlutterOverflow(tester);
      },
    );
  }
}

class _PreferenceSource implements PreferenceSource {
  final payloads = <Map<String, dynamic>>[];
  int commits = 0;
  NotificationPreferences stored = NotificationPreferences(
    userId: 'r10-owner',
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: true,
    quietHoursStart: '22:00',
    quietHoursEnd: '07:00',
    updatedAt: DateTime.utc(2026, 10, 14),
  );
  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => stored;
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: 'r10-owner',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 14),
  );
  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences value, {
    required String accessToken,
  }) async {
    payloads.add(value.toUpdateJson());
    if (payloads.length == 1) {
      throw const PreferenceApiException(
        'network unavailable',
        code: 'NETWORK_OFFLINE',
      );
    }
    commits++;
    stored = value;
    return stored;
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults value, {
    required String accessToken,
  }) async => value;
}

class _CaseSource extends FakeRescueSource {
  RescueCaseDetail stored = sampleCaseDetail(
    caseId: 'r10-case',
    canUpdateStatus: true,
    version: 2,
  );
  @override
  Future<RescueCaseDetail> getCase(String caseId) async => stored;
}

class _StatusSource implements RescueStatusSource {
  _StatusSource(this.cases);
  final _CaseSource cases;
  final keys = <String>[];
  final versions = <int>[];
  int commits = 0;
  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    versions.add(expectedVersion);
    if (keys.length == 1) {
      throw const RescueStatusApiException(
        'Không thể kết nối. Trạng thái chưa được thay đổi.',
        code: 'SYS_001',
        statusCode: 503,
      );
    }
    commits++;
    cases.stored = cases.stored.copyWith(
      status: RescueCaseStatus.found,
      version: expectedVersion + 1,
    );
    return cases.stored;
  }
}

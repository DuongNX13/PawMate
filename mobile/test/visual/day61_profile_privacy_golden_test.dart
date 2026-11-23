import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/privacy_defaults_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_controls_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day61-profile-privacy-golden-root');
const _viewport = Size(390, 844);

Future<void> pumpDay120Privacy(
  WidgetTester tester,
  Size size, {
  required bool controls,
}) => _pump(
  tester,
  controls ? const ProfileControlsScreen() : const PrivacyDefaultsScreen(),
  viewport: size,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-15 Privacy Defaults golden at 390x844', (tester) async {
    await _pump(tester, const PrivacyDefaultsScreen());

    expect(find.text('Quyền riêng tư'), findsOneWidget);
    expect(find.text('An toàn là ưu tiên'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Quyền riêng tư')).dy, lessThan(64));
    expect(tester.getTopLeft(find.text('Quyền riêng tư')).dy, greaterThan(0));
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day61/p2-15-privacy-defaults-390x844.png'),
    );
  });

  testWidgets('P2-16 Profile Controls golden at 390x844', (tester) async {
    await _pump(tester, const ProfileControlsScreen());

    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Dương Nguyễn'), findsOneWidget);
    expect(
      find.byKey(const Key('profile-controls-security-status')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.text('Tài khoản')).dy, lessThan(64));
    expect(tester.getTopLeft(find.text('Tài khoản')).dy, greaterThan(0));
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day61/p2-16-profile-controls-390x844.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authAccessTokenProvider.overrideWith((ref) async => 'golden-owner'),
        authSessionSnapshotProvider.overrideWith(
          (ref) async => _goldenSession(),
        ),
        preferenceSourceProvider.overrideWithValue(_GoldenPreferenceSource()),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _goldenSession() => AuthSession(
  user: const AuthUser(
    id: 'owner-1',
    email: 'duong@example.test',
    authProvider: 'email',
    emailVerified: true,
    displayName: 'Dương Nguyễn',
  ),
  accessToken: 'golden-owner',
  refreshToken: 'golden-refresh',
  accessTokenExpiresAt: '2026-07-30T00:00:00Z',
  refreshTokenExpiresAt: '2026-08-30T00:00:00Z',
);

class _GoldenPreferenceSource implements PreferenceSource {
  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => NotificationPreferences(
    userId: 'owner-1',
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: true,
    quietHoursStart: '22:00',
    quietHoursEnd: '07:00',
    updatedAt: DateTime.utc(2026, 7, 29, 10),
  );

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: 'owner-1',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: false,
    updatedAt: DateTime.utc(2026, 7, 29, 10),
  );

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async => preferences;

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async => defaults;
}

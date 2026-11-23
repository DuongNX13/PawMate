import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/data/privacy_guidance_share_service.dart';
import 'package:pawmate_mobile/features/profile/presentation/privacy_defaults_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_controls_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day116_capture.dart';

void main() {
  testWidgets('P2-15 privacy copy matches the enforced 500m backend policy', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      _testApp(_FakePreferenceSource(), const PrivacyDefaultsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('500m'), findsOneWidget);
    expect(find.textContaining('200m'), findsNothing);
    expect(
      find.textContaining('Vị trí chính xác không được công khai'),
      findsOneWidget,
    );
  });

  testWidgets(
    'P2-16 quiet hours do not promise an unsupported emergency exception',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      await tester.pumpWidget(
        _testApp(_FakePreferenceSource(), const ProfileControlsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-controls-quiet-hours')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('trừ khi có khẩn cấp'), findsNothing);
      expect(
        find.textContaining('tạm dừng trong khung giờ này'),
        findsOneWidget,
      );
    },
  );

  testWidgets('P2-15 loads, edits and saves authoritative privacy defaults', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource();
    await tester.pumpWidget(_testApp(source, const PrivacyDefaultsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-defaults-screen')), findsOneWidget);
    final stripExif = find.byKey(const Key('privacy-strip-exif'));
    await tester.scrollUntilVisible(
      stripExif,
      240,
      scrollable: find.descendant(
        of: find.byKey(const Key('privacy-defaults-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(stripExif, findsOneWidget);
    final exifSwitch = tester.widget<Switch>(
      find.descendant(of: stripExif, matching: find.byType(Switch)),
    );
    expect(exifSwitch.value, isTrue);

    await tester.tap(find.byKey(const Key('privacy-hide-house-number')));
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(source.privacy.hideHouseNumber, isFalse);
    expect(find.text('Đã lưu cài đặt quyền riêng tư.'), findsOneWidget);
  });

  testWidgets('P2-15 save failure retains the local toggle draft', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource()..failPrivacySave = true;
    await tester.pumpWidget(_testApp(source, const PrivacyDefaultsScreen()));
    await tester.pumpAndSettle();

    final reviewMedia = find.byKey(const Key('privacy-review-media'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(tester.getCenter(reviewMedia).dy, lessThan(760));
    await tester.tap(
      find.descendant(of: reviewMedia, matching: find.byType(Switch)),
    );
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(const Key('privacy-review-media')),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile.value, isFalse);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Thay đổi trên màn hình vẫn được giữ'),
      findsOneWidget,
    );
    await captureDay116(tester, 'R23-ST12-P215-failed');
    // Explicit retry must save the retained draft without re-entering it.
    source.failPrivacySave = false;
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(source.privacy.reviewMediaBeforePublish, isFalse);
    expect(find.text('Đã lưu cài đặt quyền riêng tư.'), findsOneWidget);
    await captureDay116(tester, 'R23-ST12-P215-saved');
  });

  testWidgets('P2-15 share action opens the native guidance share contract', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource();
    final shareSource = _FakePrivacyGuidanceShareSource();
    await tester.pumpWidget(
      _testApp(
        source,
        const PrivacyDefaultsScreen(),
        privacyGuidanceShareSource: shareSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('privacy-share-guidance')));
    await tester.pumpAndSettle();

    expect(shareSource.calls, 1);
    expect(shareSource.lastOrigin, isNotNull);
    expect(find.text('Đã sao chép hướng dẫn quyền riêng tư.'), findsNothing);
  });

  testWidgets(
    'P2-16 uses real session and persists global notification toggle',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = _FakePreferenceSource();
      await tester.pumpWidget(_testApp(source, const ProfileControlsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Dương Nguyễn'), findsOneWidget);
      expect(find.text('duong@example.test'), findsOneWidget);
      expect(
        find.byKey(const Key('profile-controls-security-status')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile-controls-privacy')), findsOneWidget);

      final globalTile = find.byKey(
        const Key('profile-controls-global-notifications'),
      );
      await tester.tap(
        find.descendant(of: globalTile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(source.notifications.nearbyLostCases, isFalse);
      expect(source.notifications.chatMessages, isFalse);
      expect(source.notifications.adoptionUpdates, isFalse);
    },
  );

  testWidgets(
    'P2-16 out-of-v1 rows remain honest and deletion is non-destructive',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = _FakePreferenceSource();
      await tester.pumpWidget(_testApp(source, const ProfileControlsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-controls-delete-account')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const Key('profile-controls-delete-account')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('profile-controls-delete-confirmation')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('profile-controls-delete-confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Không có thay đổi nào được lưu'),
        findsOneWidget,
      );
      expect(source.deleteCalls, 0);
    },
  );

  testWidgets(
    'P2-16 persists quiet hours and labels unavailable security controls',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = _FakePreferenceSource();
      await tester.pumpWidget(_testApp(source, const ProfileControlsScreen()));
      await tester.pumpAndSettle();

      final quietHours = find.byKey(const Key('profile-controls-quiet-hours'));
      await tester.ensureVisible(quietHours);
      expect(find.text('TỰ ĐỘNG BẬT: 22:00 - 07:00'), findsOneWidget);
      await tester.tap(
        find.descendant(of: quietHours, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(source.notifications.quietHoursEnabled, isFalse);
      expect(source.notifications.quietHoursStart, isNull);
      expect(source.notifications.quietHoursEnd, isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-controls-two-factor')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('profile-controls-two-factor')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Xác thực hai bước chưa hỗ trợ'),
        findsOneWidget,
      );
    },
  );

  testWidgets('P2-16 uses a Cupertino confirmation dialog on iOS', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource();
    await tester.pumpWidget(
      _testApp(
        source,
        const ProfileControlsScreen(),
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAccount = find.byKey(
      const Key('profile-controls-delete-account'),
    );
    await tester.scrollUntilVisible(
      deleteAccount,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(deleteAccount);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-controls-delete-confirm')));
    await tester.pumpAndSettle();
    expect(source.deleteCalls, 0);
  });

  testWidgets(
    'P2-16 reports notification save failure and retains saved values',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = _FakePreferenceSource()..failNotificationSave = true;
      await tester.pumpWidget(_testApp(source, const ProfileControlsScreen()));
      await tester.pumpAndSettle();

      final globalTile = find.byKey(
        const Key('profile-controls-global-notifications'),
      );
      await tester.tap(
        find.descendant(of: globalTile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(source.notifications.nearbyLostCases, isTrue);
      expect(source.notifications.chatMessages, isTrue);
      expect(source.notifications.adoptionUpdates, isTrue);
      expect(find.textContaining('Mức trước đó vẫn được giữ'), findsOneWidget);
    },
  );

  testWidgets('P2-15 and P2-16 survive 320dp at text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakePreferenceSource();

    await tester.pumpWidget(
      _testApp(
        source,
        const PrivacyDefaultsScreen(),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _testApp(
        source,
        const ProfileControlsScreen(),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'P2-15 and P2-16 keep deep controls reachable at 320dp with large text',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final source = _FakePreferenceSource();
      const textScaler = TextScaler.linear(2);

      await tester.pumpWidget(
        _testApp(source, const PrivacyDefaultsScreen(), textScaler: textScaler),
      );
      await tester.pumpAndSettle();
      final reviewMedia = find.byKey(const Key('privacy-review-media'));
      await tester.scrollUntilVisible(
        reviewMedia,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('privacy-defaults-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(reviewMedia);
      expectNoFlutterOverflow(tester);

      await tester.pumpWidget(
        _testApp(source, const ProfileControlsScreen(), textScaler: textScaler),
      );
      await tester.pumpAndSettle();
      final deleteAccount = find.byKey(
        const Key('profile-controls-delete-account'),
      );
      await tester.scrollUntilVisible(
        deleteAccount,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('profile-controls-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(deleteAccount);
      expectNoFlutterOverflow(tester);
    },
  );
}

Widget _testApp(
  _FakePreferenceSource source,
  Widget screen, {
  TextScaler textScaler = TextScaler.noScaling,
  TargetPlatform platform = TargetPlatform.android,
  PrivacyGuidanceShareSource? privacyGuidanceShareSource,
}) {
  return ProviderScope(
    overrides: [
      preferenceSourceProvider.overrideWithValue(source),
      authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
      authSessionSnapshotProvider.overrideWith((ref) async => _ownerSession()),
      if (privacyGuidanceShareSource != null)
        privacyGuidanceShareSourceProvider.overrideWithValue(
          privacyGuidanceShareSource,
        ),
    ],
    child: MaterialApp(
      theme: AppTheme.light().copyWith(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: screen,
    ),
  );
}

AuthSession _ownerSession() => AuthSession(
  user: const AuthUser(
    id: 'owner-1',
    email: 'duong@example.test',
    authProvider: 'email',
    emailVerified: true,
    displayName: 'Dương Nguyễn',
  ),
  accessToken: 'owner-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: '2026-07-30T00:00:00Z',
  refreshTokenExpiresAt: '2026-08-30T00:00:00Z',
);

class _FakePrivacyGuidanceShareSource implements PrivacyGuidanceShareSource {
  int calls = 0;
  Rect? lastOrigin;

  @override
  Future<void> shareGuidance({required Rect sharePositionOrigin}) async {
    calls += 1;
    lastOrigin = sharePositionOrigin;
  }
}

class _FakePreferenceSource implements PreferenceSource {
  bool failPrivacySave = false;
  bool failNotificationSave = false;
  int deleteCalls = 0;
  NotificationPreferences notifications = NotificationPreferences(
    userId: 'owner-1',
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: true,
    quietHoursStart: '22:00',
    quietHoursEnd: '07:00',
    updatedAt: DateTime.utc(2026, 7, 29),
  );
  PrivacyDefaults privacy = PrivacyDefaults(
    userId: 'owner-1',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 7, 29),
  );

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => notifications;

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => privacy;

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async {
    if (failNotificationSave) {
      throw const PreferenceApiException(
        'Không thể kết nối.',
        code: 'NETWORK_OFFLINE',
      );
    }
    notifications = NotificationPreferences(
      userId: preferences.userId,
      version: preferences.version + 1,
      nearbyLostCases: preferences.nearbyLostCases,
      chatMessages: preferences.chatMessages,
      adoptionUpdates: preferences.adoptionUpdates,
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietHoursStart: preferences.quietHoursStart,
      quietHoursEnd: preferences.quietHoursEnd,
      updatedAt: DateTime.utc(2026, 7, 29, 12),
    );
    return notifications;
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async {
    if (failPrivacySave) {
      throw const PreferenceApiException(
        'Không thể kết nối. Thay đổi trên màn hình vẫn được giữ.',
        code: 'NETWORK_OFFLINE',
      );
    }
    privacy = PrivacyDefaults(
      userId: defaults.userId,
      version: defaults.version + 1,
      hideHouseNumber: defaults.hideHouseNumber,
      hidePhoneByDefault: defaults.hidePhoneByDefault,
      reviewMediaBeforePublish: defaults.reviewMediaBeforePublish,
      updatedAt: DateTime.utc(2026, 7, 29, 12),
    );
    return privacy;
  }
}

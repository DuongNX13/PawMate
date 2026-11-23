import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/notification_preferences_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day60-health-preferences-golden-root');
const _viewport = Size(390, 844);
const _userId = '60000000-0000-4000-8000-000000000001';

Future<void> pumpDay120NotificationPreferences(
  WidgetTester tester,
  Size size,
) => _pumpPreferences(tester, viewport: size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-13 Health Hub golden at 390x844', (tester) async {
    await _pumpHealth(tester);

    expect(find.text('Công cụ & Tiện ích'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day60/p2-13-health-hub-390x844.png'),
    );
  });

  testWidgets('P2-14 Notification Preferences golden at 390x844', (
    tester,
  ) async {
    await _pumpPreferences(tester);

    expect(find.text('Cài đặt thông báo'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/day60/p2-14-notification-preferences-390x844.png',
      ),
    );
  });
}

Future<void> pumpDay118HealthHub(WidgetTester tester, Size viewport) =>
    _pumpHealth(tester, viewport: viewport);

Future<void> _pumpHealth(
  WidgetTester tester, {
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [petListProvider.overrideWith(_GoldenPetListNotifier.new)],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const HealthHubScreen(),
        ),
      ),
    ),
  );
  final context = tester.element(find.byType(HealthHubScreen));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/pets/home_adoption_golden.png'),
      context,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPreferences(
  WidgetTester tester, {
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authAccessTokenProvider.overrideWith((ref) async => 'golden-owner'),
        preferenceSourceProvider.overrideWithValue(_GoldenPreferenceSource()),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const NotificationPreferencesScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _GoldenPetListNotifier extends PetListNotifier {
  @override
  List<PetProfile> build() => const [
    PetProfile(
      id: 'pet-mochi',
      name: 'Mochi',
      species: 'dog',
      breed: 'Golden Retriever',
      gender: 'female',
      weightKg: 12.4,
      healthStatus: 'healthy',
    ),
  ];
}

class _GoldenPreferenceSource implements PreferenceSource {
  final preferences = NotificationPreferences(
    userId: _userId,
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
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => preferences;

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async => preferences;

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({required String accessToken}) {
    throw UnimplementedError();
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) {
    throw UnimplementedError();
  }
}

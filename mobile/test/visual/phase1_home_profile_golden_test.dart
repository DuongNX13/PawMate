import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenRootKey = Key('day19-home-profile-golden-root');
const _viewport = Size(390, 844);
const _homeResponsiveViewports = [
  Size(320, 568),
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];
const _profileResponsiveViewports = [
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-07 Home Screen golden at 390x844', (tester) async {
    await _pumpHome(tester, _viewport);

    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day19/p1-07-home-390x844.png'),
    );
  });

  testWidgets('P1-16 Profile golden at 390x844', (tester) async {
    await _pumpProfile(tester, _viewport);

    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day19/p1-16-profile-390x844.png'),
    );
  });

  for (final viewport in _homeResponsiveViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';

    testWidgets('P1-07 Home responsive golden at $tag', (tester) async {
      await _pumpHome(tester, viewport);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day19/p1-07-home-$tag.png'),
      );
    });
  }

  for (final viewport in _profileResponsiveViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';

    testWidgets('P1-16 Profile responsive golden at $tag', (tester) async {
      await _pumpProfile(tester, viewport);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day19/p1-16-profile-$tag.png'),
      );
    });
  }
}

Future<void> _pumpHome(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final pets = _pets();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue<AuthSession?>.data(_session),
        ),
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data(pets),
        ),
        upcomingRemindersProvider.overrideWithValue(
          AsyncValue<List<Reminder>>.data([_reminder]),
        ),
      ],
      child: RepaintBoundary(
        key: _goldenRootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: PetHomeScreen(now: DateTime(2026, 7, 16)),
        ),
      ),
    ),
  );
  await _precacheAssets(tester);
}

Future<void> _pumpProfile(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final pets = _pets();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileSessionProvider.overrideWithValue(
          const AsyncValue<AuthSession?>.data(_session),
        ),
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data(pets),
        ),
      ],
      child: RepaintBoundary(
        key: _goldenRootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    ),
  );
  await _precacheAssets(tester);
}

Future<void> _precacheAssets(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byKey(_goldenRootKey));
  for (final asset in const [
    'assets/images/pets/p1_05_mochi.png',
    'assets/images/pets/p1_05_kem.png',
    'assets/images/pets/home_adoption_golden.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pumpAndSettle();
}

List<PetProfile> _pets() => [
  PetProfile(
    id: 'mochi',
    name: 'Mochi',
    species: 'dog',
    breed: 'Golden Retriever',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
    avatarPath: 'assets/images/pets/p1_05_mochi.png',
    color: 'Vàng kem',
  ),
  PetProfile(
    id: 'kem',
    name: 'Kem',
    species: 'cat',
    breed: 'Mèo Ba Tư',
    gender: 'female',
    dateOfBirth: DateTime(2023, 2, 8),
    weightKg: 4.1,
    healthStatus: 'needs_vaccine',
    avatarPath: 'assets/images/pets/p1_05_kem.png',
    color: 'Trắng kem',
  ),
];

const _session = AuthSession(
  user: AuthUser(
    id: 'owner-1',
    email: 'duong.ngo@example.com',
    authProvider: 'email',
    emailVerified: true,
    displayName: 'Dương Ngô',
  ),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: '2099-05-14T10:00:00.000Z',
  refreshTokenExpiresAt: '2099-06-14T10:00:00.000Z',
);

final _reminder = Reminder(
  id: 'reminder-1',
  petId: 'mochi',
  title: 'Tiêm ngừa cho Mochi',
  reminderAt: DateTime(2026, 7, 17, 9, 30),
  repeatRule: ReminderRepeatRule.none,
  timezone: 'Asia/Bangkok',
  status: ReminderStatus.scheduled,
  createdAt: '2026-07-16T00:00:00.000Z',
  updatedAt: '2026-07-16T00:00:00.000Z',
  note: 'PetCare Elite',
);

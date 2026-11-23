import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home clinic card matches the approved anchor contract', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionSnapshotProvider.overrideWithValue(
            const AsyncValue<AuthSession?>.data(_session),
          ),
          petBackendListProvider.overrideWithValue(
            AsyncValue<List<PetProfile>>.data(_pets),
          ),
          upcomingRemindersProvider.overrideWithValue(
            AsyncValue<List<Reminder>>.data([_reminder]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: PetHomeScreen(now: DateTime(2026, 8, 27)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-nearby-vet-image')), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('★ 4.8'), findsOneWidget);
    expect(find.textContaining('(120+)'), findsNothing);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Home pet imagery keeps a centered cover focal crop', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionSnapshotProvider.overrideWithValue(
            const AsyncValue<AuthSession?>.data(_session),
          ),
          petBackendListProvider.overrideWithValue(
            AsyncValue<List<PetProfile>>.data(_pets),
          ),
          upcomingRemindersProvider.overrideWithValue(
            const AsyncValue<List<Reminder>>.data([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: PetHomeScreen(now: DateTime(2026, 8, 27)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = find.byKey(const Key('home-pet-avatar-mochi'));
    final image = tester.widget<Image>(
      find.descendant(of: avatar, matching: find.byType(Image)),
    );
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
  });
}

const _session = AuthSession(
  user: AuthUser(
    id: 'owner-1',
    email: 'day86@pawmate.test',
    authProvider: 'email',
    emailVerified: true,
    displayName: 'Nguyễn Văn Nam',
  ),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: '2099-05-14T10:00:00.000Z',
  refreshTokenExpiresAt: '2099-06-14T10:00:00.000Z',
);

final _pets = <PetProfile>[
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
];

final _reminder = Reminder(
  id: 'reminder-day86',
  petId: 'mochi',
  title: 'Tiêm ngừa cho Mochi',
  reminderAt: DateTime(2026, 8, 28, 9, 30),
  repeatRule: ReminderRepeatRule.none,
  timezone: 'Asia/Bangkok',
  status: ReminderStatus.scheduled,
  createdAt: '2026-08-27T00:00:00.000Z',
  updatedAt: '2026-08-27T00:00:00.000Z',
  note: 'PetCare Elite',
);

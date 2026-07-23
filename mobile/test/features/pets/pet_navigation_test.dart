import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';

import '../../test_support/ui_test_helpers.dart';

const _homeResponsiveViewports = <Size>[
  Size(360, 844),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];

void main() {
  testWidgets('Pet home at /pets opens selected pet detail from a pet card', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final semantics = tester.ensureSemantics();
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );
    final container = ProviderContainer(
      overrides: [
        petBackendListProvider.overrideWith(
          (ref) async => [
            _samplePet(id: 'mochi', name: 'Mochi'),
            _samplePet(id: 'bap', name: 'Bắp'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào buổi sáng, bạn!'), findsOneWidget);
    expect(find.byKey(const Key('home-pet-avatar-mochi')), findsOneWidget);
    final petSemantics = tester.getSemantics(
      find.bySemanticsLabel('Mochi, tình trạng KHỎE'),
    );
    expect(petSemantics.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      petSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(find.bySemanticsLabel('Thêm thú cưng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-pet-avatar-mochi')));
    await tester.pumpAndSettle();

    expect(find.text('Pet detail target: mochi'), findsOneWidget);
    expect(container.read(selectedPetIdProvider), 'mochi');
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('Pet home adoption teaser opens the contracted adoption route', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [
              _samplePet(id: 'mochi', name: 'Mochi'),
              _samplePet(id: 'kem', name: 'Kem'),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-adoption-view-more')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-adoption-view-more')));
    await tester.pumpAndSettle();

    expect(find.text('Adoption target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  for (final viewport in _homeResponsiveViewports) {
    testWidgets('Pet home keeps Golden adoption content and 48px actions at '
        '${viewport.width.toInt()}px', (tester) async {
      await setTestViewport(tester, size: viewport);
      final router = _petRouter(
        initialLocation: '/pets',
        includeCreateScreen: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith(
              (ref) async => [
                _samplePet(id: 'mochi', name: 'Mochi'),
                _samplePet(id: 'kem', name: 'Kem'),
              ],
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('home-adoption-card'));
      final contentKeys = <Key>[
        const Key('home-adoption-image'),
        const Key('home-adoption-title'),
        const Key('home-adoption-meta'),
        const Key('home-adoption-cta'),
        const Key('home-adoption-view-more'),
      ];
      expect(card, findsOneWidget);
      final cardRect = tester.getRect(card);
      for (final key in contentKeys) {
        final content = find.byKey(key);
        expect(content, findsOneWidget);
        expect(
          cardRect.contains(tester.getCenter(content)),
          isTrue,
          reason: '$key must remain inside the adoption card at $viewport',
        );
      }

      for (final key in const [
        Key('home-profile-action'),
        Key('home-book-reminder-cta'),
        Key('home-find-vet-shortcut'),
      ]) {
        final actionSize = tester.getSize(find.byKey(key));
        expect(actionSize.width, greaterThanOrEqualTo(48));
        expect(actionSize.height, greaterThanOrEqualTo(48));
        if (key != const Key('home-profile-action')) {
          expect(
            actionSize.width,
            lessThanOrEqualTo(viewport.width * 0.6),
            reason: '$key must remain a compact CTA at $viewport',
          );
        }
      }

      final avatar = find.byKey(const Key('home-pet-avatar-mochi'));
      expect(
        find.descendant(of: avatar, matching: find.byIcon(Icons.pets_rounded)),
        findsOneWidget,
        reason: 'A missing avatar must render an explicit pet fallback.',
      );
      expectNoFlutterOverflow(tester);
    });
  }

  testWidgets('Pet home renders account and selected-pet reminder data', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final dueAt = DateTime.now().add(const Duration(hours: 2));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionSnapshotProvider.overrideWith(
            (ref) async => _homeSession(),
          ),
          petBackendListProvider.overrideWith(
            (ref) async => [
              _samplePet(
                id: 'mochi',
                name: 'Mochi',
                healthStatus: 'needs_vaccine',
                avatarPath: 'assets/images/pets/p1_05_mochi.png',
              ),
            ],
          ),
          upcomingRemindersProvider.overrideWith(
            (ref) async => [
              Reminder(
                id: 'reminder-1',
                petId: 'mochi',
                title: 'Tiêm ngừa cho Mochi',
                reminderAt: dueAt,
                repeatRule: ReminderRepeatRule.none,
                timezone: 'Asia/Bangkok',
                status: ReminderStatus.scheduled,
                createdAt: '2026-07-16T00:00:00.000Z',
                updatedAt: '2026-07-16T00:00:00.000Z',
                note: 'PetCare Elite',
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào buổi sáng, Ngô!'), findsOneWidget);
    expect(find.text('CẦN TIÊM'), findsOneWidget);
    expect(find.text('Tiêm ngừa cho Mochi'), findsOneWidget);
    expect(find.textContaining('PetCare Elite'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-05 pet list opens pet detail and create form', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets/list',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [
              _samplePet(id: 'mochi', name: 'Mochi'),
              _samplePet(id: 'kem', name: 'Kem'),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet-list-featured-mochi')));
    await tester.pumpAndSettle();

    expect(find.text('Pet detail target: mochi'), findsOneWidget);

    router.go('/pets/list');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pet-list-add-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pet-list-add-card')));
    await tester.pumpAndSettle();

    expect(find.text('Create pet target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home add CTA opens pet form at /pets/create', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thú cưng nào'), findsOneWidget);

    await tester.tap(find.text('Thêm thú cưng'));
    await tester.pumpAndSettle();

    expect(find.text('Create pet target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home vet shortcut opens vet list', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-vet-search-action')));
    await tester.pumpAndSettle();

    expect(find.text('Vet list target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home find vet shortcut opens vet finder map', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-find-vet-shortcut')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-find-vet-shortcut')));
    await tester.pumpAndSettle();

    expect(find.text('Vet map target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home nearby clinic card opens vet detail', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-nearby-vet-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-nearby-vet-card')));
    await tester.pumpAndSettle();

    expect(find.text('Vet detail target: pethome-q7'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home health reminder card opens health timeline', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-health-reminder-card')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final healthCard = find.byKey(const Key('home-health-reminder-card'));
    await tester.tapAt(tester.getTopLeft(healthCard) + const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Health timeline target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home reminder CTA opens reminder calendar', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-book-reminder-cta')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-book-reminder-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Reminder calendar target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home defer CTA snoozes a real reminder by one hour', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final now = DateTime(2026, 7, 21, 9, 30);
    final reminder = _sampleReminder(
      id: 'reminder-vaccine',
      petId: 'mochi',
      reminderAt: now.add(const Duration(hours: 2)),
    );
    final fakeApi = _SnoozeReminderApi();
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
      homeNow: now,
    );
    final container = ProviderContainer(
      overrides: [
        petBackendListProvider.overrideWith(
          (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
        ),
        upcomingRemindersProvider.overrideWith((ref) async => [reminder]),
        reminderAccessTokenProvider.overrideWith(
          (ref) async => 'reminder-token',
        ),
        reminderApiProvider.overrideWith((ref) => fakeApi),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-defer-reminder-cta')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('home-defer-reminder-cta')));
    await tester.pumpAndSettle();

    expect(fakeApi.snoozedPetId, 'mochi');
    expect(fakeApi.snoozedReminderId, 'reminder-vaccine');
    expect(fakeApi.snoozedUntil, now.add(const Duration(hours: 1)));
    expect(fakeApi.accessToken, 'reminder-token');
    expect(find.text('Đã nhắc lại sau 1 giờ.'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home defer CTA asks an unauthenticated user to sign in', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 21, 9, 30);
    await _pumpReminderHome(
      tester,
      now: now,
      accessToken: null,
      api: _SnoozeReminderApi(),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-defer-reminder-cta')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('home-defer-reminder-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn cần đăng nhập để dời lịch nhắc.'), findsOneWidget);
  });

  testWidgets('Pet home surfaces a snooze API error without losing context', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 21, 9, 30);
    await _pumpReminderHome(
      tester,
      now: now,
      accessToken: 'reminder-token',
      api: _SnoozeReminderApi(
        failure: const ReminderApiException('Không thể dời lịch lúc này.'),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-defer-reminder-cta')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('home-defer-reminder-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Không thể dời lịch lúc này.'), findsOneWidget);
  });

  testWidgets('Pet home hides defer CTA when no reminder exists', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-defer-reminder-cta')), findsNothing);
    expect(find.text('Tạo lịch'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet home entry cards stay readable on compact large text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final router = _petRouter(
      initialLocation: '/pets',
      includeCreateScreen: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.3),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào buổi sáng, bạn!'), findsOneWidget);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expect(find.text('LỊCH NHẮC SỨC KHỎE'), findsOneWidget);
    expect(find.text('PetHome Q7'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet form save adds pet and returns to refreshed pet list', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _CreatePetApi();
    final container = ProviderContainer(
      overrides: [
        petApiProvider.overrideWith((ref) => fakeApi),
        petAccessTokenProvider.overrideWith((ref) async => 'pet-token'),
        petBackendListProvider.overrideWith(
          (ref) async => ref.watch(petListProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = _petRouter(
      initialLocation: '/pets/create?returnTo=/pets/list',
      includeCreateScreen: true,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ thú cưng'), findsOneWidget);
    expect(find.text('Tên thú cưng *'), findsOneWidget);
    expect(find.text('Loài'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pet-form-name-field')),
        matching: find.byType(TextFormField),
      ),
      'Bắp',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pet-form-breed-field')),
        matching: find.byType(TextFormField),
      ),
      'Golden Retriever',
    );
    await tester.tap(find.byKey(const Key('pet-form-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pet-form-weight-field')),
        matching: find.byType(TextFormField),
      ),
      '12.4',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('pet-form-color-field')),
        matching: find.byType(TextFormField),
      ),
      'Vàng kem',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('pet-form-save-button')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('pet-form-save-button')));
    await tester.pumpAndSettle();

    final pets = container.read(petListProvider);
    expect(pets.any((pet) => pet.name == 'Bắp'), isTrue);
    expect(
      find.byKey(const Key('pet-list-featured-pet-created')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet form blocks submit and shows required validation', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _petRouter(
      initialLocation: '/pets/create',
      includeCreateScreen: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet-form-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tên'), findsOneWidget);
    expect(find.text('Hồ sơ thú cưng'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Pet form stays readable on compact large text', (tester) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final router = _petRouter(
      initialLocation: '/pets/create',
      includeCreateScreen: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.3),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ thú cưng'), findsOneWidget);
    expect(find.byKey(const Key('pet-form-save-button')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

Future<void> _pumpReminderHome(
  WidgetTester tester, {
  required DateTime now,
  required String? accessToken,
  required ReminderApi api,
}) async {
  await setTestViewport(tester, size: const Size(390, 844));
  final router = _petRouter(
    initialLocation: '/pets',
    includeCreateScreen: false,
    homeNow: now,
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      petBackendListProvider.overrideWith(
        (ref) async => [_samplePet(id: 'mochi', name: 'Mochi')],
      ),
      upcomingRemindersProvider.overrideWith(
        (ref) async => [
          _sampleReminder(
            id: 'reminder-vaccine',
            petId: 'mochi',
            reminderAt: now.add(const Duration(hours: 2)),
          ),
        ],
      ),
      reminderAccessTokenProvider.overrideWith((ref) async => accessToken),
      reminderApiProvider.overrideWith((ref) => api),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _petRouter({
  required String initialLocation,
  required bool includeCreateScreen,
  DateTime? homeNow,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/pets',
        builder: (context, state) => PetHomeScreen(now: homeNow),
      ),
      GoRoute(
        path: '/pets/list',
        builder: (context, state) => const PetListScreen(),
      ),
      GoRoute(
        path: '/pets/create',
        builder: (context, state) => includeCreateScreen
            ? CreatePetScreen(returnTo: state.uri.queryParameters['returnTo'])
            : const Scaffold(body: Center(child: Text('Create pet target'))),
      ),
      GoRoute(
        path: '/pets/:id',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('Pet detail target: ${state.pathParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/vets/list',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Vet list target'))),
      ),
      GoRoute(
        path: '/vets/map',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Vet map target'))),
      ),
      GoRoute(
        path: '/vets/:id',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('Vet detail target: ${state.pathParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Health timeline target'))),
      ),
      GoRoute(
        path: '/health/reminders',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Reminder calendar target')),
        ),
      ),
      GoRoute(
        path: '/rescue',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Rescue target'))),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Notifications target'))),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Profile target'))),
      ),
      GoRoute(
        path: '/adoption',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Adoption target'))),
      ),
    ],
  );
}

PetProfile _samplePet({
  required String id,
  required String name,
  String healthStatus = 'healthy',
  String? avatarPath,
}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Poodle',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 6.3,
    healthStatus: healthStatus,
    avatarPath: avatarPath,
    color: 'Apricot',
    isNeutered: true,
  );
}

Reminder _sampleReminder({
  required String id,
  required String petId,
  required DateTime reminderAt,
}) {
  return Reminder(
    id: id,
    petId: petId,
    title: 'Tiêm phòng định kỳ',
    reminderAt: reminderAt,
    repeatRule: ReminderRepeatRule.none,
    timezone: 'Asia/Bangkok',
    status: ReminderStatus.scheduled,
    createdAt: '2026-07-21T00:00:00.000Z',
    updatedAt: '2026-07-21T00:00:00.000Z',
  );
}

AuthSession _homeSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'home-owner',
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
}

class _CreatePetApi extends PetApi {
  _CreatePetApi() : super(Dio());

  @override
  Future<PetProfile> createPet(
    CreatePetProfileInput input, {
    required String accessToken,
  }) async {
    return PetProfile(
      id: 'pet-created',
      name: input.name,
      species: input.species,
      breed: input.breed,
      gender: input.gender,
      dateOfBirth: input.dateOfBirth,
      weightKg: input.weightKg,
      healthStatus: input.healthStatus,
      color: input.color,
      microchip: input.microchip,
      isNeutered: input.isNeutered,
    );
  }
}

class _SnoozeReminderApi extends ReminderApi {
  _SnoozeReminderApi({this.failure}) : super(Dio());

  final Object? failure;

  String? snoozedPetId;
  String? snoozedReminderId;
  DateTime? snoozedUntil;
  String? accessToken;

  @override
  Future<Reminder> snoozeReminder(
    String petId,
    String reminderId,
    DateTime snoozedUntil, {
    required String accessToken,
  }) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    snoozedPetId = petId;
    snoozedReminderId = reminderId;
    this.snoozedUntil = snoozedUntil;
    this.accessToken = accessToken;
    return _sampleReminder(
      id: reminderId,
      petId: petId,
      reminderAt: snoozedUntil,
    );
  }
}

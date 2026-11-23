import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/data/reminder_api.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day116_capture.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R23 C04 P1-14 edit retry persists same record text$scale',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final api = _FakeReminderApi(
          failUpdate: true,
          reminders: [
            _sampleReminder(
              id: 'r23-edit',
              title: 'Lịch ban đầu',
              dueAt: DateTime.now().add(const Duration(days: 2)),
              petId: 'day8-pet',
            ),
          ],
        );
        final router = GoRouter(
          initialLocation: '/health/reminders',
          routes: [
            GoRoute(
              path: '/health/reminders',
              builder: (_, _) => const ReminderCalendarScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              petBackendListProvider.overrideWith(
                (_) async => [_samplePet(name: 'Mochi')],
              ),
              reminderAccessTokenProvider.overrideWith(
                (_) async => 'fixture-token',
              ),
              reminderApiProvider.overrideWithValue(api),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('reminder-menu-r23-edit'));
        await tester.scrollUntilVisible(
          menu,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        // A built menu may still sit under the endFloat action. Use the
        // list's real remaining scroll range before testing the pointer.
        final list = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        list.position.jumpTo(list.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(menu.hitTestable(), findsOneWidget);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chỉnh sửa'));
        await tester.pumpAndSettle();
        final title = find.byKey(const ValueKey('reminder-edit-title-field'));
        await tester.ensureVisible(title);
        await tester.enterText(title, 'Bản nháp không được mất');
        await setKeyboardInset(tester, bottom: 300);
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('reminder-edit-save-button'));
        Future<void> reach() async {
          final outer = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey('reminder-create-sheet-scroll'),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          outer.position.jumpTo(outer.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(save.hitTestable(), findsOneWidget);
          expect(tester.getRect(save).bottom, lessThanOrEqualTo(268));
          expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        }

        await reach();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(api.updateAttempts, 1);
        expect(api.updatedIds, isEmpty);
        expect(api.reminders.single.title, 'Lịch ban đầu');
        expect(
          tester.widget<TextField>(title).controller!.text,
          'Bản nháp không được mất',
        );
        expect(
          find.text('Không thể cập nhật lịch nhắc lúc này.'),
          findsOneWidget,
        );
        await reach();
        await captureDay116(
          tester,
          'R23-C04-P114-failed-text${scale.toString().replaceAll('.', '-')}',
        );
        api.failUpdate = false;
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(api.updateAttempts, 2);
        expect(api.updatedIds, ['r23-edit']);
        expect(api.reminders, hasLength(1));
        expect(api.reminders.single.id, 'r23-edit');
        expect(api.reminders.single.title, 'Bản nháp không được mất');
        expect(find.text('Chỉnh sửa lịch nhắc'), findsNothing);
        await setKeyboardInset(tester, bottom: 0);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final savedTitle = find.text('Bản nháp không được mất');
        await tester.scrollUntilVisible(
          savedTitle,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(savedTitle.hitTestable(), findsOneWidget);
        await captureDay116(
          tester,
          'R23-C04-P114-saved-text${scale.toString().replaceAll('.', '-')}',
        );
        expectNoFlutterOverflow(tester);
      },
    );
  }
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 R9 ST-11 ST-12 P1-14 stored retry with IME text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final api = _FakeReminderApi()..failCreate = true;
      final router = GoRouter(
        initialLocation: '/health/reminders',
        routes: [
          GoRoute(
            path: '/health/reminders',
            builder: (_, _) => const ReminderCalendarScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            petBackendListProvider.overrideWith(
              (ref) async => [_samplePet(name: 'Mochi')],
            ),
            reminderAccessTokenProvider.overrideWith(
              (ref) async => 'test-token',
            ),
            reminderApiProvider.overrideWith((ref) => api),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: testTextScaleBuilder(scale),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final note = find.byKey(const ValueKey('reminder-create-note-field'));
      await tester.ensureVisible(note);
      await tester.enterText(note, 'R9 draft must survive failure');
      await setKeyboardInset(tester, bottom: 300);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('reminder-create-save-button'));
      Future<void> reachSave() async {
        final scroll = find.byKey(
          const ValueKey('reminder-create-sheet-scroll'),
        );
        // The first Scrollable below the keyed SingleChildScrollView is its
        // own viewport; later descendants belong to multiline TextFields.
        // The failure captured both, so an axis-only selector is ambiguous.
        expect(tester.widget(scroll), isA<SingleChildScrollView>());
        final outer = tester.state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        );
        expect(outer.position.axis, Axis.vertical);
        outer.position.jumpTo(outer.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        final rect = tester.getRect(save);
        expect(rect.bottom, lessThanOrEqualTo(268));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(48));
      }

      await reachSave();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.createCalls, 1);
      expect(api.reminders, isEmpty);
      expect(
        tester.widget<TextField>(note).controller?.text,
        'R9 draft must survive failure',
      );
      expect(find.text('Không thể lưu lịch nhắc lúc này.'), findsOneWidget);
      // Error insertion grows scroll content. Prove it can be exposed above
      // the fixed CTA rather than judging a stale scroll offset as clipping.
      await reachSave();
      await captureDay116(
        tester,
        'R9-ST11-P114-text${scale.toString().replaceAll('.', '-')}',
      );
      await reachSave();
      final errorRect = tester.getRect(
        find.text('Không thể lưu lịch nhắc lúc này.'),
      );
      debugPrint(
        'D116_R9_REMINDER_LAYOUT scale=$scale error=$errorRect save=${tester.getRect(save)}',
      );
      expect(errorRect.overlaps(tester.getRect(save)), isFalse);
      expect(errorRect.top, greaterThanOrEqualTo(0));
      expect(errorRect.bottom, lessThanOrEqualTo(268));
      api.failCreate = false;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.createCalls, 2);
      expect(api.reminders, hasLength(1));
      expect(api.reminders.single.note, 'R9 draft must survive failure');
      expect(api.reminders.single.petId, 'day8-pet');
      expect(
        find.byKey(const ValueKey('reminder-create-sheet-viewport')),
        findsNothing,
      );
      await setKeyboardInset(tester, bottom: 0);
      await tester.pumpAndSettle();
      expectNoFlutterOverflow(tester);
    });
  }
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 ST-02 P1-14 actual retry text$scale', (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final api = _FakeReminderApi()..failList = true;
      final router = GoRouter(
        initialLocation: '/health/reminders',
        routes: [
          GoRoute(
            path: '/health/reminders',
            builder: (_, _) => const ReminderCalendarScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            petBackendListProvider.overrideWith(
              (ref) async => [_samplePet(name: 'Mochi')],
            ),
            reminderAccessTokenProvider.overrideWith(
              (ref) async => 'test-token',
            ),
            reminderApiProvider.overrideWith((ref) => api),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: testTextScaleBuilder(scale),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Thử lại'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được lịch nhắc'), findsOneWidget);
      expect(api.listCalls, 1);
      final retry = find.widgetWithText(OutlinedButton, 'Thử lại');
      expect(retry.hitTestable(), findsOneWidget);
      expectNoFlutterOverflow(tester);
      await captureDay116(
        tester,
        'D116-ST02-P114-text${scale.toString().replaceAll('.', '-')}',
      );
      api.failList = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Chưa có lịch nhắc'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(api.listCalls, 2);
      expect(find.text('Chưa có lịch nhắc'), findsOneWidget);
      expect(find.text('Chưa tải được lịch nhắc'), findsNothing);
      expectNoFlutterOverflow(tester);
    });
  }
  testWidgets('reminder calendar keeps a long selected pet name on one line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longPetName = 'Day8 Smoke 20260511045925 Long Selected Pet Name';
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Health target'))),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pets target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vets target'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Notifications target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: longPetName)],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => _FakeReminderApi()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(longPetName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reminder calendar stays readable at 320x568 with text scale 2.0',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final router = GoRouter(
        initialLocation: '/health/reminders',
        routes: [
          GoRoute(
            path: '/health/reminders',
            builder: (context, state) => const ReminderCalendarScreen(),
          ),
          GoRoute(
            path: '/health',
            builder: (context, state) => const Scaffold(body: Text('Health')),
          ),
          GoRoute(
            path: '/pets',
            builder: (context, state) => const Scaffold(body: Text('Pets')),
          ),
          GoRoute(
            path: '/vets/list',
            builder: (context, state) => const Scaffold(body: Text('Vets')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('Profile')),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) =>
                const Scaffold(body: Text('Notifications')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith(
              (ref) async => [_samplePet(name: 'Mochi')],
            ),
            reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
            reminderApiProvider.overrideWith(
              (ref) => _FakeReminderApi(
                reminders: [
                  _sampleReminder(
                    id: 'large-text',
                    title: 'Tiêm phòng định kỳ hằng năm',
                    dueAt: DateTime.now().add(const Duration(hours: 3)),
                    petId: 'day8-pet',
                  ),
                ],
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2.0),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('reminder-back-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reminder-filter-button')),
        findsOneWidget,
      );
      expectNoFlutterOverflow(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(find.text('Tiêm phòng định kỳ hằng năm'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('renders v0.27 reminder calendar shell without mobile overflow', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final fakeApi = _FakeReminderApi(
      reminders: [
        _sampleReminder(
          id: 'overdue',
          title: 'Tiêm nhắc lại (Overdue)',
          dueAt: DateTime.now().subtract(const Duration(hours: 2)),
          petId: 'mochi',
        ),
        _sampleReminder(
          id: 'rabies',
          title: 'Tiêm phòng dại',
          dueAt: DateTime.now().add(const Duration(hours: 3)),
          petId: 'kem',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Health target'))),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pets target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vets target'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Notifications target'))),
        ),
      ],
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
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.1),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch nhắc nhở'), findsOneWidget);
    expect(find.textContaining('Bật thông báo'), findsOneWidget);
    expect(find.text('BẬT'), findsOneWidget);
    expect(find.textContaining('Tháng'), findsOneWidget);
    expect(find.text('Lịch hôm nay'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget);
    for (final key in [
      'reminder-back-button',
      'reminder-filter-button',
      'reminder-notification-enable-button',
    ]) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
    final addFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addFab.isExtended, isFalse);
    expect(
      tester.getSize(find.byType(FloatingActionButton)).width,
      lessThanOrEqualTo(56),
    );
    expectNoFlutterOverflow(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(find.text('Tiêm nhắc lại (Overdue)'), findsOneWidget);
    expect(find.text('TRỄ HẠN'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('Tiêm phòng dại'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Day 28 filters overdue reminders and syncs snooze/done', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeReminderApi(
      reminders: [
        _sampleReminder(
          id: 'overdue-day28',
          title: 'Lịch trễ Day 28',
          dueAt: DateTime.now().subtract(const Duration(hours: 2)),
          petId: 'day8-pet',
        ),
        _sampleReminder(
          id: 'upcoming-day28',
          title: 'Lịch sắp tới Day 28',
          dueAt: DateTime.now().add(const Duration(hours: 3)),
          petId: 'day8-pet',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) => const Scaffold(body: Text('Health')),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) => const Scaffold(body: Text('Pets')),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) => const Scaffold(body: Text('Vets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Text('Notifications')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Milo')],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reminder-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-filter-overdue')));
    await tester.pumpAndSettle();

    expect(find.text('Lịch trễ Day 28'), findsOneWidget);
    expect(find.text('Lịch sắp tới Day 28'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('reminder-menu-overdue-day28')),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-menu-overdue-day28')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhắc lại sau 1 giờ'));
    await tester.pumpAndSettle();

    expect(fakeApi.snoozedIds, ['overdue-day28']);
    expect(find.text('Lịch trễ Day 28'), findsNothing);

    final activeFilterChip = find.byKey(
      const ValueKey('reminder-filter-button'),
    );
    await tester.ensureVisible(activeFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(activeFilterChip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-filter-upcoming')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reminder-menu-overdue-day28')),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-menu-overdue-day28')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();

    expect(fakeApi.doneIds, ['overdue-day28']);
    expect(find.text('Lịch trễ Day 28'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('requires confirmation before deleting a reminder', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeReminderApi(
      reminders: [
        _sampleReminder(
          id: 'delete-confirmation',
          title: 'Lịch cần xác nhận xóa',
          dueAt: DateTime.now().add(const Duration(hours: 3)),
          petId: 'day8-pet',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Milo')],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('reminder-menu-delete-confirmation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.text('Xóa lịch nhắc?'), findsOneWidget);
    expect(fakeApi.deletedIds, isEmpty);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(fakeApi.deletedIds, isEmpty);
    expect(find.text('Lịch cần xác nhận xóa'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('reminder-menu-delete-confirmation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(fakeApi.deletedIds, ['delete-confirmation']);
    expect(find.text('Lịch cần xác nhận xóa'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('reminder create sheet stays usable with keyboard open', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final fakeApi = _FakeReminderApi();
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Health target'))),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pets target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vets target'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Milo')],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byKey(const ValueKey('reminder-create-date-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('reminder-create-time-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-create-time-button')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
    await tester.pumpAndSettle();

    final noteField = find.byKey(const ValueKey('reminder-create-note-field'));
    await tester.tap(noteField);
    await setKeyboardInset(tester, bottom: 300);
    await tester.enterText(
      noteField,
      'Keyboard open reminder note remains scrollable.',
    );
    final saveButton = find.byKey(
      const ValueKey('reminder-create-save-button'),
    );
    final sheetViewport = find.byKey(
      const ValueKey('reminder-create-sheet-viewport'),
    );
    final sheetScrollStates = tester
        .stateList<ScrollableState>(
          find.descendant(of: sheetViewport, matching: find.byType(Scrollable)),
        )
        // Text metrics change after real test fonts are loaded for capture.
        // Require a unique vertically scrollable sheet, not an arbitrary
        // 500px content height; actual CTA/keyboard bounds are checked below.
        .where(
          (state) =>
              state.position.axis == Axis.vertical &&
              state.position.maxScrollExtent > 0,
        )
        .toList(growable: false);
    expect(sheetScrollStates, hasLength(1));
    sheetScrollStates.single.position.jumpTo(
      sheetScrollStates.single.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(MediaQuery.viewInsetsOf(tester.element(saveButton)).bottom, 300);
    final sheetViewportSize = tester.getSize(sheetViewport);
    expect(sheetViewportSize.height, greaterThan(0));
    expect(sheetViewportSize.height, lessThanOrEqualTo(268));
    expect(tester.getRect(sheetViewport).bottom, lessThanOrEqualTo(268));
    final keyboardTop = 568 - 300.0;
    final saveRect = tester.getRect(saveButton);
    expect(saveRect.top, greaterThanOrEqualTo(0));
    expect(saveRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(tester.getSize(saveButton).height, greaterThanOrEqualTo(48));
    expectNoFlutterOverflow(tester);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(fakeApi.createdPetId, 'day8-pet');
    expect(fakeApi.createdAccessToken, 'token');
    expect(
      fakeApi.createdInput?.note,
      'Keyboard open reminder note remains scrollable.',
    );
  });

  testWidgets('Day96 reminder exposes an editable prefilled surface', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeReminderApi(
      reminders: [
        _sampleReminder(
          id: 'day96-edit',
          title: 'Tái khám Day 96',
          dueAt: DateTime.now().add(const Duration(days: 2)),
          petId: 'day8-pet',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Milo')],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-menu-day96-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa'), findsOneWidget);
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();
    final titleField = find.byKey(const ValueKey('reminder-edit-title-field'));
    expect(
      tester.widget<TextField>(titleField).controller?.text,
      'Tái khám Day 96',
    );
    await tester.enterText(titleField, 'Tái khám Day 96 đã sửa');
    await tester.tap(find.byKey(const ValueKey('reminder-edit-save-button')));
    await tester.pumpAndSettle();
    expect(fakeApi.updatedIds, ['day96-edit']);
    expect(fakeApi.updatedInput?.title, 'Tái khám Day 96 đã sửa');
    expect(find.text('Chỉnh sửa lịch nhắc'), findsNothing);
  });

  testWidgets('Day96 keeps edited reminder draft after update failure', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeReminderApi(
      failUpdate: true,
      reminders: [
        _sampleReminder(
          id: 'day96-recovery',
          title: 'Lịch nhắc ban đầu',
          dueAt: DateTime.now().add(const Duration(days: 2)),
          petId: 'day8-pet',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health/reminders',
      routes: [
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) => const ReminderCalendarScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Milo')],
          ),
          reminderAccessTokenProvider.overrideWith((ref) async => 'token'),
          reminderApiProvider.overrideWith((ref) => fakeApi),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('reminder-menu-day96-recovery')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('reminder-edit-title-field'));
    await tester.enterText(field, 'Bản nháp không được mất');
    await tester.tap(find.byKey(const ValueKey('reminder-edit-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa lịch nhắc'), findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Bản nháp không được mất',
    );
    expect(find.text('Không thể cập nhật lịch nhắc lúc này.'), findsOneWidget);
  });
}

class _FakeReminderApi extends ReminderApi {
  _FakeReminderApi({
    List<Reminder> reminders = const [],
    this.failUpdate = false,
  }) : reminders = [...reminders],
       super(Dio());

  final List<Reminder> reminders;
  bool failList = false;
  bool failCreate = false;
  int createCalls = 0;
  int listCalls = 0;
  bool failUpdate;
  int updateAttempts = 0;
  String? createdPetId;
  String? createdAccessToken;
  CreateReminderInput? createdInput;
  CreateReminderInput? updatedInput;
  final List<String> updatedIds = [];
  final List<String> snoozedIds = [];
  final List<String> doneIds = [];
  final List<String> deletedIds = [];

  @override
  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    listCalls++;
    if (failList) {
      throw const ReminderApiException(
        'Máy chủ lịch nhắc tạm thời chưa sẵn sàng.',
        statusCode: 503,
      );
    }
    return ReminderListResult(
      items: reminders,
      total: reminders.length,
      limit: query.limit,
    );
  }

  @override
  Future<Reminder> createReminder(
    String petId,
    CreateReminderInput input, {
    required String accessToken,
  }) async {
    createdPetId = petId;
    createCalls++;
    if (failCreate) {
      throw const ReminderApiException(
        'Không thể lưu lịch nhắc lúc này.',
        statusCode: 503,
      );
    }
    createdAccessToken = accessToken;
    createdInput = input;

    final reminder = Reminder(
      id: 'created-reminder',
      petId: petId,
      title: input.title,
      note: input.note,
      reminderAt: input.reminderAt,
      repeatRule: input.repeatRule,
      timezone: input.timezone,
      status: ReminderStatus.scheduled,
      createdAt: '2026-05-13T00:00:00.000Z',
      updatedAt: '2026-05-13T00:00:00.000Z',
    );
    reminders.insert(0, reminder);
    return reminder;
  }

  @override
  Future<Reminder> updateReminder(
    String petId,
    String reminderId,
    CreateReminderInput input, {
    required String accessToken,
  }) async {
    updateAttempts++;
    if (failUpdate) {
      throw const ReminderApiException(
        'Không thể cập nhật lịch nhắc lúc này.',
        code: 'REMINDER_CONFLICT',
        statusCode: 409,
      );
    }
    updatedIds.add(reminderId);
    updatedInput = input;
    final index = reminders.indexWhere((item) => item.id == reminderId);
    final source = reminders[index];
    final updated = Reminder(
      id: source.id,
      petId: source.petId,
      title: input.title,
      note: input.note,
      reminderAt: input.reminderAt,
      nextTriggerAt: input.reminderAt,
      lastTriggeredAt: source.lastTriggeredAt,
      repeatRule: input.repeatRule,
      timezone: input.timezone,
      status: source.status,
      completedAt: source.completedAt,
      cancelledAt: source.cancelledAt,
      snoozedUntil: source.snoozedUntil,
      createdAt: source.createdAt,
      updatedAt: '2026-08-28T00:00:00.000Z',
    );
    reminders[index] = updated;
    return updated;
  }

  @override
  Future<Reminder> snoozeReminder(
    String petId,
    String reminderId,
    DateTime snoozedUntil, {
    required String accessToken,
  }) async {
    snoozedIds.add(reminderId);
    final index = reminders.indexWhere((item) => item.id == reminderId);
    final updated = _copyReminder(
      reminders[index],
      nextTriggerAt: snoozedUntil,
      snoozedUntil: snoozedUntil,
    );
    reminders[index] = updated;
    return updated;
  }

  @override
  Future<Reminder> markDone(
    String petId,
    String reminderId, {
    required String accessToken,
  }) async {
    doneIds.add(reminderId);
    final index = reminders.indexWhere((item) => item.id == reminderId);
    final updated = _copyReminder(
      reminders[index],
      status: ReminderStatus.done,
      completedAt: DateTime.now(),
    );
    reminders[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteReminder(
    String petId,
    String reminderId, {
    required String accessToken,
  }) async {
    deletedIds.add(reminderId);
    reminders.removeWhere((item) => item.id == reminderId);
  }
}

PetProfile _samplePet({String id = 'day8-pet', required String name}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'QA Mix',
    gender: 'male',
    dateOfBirth: DateTime(2022, 5, 11),
    weightKg: 9.8,
    healthStatus: 'healthy',
  );
}

Reminder _sampleReminder({
  required String id,
  required String title,
  required DateTime dueAt,
  required String petId,
}) {
  return Reminder(
    id: id,
    petId: petId,
    title: title,
    reminderAt: dueAt,
    nextTriggerAt: dueAt,
    repeatRule: ReminderRepeatRule.none,
    timezone: 'Asia/Bangkok',
    status: ReminderStatus.scheduled,
    createdAt: '2026-05-13T00:00:00.000Z',
    updatedAt: '2026-05-13T00:00:00.000Z',
  );
}

Reminder _copyReminder(
  Reminder source, {
  DateTime? nextTriggerAt,
  DateTime? snoozedUntil,
  DateTime? completedAt,
  ReminderStatus? status,
}) {
  return Reminder(
    id: source.id,
    petId: source.petId,
    title: source.title,
    note: source.note,
    reminderAt: source.reminderAt,
    nextTriggerAt: nextTriggerAt ?? source.nextTriggerAt,
    lastTriggeredAt: source.lastTriggeredAt,
    repeatRule: source.repeatRule,
    timezone: source.timezone,
    status: status ?? source.status,
    completedAt: completedAt ?? source.completedAt,
    cancelledAt: source.cancelledAt,
    snoozedUntil: snoozedUntil ?? source.snoozedUntil,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
  );
}

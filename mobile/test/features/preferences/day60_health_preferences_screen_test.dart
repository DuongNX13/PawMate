import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/health_hub/application/health_knowledge_provider.dart';
import 'package:pawmate_mobile/features/health_hub/domain/health_knowledge.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/profile/presentation/notification_preferences_screen.dart';
import 'package:pawmate_mobile/features/vets/application/vet_finder_session_provider.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day114_capture.dart';

const _userId = '60000000-0000-4000-8000-000000000001';
final _updatedAt = DateTime.utc(2026, 7, 29, 10);

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final small in [false, true]) {
    testWidgets('D114 ST-04 Health Hub empty pet recovery small=$small', (
      tester,
    ) async {
      await setTestViewport(
        tester,
        size: small ? const Size(320, 568) : const Size(390, 844),
      );
      final router = GoRouter(
        initialLocation: '/health/hub',
        routes: [
          GoRoute(
            path: '/health/hub',
            builder: (_, _) => const HealthHubScreen(),
          ),
          GoRoute(
            path: '/pets/create',
            builder: (_, _) =>
                const Scaffold(body: Text('Pet creation target')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [petBackendListProvider.overrideWith((ref) async => [])],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: testTextScaleBuilder(small ? 2 : 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Khỏe mạnh'), findsNothing);
      final add = find.text('Thêm hồ sơ thú cưng');
      expect(add, findsOneWidget);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      expect(add.hitTestable(), findsOneWidget);
      await captureDay114(
        tester,
        small ? 'ST-04-hub-small-text2' : 'ST-04-hub',
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Pet creation target'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    });
  }

  testWidgets(
    'D111-OS-01 unsupported OS permission integration gives honest manual guidance',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = _FakePreferenceSource();
      await _pumpPreferences(tester, source);
      expect(
        find.textContaining('cài đặt hệ thống của điện thoại'),
        findsOneWidget,
      );
      expect(find.text('Đã cấp quyền thông báo'), findsNothing);
      expect(find.text('Mở cài đặt'), findsNothing);
      expect(source.updateCalls, 0);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('emergency CTA deep-links to Vet with emergency filters', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/health/knowledge',
      routes: [
        GoRoute(
          path: '/health/knowledge',
          builder: (_, _) => const HealthHubScreen(),
        ),
        GoRoute(
          path: '/vets/map',
          builder: (_, state) => Scaffold(
            body: Text('Vet target ${state.uri.queryParameters['source']}'),
          ),
        ),
        GoRoute(
          path: '/profile/notifications',
          builder: (_, _) => const Scaffold(body: Text('Settings target')),
        ),
        GoRoute(
          path: '/health',
          builder: (_, _) => const Scaffold(body: Text('Health target')),
        ),
        GoRoute(
          path: '/health/reminders',
          builder: (_, _) => const Scaffold(body: Text('Reminder target')),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [petBackendListProvider.overrideWith((ref) async => [])],
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
      find.byKey(const Key('health-hub-emergency-vet')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('health-hub-emergency-vet')));
    await tester.pumpAndSettle();

    expect(find.text('Vet target health-emergency'), findsOneWidget);
    final finder = container.read(vetFinderSessionProvider);
    expect(finder.only24h, isTrue);
    expect(finder.openNow, isTrue);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('loads, saves, and reopens server notification preferences', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource();

    await _pumpPreferences(tester, source);
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const Key('preference-chat-messages')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('preference-chat-messages')));
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(source.updateCalls, 1);
    expect(source.current.chatMessages, isFalse);
    expect(find.text('Đã lưu cài đặt thông báo.'), findsOneWidget);
    await captureDay114(tester, 'ST-11');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpPreferences(tester, source);
    expect(source.loadCalls, greaterThanOrEqualTo(2));
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const Key('preference-chat-messages')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isFalse,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('save failure preserves draft and exposes recoverable error', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource(failSave: true);

    await _pumpPreferences(tester, source);
    await tester.tap(find.byKey(const Key('preference-adoption-updates')));
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(
      find.text('Mạng đang gián đoạn. Bản nháp vẫn được giữ.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const Key('preference-adoption-updates')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isFalse,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label?.contains('Lỗi lưu cài đặt') == true,
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.text('Mạng đang gián đoạn. Bản nháp vẫn được giữ.'),
    );
    await captureDay114(tester, 'ST-12');
    expectNoFlutterOverflow(tester);
  });

  testWidgets('load failure retries into the server form', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _FakePreferenceSource(failLoadCount: 100);

    await _pumpPreferences(tester, source);
    expect(find.text('Chưa tải được cài đặt'), findsOneWidget);
    expect(find.text('Mạng đang gián đoạn khi tải cài đặt.'), findsOneWidget);
    source.failLoadCount = 0;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(source.loadCalls, greaterThanOrEqualTo(2));
    expect(
      find.byKey(const Key('notification-preferences-scroll')),
      findsOneWidget,
    );
  });

  testWidgets(
    'quiet hours uses checkbox semantics and deterministic defaults',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      await _pumpPreferences(tester, _FakePreferenceSource());

      final quietRow = find.byKey(const Key('preference-quiet-hours'));
      await tester.scrollUntilVisible(
        quietRow,
        220,
        scrollable: find.descendant(
          of: find.byKey(const Key('notification-preferences-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      final quietCheckbox = tester.widget<Checkbox>(
        find.descendant(of: quietRow, matching: find.byType(Checkbox)),
      );
      expect(quietCheckbox.value, isFalse);
      expect(quietCheckbox.semanticLabel, 'Giờ yên tĩnh');
      await tester.ensureVisible(quietRow);
      await tester.tap(quietRow);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quiet-hours-start')), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: quietRow, matching: find.byType(Checkbox)),
            )
            .value,
        isTrue,
      );
      await tester.tap(quietRow);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quiet-hours-start')), findsNothing);
    },
  );

  testWidgets('quiet time picker updates draft and rejects equal endpoints', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final selections = <TimeOfDay>[
      const TimeOfDay(hour: 21, minute: 30),
      const TimeOfDay(hour: 7, minute: 0),
    ];
    var selectionIndex = 0;
    await _pumpPreferences(
      tester,
      _FakePreferenceSource(
        initial: _preferences(
          quietHoursEnabled: true,
          quietHoursStart: '22:00',
          quietHoursEnd: '07:00',
        ),
      ),
      screen: NotificationPreferencesScreen(
        timePicker: (_, _, _) async => selections[selectionIndex++],
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('quiet-hours-start')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('notification-preferences-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiet-hours-start')));
    await tester.pumpAndSettle();
    expect(find.text('21:30'), findsOneWidget);

    await _pumpPreferences(
      tester,
      _FakePreferenceSource(
        initial: _preferences(
          quietHoursEnabled: true,
          quietHoursStart: '21:30',
          quietHoursEnd: '07:00',
        ),
      ),
      screen: NotificationPreferencesScreen(
        timePicker: (_, _, _) async => const TimeOfDay(hour: 7, minute: 0),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('quiet-hours-start')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const Key('notification-preferences-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiet-hours-start')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('notification-preferences-scroll')),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Giờ bắt đầu và kết thúc phải khác nhau.'),
      findsOneWidget,
    );
  });

  test('health knowledge provider filters bundled editorial content', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(filteredHealthKnowledgeProvider), hasLength(3));
    container
        .read(healthKnowledgeFilterProvider.notifier)
        .select(HealthKnowledgeFilter.nutrition);
    final filtered = container.read(filteredHealthKnowledgeProvider);

    expect(filtered, hasLength(1));
    expect(filtered.single.filter, HealthKnowledgeFilter.nutrition);
  });

  testWidgets('screens remain scrollable at 320dp and text scale 2.0', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 700));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [petBackendListProvider.overrideWith((ref) async => [])],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const HealthHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-hub-scroll')), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
          preferenceSourceProvider.overrideWithValue(_FakePreferenceSource()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const NotificationPreferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('notification-preferences-scroll')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-13 keeps the emergency-vet action reachable at 320dp with large text',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [petBackendListProvider.overrideWith((ref) async => [])],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const HealthHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emergencyAction = find.byKey(const Key('health-hub-emergency-vet'));
      await tester.scrollUntilVisible(
        emergencyAction,
        260,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('health-hub-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(emergencyAction);
      await tester.pumpAndSettle();

      final visibleBottom = tester.getBottomRight(emergencyAction).dy;
      expect(tester.getSize(emergencyAction).height, greaterThanOrEqualTo(48));
      expect(visibleBottom, lessThanOrEqualTo(568));
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'P2-14 keeps quiet-hours controls reachable at 320dp with large text',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final source = _FakePreferenceSource(
        initial: _preferences(
          quietHoursEnabled: true,
          quietHoursStart: '22:00',
          quietHoursEnd: '07:00',
        ),
      );

      await _pumpPreferences(
        tester,
        source,
        textScaler: const TextScaler.linear(2),
      );

      final start = find.byKey(const Key('quiet-hours-start'));
      await tester.scrollUntilVisible(
        start,
        240,
        scrollable: find.descendant(
          of: find.byKey(const Key('notification-preferences-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();

      expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
      expect(find.byKey(const Key('quiet-hours-end')), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );
}

Future<void> _pumpPreferences(
  WidgetTester tester,
  PreferenceSource source, {
  Widget screen = const NotificationPreferencesScreen(),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
        preferenceSourceProvider.overrideWithValue(source),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

NotificationPreferences _preferences({
  int version = 1,
  bool nearbyLostCases = true,
  bool chatMessages = true,
  bool adoptionUpdates = true,
  bool quietHoursEnabled = false,
  String? quietHoursStart,
  String? quietHoursEnd,
}) {
  return NotificationPreferences(
    userId: _userId,
    version: version,
    nearbyLostCases: nearbyLostCases,
    chatMessages: chatMessages,
    adoptionUpdates: adoptionUpdates,
    quietHoursEnabled: quietHoursEnabled,
    quietHoursStart: quietHoursStart,
    quietHoursEnd: quietHoursEnd,
    updatedAt: _updatedAt,
  );
}

class _FakePreferenceSource implements PreferenceSource {
  _FakePreferenceSource({
    this.failSave = false,
    this.failLoadCount = 0,
    NotificationPreferences? initial,
  }) : current = initial ?? _preferences();

  final bool failSave;
  int failLoadCount;
  NotificationPreferences current;
  int loadCalls = 0;
  int updateCalls = 0;

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async {
    loadCalls += 1;
    if (failLoadCount > 0) {
      failLoadCount -= 1;
      throw const PreferenceApiException(
        'Mạng đang gián đoạn khi tải cài đặt.',
        code: 'NETWORK_OFFLINE',
      );
    }
    return current;
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async {
    updateCalls += 1;
    if (failSave) {
      throw const PreferenceApiException(
        'Mạng đang gián đoạn. Bản nháp vẫn được giữ.',
        code: 'NETWORK_OFFLINE',
      );
    }
    current = _preferences(
      version: preferences.version + 1,
      nearbyLostCases: preferences.nearbyLostCases,
      chatMessages: preferences.chatMessages,
      adoptionUpdates: preferences.adoptionUpdates,
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietHoursStart: preferences.quietHoursStart,
      quietHoursEnd: preferences.quietHoursEnd,
    );
    return current;
  }

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

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/data/health_record_api.dart';
import 'package:pawmate_mobile/features/health/domain/health_record.dart';
import 'package:pawmate_mobile/features/health/presentation/add_health_event_screen.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/reminders/domain/reminder.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('health timeline shows backend loading state', (tester) async {
    final completer = Completer<HealthRecordListResult>();
    final fakeApi = _FakeHealthRecordApi(
      records: [],
      listHandler: (_, {required accessToken}) => completer.future,
    );
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Đang đồng bộ'), findsWidgets);

    completer.complete(
      const HealthRecordListResult(items: [], total: 0, limit: 20),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có sự kiện'), findsOneWidget);
  });

  testWidgets('health timeline keeps bottom navigation reachable', (
    tester,
  ) async {
    final fakeApi = _FakeHealthRecordApi(
      records: [
        _sampleRecord(
          title: 'Tiêm nhắc lại 5 bệnh',
          note: 'Theo dõi phản ứng trong 24 giờ sau mũi tiêm.',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile target'))),
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
          path: '/rescue',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Rescue target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
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

    expect(find.text('Sức khỏe'), findsWidgets);
    expect(find.text('Thêm sự kiện'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Vet'), findsOneWidget);
    expect(find.text('Sức khỏe'), findsWidgets);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Rescue'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Tiêm nhắc lại 5 bệnh'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile target'), findsOneWidget);
  });

  testWidgets('renders v0.27 health timeline shell without mobile overflow', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final fakeApi = _FakeHealthRecordApi(
      records: [
        _sampleRecord(
          id: 'vaccination',
          title: 'Tiêm phòng dại',
          note: 'Vaccine dại 3 năm (Rabies)',
        ),
        _sampleRecord(
          id: 'weight',
          type: HealthRecordType.checkup,
          title: 'Kiểm tra cân nặng',
          note: '+0.2kg',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) async => [_samplePet(name: 'Mochi')],
          ),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith(
            (ref) async => [_sampleReminder()],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.1),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mochi'), findsOneWidget);
    expect(find.text('Sức khỏe'), findsWidgets);
    expect(find.text('NHẮC NHỞ SẮP TỚI'), findsOneWidget);
    expect(find.textContaining('Tiêm ngừa dại'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Vaccine'), findsOneWidget);
    expect(find.text('Cân nặng'), findsOneWidget);
    expect(find.text('Tiêm phòng dại'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('health-filter-Tất cả'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      MediaQuery.sizeOf(
        tester.element(find.byType(HealthTimelineScreen)),
      ).width,
      360,
    );
    final addFab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addFab.isExtended, isFalse);
    expect(
      tester.getSize(find.byType(FloatingActionButton)).width,
      lessThanOrEqualTo(56),
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('health timeline shows auth error when token is missing', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordAccessTokenProvider.overrideWith((ref) async => null),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa đồng bộ được'), findsOneWidget);
    expect(
      find.text('Bạn cần đăng nhập để đồng bộ hồ sơ sức khỏe.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets(
    'health timeline opens P1-13 and creates a backend-backed event',
    (tester) async {
      final fakeApi = _FakeHealthRecordApi(records: []);
      final router = GoRouter(
        initialLocation: '/health',
        routes: [
          GoRoute(
            path: '/health',
            builder: (context, state) => const HealthTimelineScreen(),
          ),
          GoRoute(
            path: '/health/events/new',
            builder: (context, state) => AddHealthEventScreen(
              initialPetId: state.uri.queryParameters['petId'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
            healthRecordApiProvider.overrideWith((ref) => fakeApi),
            healthRecordAccessTokenProvider.overrideWith(
              (ref) async => 'health-token',
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

      expect(find.text('Chưa có sự kiện'), findsOneWidget);

      await tester.tap(find.text('Thêm sự kiện').last);
      await tester.pumpAndSettle();

      expect(find.text('Thêm sự kiện sức khỏe'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('add-health-date-field')),
      );
      // The fixed save CTA intentionally overlays the bottom edge of the form.
      // Move the picker row into the unobscured content area before tapping it.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-health-date-field')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('add-health-time-field')),
      );
      await tester.tap(find.byKey(const Key('add-health-time-field')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('add-health-note-input')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('add-health-note-input')),
        'Bé uống thuốc đúng lịch.',
      );
      await tester.tap(find.byKey(const Key('add-health-save-button')));
      await tester.pumpAndSettle();

      expect(fakeApi.createdPetId, 'milo');
      expect(fakeApi.createdAccessToken, 'health-token');
      expect(fakeApi.createdInput?.type, HealthRecordType.vaccination);
      expect(find.text('Bé uống thuốc đúng lịch.'), findsOneWidget);
    },
  );

  testWidgets('P1-13 add health event screen stays usable with keyboard open', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final fakeApi = _FakeHealthRecordApi(records: []);
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthTimelineScreen(),
        ),
        GoRoute(
          path: '/health/events/new',
          builder: (context, state) => AddHealthEventScreen(
            initialPetId: state.uri.queryParameters['petId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.3),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Thêm sự kiện sức khỏe'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('add-health-note-input')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-health-note-input')));
    await setKeyboardInset(tester, bottom: 300);
    await tester.enterText(
      find.byKey(const Key('add-health-note-input')),
      'Keyboard open health note remains scrollable.',
    );
    await tester.ensureVisible(find.byKey(const Key('add-health-save-button')));
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byKey(const Key('add-health-save-button')));
    await tester.pumpAndSettle();

    expect(fakeApi.createdAccessToken, 'health-token');
    expect(
      fakeApi.createdInput?.note,
      'Keyboard open health note remains scrollable.',
    );
  });

  testWidgets('Day27 groups same-day records and filters by event type', (
    tester,
  ) async {
    final fakeApi = _FakeHealthRecordApi(
      records: [
        _sampleRecord(
          id: 'vaccination-morning',
          date: '2026-05-06',
          time: '08:15',
          title: 'Tiêm phòng buổi sáng',
        ),
        _sampleRecord(
          id: 'checkup-afternoon',
          type: HealthRecordType.checkup,
          date: '2026-05-06',
          time: '15:30',
          title: 'Khám cân nặng buổi chiều',
        ),
        _sampleRecord(
          id: 'older-deworming',
          type: HealthRecordType.deworming,
          date: '2026-05-05',
          title: 'Tẩy giun hôm trước',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HealthTimelineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('health-timeline-date-2026-05-06')),
      findsOneWidget,
    );
    expect(find.text('Ngày 06/05/2026'), findsOneWidget);
    expect(find.text('15:30', findRichText: true), findsNothing);
    expect(find.textContaining('15:30'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('health-timeline-date-2026-05-05')),
      findsOneWidget,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cân nặng'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastQuery?.type, HealthRecordType.checkup);
    expect(find.text('Khám cân nặng buổi chiều'), findsOneWidget);
    expect(find.text('Tiêm phòng buổi sáng'), findsNothing);
    expect(
      find.byKey(const Key('health-timeline-date-2026-05-06')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('health-timeline-date-2026-05-05')),
      findsNothing,
    );
  });

  testWidgets('Day29 switches pet and reloads the selected Health timeline', (
    tester,
  ) async {
    final fakeApi = _FakeHealthRecordApi(
      records: [
        _sampleRecord(
          id: 'mochi-record',
          petId: 'mochi',
          title: 'Hồ sơ của Mochi',
        ),
        _sampleRecord(id: 'kem-record', petId: 'kem', title: 'Hồ sơ của Kem'),
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
          healthRecordApiProvider.overrideWith((ref) => fakeApi),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
          upcomingRemindersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HealthTimelineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ của Mochi'), findsOneWidget);
    expect(find.text('Hồ sơ của Kem'), findsNothing);

    await tester.tap(find.byTooltip('Chọn thú cưng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kem').last);
    await tester.pumpAndSettle();

    expect(fakeApi.lastQuery?.petId, 'kem');
    expect(find.text('Hồ sơ của Mochi'), findsNothing);
    expect(find.text('Hồ sơ của Kem'), findsOneWidget);
  });

  testWidgets(
    'Day27 keeps form draft and selected time after network failure',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final fakeApi = _FakeHealthRecordApi(records: [], failCreate: true);
      final router = GoRouter(
        initialLocation: '/health/events/new?petId=milo',
        routes: [
          GoRoute(
            path: '/health',
            builder: (context, state) => const HealthTimelineScreen(),
          ),
          GoRoute(
            path: '/health/events/new',
            builder: (context, state) => AddHealthEventScreen(
              initialPetId: state.uri.queryParameters['petId'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
            healthRecordApiProvider.overrideWith((ref) => fakeApi),
            healthRecordAccessTokenProvider.overrideWith(
              (ref) async => 'health-token',
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

      final clinicField = find.byKey(const Key('add-health-clinic-input'));
      final noteField = find.byKey(const Key('add-health-note-input'));
      await tester.scrollUntilVisible(
        clinicField,
        420,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(clinicField, 'PetCare Elite');
      await tester.scrollUntilVisible(
        noteField,
        420,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(noteField, 'Giữ lại ghi chú để thử lại.');
      await tester.tap(find.byKey(const Key('add-health-save-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Mất kết nối. Dữ liệu vẫn được giữ để thử lại.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(clinicField).controller?.text,
        'PetCare Elite',
      );
      expect(
        tester.widget<TextField>(noteField).controller?.text,
        'Giữ lại ghi chú để thử lại.',
      );
      expect(fakeApi.createdInput?.time, '09:30');
      expect(fakeApi.createdInput?.toJson()['time'], '09:30');
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/health/events/new',
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('Day27 disables save when the owner has no pet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) async => const []),
          healthRecordApiProvider.overrideWith(
            (ref) => _FakeHealthRecordApi(records: []),
          ),
          healthRecordAccessTokenProvider.overrideWith(
            (ref) async => 'health-token',
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AddHealthEventScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thú cưng'), findsOneWidget);
    expect(find.text('Thêm thú cưng'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('add-health-save-button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(saveButton.onPressed, isNull);
  });
}

class _FakeHealthRecordApi extends HealthRecordApi {
  _FakeHealthRecordApi({
    required List<HealthRecord> records,
    this.listHandler,
    this.failCreate = false,
  }) : records = [...records],
       super(Dio());

  final List<HealthRecord> records;
  final Future<HealthRecordListResult> Function(
    HealthRecordListQuery query, {
    required String accessToken,
  })?
  listHandler;
  final bool failCreate;
  HealthRecordListQuery? lastQuery;
  String? createdPetId;
  String? createdAccessToken;
  CreateHealthRecordInput? createdInput;

  @override
  Future<HealthRecordListResult> listRecords(
    HealthRecordListQuery query, {
    required String accessToken,
  }) async {
    lastQuery = query;
    final handler = listHandler;
    if (handler != null) {
      return handler(query, accessToken: accessToken);
    }

    final items = records
        .where((record) => record.petId == query.petId)
        .where((record) => query.type == null || record.type == query.type)
        .toList();

    return HealthRecordListResult(
      items: items,
      total: items.length,
      limit: query.limit,
    );
  }

  @override
  Future<HealthRecord> createRecord(
    String petId,
    CreateHealthRecordInput input, {
    required String accessToken,
  }) async {
    createdPetId = petId;
    createdAccessToken = accessToken;
    createdInput = input;

    if (failCreate) {
      throw const HealthRecordApiException(
        'Mất kết nối. Dữ liệu vẫn được giữ để thử lại.',
        code: 'NETWORK_ERROR',
      );
    }

    final record = _sampleRecord(
      id: 'created-record',
      petId: petId,
      type: input.type,
      title: input.title,
      note: input.note,
    );
    records.insert(0, record);
    return record;
  }
}

PetProfile _samplePet({String id = 'milo', String name = 'Milo'}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Poodle',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 6.3,
    healthStatus: 'healthy',
  );
}

Reminder _sampleReminder() {
  final dueAt = DateTime.now().add(const Duration(days: 1));
  return Reminder(
    id: 'reminder-1',
    petId: 'milo',
    title: 'Tiêm ngừa dại',
    reminderAt: dueAt,
    nextTriggerAt: dueAt,
    repeatRule: ReminderRepeatRule.none,
    timezone: 'Asia/Bangkok',
    status: ReminderStatus.scheduled,
    createdAt: '2026-05-05T00:00:00.000Z',
    updatedAt: '2026-05-05T00:00:00.000Z',
  );
}

HealthRecord _sampleRecord({
  String id = 'record-1',
  String petId = 'milo',
  HealthRecordType type = HealthRecordType.vaccination,
  String date = '2026-05-05',
  String? time,
  String title = 'Tiêm phòng',
  String? note,
}) {
  return HealthRecord(
    id: id,
    petId: petId,
    type: type,
    date: date,
    time: time,
    title: title,
    note: note,
    attachments: const [],
    createdAt: '2026-05-05T00:00:00.000Z',
    updatedAt: '2026-05-05T00:00:00.000Z',
  );
}

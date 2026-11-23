import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day27-health-golden-root');
const _responsiveViewports = [
  Size(320, 568),
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];

Future<void> pumpDay120HealthEvent(WidgetTester tester, Size size) =>
    _pumpHealthScreen(
      tester,
      AddHealthEventScreen(
        initialPetId: 'mochi',
        initialDate: DateTime(2023, 10, 24),
      ),
      viewport: size,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-12 Health Timeline golden at 390x844', (tester) async {
    await _pumpHealthScreen(tester, HealthTimelineScreen(now: () => _now));
    expect(find.text('Ngày 04/05/2026'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('health-reminder-hero'))).height,
      96,
    );
    expect(
      tester.getSize(find.byKey(const Key('health-event-vaccination'))).width,
      298,
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day27/p1-12-health-timeline-390x844.png'),
    );
  });

  testWidgets('P1-13 Add Health Event golden at 390x844', (tester) async {
    await _pumpHealthScreen(
      tester,
      AddHealthEventScreen(
        initialPetId: 'mochi',
        initialDate: DateTime(2023, 10, 24),
      ),
    );
    expect(find.text('Thêm sự kiện sức khỏe'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('add-health-event-type-vaccination')))
          .height,
      78,
    );
    expect(
      tester.getSize(find.byKey(const Key('add-health-save-button'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getRect(find.byKey(const Key('add-health-note-input'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('add-health-save-button'))).top,
      ),
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day27/p1-13-add-health-event-390x844.png'),
    );
  });

  testWidgets('P1-12 Health Timeline responsive golden at 360x800', (
    tester,
  ) async {
    await _pumpHealthScreen(
      tester,
      HealthTimelineScreen(now: () => _now),
      viewport: const Size(360, 800),
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day27/p1-12-health-timeline-360x800.png'),
    );
  });

  for (final viewport in _responsiveViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-12 Health Timeline responsive golden at $tag', (
      tester,
    ) async {
      await _pumpHealthScreen(
        tester,
        HealthTimelineScreen(now: () => _now),
        viewport: viewport,
      );
      expect(find.text('Ngày 04/05/2026'), findsOneWidget);
      if (viewport.width == 360) {
        for (final label in [
          'NHẮC NHỞ SẮP TỚI',
          'Tiêm ngừa dại - Ngày mai, 09:30',
          'Tiêm phòng dại',
          '04/05/2026',
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label).first,
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '$label must remain fully legible at 360dp',
          );
        }
      }
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day27/p1-12-health-timeline-$tag.png'),
      );
    });

    testWidgets('P1-13 Add Health Event responsive golden at $tag', (
      tester,
    ) async {
      await _pumpHealthScreen(
        tester,
        AddHealthEventScreen(
          initialPetId: 'mochi',
          initialDate: DateTime(2023, 10, 24),
        ),
        viewport: viewport,
      );
      expect(find.text('Thêm sự kiện sức khỏe'), findsOneWidget);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day27/p1-13-add-health-event-$tag.png'),
      );
    });
  }
}

Future<void> pumpDay118Timeline(WidgetTester tester, Size viewport) =>
    _pumpHealthScreen(
      tester,
      HealthTimelineScreen(now: () => _now),
      viewport: viewport,
    );

Future<void> _pumpHealthScreen(
  WidgetTester tester,
  Widget screen, {
  Size viewport = const Size(390, 844),
}) async {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWith((ref) async => [_pet, _secondPet]),
        healthRecordApiProvider.overrideWith((ref) => _FakeHealthRecordApi()),
        healthRecordAccessTokenProvider.overrideWith(
          (ref) async => 'day27-token',
        ),
        upcomingRemindersProvider.overrideWith(
          (ref) async => [_upcomingReminder],
        ),
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
  await tester.pump();
  final context = tester.element(find.byKey(_goldenKey));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/pets/p1_05_mochi.png'),
      context,
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/pets/p1_05_kem.png'),
      context,
    ),
  );
  await tester.pumpAndSettle();
  if (screen is AddHealthEventScreen &&
      find.byKey(const Key('add-health-note-input')).evaluate().isNotEmpty) {
    await tester.enterText(
      find.byKey(const Key('add-health-note-input')),
      'Bé Mochi vừa tiêm nhắc lại mũi 5 bệnh. Sau khi tiêm có biểu hiện hơi lờ đờ, chán ăn nhẹ trong khoảng 2 tiếng đầu nhưng sau đó đã hoạt động bình thường trở lại. Cần theo dõi thêm vùng tiêm xem có sưng tấy hay không trong 24h tới. Đã cho bé uống thêm nước, bổ sung gel dinh dưỡng.',
    );
    await tester.pumpAndSettle();
  }
}

final _pet = PetProfile(
  id: 'mochi',
  name: 'Mochi',
  species: 'cat',
  breed: 'Mèo Anh lông ngắn',
  gender: 'female',
  dateOfBirth: DateTime(2022, 4, 12),
  weightKg: 4.8,
  healthStatus: 'healthy',
  avatarPath: 'assets/images/pets/p1_05_mochi.png',
);

final _secondPet = PetProfile(
  id: 'kem',
  name: 'Kem',
  species: 'dog',
  breed: 'Poodle',
  gender: 'male',
  dateOfBirth: DateTime(2023, 2, 8),
  weightKg: 6.1,
  healthStatus: 'healthy',
  avatarPath: 'assets/images/pets/p1_05_kem.png',
);

final _now = DateTime(2026, 5, 3, 9);

final _upcomingReminder = Reminder(
  id: 'reminder-rabies',
  petId: 'mochi',
  title: 'Tiêm ngừa dại',
  reminderAt: DateTime(2026, 5, 4, 9, 30),
  nextTriggerAt: DateTime(2026, 5, 4, 9, 30),
  repeatRule: ReminderRepeatRule.none,
  timezone: 'Asia/Bangkok',
  status: ReminderStatus.scheduled,
  createdAt: '2026-05-01T09:00:00.000Z',
  updatedAt: '2026-05-01T09:00:00.000Z',
);

class _FakeHealthRecordApi extends HealthRecordApi {
  _FakeHealthRecordApi() : super(Dio());

  @override
  Future<HealthRecordListResult> listRecords(
    HealthRecordListQuery query, {
    required String accessToken,
  }) async {
    const records = [
      HealthRecord(
        id: 'vaccination',
        petId: 'mochi',
        type: HealthRecordType.vaccination,
        date: '2026-05-04',
        title: 'Tiêm phòng dại',
        note: 'Vaccine dại 3 năm (Rabies)',
        attachments: [],
        createdAt: '2026-05-04T15:30:00.000Z',
        updatedAt: '2026-05-04T15:30:00.000Z',
      ),
      HealthRecord(
        id: 'weight',
        petId: 'mochi',
        type: HealthRecordType.checkup,
        date: '2026-05-04',
        title: 'Kiểm tra cân nặng',
        note: '12.5 kg',
        attachments: [],
        createdAt: '2026-05-04T12:00:00.000Z',
        updatedAt: '2026-05-04T12:00:00.000Z',
      ),
      HealthRecord(
        id: 'general-checkup',
        petId: 'mochi',
        type: HealthRecordType.checkup,
        date: '2026-05-04',
        title: 'Khám tổng quát',
        note: 'PetCare Elite Clinic',
        attachments: [],
        createdAt: '2026-05-04T09:30:00.000Z',
        updatedAt: '2026-05-04T09:30:00.000Z',
      ),
    ];
    final items = records
        .where((record) => query.type == null || record.type == query.type)
        .toList();
    return HealthRecordListResult(
      items: items,
      total: items.length,
      limit: query.limit,
    );
  }
}

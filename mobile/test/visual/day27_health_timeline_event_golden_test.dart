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

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day27-health-golden-root');
const _responsiveViewports = [
  Size(320, 568),
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

  testWidgets('P1-12 Health Timeline golden at 390x844', (tester) async {
    await _pumpHealthScreen(tester, const HealthTimelineScreen());
    expect(find.text('Ngày 06/05/2026'), findsOneWidget);
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
        initialDate: DateTime(2026, 7, 16),
      ),
    );
    expect(find.text('Thêm sự kiện sức khỏe'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day27/p1-13-add-health-event-390x844.png'),
    );
  });

  for (final viewport in _responsiveViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-12 Health Timeline responsive golden at $tag', (
      tester,
    ) async {
      await _pumpHealthScreen(
        tester,
        const HealthTimelineScreen(),
        viewport: viewport,
      );
      expect(find.text('Ngày 06/05/2026'), findsOneWidget);
      if (viewport.width == 360) {
        for (final label in [
          'NHẮC NHỞ SẮP TỚI',
          'Chưa có lịch nhắc sắp tới',
          'Tiêm phòng dại',
          '06/05/2026 · 15:30',
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
          initialDate: DateTime(2026, 7, 16),
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
        petBackendListProvider.overrideWith((ref) async => [_pet]),
        healthRecordApiProvider.overrideWith((ref) => _FakeHealthRecordApi()),
        healthRecordAccessTokenProvider.overrideWith(
          (ref) async => 'day27-token',
        ),
        upcomingRemindersProvider.overrideWith((ref) async => const []),
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

final _pet = PetProfile(
  id: 'mochi',
  name: 'Mochi',
  species: 'cat',
  breed: 'Mèo Anh lông ngắn',
  gender: 'female',
  dateOfBirth: DateTime(2022, 4, 12),
  weightKg: 4.8,
  healthStatus: 'healthy',
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
        id: 'checkup-afternoon',
        petId: 'mochi',
        type: HealthRecordType.checkup,
        date: '2026-05-06',
        time: '15:30',
        title: 'Kiểm tra cân nặng',
        note: '4.8kg, thể trạng ổn định.',
        attachments: [],
        createdAt: '2026-05-06T15:30:00.000Z',
        updatedAt: '2026-05-06T15:30:00.000Z',
      ),
      HealthRecord(
        id: 'vaccination-morning',
        petId: 'mochi',
        type: HealthRecordType.vaccination,
        date: '2026-05-06',
        time: '09:30',
        title: 'Tiêm phòng dại',
        note: 'Theo dõi phản ứng trong 24 giờ.',
        vetId: 'PetCare Elite',
        attachments: [],
        createdAt: '2026-05-06T09:30:00.000Z',
        updatedAt: '2026-05-06T09:30:00.000Z',
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

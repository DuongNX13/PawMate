import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_canvas.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_map_screen.dart';

import '../features/rescue/rescue_test_fixtures.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day44-rescue-map-golden-root');
const _viewport = Size(390, 844);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-05 Rescue Map golden at 390x844', (tester) async {
    await _pumpMap(tester);

    expect(find.text('Bản đồ cứu hộ'), findsOneWidget);
    expect(find.text('Gần bạn nhất (2)'), findsOneWidget);
    expect(find.textContaining('10.7769'), findsNothing);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day44/p2-05-rescue-map-390x844.png'),
    );
  });

  testWidgets('P2-05 marker-card sheet golden at 390x844', (tester) async {
    await _pumpMap(tester);
    await tester.tap(
      find.byKey(
        const Key('golden-marker-22222222-2222-4222-8222-222222222222'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đang chọn Mực'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/day44/p2-05-rescue-map-marker-sheet-390x844.png',
      ),
    );
  });
}

Future<void> pumpDay118RescueMap(WidgetTester tester, Size viewport) =>
    _pumpMap(tester, viewport: viewport, day118PetMedia: true);

Future<void> _pumpMap(
  WidgetTester tester, {
  Size viewport = _viewport,
  bool day118PetMedia = false,
}) async {
  await setTestViewport(tester, size: viewport);
  final source = FakeRescueSource(
    pages: [samplePage(items: _figmaCases(day118PetMedia: day118PetMedia))],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
        rescueLocationServiceProvider.overrideWithValue(
          const _GoldenLocationService(),
        ),
        rescueMapCanvasBuilderProvider.overrideWithValue(_goldenMapBuilder),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const RescueMapScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byKey(_goldenKey));
  for (final asset in const [
    'assets/images/rescue/p2_05_lulu.png',
    'assets/images/rescue/p2_05_muc.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pumpAndSettle();
}

Widget _goldenMapBuilder(
  RescueMapLocation center,
  List<RescueCaseSummary> items,
  ValueChanged<String> onMarkerTap,
  ValueChanged<Object> onMapUnavailable,
) {
  return ColoredBox(
    color: AppColors.lightBeige,
    child: CustomPaint(
      painter: const _GoldenMapPainter(),
      child: Stack(
        children: [
          Positioned(
            left: 160,
            top: 311,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.deepGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          for (var index = 0; index < items.length; index++)
            Positioned(
              left: index == 0 ? 118 : 194,
              top: index == 0 ? 360 : 312,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepGreen,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      items[index].status.label,
                      style: AppTextStyles.micro(color: AppColors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Semantics(
                    button: true,
                    label:
                        'Khu vực ước tính của ${items[index].petName}, ${items[index].publicLocation.areaLabel}',
                    child: IconButton.filled(
                      key: ValueKey('golden-marker-${items[index].caseId}'),
                      tooltip: 'Khu vực ${items[index].petName}',
                      onPressed: () => onMarkerTap(items[index].caseId),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.deepGreen,
                        foregroundColor: AppColors.white,
                        side: const BorderSide(
                          color: AppColors.white,
                          width: 3,
                        ),
                      ),
                      icon: const Icon(Icons.pets_rounded),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _GoldenLocationService implements RescueLocationService {
  const _GoldenLocationService();

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async => const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
}

class _GoldenMapPainter extends CustomPainter {
  const _GoldenMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final uncertainty = Paint()
      ..color = AppColors.surfaceContainer.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const center = Offset(200, 340);
    canvas.drawCircle(center, 150, uncertainty);
    canvas.drawCircle(center, 150, border);
  }

  @override
  bool shouldRepaint(covariant _GoldenMapPainter oldDelegate) => false;
}

List<RescueCaseSummary> _figmaCases({bool day118PetMedia = false}) {
  final source = sampleCases().take(2).toList(growable: false);
  final assets = day118PetMedia
      ? const [
          'assets/images/pets/home_adoption_golden.png',
          'assets/images/pets/p1_05_mochi.png',
        ]
      : const [
          'assets/images/rescue/p2_05_lulu.png',
          'assets/images/rescue/p2_05_muc.png',
        ];
  return [
    for (var index = 0; index < source.length; index++)
      RescueCaseSummary(
        caseId: source[index].caseId,
        petName: source[index].petName,
        species: source[index].species,
        status: source[index].status,
        lostAt: source[index].lostAt,
        publicLocation: source[index].publicLocation,
        media: [
          RescuePublicMedia(
            mediaId: 'map-media-$index',
            mimeType: 'image/png',
            publicUrl: Uri.parse('asset:${assets[index]}'),
            createdAt: source[index].createdAt,
          ),
        ],
        commentCount: source[index].commentCount,
        createdAt: source[index].createdAt,
        updatedAt: source[index].updatedAt,
        breedOrColor: source[index].breedOrColor,
        ageLabel: source[index].ageLabel,
        distanceMeters: source[index].distanceMeters,
      ),
  ];
}

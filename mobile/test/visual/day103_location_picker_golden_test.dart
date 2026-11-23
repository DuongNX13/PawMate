import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_location_picker_sheet.dart';

import '../test_support/ui_test_helpers.dart';

Widget _canvas(
  RescueDraftLocation? selected,
  ValueChanged<RescueDraftLocation> onSelect,
  VoidCallback onUnavailable,
) => DecoratedBox(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xffeaf6ef), Color(0xffd5ece4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  child: Stack(
    children: [
      const Positioned.fill(
        child: CustomPaint(painter: _DeterministicMapPainter()),
      ),
      Center(
        child: IconButton.filled(
          key: const Key('day103-golden-select'),
          tooltip: 'Chọn ghim',
          onPressed: () => onSelect(
            const RescueDraftLocation(latitude: 10.7769, longitude: 106.7009),
          ),
          icon: const Icon(Icons.pets_outlined),
        ),
      ),
      Positioned(
        right: 8,
        top: 8,
        child: IconButton(
          key: const Key('day103-golden-unavailable'),
          tooltip: 'Bản đồ lỗi',
          onPressed: onUnavailable,
          icon: const Icon(Icons.cloud_off_outlined),
        ),
      ),
    ],
  ),
);

class _DeterministicMapPainter extends CustomPainter {
  const _DeterministicMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = const Color(0xfff8f3ea)
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke;
    final river = Paint()
      ..color = const Color(0xffb9e2e6)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * .7),
      Offset(size.width, size.height * .25),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .25, 0),
      Offset(size.width * .72, size.height),
      river,
    );
    canvas.drawCircle(
      Offset(size.width * .17, size.height * .28),
      22,
      Paint()..color = const Color(0xff95d5b2),
    );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .68),
      30,
      Paint()..color = const Color(0xffcce8d8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double scale,
}) async {
  await setTestViewport(tester, size: size);
  const root = Key('day103-golden-root');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rescuePickerMapBuilderProvider.overrideWithValue(_canvas)],
      child: RepaintBoundary(
        key: root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(scale),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('day103-open-picker'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const RescueLocationPickerSheet(),
                  ),
                  child: const Text('Mở chọn vị trí'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('day103-open-picker')));
  await tester.pumpAndSettle();
}

Future<void> pumpDay120Location(WidgetTester tester, Size size) =>
    _pump(tester, size: size, scale: 1);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('DT-09 default 390x844', (tester) async {
    await _pump(tester, size: const Size(390, 844), scale: 1);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(const Key('day103-golden-root')),
      matchesGoldenFile('goldens/day103/dt-09-default-390x844.png'),
    );
  });

  testWidgets('DT-09 selected 430x932', (tester) async {
    await _pump(tester, size: const Size(430, 932), scale: 1);
    await tester.tap(find.byKey(const Key('day103-golden-select')));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('rescue-location-confirm'))),
      alignment: .8,
    );
    await tester.pumpAndSettle();
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(const Key('day103-golden-root')),
      matchesGoldenFile('goldens/day103/dt-09-selected-430x932.png'),
    );
  });

  testWidgets('DT-09 unavailable 320x568 text2', (tester) async {
    await _pump(tester, size: const Size(320, 568), scale: 2);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('day103-golden-unavailable'))),
      alignment: .35,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day103-golden-unavailable')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bản đồ chưa tải được'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(const Key('day103-golden-root')),
      matchesGoldenFile('goldens/day103/dt-09-unavailable-320x568-text2.png'),
    );
  });
}

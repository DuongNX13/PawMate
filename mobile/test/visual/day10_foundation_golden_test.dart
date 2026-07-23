import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../test_support/day10_foundation_harness.dart';
import '../test_support/ui_test_helpers.dart';
import '../test_support/visual_diff_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);

  const viewports = [390.0, 360.0, 412.0, 430.0];
  for (final width in viewports) {
    for (final surface in Day10FoundationSurface.values) {
      final fileName = '${surface.name}-${width.toInt()}x844.png';
      testWidgets('golden ${surface.name} at ${width.toInt()}x844', (
        tester,
      ) async {
        await setTestViewport(tester, size: ui.Size(width, 844));
        await tester.pumpWidget(buildDay10FoundationHarness(surface));
        await _precacheNavigationIcons(tester);
        await tester.pumpAndSettle();

        expectNoFlutterOverflow(tester);
        await expectLater(
          find.byKey(day10GoldenRootKey),
          matchesGoldenFile('goldens/day10/$fileName'),
        );
      });
    }
  }

  testWidgets('visual guard rejects an intentional app-shell drift', (
    tester,
  ) async {
    await setTestViewport(tester, size: const ui.Size(390, 844));
    await tester.pumpWidget(
      buildDay10FoundationHarness(
        Day10FoundationSurface.appShell,
        intentionalDrift: true,
      ),
    );
    await _precacheNavigationIcons(tester);
    await tester.pumpAndSettle();

    final expectedFile = File('test/visual/goldens/day10/appShell-390x844.png');
    expect(expectedFile.existsSync(), isTrue);
    final diff = await tester.runAsync(() async {
      final actual = await _capture(tester).timeout(const Duration(seconds: 5));
      return comparePawMatePng(
        expectedFile.readAsBytesSync(),
        actual,
        channelTolerance: 2,
      ).timeout(const Duration(seconds: 5));
    });

    expect(diff, isNotNull);
    final provenDiff = diff!;
    expect(provenDiff.diffPercent, greaterThan(0.1));
    expect(
      () => enforcePawMateVisualTolerance(provenDiff, maxDiffPercent: 0.1),
      throwsA(isA<TestFailure>()),
    );
  });
}

Future<void> _precacheNavigationIcons(WidgetTester tester) async {
  final navFinder = find.byType(PawMateBottomNav);
  if (navFinder.evaluate().isEmpty) return;

  final context = tester.element(navFinder.first);
  await tester.runAsync(() async {
    for (final destination in PawMateBottomNav.destinations) {
      await precacheImage(
        AssetImage(destination.iconAsset),
        context,
      ).timeout(const Duration(seconds: 5));
    }
  });
  await tester.pump();
}

Future<Uint8List> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(day10GoldenRootKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Unable to capture golden surface.');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

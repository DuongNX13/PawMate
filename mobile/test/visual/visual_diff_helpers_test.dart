import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test_support/visual_diff_helpers.dart';

void main() {
  testWidgets('visual diff reports zero for identical PNG bytes', (
    tester,
  ) async {
    final file = File('test/visual/goldens/day10/appShell-390x844.png');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    final result = await tester.runAsync(() => comparePawMatePng(bytes, bytes));

    expect(result, isNotNull);
    expect(result!.dimensionsMatch, isTrue);
    expect(result.differentPixels, 0);
    expect(result.diffPercent, 0);
    expect(
      () => enforcePawMateVisualTolerance(result, maxDiffPercent: 0),
      returnsNormally,
    );
  });

  testWidgets('visual diff rejects a viewport dimension mismatch', (
    tester,
  ) async {
    final expected = File(
      'test/visual/goldens/day10/appShell-390x844.png',
    ).readAsBytesSync();
    final actual = File(
      'test/visual/goldens/day10/appShell-360x844.png',
    ).readAsBytesSync();
    final result = await tester.runAsync(
      () => comparePawMatePng(expected, actual),
    );

    expect(result, isNotNull);
    expect(result!.dimensionsMatch, isFalse);
    expect(
      () => enforcePawMateVisualTolerance(result, maxDiffPercent: 100),
      throwsA(isA<TestFailure>()),
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/rescue/day102_report_review_test.dart';
import '../test_support/ui_test_helpers.dart';

Future<void> pumpDay120ReportReview(WidgetTester tester, Size size) async {
  await pumpReviewForm(
    tester,
    ReviewWriteSource(),
    size: size,
    scale: 1,
    seed: true,
    localPrivacy: true,
  );
  await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, bottom: false, seed: true),
    (size: const Size(390, 844), scale: 1.0, bottom: true, seed: true),
    (size: const Size(430, 932), scale: 1.0, bottom: false, seed: true),
    (size: const Size(320, 568), scale: 2.0, bottom: true, seed: false),
  ]) {
    final name =
        'dt08-${scenario.size.width.toInt()}-${scenario.bottom ? 'actions' : 'summary'}-text${scenario.scale.toInt()}';
    testWidgets(name, (tester) async {
      await pumpReviewForm(
        tester,
        ReviewWriteSource(),
        size: scenario.size,
        scale: scenario.scale,
        seed: scenario.seed,
      );
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      if (scenario.bottom) {
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('rescue-review-back'))),
        );
        await tester.pumpAndSettle();
      }
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/day102/$name.png'),
      );
    });
  }
}

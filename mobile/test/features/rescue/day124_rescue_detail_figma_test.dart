import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/ui_v031_rescue_case_detail_golden_test.dart' as detail;

// D123-IOS-UI-012: Figma P2-04 shows uppercase fact labels and a bold,
// filled comment icon in the bottom bar.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('fact labels are uppercase', (t) async {
    await detail.pumpDay118RescueDetail(t, const Size(390, 844));
    expect(find.text('LOẠI'), findsOneWidget);
    expect(find.text('GIỐNG/MÀU'), findsOneWidget);
  });

  testWidgets('comment bar uses the filled bubble icon', (t) async {
    await detail.pumpDay118RescueDetail(t, const Size(390, 844));
    expect(
      find.descendant(
        of: find.byKey(const Key('rescue-detail-comment-bar')),
        matching: find.byIcon(Icons.chat_bubble_rounded),
      ),
      findsOneWidget,
    );
  });
}

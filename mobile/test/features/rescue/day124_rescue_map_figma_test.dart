import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/day44_rescue_map_golden_test.dart' as rescue_map;

// D123-IOS-UI-005: Figma v0.34 P2-05 (590:14485) floats the filter chips in a
// rounded tray and the "Gần bạn nhất" list in an inset rounded sheet over a
// full-screen map.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('P2-05 filter tray and floating nearby sheet', (t) async {
    await rescue_map.pumpDay118RescueMap(t, const Size(430, 932));
    expect(find.byKey(const Key('rescue-map-filter-tray')), findsOneWidget);
    final sheet = find.byKey(const Key('rescue-map-sheet'));
    expect(sheet, findsOneWidget);
    final rect = t.getRect(sheet);
    expect(rect.left, greaterThanOrEqualTo(8));
    expect(rect.right, lessThanOrEqualTo(422));
    final material = t.widget<Material>(sheet);
    expect(material.color, Colors.white);
    expect(material.borderRadius, BorderRadius.circular(24));
    expectNoFlutterOverflow(t);
  });
}

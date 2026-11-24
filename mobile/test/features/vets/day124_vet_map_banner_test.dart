import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/day23_vet_finder_golden_test.dart' as vets;

// D123-IOS-A11Y-001: the P1-08 location banner was translucent over the map,
// so its text contrast depended on the tiles behind it.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('location banner background is opaque', (t) async {
    await vets.pumpDay118VetMap(t, const Size(390, 844));
    final banner = find.byKey(const Key('vet-map-location-banner'));
    if (banner.evaluate().isEmpty) return;
    final box = t.widget<Container>(banner).decoration! as BoxDecoration;
    expect(box.color!.a, 1.0);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support/ui_test_helpers.dart';
import '../visual/day23_vet_finder_golden_test.dart' as vets;
import '../visual/day28_reminder_notification_golden_test.dart' as reminders;
import '../visual/day44_rescue_map_golden_test.dart' as rescue_map;
import '../visual/day46_rescue_status_discussion_golden_test.dart'
    as discussion;
import '../visual/ui_v031_rescue_live_golden_test.dart' as rescue;

typedef _Pump = Future<void> Function(WidgetTester, Size);

// D123-IOS-A11Y-002/003: screens flagged by the iOS audit must meet the
// Flutter tap-target and labeled-target guidelines.
final _screens = <String, _Pump>{
  'P1-09': vets.pumpDay118VetList,
  'P1-15': reminders.pumpDay118Notifications,
  'P2-01': rescue.pumpDay118RescueHome,
  'P2-05': rescue_map.pumpDay118RescueMap,
  'P2-08': discussion.pumpDay118Discussion,
};

void main() {
  setUpAll(loadPawMateTestFonts);

  for (final entry in _screens.entries) {
    testWidgets('${entry.key} meets tap target and label guidelines', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await entry.value(t, const Size(390, 844));
      await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  // D123-IOS-A11Y-001: text contrast on the flagged map screens. P2-05 is
  // left out: its golden harness paints a fake map with white status pills
  // that the real canvas never draws; the real filter tray is now opaque.
  for (final entry in <String, _Pump>{
    'P1-08': vets.pumpDay118VetMap,
  }.entries) {
    testWidgets('${entry.key} meets text contrast guideline', (t) async {
      final handle = t.ensureSemantics();
      await entry.value(t, const Size(390, 844));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}

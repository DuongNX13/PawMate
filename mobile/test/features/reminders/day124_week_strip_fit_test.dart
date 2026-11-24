import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/day28_reminder_notification_golden_test.dart'
    as reminders;

// D122-TB-P2-006: the week strip was clipped at the right edge on narrow
// screens; all seven days must fit inside the page gutters.
void main() {
  setUpAll(loadPawMateTestFonts);

  for (final size in const [Size(320, 568), Size(360, 800)]) {
    testWidgets('week strip fits at ${size.width}', (t) async {
      await reminders.pumpDay118Calendar(t, size);
      final days = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('reminder-day-'),
      );
      expect(days, findsNWidgets(7));
      for (final element in days.evaluate()) {
        final rect = t.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(15.5));
        expect(rect.right, lessThanOrEqualTo(size.width - 15.5));
      }
      expectNoFlutterOverflow(t);
    });
  }
}

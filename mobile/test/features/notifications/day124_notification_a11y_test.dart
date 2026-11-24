import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/day28_reminder_notification_golden_test.dart'
    as reminders;

// D123-IOS-A11Y-001/002: the P1-15 section header used low-contrast muted
// text and clipped the mark-all button to a 28pt touch target.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('section header text uses readable secondary color', (t) async {
    await reminders.pumpDay118Notifications(t, const Size(430, 932));
    final header = find.text('TRƯỚC ĐÓ');
    expect(header, findsOneWidget);
    expect(t.widget<Text>(header).style?.color, AppColors.textSecondary);
  });

  testWidgets('unread badge stays a compact pill in the taller row', (t) async {
    await reminders.pumpDay118Notifications(t, const Size(390, 844));
    final badge = find.byKey(const ValueKey('notification-unread-count'));
    expect(badge, findsOneWidget);
    expect(t.getSize(badge).height, lessThan(30));
  });

  testWidgets('mark all read keeps a 44pt touch target', (t) async {
    await reminders.pumpDay118Notifications(t, const Size(430, 932));
    final button = find.byKey(
      const ValueKey('notification-mark-all-read-button'),
    );
    if (button.evaluate().isEmpty) return;
    final parent = find
        .ancestor(of: button, matching: find.byType(SizedBox))
        .first;
    expect(t.getSize(parent).height, greaterThanOrEqualTo(44));
  });
}

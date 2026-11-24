import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/phase1_home_profile_golden_test.dart' as profile;

// D123-IOS-UI-007: Figma v0.34 P1-16 (590:14030) shows each system setting
// as its own white card with a 44pt tinted icon box, and pet previews as two
// large half-width cards.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('P1-16 settings are separate cards with 44pt icon boxes', (
    t,
  ) async {
    await profile.pumpDay118Profile(t, const Size(430, 932));
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'profile-settings-card-',
          ),
    );
    expect(cards, findsNWidgets(5));
    final iconBox = t.getSize(
      find.byKey(const Key('profile-settings-icon')).first,
    );
    expect(iconBox.width, 44);
    expectNoFlutterOverflow(t);
  });

  testWidgets('P1-16 pet previews are half-width cards', (t) async {
    await profile.pumpDay118Profile(t, const Size(430, 932));
    final card = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('profile-pet-') &&
          !(w.key! as ValueKey<String>).value.contains('selected'),
    );
    expect(card, findsWidgets);
    expect(t.getSize(card.first).width, greaterThan(180));
  });
}

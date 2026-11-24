import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/day46_rescue_status_discussion_golden_test.dart'
    as discussion;

// D123-IOS-UI-008: Figma v0.34 P2-08 (590:14764) draws every comment as a
// rounded bubble: top-level comments white, replies mint and indented.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('P2-08 comments render as bubbles, top-level white', (t) async {
    await discussion.pumpDay118Discussion(t, const Size(430, 932));
    final bubbles = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('rescue-comment-') &&
          w.decoration is BoxDecoration,
    );
    final all = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('rescue-comment-'),
    );
    expect(all, findsWidgets);
    expect(bubbles.evaluate().length, all.evaluate().length);
    final colors = bubbles
        .evaluate()
        .map(
          (e) => ((e.widget as Container).decoration! as BoxDecoration).color,
        )
        .toSet();
    expect(colors, contains(Colors.white));
  });
}

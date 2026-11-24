import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_add_fab.dart';

import '../../test_support/ui_test_helpers.dart';

// D123-IOS-UI-004: Figma v0.34 P1-12/P1-14 use a round "+" FAB at every
// width (FAB/Add, 53x53); the action name stays in the tooltip/semantics.
void main() {
  setUpAll(loadPawMateTestFonts);

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('D124 add FAB is round icon-only width=$width', (t) async {
      await setTestViewport(t, size: Size(width, 932));
      final semantics = t.ensureSemantics();
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            floatingActionButton: PawMateAddFab(
              heroTag: 'd124-fab',
              tooltip: 'Thêm sự kiện',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final fab = find.byType(PawMateAddFab);
      expect(
        find.descendant(of: fab, matching: find.byType(Text)),
        findsNothing,
      );
      final rect = t.getRect(
        find.descendant(of: fab, matching: find.byType(FloatingActionButton)),
      );
      expect(rect.width, rect.height);
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Thêm sự kiện'), findsOneWidget);
      final node = t.getSemantics(find.byType(FloatingActionButton));
      expect(node.getSemanticsData().tooltip, 'Thêm sự kiện');
      await t.tap(fab);
      expect(taps, 1);
      semantics.dispose();
    });
  }
}

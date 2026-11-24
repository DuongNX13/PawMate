import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

// D123-IOS-UI-002/003: Figma v0.34 DT-04/DT-05 draw the map edge to edge and
// float the nearby sheet and the selected-case card over its lower part.
Future<void> _pump(WidgetTester t) async {
  await setTestViewport(t, size: const Size(430, 932));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(
            pages: [samplePage(items: sampleCasesWithoutImages())],
          ),
        ),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const RescueHomeScreen(browseEnabled: true, createEnabled: true),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('DT-04 map is full bleed and the sheet overlaps it', (t) async {
    await _pump(t);
    final map = t.getRect(find.byKey(const Key('rescue-map-preview')));
    expect(map.left, 0);
    expect(map.width, 430);
    final sheet = t.getRect(find.byKey(const Key('rescue-nearby-list')));
    expect(sheet.top, lessThan(map.bottom));
    expect(find.byKey(const Key('rescue-sheet-handle')), findsOneWidget);
    expectNoFlutterOverflow(t);
  });

  testWidgets('DT-05 selected card floats over the map', (t) async {
    await _pump(t);
    final marker = find.byKey(
      ValueKey('rescue-marker-${sampleCases().first.caseId}'),
    );
    await t.tap(marker, warnIfMissed: false);
    await t.pumpAndSettle();
    final map = t.getRect(find.byKey(const Key('rescue-map-preview')));
    final card = t.getRect(find.byKey(const Key('rescue-selected-case-card')));
    expect(card.top, lessThan(map.bottom));
    final cta = t.getRect(find.byKey(const Key('rescue-selected-details')));
    expect(cta.right, greaterThan(card.center.dx));
    expectNoFlutterOverflow(t);
  });
}

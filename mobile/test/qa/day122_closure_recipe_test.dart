import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../test_support/ui_test_helpers.dart';
import '../../integration_test/day122_closure_recipes.dart';
import '../test_support/day119_detail_support.dart' as legacy_detail;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  for (final width in [360.0, 430.0]) {
    testWidgets('DT08 opening recipe must mount actual sheet $width', (
      t,
    ) async {
      await pumpClosureReportReview(t, Size(width, 844));
      expect(
        find.byKey(const Key('rescue-report-review-sheet')),
        findsOneWidget,
        reason: 'A named form capture is not Report Review Sheet proof',
      );
    });
    for (final edit in [false, true]) {
      testWidgets('Dog fixture binds correct asset edit=$edit $width', (
        t,
      ) async {
        if (const bool.fromEnvironment('D122_MUTATE_PET_FIXTURE')) {
          final old = await legacy_detail.pumpDay119(
            t,
            'DT-01',
            Size(width, 844),
          );
          if (edit) {
            old.router.go('/pets/mochi/edit');
            await t.pumpAndSettle();
          }
        } else {
          await pumpClosurePet(t, Size(width, 844), edit: edit);
        }
        final images = t.widgetList<Image>(find.byType(Image));
        final assets = images
            .map((image) => image.image)
            .whereType<AssetImage>();
        expect(
          assets.any((image) => image.assetName == closureDogAvatar),
          isTrue,
        );
        expect(
          assets.any((image) => image.assetName.endsWith('p1_05_mochi.png')),
          isFalse,
        );
      });
    }
  }
  testWidgets('Nested scroll uses owning panel instead of first scrollable', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(
              child: ListView(
                children: [for (var i = 0; i < 30; i++) Text('Background $i')],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < 30; i++)
                    Text('Panel $i', key: ValueKey('panel-$i')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final content = find.byKey(const ValueKey('panel-0'));
    final owner = const bool.fromEnvironment('D122_MUTATE_SCROLL')
        ? find.byType(Scrollable).first
        : closureScrollFor(t, content);
    final first = t.state<ScrollableState>(find.byType(Scrollable).first);
    final panel = t.state<ScrollableState>(owner);
    expect(identical(first, panel), isFalse);
    panel.position.jumpTo(panel.position.maxScrollExtent);
    await t.pumpAndSettle();
    expect(first.position.pixels, 0);
    expect(panel.position.pixels, greaterThan(0));
  });
  testWidgets('Owning sweep covers middle and end without moving background', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(
              child: ListView(
                children: [for (var i = 0; i < 50; i++) Text('Background $i')],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < 80; i++)
                    Text('Item $i', key: ValueKey('item-$i')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final content = find.byKey(const ValueKey('item-0'));
    final panel = t.state<ScrollableState>(closureScrollFor(t, content));
    final background = t.state<ScrollableState>(find.byType(Scrollable).first);
    final offsets = <double>[];
    await closureSweep(
      t,
      content,
      capture: (index, offset) async {
        expect(index, offsets.length);
        offsets.add(offset);
      },
    );
    expect(offsets.length, greaterThan(2));
    expect(offsets.first, 0);
    expect(offsets.last, closeTo(panel.position.maxScrollExtent, .5));
    for (var i = 1; i < offsets.length; i++) {
      expect(
        offsets[i] - offsets[i - 1],
        lessThanOrEqualTo(panel.position.viewportDimension * .7 + .5),
      );
    }
    expect(background.position.pixels, 0);
  });
}

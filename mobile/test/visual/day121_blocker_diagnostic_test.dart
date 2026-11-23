import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_support/ui_test_helpers.dart';
import 'day120_support_scaling_test.dart' as support;

void main() {
  setUpAll(loadPawMateTestFonts);
  testWidgets('D121 diagnostic onboarding IME scroll coordinates', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await support.pumpFamily(t, 'P1-01', const Size(320, 568));
    final field = find.byKey(const Key('onboarding-pet-name-field'));
    final action = find.byKey(const Key('onboarding-continue-button'));
    void record(String stage) {
      final c = t.element(action);
      final m = MediaQuery.of(c);
      final s = Scrollable.of(c);
      debugPrint(
        jsonEncode({
          'stage': stage,
          'action': t.getRect(action).toString(),
          'field': t.getRect(field).toString(),
          'scaffold': t.getRect(find.byType(Scaffold)).toString(),
          'viewport': t.getRect(find.byType(SingleChildScrollView)).toString(),
          'padding': m.padding.toString(),
          'viewPadding': m.viewPadding.toString(),
          'insets': m.viewInsets.toString(),
          'offset': s.position.pixels,
          'extent': s.position.maxScrollExtent,
          'dimension': s.position.viewportDimension,
          'focus': FocusManager.instance.primaryFocus?.debugLabel,
        }),
      );
    }

    await t.ensureVisible(field);
    await t.enterText(field, '');
    await Scrollable.ensureVisible(t.element(action), alignment: .5);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(action);
    await t.pump(const Duration(milliseconds: 400));
    await t.ensureVisible(field);
    await t.enterText(field, 'Mochi thử nghiệm');
    record('before-ime');
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await t.pump(const Duration(milliseconds: 400));
    record('ime-before-ensure');
    await Scrollable.ensureVisible(t.element(action), alignment: .5);
    record('immediate-ensure');
    await t.pump(const Duration(milliseconds: 400));
    record('after-ensure');
    // The IME changes the animated hero's target size. A single pump starts
    // that animation; do not measure/scroll against the intermediate extent.
    await t.pumpAndSettle();
    record('settled-before-ensure');
    await Scrollable.ensureVisible(t.element(action), alignment: .5);
    await t.pumpAndSettle();
    record('settled-after-ensure');
    expect(t.getRect(action).top, greaterThanOrEqualTo(23.9));
  });
}

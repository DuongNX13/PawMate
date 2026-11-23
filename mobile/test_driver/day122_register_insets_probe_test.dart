import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_adaptive.dart';
import '../test/test_support/ui_test_helpers.dart';
import '../test/visual/phase1_register_otp_golden_test.dart' as auth;

// Diagnostic only: expected to expose the source-backed status-bar overlap.
// Not a fix/regression PASS and not a native system-inset proof by itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  testWidgets('D122 register back control stays below top system inset', (t) async {
    await auth.pumpDay120Auth(t, const Size(360, 800), otp: false);
    t.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
    t.view.padding = const FakeViewPadding(top: 32, bottom: 24);
    addTearDown(t.view.resetViewPadding);
    addTearDown(t.view.resetPadding);
    await t.pump();
    final back = find.byType(PawMateAdaptiveBackButton);
    expect(back, findsOneWidget);
    final inset = MediaQuery.viewPaddingOf(t.element(back)).top;
    expect(inset, 32, reason: 'Probe must reach the actual MediaQuery');
    final top = t.getRect(back).top;
    // ignore: avoid_print
    print('D122_REGISTER_INSET: top=$top system_inset=$inset');
    expect(top, greaterThanOrEqualTo(inset),
        reason: 'Interactive back target must not overlap the OS status bar');
  });
}

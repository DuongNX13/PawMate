import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../integration_test/day122_pet_edit_stress_recipe.dart';
import '../test_support/ui_test_helpers.dart';
import '../visual/day120_support_scaling_test.dart' as historical;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('Pet Edit stress uses the verified dog asset on the edit form', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (const bool.fromEnvironment('D122_PET_EDIT_LEGACY_FIXTURE')) {
      await historical.pumpFamily(tester, 'DT-02', petEditStressSize);
    } else {
      await pumpPetEditStress(tester);
    }
    verifyPetEditStressIdentity(tester);
    for (final key in petEditStressFields.keys) {
      await revealPetEditStressField(tester, key);
    }
    final name = await revealPetEditStressField(tester, petEditNameKey);
    await tester.showKeyboard(name);
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await revealPetEditStressField(tester, petEditNameKey);
    verifyPetEditStressIme(tester, 280);
    expect(tester.takeException(), isNull);
  });
}

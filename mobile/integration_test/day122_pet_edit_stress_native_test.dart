import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';

import 'day122_android_responsive_test.dart' show restoreNativeMetrics122;
import 'day122_closure_checkpoint.dart';
import 'day122_pet_edit_stress_recipe.dart';

const _bridge = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-pet-edit';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'Day122 Pet Edit: full form and real Android IME at font 2.0',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final native = ui.PlatformDispatcher.instance.views.single;
      expect(native.physicalSize / native.devicePixelRatio, petEditStressSize);
      expect(ui.PlatformDispatcher.instance.textScaleFactor, closeTo(2, .01));
      final identity =
          jsonDecode(File('$_bridge/identity.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(identity['id'], petEditStressId);
      final checkpoint = ClosureCheckpoint(
        run: identity['run'] as String,
        bridge: _bridge,
      );

      Future<void> capture(String stage, String key) => checkpoint.capture(
        tester,
        id: petEditStressId,
        stage: stage,
        screenName: 'CreatePetScreen',
        screen: find.byType(CreatePetScreen),
        foregroundKeys: [key, petEditSaveKey],
        context: const {'input_scope': 'WIDGET_AND_SYSTEM_IME_NOT_TALKBACK'},
      );

      try {
        await pumpPetEditStress(
          tester,
          restoreNativeMetrics: () => restoreNativeMetrics122(tester),
        );
        final avatar = verifyPetEditStressIdentity(tester);
        expect(avatar.hitTestable(), findsOneWidget);
        expect(native.viewInsets.bottom, 0);
        await capture('avatar', petEditAvatarKey);
        for (final key in petEditStressFields.keys) {
          await revealPetEditStressField(tester, key);
          await capture(key, key);
        }
        final name = await revealPetEditStressField(tester, petEditNameKey);
        expect(tester.testTextInput.isRegistered, isFalse);
        await tester.tap(name);
        await tester.showKeyboard(name);
        final clock = Stopwatch()..start();
        while (native.viewInsets.bottom <= 0 &&
            clock.elapsed < const Duration(seconds: 8)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final ime = native.viewInsets.bottom / native.devicePixelRatio;
        expect(ime, greaterThan(0));
        await revealPetEditStressField(tester, petEditNameKey);
        verifyPetEditStressIme(tester, ime);
        await capture('ime-open', petEditNameKey);
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        FocusManager.instance.primaryFocus?.unfocus();
        clock.reset();
        while (native.viewInsets.bottom > 0 &&
            clock.elapsed < const Duration(seconds: 8)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(native.viewInsets.bottom, 0);
        await revealPetEditStressField(tester, petEditNameKey);
        await capture('ime-closed', petEditNameKey);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

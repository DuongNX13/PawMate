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
import 'day122_closure_recipes.dart' show closureScrollFor;
import 'day122_pet_edit_stress_recipe.dart';

const _bridge = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-pet-edit';

List<double> _rect(Rect value) => [
  value.left,
  value.top,
  value.right,
  value.bottom,
];

Map<String, Object?> _geometry(WidgetTester tester, Finder field) {
  final scroll = closureScrollFor(tester, field);
  final viewport = tester.getRect(scroll);
  final position = tester.state<ScrollableState>(scroll).position;
  final edit = find.descendant(of: field, matching: find.byType(EditableText));
  final fieldRect = tester.getRect(field);
  final cta = tester.getRect(petEditStressCta);
  final native = ui.PlatformDispatcher.instance.views.single;
  final nativeInset = native.viewInsets.bottom / native.devicePixelRatio;
  return {
    'field': _rect(fieldRect),
    'viewport': _rect(viewport),
    'editable': _rect(tester.getRect(edit)),
    'update_cta': _rect(cta),
    'scroll_offset': position.pixels,
    'focused': tester.widget<EditableText>(edit).focusNode.hasFocus,
    'field_hit': field.hitTestable().evaluate().isNotEmpty,
    'cta_hit': petEditStressCta.hitTestable().evaluate().isNotEmpty,
    'field_in_viewport':
        fieldRect.top >= viewport.top - 1 &&
        fieldRect.bottom <= viewport.bottom + 1,
    'controls_above_ime':
        fieldRect.bottom <= petEditStressSize.height - nativeInset + 1 &&
        cta.bottom <= petEditStressSize.height - nativeInset + 1,
  };
}

Future<void> _waitInsets(WidgetTester tester, {required bool open}) async {
  final view = ui.PlatformDispatcher.instance.views.single;
  final clock = Stopwatch()..start();
  double? previous;
  var consecutive = 0;
  while (clock.elapsed < const Duration(seconds: 8)) {
    await tester.pump(const Duration(milliseconds: 100));
    final bottom = view.viewInsets.bottom;
    consecutive = (bottom > 0) == open
        ? bottom == previous
              ? consecutive + 1
              : 1
        : 0;
    previous = bottom;
    if (consecutive == 3) return;
  }
  fail(open ? 'System IME did not open' : 'System IME did not close');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'Day122 Pet Edit diagnostic: capture before layout verdict',
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

      try {
        await pumpPetEditStress(
          tester,
          restoreNativeMetrics: () => restoreNativeMetrics122(tester),
        );
        verifyPetEditStressIdentity(tester);
        final name = await revealPetEditStressField(tester, petEditNameKey);
        Future<Map<String, Object?>> capture(String stage) async {
          late Map<String, Object?> geometry;
          await checkpoint.capture(
            tester,
            id: petEditStressId,
            stage: stage,
            screenName: 'CreatePetScreen',
            screen: find.byType(CreatePetScreen),
            foregroundKeys: [petEditNameKey, petEditSaveKey],
            inspectAfterPump: () async {
              geometry = _geometry(tester, name);
              return {
                'input_scope': 'WIDGET_AND_SYSTEM_IME_NOT_TALKBACK',
                'diagnostic_only': true,
                'geometry': geometry,
              };
            },
          );
          return geometry;
        }

        await _waitInsets(tester, open: false);
        await capture('before-ime');
        expect(tester.testTextInput.isRegistered, isFalse);
        await tester.tap(name);
        await tester.showKeyboard(name);
        await _waitInsets(tester, open: true);
        final initial = await capture('ime-initial');
        await Scrollable.ensureVisible(tester.element(name), alignment: .5);
        await tester.pumpAndSettle();
        await capture('ime-centered');
        await Scrollable.ensureVisible(tester.element(name), alignment: 0);
        await tester.pumpAndSettle();
        await capture('ime-leading');
        final viewport = tester.getRect(closureScrollFor(tester, name));
        await tester.dragFrom(
          Offset(viewport.left + 7, viewport.center.dy),
          const Offset(0, -48),
        );
        await tester.pumpAndSettle();
        await capture('ime-after-drag');
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        FocusManager.instance.primaryFocus?.unfocus();
        await _waitInsets(tester, open: false);
        await revealPetEditStressField(tester, petEditNameKey);
        await capture('ime-closed');

        // Programmatic alignment is diagnostic, not a substitute for the
        // initial user-facing state after the real system keyboard opens.
        expect(
          initial,
          containsPair('field_in_viewport', true),
          reason: 'Focused name and its label must fit after system IME opens',
        );
        expect(initial, containsPair('focused', true));
        expect(initial, containsPair('field_hit', true));
        expect(initial, containsPair('cta_hit', true));
        expect(initial, containsPair('controls_above_ime', true));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

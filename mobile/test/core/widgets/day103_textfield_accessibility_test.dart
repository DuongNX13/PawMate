import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_text_field.dart';

import '../../test_support/ui_test_helpers.dart';

SemanticsNode editableActionNode(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(EditableText));
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isTextField &&
        (data.hasAction(SemanticsAction.tap) ||
            data.hasAction(SemanticsAction.setText))) {
      nodes.add(node);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  expect(nodes, hasLength(1), reason: root.toStringDeep());
  return nodes.single;
}

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets(
    'native value stays separate from required label and live error',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(supportsAnnounce: false);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PawMateTextField(
                label: 'Tên thú cưng',
                isRequired: true,
                initialValue: 'Mochi',
                errorText: 'Vui lòng kiểm tra tên',
              ),
            ),
          ),
        );
        final node = editableActionNode(tester);
        expect(node.label, 'Tên thú cưng, bắt buộc');
        expect(node.value, 'Mochi');
        final error = tester.getSemantics(find.text('Vui lòng kiểm tra tên'));
        expect(
          [
            error,
            error.parent,
            error.parent?.parent,
          ].whereType<SemanticsNode>().any(
            (node) => node.getSemanticsData().flagsCollection.isLiveRegion,
          ),
          isTrue,
          reason: error.parent?.toStringDeep(),
        );
      } finally {
        handle.dispose();
      }
    },
  );

  for (final mode in ['disabled', 'readOnly', 'password']) {
    testWidgets('native $mode semantics are preserved', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PawMateTextField(
                label: 'Nhãn',
                initialValue: 'Secret123',
                enabled: mode != 'disabled',
                readOnly: mode == 'readOnly',
                obscureText: mode == 'password',
              ),
            ),
          ),
        );
        final node = tester.getSemantics(find.byType(EditableText));
        final data = node.getSemanticsData();
        expect(node.label, 'Nhãn');
        if (mode == 'disabled') {
          expect(data.flagsCollection.isEnabled, Tristate.isFalse);
          expect(data.hasAction(SemanticsAction.focus), isFalse);
        } else if (mode == 'readOnly') {
          expect(data.flagsCollection.isReadOnly, isTrue);
          expect(data.hasAction(SemanticsAction.setText), isFalse);
        } else {
          expect(data.flagsCollection.isObscured, isTrue);
          expect(node.value, isNot(contains('Secret123')));
          expect(node.value.length, 9);
        }
      } finally {
        handle.dispose();
      }
    });
  }

  for (final scale in [1.0, 2.0]) {
    for (final label in ['Vĩ độ', 'Kinh độ', 'Địa chỉ gợi nhớ']) {
      for (final focused in [false, true]) {
        for (final nativeControl in [true, false]) {
          testWidgets(
            '${nativeControl ? 'native control' : 'PawMate'} $label scale $scale focused $focused',
            (tester) async {
              await setTestViewport(tester, size: const Size(390, 844));
              final handle = tester.ensureSemantics();
              final controller = TextEditingController();
              addTearDown(controller.dispose);
              try {
                await tester.pumpWidget(
                  MaterialApp(
                    theme: AppTheme.light(),
                    home: Scaffold(
                      body: MediaQuery(
                        data: MediaQueryData(
                          textScaler: TextScaler.linear(scale),
                        ),
                        child: SingleChildScrollView(
                          child: nativeControl
                              ? TextFormField(
                                  decoration: InputDecoration(labelText: label),
                                  controller: controller,
                                  maxLines: label.startsWith('Địa') ? 2 : 1,
                                )
                              : PawMateTextField(
                                  label: label,
                                  controller: controller,
                                  maxLines: label.startsWith('Địa') ? 2 : 1,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
                if (focused) {
                  await tester.showKeyboard(find.byType(EditableText));
                  await tester.pump();
                }
                final editable = editableActionNode(tester);
                final data = editable.getSemanticsData();
                expect(data.hasAction(SemanticsAction.tap), isTrue);
                expect(data.hasAction(SemanticsAction.setText), focused);
                expect(
                  data.label,
                  contains(label),
                  reason:
                      'The editable action node, not only its wrapper, needs a name. '
                      '${editable.toStringDeep()}',
                );
                await tester.enterText(find.byType(TextFormField), '10.7769');
                await tester.pump();
                final filled = editableActionNode(tester);
                expect(filled.label, contains(label));
                expect(filled.value, '10.7769');
                expectNoFlutterOverflow(tester);
              } finally {
                handle.dispose();
              }
            },
          );
        }
      }
    }
  }
}

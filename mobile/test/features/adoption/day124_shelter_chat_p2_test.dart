import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../visual/day55_adoption_request_chat_golden_test.dart' as chat;

void main() {
  setUpAll(loadPawMateTestFonts);

  // D123-IOS-UI-013: Figma keeps the send button filled even when empty.
  testWidgets('empty send button stays filled teal', (t) async {
    await chat.pumpDay118Chat(t, const Size(430, 932));
    final button = t.widget<IconButton>(
      find.byKey(const Key('adoption-chat-send')),
    );
    final bg = button.style!.backgroundColor!.resolve({WidgetState.disabled});
    expect(bg, isNotNull);
    expect(bg!.a, greaterThan(0.5));
  });

  // D123-IOS-UI-013: Figma left-aligns the shelter avatar and name.
  testWidgets('shelter name is left aligned', (t) async {
    await chat.pumpDay118Chat(t, const Size(430, 932));
    final name = find.textContaining('& PawMate');
    expect(name, findsOneWidget);
    expect(t.getRect(name).left, lessThan(60));
  });

  // Android ShelterChat stress: chips must grow with text, not clip at 36dp.
  testWidgets('quick reply chip is not a fixed 36dp box', (t) async {
    await chat.pumpDay118Chat(t, const Size(430, 932));
    final chip = find.descendant(
      of: find.byKey(const Key('adoption-chat-quick-reply-0')),
      matching: find.byType(Container),
    );
    final box = t.widget<Container>(chip.first);
    expect(box.constraints?.maxHeight ?? double.infinity, double.infinity);
  });
}

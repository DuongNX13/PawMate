import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_top_bar.dart';

import '../../test_support/ui_test_helpers.dart';

// D122-TB-P2-005 / Android Notifications stress: screen titles must stay
// whole ("Thông báo", "Lịch nhắc nhở") at 320 wide and 2x text.
void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('top bar title is never ellipsized at 320 text 2', (t) async {
    await setTestViewport(t, size: const Size(320, 568));
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(2),
        home: Scaffold(
          appBar: PawMateTopBar(
            title: 'Lịch nhắc nhở',
            showBackButton: true,
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final title = find.text('Lịch nhắc nhở');
    expect(t.renderObject<RenderParagraph>(title).didExceedMaxLines, isFalse);
    expectNoFlutterOverflow(t);
  });
}

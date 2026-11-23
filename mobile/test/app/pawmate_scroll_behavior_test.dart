import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/pawmate_scroll_behavior.dart';

void main() {
  testWidgets('PawMate does not install a shader-backed overscroll decorator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const PawMateScrollBehavior(),
        home: Scaffold(
          body: ListView(
            children: const [SizedBox(height: 1200, child: Text('Nội dung'))],
          ),
        ),
      ),
    );

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });
}

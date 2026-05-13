import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/primary_gradient_button.dart';

import '../test_support/ui_test_helpers.dart';

void main() {
  test('brand text colors meet WCAG contrast thresholds', () {
    expect(
      _contrastRatio(Colors.white, AppColors.primary500),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(Colors.white, AppColors.primary700),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.label, AppColors.surfaceMuted),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.label, AppColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.primary700, AppColors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('primary CTA meets tap target, label, and contrast guidelines', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: testTextScaleBuilder(1.3),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: PrimaryGradientButton(
                label: 'Gửi đánh giá',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gửi đánh giá'), findsOneWidget);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(textContrastGuideline));
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLum = foreground.computeLuminance();
  final backgroundLum = background.computeLuminance();
  final lighter = foregroundLum > backgroundLum ? foregroundLum : backgroundLum;
  final darker = foregroundLum > backgroundLum ? backgroundLum : foregroundLum;
  return (lighter + 0.05) / (darker + 0.05);
}

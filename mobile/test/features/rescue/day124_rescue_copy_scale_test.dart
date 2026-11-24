import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

// D122-R61-COPY-01/02 (Android DT-04/DT-05/RescueExpanded/RescueSelected):
// the "Báo mất" subtitle and case breed must not clip at 360x800 / 2x text.
void main() {
  setUpAll(loadPawMateTestFonts);

  for (final size in const [Size(360, 800), Size(320, 568)]) {
    testWidgets('rescue copy readable at ${size.width} text 2', (t) async {
      await setTestViewport(t, size: size);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(pages: [samplePage(items: sampleCases())]),
            ),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const RescueHomeScreen(
              browseEnabled: true,
              createEnabled: true,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final subtitle = find.text('Gửi thông tin tìm kiếm thú cưng ngay');
      expect(subtitle, findsOneWidget);
      expect(
        t.renderObject<RenderParagraph>(subtitle).didExceedMaxLines,
        isFalse,
      );
      expectNoFlutterOverflow(t);
    });
  }
}

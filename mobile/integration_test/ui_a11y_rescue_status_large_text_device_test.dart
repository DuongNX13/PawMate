import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_status_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Rescue Status keeps its title readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(
                detail: sampleCaseDetail(canUpdateStatus: true, version: 2),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const RescueStatusScreen(
              caseId: '11111111-1111-4111-8111-111111111111',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Cập nhật trạng thái'), findsOneWidget);
      final title = find.text('Trạng thái');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-07 title must not ellipsize at text scale 2.0',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

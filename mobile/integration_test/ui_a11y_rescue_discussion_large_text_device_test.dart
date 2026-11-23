import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../test/features/rescue/rescue_comment_test_fixtures.dart';
import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Rescue Discussion keeps its title readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueCommentSourceProvider.overrideWithValue(
              FakeRescueCommentSource(comments: [sampleComments().first]),
            ),
            authAccessTokenProvider.overrideWith((ref) async => 'viewer-token'),
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: sampleCaseDetail()),
            ),
            rescueCommentClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 7, 27, 10, 30),
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
            home: const RescueCommentScreen(
              caseId: sampleCommentCaseId,
              discussionMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Thảo luận ca tìm'), findsOneWidget);
      final title = find.text('Trao đổi');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-08 title must not ellipsize at text scale 2.0',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

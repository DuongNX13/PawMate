import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Rescue Case Detail keeps its title readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/rescue/11111111-1111-4111-8111-111111111111',
        routes: [
          GoRoute(
            path: '/rescue',
            builder: (_, _) => const Scaffold(body: Text('Rescue Home')),
          ),
          GoRoute(
            path: '/rescue/:caseId',
            builder: (_, state) =>
                RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
          ),
          GoRoute(
            path: '/rescue/:caseId/comment',
            builder: (_, _) => const Scaffold(body: Text('Comment target')),
          ),
          GoRoute(
            path: '/rescue/:caseId/status',
            builder: (_, _) => const Scaffold(body: Text('Status target')),
          ),
          GoRoute(
            path: '/rescue/map',
            builder: (_, _) => const Scaffold(body: Text('Rescue Map')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: sampleCaseDetail()),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Chi tiết tin báo'), findsOneWidget);
      final title = find.text('Tin báo');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-04 title must not ellipsize at text scale 2.0',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

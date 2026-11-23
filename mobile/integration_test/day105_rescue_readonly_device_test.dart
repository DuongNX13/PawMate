import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Day105 API35 read-only Rescue journey opens the exact selected case',
    (tester) async {
      await binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => binding.setSurfaceSize(null));

      final source = FakeRescueSource(
        pages: [samplePage()],
        detail: sampleCaseDetail(),
      );
      final selectedId = sampleCases().first.caseId;
      final router = GoRouter(
        initialLocation: '/rescue',
        routes: [
          GoRoute(
            path: '/rescue',
            builder: (_, _) => const RescueHomeScreen(
              browseEnabled: true,
              createEnabled: false,
            ),
          ),
          GoRoute(
            path: '/rescue/:caseId',
            builder: (_, state) =>
                RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(source),
            rescueClockProvider.overrideWithValue(fixedRescueClock()),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rescue-live-list')), findsOneWidget);
      expect(source.callCount, 1);

      final marker = find.byKey(ValueKey('rescue-marker-$selectedId'));
      await tester.scrollUntilVisible(
        marker,
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('rescue-live-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(marker);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rescue-selected-case-card')),
        findsOneWidget,
      );
      expect(source.detailCaseIds, isEmpty);

      final details = find.byKey(const Key('rescue-selected-details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rescue-case-detail-screen')),
        findsOneWidget,
      );
      expect(source.detailCaseIds, [selectedId]);
      expect(find.text('LuLu'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Rescue Home keeps dynamic case data readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      const petName = 'Bông Tuyết Golden Retriever Siêu Dễ Thương 2026';
      const breed = 'Golden Retriever lai lông dài màu kem đậm';
      const area = 'Phường 13, Quận Tân Bình, Thành phố Hồ Chí Minh';
      final source = FakeRescueSource(
        pages: [
          samplePage(
            items: [
              rescueCase(
                caseId: '44444444-4444-4444-8444-444444444444',
                petName: petName,
                species: RescueSpecies.dog,
                status: RescueCaseStatus.missing,
                areaLabel: area,
                breedOrColor: breed,
              ),
            ],
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/rescue',
        routes: [
          GoRoute(
            path: '/rescue',
            builder: (context, state) =>
                const RescueHomeScreen(browseEnabled: true),
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

      await tester.scrollUntilVisible(
        find.byKey(
          const Key('rescue-case-44444444-4444-4444-8444-444444444444'),
        ),
        280,
        scrollable: find.descendant(
          of: find.byKey(const Key('rescue-live-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        petName,
        breed,
        '$area · 2 giờ trước',
        'CẬP NHẬT VỪA XONG',
        'Chưa thấy',
      ]) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
          reason: 'Visible Rescue data must not truncate: $label',
        );
      }

      final openCaseAction = find.byKey(
        const Key('rescue-case-44444444-4444-4444-8444-444444444444'),
      );
      expect(tester.getSize(openCaseAction).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );
}

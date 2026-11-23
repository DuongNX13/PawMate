import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_state_view.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_case_detail_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';

import '../test_support/ui_test_helpers.dart';
import '../test_support/day115_capture.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    final scale = size.width == 320 ? 2.0 : 1.0;
    testWidgets('D115 UX-25 deleted Pet safe recovery ${size.width}', (
      tester,
    ) async {
      await setTestViewport(tester, size: size);
      var requests = 0;
      final router = _router(
        const PetDetailScreen(petId: 'deleted'),
        '/pets/list',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async {
              requests++;
              return [];
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: testTextScaleBuilder(scale),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy thú cưng'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(find.text('Quay lại danh sách'), findsOneWidget);
      await captureDay115(tester, 'UX-25-pet-${size.width.toInt()}');
      await tester.ensureVisible(find.text('Quay lại danh sách'));
      await tester.tap(find.text('Quay lại danh sách'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/pets/list');
      expect(requests, 1);
      expectNoFlutterOverflow(tester);
    });

    testWidgets('D115 UX-25 deleted Vet safe recovery ${size.width}', (
      tester,
    ) async {
      await setTestViewport(tester, size: size);
      var requests = 0;
      final router = _router(
        const VetDetailScreen(vetId: 'deleted'),
        '/vets/list',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vetDetailProvider('deleted').overrideWith((ref) async {
              requests++;
              throw const VetApiException('missing', statusCode: 404);
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: testTextScaleBuilder(scale),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phòng khám không còn khả dụng'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      await captureDay115(tester, 'UX-25-vet-${size.width.toInt()}');
      await tester.ensureVisible(find.text('Về danh sách phòng khám'));
      await tester.tap(find.text('Về danh sách phòng khám'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/vets/list');
      expect(requests, 1);
      expectNoFlutterOverflow(tester);
    });

    testWidgets('D115 UX-25 deleted Rescue safe recovery ${size.width}', (
      tester,
    ) async {
      await setTestViewport(tester, size: size);
      var requests = 0;
      final router = _router(
        const RescueCaseDetailScreen(caseId: 'deleted'),
        '/rescue',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rescueCaseDetailProvider('deleted').overrideWith((ref) async {
              requests++;
              throw const RescueApiException('missing', statusCode: 404);
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: testTextScaleBuilder(scale),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tin báo không còn khả dụng'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      await captureDay115(tester, 'UX-25-rescue-${size.width.toInt()}');
      await tester.ensureVisible(find.text('Quay lại'));
      await tester.tap(find.text('Quay lại').last);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/rescue');
      expect(requests, 1);
      expectNoFlutterOverflow(tester);
    });
  }

  testWidgets(
    'D115 Vet transient error remains retryable and redacts internals',
    (tester) async {
      var requests = 0;
      final router = _router(
        const VetDetailScreen(vetId: 'offline'),
        '/vets/list',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vetDetailProvider('offline').overrideWith((ref) async {
              requests++;
              throw StateError('PRIVATE_DIAGNOSTIC');
            }),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PawMateStateView), findsOneWidget);
      expect(find.textContaining('PRIVATE_DIAGNOSTIC'), findsNothing);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      await tester.tap(find.text('Về danh sách phòng khám'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/vets/list');
    },
  );
}

GoRouter _router(Widget screen, String fallback) => GoRouter(
  initialLocation: '/detail',
  routes: [
    GoRoute(path: '/detail', builder: (_, _) => screen),
    GoRoute(
      path: fallback,
      builder: (_, _) => const Scaffold(body: Text('SAFE_DESTINATION')),
    ),
  ],
);

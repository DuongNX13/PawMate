import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Day107 active Rescue visual checkpoints',
    (tester) async {
      await binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => binding.setSurfaceSize(null));
      final source = FakeRescueSource(
        pages: [samplePage(items: _fiveCases(), hasMore: false)],
        detail: sampleCaseDetail(),
      );
      final router = _router();
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
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rescue-live-list')), findsOneWidget);
      _expectLockedNavigation(tester);
      await _checkpoint(binding, 'collapsed');

      final toggle = find.byKey(const Key('rescue-load-more'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(find.text('Mây'), findsOneWidget);
      _expectLockedNavigation(tester);
      await _checkpoint(binding, 'expanded');

      final firstId = _fiveCases().first.caseId;
      final marker = find.byKey(ValueKey('rescue-marker-$firstId'));
      await tester.scrollUntilVisible(
        marker,
        -180,
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
      _expectLockedNavigation(tester);
      await _checkpoint(binding, 'selected');

      final details = find.byKey(const Key('rescue-selected-details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rescue-case-detail-screen')),
        findsOneWidget,
      );
      expect(find.text('LuLu'), findsWidgets);
      await _checkpoint(binding, 'detail');
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

void _expectLockedNavigation(WidgetTester tester) {
  expect(
    PawMateBottomNav.destinations.map((item) => item.label).toList(),
    const ['Home', 'Vet', 'Health', 'Rescue', 'Profile'],
  );
  expect(
    PawMateBottomNav.destinations[3].iconAsset,
    'assets/icons/navigation/rescue.png',
  );
  final nav = find.byType(PawMateBottomNav);
  expect(nav, findsOneWidget);
  final rect = tester.getRect(nav);
  expect(rect.left, closeTo(0, 0.01));
  expect(rect.right, closeTo(390, 0.01));
  expect(rect.bottom, closeTo(844, 0.01));
}

Future<void> _checkpoint(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  debugPrint('DAY107_CHECKPOINT:$name:READY');
  final bytes = await binding.takeScreenshot('day107-rescue-$name');
  final encoded = base64Encode(bytes);
  const chunkSize = 384;
  final total = (encoded.length / chunkSize).ceil();
  for (var index = 0; index < total; index++) {
    final start = index * chunkSize;
    final end = (start + chunkSize).clamp(0, encoded.length);
    debugPrintSynchronously(
      'DAY107_B64:$name:$index:$total:${encoded.substring(start, end)}',
      wrapWidth: 1000,
    );
  }
  debugPrint('DAY107_CHECKPOINT:$name:DONE');
}

GoRouter _router() => GoRouter(
  initialLocation: '/rescue',
  routes: [
    GoRoute(
      path: '/rescue',
      builder: (_, _) => const RescueHomeScreen(
        browseEnabled: true,
        createEnabled: true,
        mapPreviewAsset: 'assets/images/rescue/p2_01_map.png',
      ),
    ),
    GoRoute(
      path: '/rescue/:caseId',
      builder: (_, state) =>
          RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
    ),
    for (final path in const [
      '/pets',
      '/vets/map',
      '/health',
      '/profile',
      '/profile/controls',
      '/notifications',
      '/rescue/map',
      '/rescue/create',
    ])
      GoRoute(path: path, builder: (_, _) => const Scaffold()),
  ],
);

List<RescueCaseSummary> _fiveCases() {
  final source = [
    ...sampleCases(),
    rescueCase(
      caseId: '44444444-4444-4444-8444-444444444444',
      petName: 'Nắng',
      species: RescueSpecies.dog,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 1',
      breedOrColor: 'Corgi',
    ),
    rescueCase(
      caseId: '55555555-5555-4555-8555-555555555555',
      petName: 'Mây',
      species: RescueSpecies.cat,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 5',
      breedOrColor: 'Mèo Anh lông ngắn',
    ),
  ];
  const assets = [
    'assets/images/rescue/p2_01_lulu.png',
    'assets/images/rescue/p2_01_muc.png',
    'assets/images/rescue/p2_01_bong.png',
  ];
  return [
    for (var index = 0; index < source.length; index++)
      RescueCaseSummary(
        caseId: source[index].caseId,
        petName: source[index].petName,
        species: source[index].species,
        status: source[index].status,
        lostAt: source[index].lostAt,
        publicLocation: source[index].publicLocation,
        media: [
          RescuePublicMedia(
            mediaId: 'day107-$index',
            mimeType: 'image/png',
            publicUrl: Uri(
              scheme: 'asset',
              path: assets[index % assets.length],
            ),
            createdAt: source[index].createdAt,
          ),
        ],
        commentCount: source[index].commentCount,
        createdAt: source[index].createdAt,
        updatedAt: source[index].updatedAt,
        breedOrColor: source[index].breedOrColor,
        ageLabel: source[index].ageLabel,
        distanceMeters: source[index].distanceMeters,
      ),
  ];
}

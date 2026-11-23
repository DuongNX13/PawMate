import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../features/rescue/rescue_test_fixtures.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day100-rescue-golden-root');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final expanded in [false, true]) {
    testWidgets('DT-04 ${expanded ? 'expanded' : 'collapsed'} 390x844', (
      tester,
    ) async {
      await _pumpRescueHome(tester, size: const Size(390, 844));
      if (expanded) await _expandNearbyList(tester);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile(
          'goldens/day100/dt-04-rescue-${expanded ? 'expanded' : 'collapsed'}-390x844.png',
        ),
      );
    });
  }

  testWidgets('DT-04 expanded reduced-motion 320x568 text 2', (tester) async {
    await _pumpRescueHome(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      disableAnimations: true,
    );
    await _expandNearbyList(tester);
    expectNoFlutterOverflow(tester);
    expect(find.byType(PawMateBottomNav), findsOneWidget);
    expect(tester.getRect(find.byType(PawMateBottomNav)).bottom, 568);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/day100/dt-04-rescue-expanded-text2-320x568.png',
      ),
    );
  });
}

Future<void> _pumpRescueHome(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  await setTestViewport(tester, size: size);
  final source = FakeRescueSource(
    pages: [samplePage(items: _visualCases(), hasMore: false)],
  );
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
              accessibleNavigation: disableAnimations,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await _precacheAssets(tester);
  await tester.pumpAndSettle();
}

Future<void> _expandNearbyList(WidgetTester tester) async {
  final toggle = find.byKey(const Key('rescue-load-more'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(find.text('Thu gọn'), findsOneWidget);
  expect(find.text('Mây'), findsOneWidget);
}

Future<void> _precacheAssets(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byKey(_goldenKey));
  for (final destination in PawMateBottomNav.destinations) {
    await tester.runAsync(
      () => precacheImage(AssetImage(destination.iconAsset), context),
    );
  }
  for (final asset in const [
    'assets/images/rescue/p2_01_map.png',
    'assets/images/rescue/p2_01_lulu.png',
    'assets/images/rescue/p2_01_muc.png',
    'assets/images/rescue/p2_01_bong.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/rescue',
    restorationScopeId: 'day100-router',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (context, state) => const RescueHomeScreen(
          browseEnabled: true,
          createEnabled: true,
          mapPreviewAsset: 'assets/images/rescue/p2_01_map.png',
        ),
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
        GoRoute(path: path, builder: (context, state) => const Scaffold()),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (context, state) => const Scaffold(),
      ),
    ],
  );
}

List<RescueCaseSummary> _visualCases() {
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
            mediaId: 'day100-$index',
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

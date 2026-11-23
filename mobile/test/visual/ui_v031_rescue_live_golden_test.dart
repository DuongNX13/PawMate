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

const _goldenKey = Key('ui-v031-rescue-live-golden-root');
const _viewports = [Size(360, 844), Size(390, 844), Size(430, 932)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final viewport in _viewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('Rescue live golden at $tag', (tester) async {
      await setTestViewport(tester, size: viewport);
      final source = FakeRescueSource(
        pages: [samplePage(items: _visualCases())],
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
            ),
          ),
        ),
      );
      await _precacheAssets(tester);
      await tester.pumpAndSettle();

      expect(find.text('Cứu hộ'), findsOneWidget);
      expect(find.text('Báo thấy'), findsNothing);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/ui-v031-rescue/rescue-live-$tag.png'),
      );
    });
  }
}

Future<void> pumpDay118RescueHome(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(pages: [samplePage(items: _visualCases())]),
        ),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await _precacheAssets(tester);
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
  await tester.pumpAndSettle();
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/rescue',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (context, state) => const RescueHomeScreen(
          browseEnabled: true,
          mapPreviewAsset: 'assets/images/rescue/p2_01_map.png',
          now: _displayClock,
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
      ])
        GoRoute(path: path, builder: (context, state) => const Scaffold()),
    ],
  );
}

DateTime _displayClock() => DateTime.utc(2026, 7, 23, 10, 1);

List<RescueCaseSummary> _visualCases() {
  const assets = [
    'assets/images/rescue/p2_01_lulu.png',
    'assets/images/rescue/p2_01_muc.png',
    'assets/images/rescue/p2_01_bong.png',
  ];
  final source = sampleCasesWithoutImages();
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
            mediaId: 'visual-${source[index].caseId}',
            mimeType: 'image/png',
            publicUrl: Uri(scheme: 'asset', path: assets[index]),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_location_service.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_share_service.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';

import '../features/adoption/adoption_ui_test_support.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day54-adoption-golden-root');
const _viewport = Size(390, 844);
const _adoptionHeroFixturePath =
    'test/fixtures/images/golden_retriever_hero_v1.png';

Future<void> pumpDay120AdoptionFilter(WidgetTester tester, Size size) async {
  await _pumpDeck(tester, viewport: size);
  await tester.tap(find.byKey(const Key('adoption-filter-button')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
    expect(
      File(_adoptionHeroFixturePath).existsSync(),
      isTrue,
      reason: 'Golden fixture must exist at $_adoptionHeroFixturePath.',
    );
  });

  testWidgets('P2-09 Adoption Swipe Deck golden at 390x844', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpDeck(tester, enableNearby: true);

    expect(find.text('Mochi, 2 tuổi'), findsOneWidget);
    expect(find.text('PawMate'), findsOneWidget);
    expect(find.text('Bán kính 5km'), findsOneWidget);
    expect(find.byKey(const Key('adoption-filter-button')), findsOneWidget);
    expect(find.text('VUỐT PHẢI ĐỂ XEM HỒ SƠ'), findsOneWidget);
    expect(find.byKey(const Key('adoption-my-requests-button')), findsNothing);
    expect(find.bySemanticsLabel('Bỏ qua'), findsOneWidget);
    expect(find.bySemanticsLabel('Ảnh đại diện của Mochi'), findsOneWidget);
    expect(find.text('Chưa có ảnh của Mochi'), findsNothing);

    expectNoFlutterOverflow(tester);
    semantics.dispose();
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day54/p2-09-adoption-swipe-deck-390x844.png'),
    );
  });

  testWidgets(
    'P2-09 keeps My Requests CTA readable at accessibility text scale',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDeck(tester, textScale: 2);

      const ctaKey = Key('adoption-my-requests-button');
      await tester.tap(find.byKey(const Key('adoption-filter-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(ctaKey), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(ctaKey)).label,
        contains('Xem đơn nhận nuôi của tôi'),
      );

      final rootRect = tester.getRect(find.byKey(_goldenKey));
      final ctaRect = tester.getRect(find.byKey(ctaKey));
      expect(rootRect.contains(ctaRect.topLeft), isTrue);
      expect(rootRect.contains(ctaRect.bottomRight), isTrue);
      expectNoFlutterOverflow(tester);
      semantics.dispose();
    },
  );

  testWidgets('DT-10 Adoption Filter Sheet golden at 390x844', (tester) async {
    await _pumpDeck(tester);

    await tester.tap(find.byKey(const Key('adoption-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Độ tuổi'), findsOneWidget);
    expect(find.text('1–3 tuổi'), findsOneWidget);
    expect(find.text('10 km'), findsOneWidget);
    expect(find.byKey(const Key('adoption-apply-filters')), findsOneWidget);
    expect(find.byKey(const Key('adoption-clear-filters')), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await expectLater(
      find.byType(Overlay),
      matchesGoldenFile('goldens/day108/dt-10-adoption-filter-390x844.png'),
    );
  });

  testWidgets('P2-10 Adoption Profile golden at 390x844', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('Hồ sơ nhận nuôi'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);
    expect(find.text('Gửi yêu cầu nhận nuôi'), findsOneWidget);
    expect(find.text('Lưu trên máy'), findsOneWidget);
    expect(find.bySemanticsLabel('Ảnh đại diện của Mochi'), findsOneWidget);
    expect(find.text('Chưa có ảnh của Mochi'), findsNothing);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day54/p2-10-adoption-profile-390x844.png'),
    );
  });
}

Future<void> _pumpDeck(
  WidgetTester tester, {
  double textScale = 1,
  bool enableNearby = false,
  Size viewport = _viewport,
}) async {
  final heroImageProvider = _adoptionHeroImage();
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adoptionSourceProvider.overrideWithValue(
          FakeAdoptionUiSource(
            page: uiAdoptionPage(
              items: [
                uiAdoptionSummary(
                  distanceKm: 1.2,
                  traits: const ['Thân thiện', 'Năng động', 'Dễ gần'],
                ),
              ],
            ),
          ),
        ),
        adoptionAccessTokenProvider.overrideWith(
          (ref) => Future<String?>.value('day54-golden-token'),
        ),
        adoptionLocationSourceProvider.overrideWithValue(
          FakeAdoptionLocationSource(),
        ),
        adoptionClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 28, 4),
        ),
        adoptionIdempotencyKeyFactoryProvider.overrideWithValue(
          (decision, listingId, timestamp, sequence) =>
              'day54-golden-${decision.wireValue}-$listingId-$sequence',
        ),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(textScale),
          home: AdoptionSwipeDeckScreen(heroImageProvider: heroImageProvider),
        ),
      ),
    ),
  );
  await _precacheAdoptionHero(
    tester,
    find.byType(AdoptionSwipeDeckScreen),
    heroImageProvider,
  );
  await tester.pumpAndSettle();
  if (enableNearby) {
    await tester.tap(find.byKey(const Key('adoption-location-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 km'));
    await tester.tap(find.byKey(const Key('adoption-apply-filters')));
    await tester.pumpAndSettle();
  }
}

Future<void> pumpDay118AdoptionDeck(WidgetTester tester, Size viewport) =>
    _pumpDeck(tester, viewport: viewport);

Future<void> pumpDay118AdoptionProfile(WidgetTester tester, Size viewport) =>
    _pumpProfile(tester, viewport: viewport);

Future<void> _pumpProfile(
  WidgetTester tester, {
  Size viewport = _viewport,
}) async {
  final heroImageProvider = _adoptionHeroImage();
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adoptionSourceProvider.overrideWithValue(
          FakeAdoptionUiSource(detail: uiAdoptionDetail()),
        ),
        adoptionAccessTokenProvider.overrideWith(
          (ref) => Future<String?>.value('day54-golden-token'),
        ),
        adoptionSavedListingStoreProvider.overrideWithValue(
          MemoryAdoptionSavedListingStore(),
        ),
        adoptionShareSourceProvider.overrideWithValue(
          FakeAdoptionShareSource(),
        ),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: AdoptionProfileScreen(
            listingId: adoptionListingId,
            heroImageProvider: heroImageProvider,
          ),
        ),
      ),
    ),
  );
  await _precacheAdoptionHero(
    tester,
    find.byType(AdoptionProfileScreen),
    heroImageProvider,
  );
  await tester.pumpAndSettle();
}

ImageProvider<Object> _adoptionHeroImage() =>
    FileImage(File(_adoptionHeroFixturePath));

Future<void> _precacheAdoptionHero(
  WidgetTester tester,
  Finder screen,
  ImageProvider<Object> imageProvider,
) async {
  final context = tester.element(screen);
  await tester.runAsync(() => precacheImage(imageProvider, context));
}

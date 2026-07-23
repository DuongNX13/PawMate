import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day23-vet-finder-golden-root');
const _vetListExtraViewports = <Size>[Size(360, 844), Size(430, 932)];
const _vet = VetSummary(
  id: 'petcare-elite',
  name: 'PetCare Elite',
  city: 'TP Hồ Chí Minh',
  district: 'Quận 1',
  address: '120 Nguyễn Lương Bằng, Phú Mỹ, Quận 7',
  phone: '0903 111 222',
  summary: 'Cấp cứu 24/7 và tiêm phòng định kỳ.',
  services: ['Cấp cứu 24/7', 'Tiêm phòng'],
  seedRank: 1,
  averageRating: 4.8,
  reviewCount: 120,
  is24h: true,
  isOpen: true,
  readyForMap: true,
  latitude: 10.778,
  longitude: 106.701,
  distanceMeters: 1200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-08 Vet Finder map golden at 390x844', (tester) async {
    await _pumpMap(tester, const Size(390, 844));
    expect(find.byKey(const Key('vet-map-filter-5km')), findsNothing);
    expect(find.byKey(const Key('vet-map-filter-rating-4')), findsNothing);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day23/p1-08-vet-map-390x844.png'),
    );
  });

  for (final viewport in const [
    Size(320, 568),
    Size(360, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets(
      'P1-08 map bottom sheet ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        await _pumpMap(tester, viewport);
        expect(find.byKey(const Key('vet-map-filter-5km')), findsNothing);
        expect(find.byKey(const Key('vet-map-filter-rating-4')), findsNothing);
        if (viewport.height < 700) {
          final locationBanner = tester.getRect(
            find.byKey(const Key('vet-map-location-banner')),
          );
          final bottomPanel = tester.getRect(
            find.byKey(const Key('vet-map-bottom-panel')),
          );
          expect(
            bottomPanel.top,
            greaterThanOrEqualTo(locationBanner.bottom),
            reason: 'Compact map panel must not cover the location banner',
          );
        }
        expectNoFlutterOverflow(tester);
        await expectLater(
          find.byKey(_goldenKey),
          matchesGoldenFile(
            'goldens/day23/p1-08-vet-map-bottom-sheet-${viewport.width.toInt()}x${viewport.height.toInt()}.png',
          ),
        );
      },
    );
  }

  testWidgets('P1-09 Vet Finder list golden at 390x844', (tester) async {
    await _pumpList(tester, const Size(390, 844));
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day23/p1-09-vet-list-390x844.png'),
    );
  });

  for (final viewport in _vetListExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-09 Vet Finder list responsive golden at $tag', (
      tester,
    ) async {
      await _pumpList(tester, viewport);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day23/p1-09-vet-list-$tag.png'),
      );
    });
  }
}

Future<void> _pumpList(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [vetApiProvider.overrideWith((ref) => _FakeVetApi())],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const VetListScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMap(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vetApiProvider.overrideWith((ref) => _FakeVetApi()),
        vetLocationServiceProvider.overrideWith(
          (ref) => _FakeLocationService(),
        ),
        vetMapCanvasBuilderProvider.overrideWith(
          (ref) =>
              (
                VetMapLocation center,
                List<VetSummary> items,
                VetMapStyle style,
                ValueChanged<String> onMarkerTap,
                ValueChanged<Object> onMapUnavailable,
              ) => DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.surfaceContainer, AppColors.lightBeige],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Mở ${_vet.name}',
                    child: GestureDetector(
                      onTap: () => onMarkerTap(_vet.vetId),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: AppColors.brown,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const VetMapScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeVetApi extends VetApi {
  _FakeVetApi() : super(Dio());

  @override
  Future<VetNearbyResult> nearby(VetNearbyRequest request) async {
    return const VetNearbyResult(items: [_vet], total: 1, limit: 20);
  }

  @override
  Future<VetSearchResult> search(VetSearchRequest request) async {
    return const VetSearchResult(items: [_vet], total: 1, limit: 20);
  }
}

class _FakeLocationService implements VetLocationService {
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    return const VetMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

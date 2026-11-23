import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/pawmate_scroll_behavior.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> prepareScreenshot() async {
    try {
      await binding.convertFlutterSurfaceToImage();
      return true;
    } on MissingPluginException catch (error) {
      debugPrint('ANDROID_SCREENSHOT_SKIPPED: $error');
      return false;
    }
  }

  testWidgets('captures Day 23 Map on Android', (tester) async {
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
                      colors: [Color(0xFFE6F0DF), Color(0xFFF5EBDD)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => onMarkerTap(_vet.vetId),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Color(0xFFE85D9B),
                        size: 48,
                      ),
                    ),
                  ),
                ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const VetMapScreen(),
        ),
      ),
    );
    final canTakeScreenshot = await prepareScreenshot();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (canTakeScreenshot) {
      await binding.takeScreenshot('day23-vet-map-android');
    }
  });

  testWidgets('captures Day 23 List on Android', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vetApiProvider.overrideWith((ref) => _FakeVetApi())],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const VetListScreen(),
        ),
      ),
    );
    final canTakeScreenshot = await prepareScreenshot();
    await tester.pumpAndSettle();
    expect(find.text('PetCare Elite'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (canTakeScreenshot) {
      await binding.takeScreenshot('day23-vet-list-android');
    }
  });

  testWidgets('renders Day 23 Map at Android large text without overflow', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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
                ) => const ColoredBox(color: Color(0xFFEDE6DA)),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          scrollBehavior: const PawMateScrollBehavior(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const VetMapScreen(),
        ),
      ),
    );
    final canTakeScreenshot = await prepareScreenshot();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('PawMate'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (canTakeScreenshot) {
      await binding.takeScreenshot('day23-vet-map-large-text-android');
    }
    semantics.dispose();
  });
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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';

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
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('PetCare Elite'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('day23-vet-list-android-clean');
  });
}

class _FakeVetApi extends VetApi {
  _FakeVetApi() : super(Dio());

  @override
  Future<VetSearchResult> search(VetSearchRequest request) async {
    return const VetSearchResult(items: [_vet], total: 1, limit: 20);
  }
}

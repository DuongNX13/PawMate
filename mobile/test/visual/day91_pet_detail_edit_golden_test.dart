import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _rootKey = Key('day91-pet-detail-edit-golden-root');
const _viewports = <Size>[Size(360, 800), Size(390, 844), Size(430, 932)];

Future<void> pumpDay120PetEdit(WidgetTester tester, Size size) =>
    _pumpEdit(tester, size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final viewport in _viewports) {
    final label = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('DT-01 Pet Detail anchor-derived golden at $label', (
      tester,
    ) async {
      await _pumpDetail(tester, viewport);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_rootKey),
        matchesGoldenFile('goldens/day91/dt-01-pet-detail-$label.png'),
      );
    });

    testWidgets('DT-02 Pet Edit anchor-derived golden at $label', (
      tester,
    ) async {
      await _pumpEdit(tester, viewport);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_rootKey),
        matchesGoldenFile('goldens/day91/dt-02-pet-edit-$label.png'),
      );
    });
  }

  testWidgets('DT-02 deleted/not-found contextual golden at 390x844', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWithValue(
            const AsyncValue<List<PetProfile>>.data([]),
          ),
        ],
        child: RepaintBoundary(
          key: _rootKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const CreatePetScreen(
              petId: 'deleted-pet',
              returnTo: '/pets/list',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_rootKey),
      matchesGoldenFile('goldens/day91/dt-02-pet-edit-not-found-390x844.png'),
    );
  });
}

Future<void> _pumpDetail(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final pet = _pet();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data([pet]),
        ),
      ],
      child: RepaintBoundary(
        key: _rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const PetDetailScreen(petId: 'mochi'),
        ),
      ),
    ),
  );
  await _precachePetImage(tester);
}

Future<void> _pumpEdit(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final pet = _pet();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data([pet]),
        ),
      ],
      child: RepaintBoundary(
        key: _rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const CreatePetScreen(petId: 'mochi'),
        ),
      ),
    ),
  );
  await _precachePetImage(tester);
}

Future<void> _precachePetImage(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byKey(_rootKey));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/pets/p1_05_mochi.png'),
      context,
    ),
  );
  await tester.pumpAndSettle();
}

PetProfile _pet() => PetProfile(
  id: 'mochi',
  name: 'Mochi',
  species: 'dog',
  breed: 'Golden Retriever',
  gender: 'male',
  dateOfBirth: DateTime(2022, 4, 12),
  weightKg: 12.4,
  healthStatus: 'healthy',
  avatarPath: 'assets/images/pets/p1_05_mochi.png',
  color: 'Vàng kem',
  microchip: 'MC-8293-128',
  isNeutered: true,
);

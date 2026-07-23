import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenRootKey = Key('day18-pet-golden-root');
const _formViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];
const _petListExtraViewports = <Size>[Size(360, 844), Size(430, 932)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-05 Pet List golden at 390x844', (tester) async {
    await _pumpPetList(tester, const Size(390, 844));

    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day18/p1-05-pet-list-390x844.png'),
    );
  });

  for (final viewport in _petListExtraViewports) {
    final label = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-05 Pet List responsive golden at $label', (tester) async {
      await _pumpPetList(tester, viewport);

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day18/p1-05-pet-list-$label.png'),
      );
    });
  }

  for (final viewport in _formViewports) {
    final label = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-06 Pet Form golden at $label', (tester) async {
      await setTestViewport(tester, size: viewport);
      await tester.pumpWidget(
        ProviderScope(
          child: RepaintBoundary(
            key: _goldenRootKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: const CreatePetScreen(returnTo: '/pets/list'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day18/p1-06-pet-form-$label.png'),
      );
    });
  }
}

Future<void> _pumpPetList(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final pets = [
    _pet(
      id: 'mochi',
      name: 'Mochi',
      breed: 'Mèo tam thể',
      species: 'cat',
      avatarPath: 'assets/images/pets/p1_05_mochi.png',
    ),
    _pet(
      id: 'kem',
      name: 'Kem',
      breed: 'Samoyed',
      species: 'dog',
      avatarPath: 'assets/images/pets/p1_05_kem.png',
    ),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data(pets),
        ),
      ],
      child: RepaintBoundary(
        key: _goldenRootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const PetListScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byKey(_goldenRootKey));
  for (final asset in const [
    'assets/images/pets/p1_05_mochi.png',
    'assets/images/pets/p1_05_kem.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pumpAndSettle();
}

PetProfile _pet({
  required String id,
  required String name,
  required String breed,
  required String species,
  required String avatarPath,
}) {
  return PetProfile(
    id: id,
    name: name,
    species: species,
    breed: breed,
    gender: 'unknown',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
    avatarPath: avatarPath,
    color: 'Vàng kem',
  );
}

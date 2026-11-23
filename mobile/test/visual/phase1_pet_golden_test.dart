import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_form_draft_provider.dart';
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
const _petListViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];
final _goldenNow = DateTime(2024, 5, 20);

Future<void> pumpDay120PetCreate(WidgetTester tester, Size size) =>
    _pumpPetForm(tester, size);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final viewport in _petListViewports) {
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
      await _pumpPetForm(tester, viewport);
      await tester.tap(find.byKey(const Key('pet-form-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên'), findsOneWidget);

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day18/p1-06-pet-form-$label.png'),
      );
    });
  }
}

Future<void> pumpDay118PetList(WidgetTester tester, Size viewport) =>
    _pumpPetList(tester, viewport);

Future<void> pumpDay118DynamicPets(WidgetTester tester, Size viewport) =>
    _pumpPetList(tester, viewport, dynamicContent: true);

Future<void> _pumpPetList(
  WidgetTester tester,
  Size viewport, {
  bool dynamicContent = false,
}) async {
  await setTestViewport(tester, size: viewport);
  final pets = [
    _pet(
      id: 'mochi',
      name: 'Mochi',
      breed: 'Tam thể',
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

  if (dynamicContent) {
    pets.addAll(
      List.generate(
        18,
        (i) => _pet(
          id: 'dynamic-$i',
          name: 'Bạn nhỏ Mochi đáng yêu số $i',
          breed: 'Golden Retriever lai Poodle lông xoăn',
          species: 'dog',
          avatarPath: 'assets/images/pets/p1_05_mochi.png',
        ),
      ),
    );
  }

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
          home: PetListScreen(now: _goldenNow),
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

Future<void> _pumpPetForm(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container
      .read(petFormDraftProvider.notifier)
      .replace(
        PetFormDraft(
          breed: 'Golden Retriever',
          dateOfBirth: DateTime(2022, 4, 12),
          weightText: '12.4',
          color: 'Vàng kem',
          microchip: 'MC-8293-128',
        ),
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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

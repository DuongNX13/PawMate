import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_fixed_cta_bar.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';

import '../../test_support/ui_test_helpers.dart';

const _phoneViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];

void main() {
  testWidgets('P1-05 keeps species summary deterministic and unduplicated', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await _pumpPetList(tester);

    expect(find.text('Mèo tam thể • 2 tuổi'), findsOneWidget);
    expect(find.textContaining('Mèo Mèo'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-05 keeps two readable card columns at 430dp phone width', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(430, 932));
    await _pumpPetList(tester);

    final petCard = tester.getRect(find.byKey(const Key('pet-list-card-kem')));
    final addCard = tester.getRect(find.byKey(const Key('pet-list-add-card')));
    expect(petCard.width, greaterThanOrEqualTo(160));
    expect(addCard.width, greaterThanOrEqualTo(160));
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-05 keeps visible list copy readable at text scale 2.0', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    await _pumpPetList(tester, textScale: 2);

    void expectVisibleTextIsReadable(String label) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
        isFalse,
        reason: 'Visible pet-list copy must not ellipsize: $label',
      );
    }

    for (final label in const [
      'PawMate',
      'Chào buổi sáng, Nam!',
      'Cùng chăm sóc các bạn nhỏ hôm nay nhé.',
      'Mochi',
      'Mèo tam thể • 2 tuổi',
    ]) {
      expectVisibleTextIsReadable(label);
    }
    await tester.dragUntilVisible(
      find.byKey(const Key('pet-list-card-kem')),
      find.byKey(const Key('pet-list-scroll')),
      const Offset(0, -260),
    );
    for (final label in const ['Kem', 'Chó • 2 tuổi']) {
      expectVisibleTextIsReadable(label);
    }
    expectNoFlutterOverflow(tester);
  });

  for (final viewport in _phoneViewports) {
    final label = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-06 exposes microchip above its compact CTA at $label', (
      tester,
    ) async {
      await setTestViewport(tester, size: viewport);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CreatePetScreen(returnTo: '/pets/list'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollView = find.byType(CustomScrollView);
      await tester.drag(scrollView, const Offset(0, -1200));
      await tester.pumpAndSettle();

      final microchip = find.byKey(const Key('pet-form-microchip-field'));
      final cta = find.byKey(const Key('pet-form-save-button'));
      final segment = find.byKey(const Key('pet-form-species-segment'));
      final microchipRect = tester.getRect(microchip);
      final ctaRect = tester.getRect(cta);
      final ctaWidget = tester.widget<PawMateFixedCtaBar>(cta);

      expect(microchipRect.bottom, lessThanOrEqualTo(ctaRect.top + 0.5));
      expect(ctaRect.bottom, closeTo(viewport.height, 0.5));
      expect(tester.getSize(segment).height, greaterThanOrEqualTo(48));
      expect(ctaWidget.backgroundColor, AppColors.background);
      expect(ctaWidget.elevation, AppElevation.none);
      expectNoFlutterOverflow(tester);
    });
  }
}

Future<void> _pumpPetList(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data([
            _pet(
              id: 'mochi',
              name: 'Mochi',
              species: 'cat',
              breed: 'Mèo tam thể',
            ),
            _pet(id: 'kem', name: 'Kem', species: 'dog', breed: 'Samoyed'),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(textScale),
        home: PetListScreen(now: DateTime(2024, 5, 20)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PetProfile _pet({
  required String id,
  required String name,
  required String species,
  required String breed,
}) {
  return PetProfile(
    id: id,
    name: name,
    species: species,
    breed: breed,
    gender: 'unknown',
    dateOfBirth: DateTime(2022, 4, 12),
    healthStatus: 'healthy',
  );
}

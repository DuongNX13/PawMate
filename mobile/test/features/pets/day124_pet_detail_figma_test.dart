import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';

import '../../test_support/ui_test_helpers.dart';

// D123-IOS-UI-010: Figma v0.34 DT-01 (590:15905) titles the screen
// "Hồ sơ của <name>", centres a large avatar, groups health facts in one
// card, shows microchip in its own card and uses a primary edit CTA.
final _pet = PetProfile(
  id: 'pet-mochi',
  name: 'Mochi',
  species: 'dog',
  breed: 'Pomeranian',
  gender: 'female',
  dateOfBirth: DateTime(2024, 4, 12),
  weightKg: 4.2,
  healthStatus: 'healthy',
  isNeutered: true,
  microchip: 'MC-8293-128',
);

Future<void> _pump(WidgetTester t, PetProfile pet) async {
  await setTestViewport(t, size: const Size(430, 932));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          AsyncValue<List<PetProfile>>.data([pet]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PetDetailScreen(petId: pet.id),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('DT-01 follows figma v0.34 structure', (t) async {
    await _pump(t, _pet);
    expect(find.text('Hồ sơ của Mochi'), findsOneWidget);
    expect(find.text('Thông tin sức khỏe'), findsOneWidget);
    expect(find.byKey(const Key('pet-detail-health-facts')), findsOneWidget);
    expect(find.byKey(const Key('pet-detail-microchip-card')), findsOneWidget);
    expect(find.text('MC-8293-128'), findsOneWidget);
    expect(find.textContaining('Pomeranian · Cái'), findsOneWidget);
    final cta = find.widgetWithText(PawMateButton, 'Chỉnh sửa hồ sơ');
    expect(cta, findsOneWidget);
    expect(t.widget<PawMateButton>(cta).variant, PawMateButtonVariant.primary);
    expect(find.text('Quay lại danh sách thú cưng'), findsOneWidget);
    final avatar = t.getRect(find.byKey(const Key('pet-detail-avatar')));
    expect(avatar.center.dx, closeTo(215, 1));
    expect(avatar.width, greaterThanOrEqualTo(136));
    expectNoFlutterOverflow(t);
  });

  testWidgets('DT-01 hides microchip card when missing', (t) async {
    await _pump(
      t,
      PetProfile(
        id: 'pet-2',
        name: 'Bơ',
        species: 'cat',
        breed: '',
        gender: 'male',
        healthStatus: 'monitoring',
      ),
    );
    expect(find.byKey(const Key('pet-detail-microchip-card')), findsNothing);
    expectNoFlutterOverflow(t);
  });
}

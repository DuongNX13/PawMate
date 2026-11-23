import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'DT-02 waits for backend resolution then shows deleted/not-found instead of an empty edit form',
    (tester) async {
      final backend = Completer<List<PetProfile>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) => backend.future),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CreatePetScreen(
              petId: 'deleted-pet',
              returnTo: '/pets/list',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('pet-edit-loading-state')), findsOneWidget);
      expect(find.byKey(const Key('pet-form-name-field')), findsNothing);

      backend.complete(const []);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pet-edit-not-found-state')), findsOneWidget);
      expect(find.text('Hồ sơ không còn khả dụng'), findsOneWidget);
      expect(find.byKey(const Key('pet-form-name-field')), findsNothing);
    },
  );

  testWidgets('DT-02 hydrates an owner-scoped pet after delayed backend load', (
    tester,
  ) async {
    final backend = Completer<List<PetProfile>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith((ref) => backend.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CreatePetScreen(petId: 'mochi'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('pet-edit-loading-state')), findsOneWidget);

    backend.complete([_pet(id: 'mochi', name: 'Mochi')]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pet-edit-loading-state')), findsNothing);
    expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('pet-form-name-field')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(field.controller?.text, 'Mochi');
  });

  testWidgets('DT-02 exposes a retryable offline state before edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWith(
            (ref) => Future<List<PetProfile>>.error(StateError('offline')),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CreatePetScreen(petId: 'mochi'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pet-edit-error-state')), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byKey(const Key('pet-form-name-field')), findsNothing);
  });

  testWidgets(
    'DT-02 keeps fields and fixed update CTA usable at 320x568 text scale 2 with IME',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final pet = _pet(id: 'mochi', name: 'Mochi');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWithValue(
              AsyncValue<List<PetProfile>>.data([pet]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const CreatePetScreen(petId: 'mochi'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final colorField = find.descendant(
        of: find.byKey(const Key('pet-form-color-field')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        colorField,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(colorField);
      await setKeyboardInset(tester, bottom: 300);

      expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );
}

PetProfile _pet({required String id, required String name}) => PetProfile(
  id: id,
  name: name,
  species: 'dog',
  breed: 'Golden Retriever',
  gender: 'unknown',
  dateOfBirth: DateTime(2022, 4, 12),
  weightKg: 12.4,
  healthStatus: 'healthy',
  color: 'Vàng kem',
);

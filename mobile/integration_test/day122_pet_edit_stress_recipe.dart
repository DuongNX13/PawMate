import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';

import '../test/test_support/day119_detail_support.dart' show day119Pet;
import '../test/test_support/ui_test_helpers.dart' show setTestViewport;
import 'day122_closure_recipes.dart';

const petEditStressSize = Size(320, 568);
const petEditStressId = 'ANDROID-STRESS-PetEdit';
const petEditAvatarKey = 'pet-form-avatar-picker';
const petEditNameKey = 'pet-form-name-field';
const petEditSaveKey = 'pet-form-save-button';

const petEditStressFields = <String, String?>{
  petEditNameKey: 'Mochi',
  'pet-form-species-segment': null,
  'pet-form-breed-field': 'Golden Retriever',
  'pet-form-date-field': null,
  'pet-form-weight-field': '12.4',
  'pet-form-color-field': 'Vàng kem',
  'pet-form-microchip-field': 'MC-8293-128',
};

Future<void> pumpPetEditStress(
  WidgetTester tester, {
  VoidCallback? restoreNativeMetrics,
}) async {
  if (restoreNativeMetrics == null) {
    await setTestViewport(tester, size: petEditStressSize);
  } else {
    restoreNativeMetrics();
  }
  final pet = day119Pet().copyWith(avatarPath: closureDogAvatar);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(AsyncValue.data([pet])),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: CreatePetScreen(petId: pet.id),
      ),
    ),
  );
  final context = tester.element(find.byType(CreatePetScreen));
  await tester.runAsync(() async {
    Object? decodeFailure;
    await precacheImage(
      const AssetImage(closureDogAvatar),
      context,
      onError: (error, _) => decodeFailure = error,
    );
    if (decodeFailure != null) {
      throw StateError('Pet Edit avatar did not decode');
    }
  });
  await tester.pumpAndSettle();
}

Finder get petEditStressCta => find.descendant(
  of: find.byKey(const Key(petEditSaveKey)),
  matching: find.byType(PawMateButton),
);

Finder verifyPetEditStressIdentity(WidgetTester tester) {
  final avatar = find.byKey(const Key(petEditAvatarKey));
  final photo = find.descendant(of: avatar, matching: find.byType(Image));
  expect(photo, findsOneWidget);
  expect(
    tester.widget<Image>(photo).image,
    const AssetImage(closureDogAvatar),
    reason: 'Use the verified dog image, not the historical cat image',
  );
  expect(petEditStressCta, findsOneWidget);
  expect(
    tester.widget<PawMateButton>(petEditStressCta).label,
    'Cập nhật hồ sơ',
  );
  return avatar;
}

Future<Finder> revealPetEditStressField(WidgetTester tester, String key) async {
  final field = find.byKey(ValueKey(key));
  expect(field, findsOneWidget);
  final scroll = closureScrollFor(tester, field);
  // A rendered node outside the scroll viewport is not visual coverage.
  await Scrollable.ensureVisible(tester.element(field), alignment: .5);
  await tester.pumpAndSettle();
  final bounds = tester.getRect(field);
  final viewport = tester.getRect(scroll);
  expect(bounds.top, greaterThanOrEqualTo(viewport.top - 1));
  expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom + 1));
  final value = petEditStressFields[key];
  if (value != null) {
    final input = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(input).controller.text, value);
  }
  expect(tester.takeException(), isNull);
  return field;
}

void verifyPetEditStressIme(WidgetTester tester, double inset) {
  expect(inset, greaterThan(0));
  final field = find.byKey(const Key(petEditNameKey));
  final edit = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  expect(edit.focusNode.hasFocus, isTrue);
  final bottom = petEditStressSize.height - inset;
  for (final control in [field, petEditStressCta]) {
    expect(control.hitTestable(), findsOneWidget);
    expect(tester.getRect(control).bottom, lessThanOrEqualTo(bottom + 1));
  }
}

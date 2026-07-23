import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';

void main() {
  test('missing optional backend fields stay null', () {
    final pet = PetProfile.fromJson({
      'id': 'pet-1',
      'name': 'Mochi',
      'species': 'cat',
      'breed': 'Mèo tam thể',
      'color': 'Tam thể',
      'gender': 'unknown',
      'healthStatus': 'healthy',
    });

    expect(pet.dateOfBirth, isNull);
    expect(pet.weightKg, isNull);
    expect(pet.avatarPath, isNull);
  });

  test('create payload only sends visible P1-06 fields by default', () {
    const input = CreatePetProfileInput(
      name: ' Mochi ',
      species: 'cat',
      breed: ' Mèo tam thể ',
      color: ' Tam thể ',
      microchip: ' MC-123 ',
    );

    expect(input.toJson(), {
      'name': 'Mochi',
      'species': 'cat',
      'breed': 'Mèo tam thể',
      'color': 'Tam thể',
      'microchip': 'MC-123',
    });
  });

  test(
    'update payload clears optional SRS fields without overwriting hidden fields',
    () {
      const input = UpdatePetProfileInput(
        name: 'Mochi',
        species: 'cat',
        breed: 'Mèo tam thể',
        color: 'Tam thể',
      );

      expect(input.toJson(), {
        'name': 'Mochi',
        'species': 'cat',
        'breed': 'Mèo tam thể',
        'color': 'Tam thể',
        'dob': null,
        'weight': null,
        'microchip': null,
      });
    },
  );
}

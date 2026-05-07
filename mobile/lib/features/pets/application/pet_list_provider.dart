import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_session_store.dart';
import '../data/pet_api.dart';
import '../domain/pet_profile.dart';

final petListProvider = NotifierProvider<PetListNotifier, List<PetProfile>>(
  PetListNotifier.new,
);

final petAccessTokenProvider = FutureProvider<String?>((ref) async {
  final session = await ref.watch(authSessionStoreProvider).read();
  final token = session?.accessToken.trim();
  return token == null || token.isEmpty ? null : token;
});

final petBackendListProvider = FutureProvider<List<PetProfile>>((ref) async {
  final accessToken = await ref.watch(petAccessTokenProvider.future);
  if (accessToken == null) {
    return ref.read(petListProvider);
  }

  final pets = await ref
      .watch(petApiProvider)
      .listPets(accessToken: accessToken);
  ref.read(petListProvider.notifier).replaceAll(pets);
  return pets;
});

final petByIdProvider = Provider.family<PetProfile?, String>((ref, petId) {
  for (final pet in ref.watch(petListProvider)) {
    if (pet.id == petId) {
      return pet;
    }
  }
  return null;
});

class PetListNotifier extends Notifier<List<PetProfile>> {
  @override
  List<PetProfile> build() {
    return [
      PetProfile(
        id: 'milo',
        name: 'Milo',
        species: 'dog',
        breed: 'Poodle',
        gender: 'male',
        dateOfBirth: DateTime(2022, 4, 12),
        weightKg: 6.3,
        healthStatus: 'healthy',
        color: 'Apricot',
        isNeutered: true,
      ),
      PetProfile(
        id: 'lua',
        name: 'Lua',
        species: 'cat',
        breed: 'British Shorthair',
        gender: 'female',
        dateOfBirth: DateTime(2021, 9, 5),
        weightKg: 4.1,
        healthStatus: 'monitoring',
        color: 'Blue Gray',
      ),
    ];
  }

  void replaceAll(List<PetProfile> pets) {
    state = pets;
  }

  Future<String> createPet({
    required String name,
    required String species,
    required String breed,
    required String gender,
    required DateTime dateOfBirth,
    required double weightKg,
    required String healthStatus,
    String? avatarPath,
    String? color,
    String? microchip,
    required bool isNeutered,
  }) async {
    final input = CreatePetProfileInput(
      name: name,
      species: species,
      breed: breed,
      gender: gender,
      dateOfBirth: dateOfBirth,
      weightKg: weightKg,
      healthStatus: healthStatus,
      color: color,
      microchip: microchip,
      isNeutered: isNeutered,
    );

    final accessToken = await ref.read(petAccessTokenProvider.future);
    if (accessToken == null) {
      final newPet = PetProfile(
        id: 'pet-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        species: species,
        breed: breed,
        gender: gender,
        dateOfBirth: dateOfBirth,
        weightKg: weightKg,
        healthStatus: healthStatus,
        avatarPath: avatarPath,
        color: color,
        microchip: microchip,
        isNeutered: isNeutered,
      );
      state = [...state, newPet];
      return newPet.id;
    }

    final newPet = await ref
        .read(petApiProvider)
        .createPet(input, accessToken: accessToken);
    state = [...state, newPet];
    ref.invalidate(petBackendListProvider);
    return newPet.id;
  }
}

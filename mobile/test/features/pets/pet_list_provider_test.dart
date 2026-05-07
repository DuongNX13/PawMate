import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';

void main() {
  test('pet backend list sync replaces local sample cache', () async {
    final fakeApi = _FakePetApi(
      backendPets: [_samplePet(id: 'backend-pet', name: 'Bắp')],
    );
    final container = ProviderContainer(
      overrides: [
        petApiProvider.overrideWith((ref) => fakeApi),
        petAccessTokenProvider.overrideWith((ref) async => 'pet-token'),
      ],
    );
    addTearDown(container.dispose);

    final syncedPets = await container.read(petBackendListProvider.future);

    expect(fakeApi.listAccessToken, 'pet-token');
    expect(syncedPets.single.id, 'backend-pet');
    expect(container.read(petListProvider).single.id, 'backend-pet');
  });

  test('createPet uses backend token and stores backend-owned petId', () async {
    final fakeApi = _FakePetApi(backendPets: []);
    final container = ProviderContainer(
      overrides: [
        petApiProvider.overrideWith((ref) => fakeApi),
        petAccessTokenProvider.overrideWith((ref) async => 'pet-token'),
      ],
    );
    addTearDown(container.dispose);

    final createdId = await container
        .read(petListProvider.notifier)
        .createPet(
          name: 'Bắp',
          species: 'dog',
          breed: 'Golden Retriever',
          gender: 'male',
          dateOfBirth: DateTime(2022, 4, 12),
          weightKg: 12.4,
          healthStatus: 'healthy',
          isNeutered: true,
        );

    expect(createdId, 'created-backend-pet');
    expect(fakeApi.createAccessToken, 'pet-token');
    expect(fakeApi.createdInput?.name, 'Bắp');
    expect(container.read(petListProvider).last.id, 'created-backend-pet');
  });
}

class _FakePetApi extends PetApi {
  _FakePetApi({required this.backendPets}) : super(Dio());

  final List<PetProfile> backendPets;
  String? listAccessToken;
  String? createAccessToken;
  CreatePetProfileInput? createdInput;

  @override
  Future<List<PetProfile>> listPets({required String accessToken}) async {
    listAccessToken = accessToken;
    return [...backendPets];
  }

  @override
  Future<PetProfile> createPet(
    CreatePetProfileInput input, {
    required String accessToken,
  }) async {
    createAccessToken = accessToken;
    createdInput = input;
    final created = _samplePet(id: 'created-backend-pet', name: input.name);
    backendPets.add(created);
    return created;
  }
}

PetProfile _samplePet({required String id, required String name}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Golden Retriever',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
    isNeutered: true,
  );
}

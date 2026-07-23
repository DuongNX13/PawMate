import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/application/pet_form_draft_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';

void main() {
  test('pet cache starts empty and never exposes production fixture data', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(petListProvider), isEmpty);
  });

  test(
    'pet backend list fails closed when auth token is unavailable',
    () async {
      final container = ProviderContainer(
        overrides: [petAccessTokenProvider.overrideWith((ref) async => null)],
      );
      addTearDown(container.dispose);
      final errorCompleter = Completer<Object>();
      final subscription = container.listen(petBackendListProvider, (_, next) {
        if (next.hasError && !errorCompleter.isCompleted) {
          errorCompleter.complete(next.error!);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);

      await expectLater(
        errorCompleter.future,
        completion(
          isA<PetApiException>()
              .having((error) => error.code, 'code', 'AUTH_REQUIRED')
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
      expect(container.read(petListProvider), isEmpty);
    },
  );

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
          color: 'Vàng kem',
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
    expect(container.read(selectedPetIdProvider), 'created-backend-pet');
  });

  test('update and delete keep selected pet state consistent', () async {
    final fakeApi = _FakePetApi(
      backendPets: [
        _samplePet(id: 'pet-1', name: 'Mochi'),
        _samplePet(id: 'pet-2', name: 'Bắp'),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        petApiProvider.overrideWith((ref) => fakeApi),
        petAccessTokenProvider.overrideWith((ref) async => 'pet-token'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(petBackendListProvider.future);
    expect(container.read(selectedPetIdProvider), 'pet-1');

    final updated = await container
        .read(petListProvider.notifier)
        .updatePet(
          'pet-1',
          const UpdatePetProfileInput(
            name: 'Mochi mới',
            species: 'cat',
            breed: 'Mèo tam thể',
            color: 'Tam thể',
          ),
        );
    expect(updated.name, 'Mochi mới');
    expect(container.read(selectedPetProvider)?.name, 'Mochi mới');

    await container.read(petListProvider.notifier).deletePet('pet-1');
    expect(fakeApi.deletedPetId, 'pet-1');
    expect(container.read(selectedPetIdProvider), 'pet-2');
    expect(container.read(selectedPetProvider)?.id, 'pet-2');
  });

  test('photo failure keeps the saved pet and the user draft', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pawmate-pet-photo-test-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final avatar = File(
      '${tempDirectory.path}${Platform.pathSeparator}pet.png',
    );
    await avatar.writeAsBytes(const [1, 2, 3, 4]);

    final fakeApi = _FakePetApi(backendPets: [], failPhotoUpload: true);
    final container = ProviderContainer(
      overrides: [
        petApiProvider.overrideWith((ref) => fakeApi),
        petAccessTokenProvider.overrideWith((ref) async => 'pet-token'),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(petFormDraftProvider.notifier)
        .replace(
          const PetFormDraft(name: 'Bắp', breed: 'Corgi', color: 'Vàng trắng'),
        );

    await expectLater(
      container
          .read(petListProvider.notifier)
          .createPet(
            name: 'Bắp',
            species: 'dog',
            breed: 'Corgi',
            color: 'Vàng trắng',
            avatarPath: avatar.path,
            isNeutered: false,
          ),
      throwsA(
        isA<PetPhotoSaveException>().having(
          (error) => error.petId,
          'petId',
          'created-backend-pet',
        ),
      ),
    );

    expect(container.read(petListProvider).single.id, 'created-backend-pet');
    expect(container.read(selectedPetIdProvider), 'created-backend-pet');
    expect(container.read(petFormDraftProvider).name, 'Bắp');
  });
}

class _FakePetApi extends PetApi {
  _FakePetApi({required this.backendPets, this.failPhotoUpload = false})
    : super(Dio());

  final List<PetProfile> backendPets;
  final bool failPhotoUpload;
  String? listAccessToken;
  String? createAccessToken;
  CreatePetProfileInput? createdInput;
  String? deletedPetId;

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

  @override
  Future<PetProfile> updatePet(
    String petId,
    UpdatePetProfileInput input, {
    required String accessToken,
  }) async {
    final index = backendPets.indexWhere((pet) => pet.id == petId);
    final current = backendPets[index];
    final updated = current.copyWith(
      name: input.name,
      species: input.species,
      breed: input.breed,
      color: input.color,
      dateOfBirth: input.dateOfBirth,
      clearDateOfBirth: input.dateOfBirth == null,
      weightKg: input.weightKg,
      clearWeight: input.weightKg == null,
      microchip: input.microchip,
      clearMicrochip: input.microchip == null,
    );
    backendPets[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePet(String petId, {required String accessToken}) async {
    deletedPetId = petId;
    backendPets.removeWhere((pet) => pet.id == petId);
  }

  @override
  Future<PetProfile> uploadPetPhoto(
    String petId,
    PetPhotoInput photo, {
    required String accessToken,
  }) async {
    if (failPhotoUpload) {
      throw const PetApiException(
        'Không thể lưu ảnh.',
        code: 'PET_015',
        statusCode: 503,
      );
    }
    final index = backendPets.indexWhere((pet) => pet.id == petId);
    final updated = backendPets[index].copyWith(avatarPath: '/photos/$petId');
    backendPets[index] = updated;
    return updated;
  }
}

PetProfile _samplePet({required String id, required String name}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Golden Retriever',
    color: 'Vàng kem',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
    isNeutered: true,
  );
}

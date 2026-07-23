import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/pet_api.dart';
import '../domain/pet_profile.dart';

final petListProvider = NotifierProvider<PetListNotifier, List<PetProfile>>(
  PetListNotifier.new,
);

final petAccessTokenProvider = Provider<Future<String?>>((ref) {
  return ref.watch(authAccessTokenProvider.future);
});

final petSessionRevisionProvider = Provider<int>((ref) {
  return ref.watch(authSessionRevisionProvider);
});

final petPhotoBytesReaderProvider =
    Provider<Future<List<int>> Function(String)>(
      (ref) =>
          (path) => File(path).readAsBytes(),
    );

final selectedPetIdProvider = NotifierProvider<SelectedPetIdNotifier, String?>(
  SelectedPetIdNotifier.new,
);

final selectedPetProvider = Provider<PetProfile?>((ref) {
  final selectedId = ref.watch(selectedPetIdProvider);
  if (selectedId == null) {
    return null;
  }
  for (final pet in ref.watch(petListProvider)) {
    if (pet.id == selectedId) {
      return pet;
    }
  }
  return null;
});

final petBackendListProvider = FutureProvider<List<PetProfile>>((ref) async {
  final accessToken = await ref.watch(petAccessTokenProvider);
  if (accessToken == null) {
    throw const PetApiException(
      'Bạn cần đăng nhập để xem hồ sơ thú cưng.',
      code: 'AUTH_REQUIRED',
      statusCode: 401,
    );
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
    ref.watch(petSessionRevisionProvider);
    return const [];
  }

  void replaceAll(List<PetProfile> pets) {
    state = List.unmodifiable(pets);
    _normalizeSelection();
  }

  Future<String> createPet({
    required String name,
    required String species,
    required String breed,
    String gender = 'unknown',
    DateTime? dateOfBirth,
    double? weightKg,
    String healthStatus = 'healthy',
    String? avatarPath,
    required String color,
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

    final accessToken = await _requireAccessToken();
    final api = ref.read(petApiProvider);
    final newPet = await api.createPet(input, accessToken: accessToken);
    _upsert(newPet);
    ref.read(selectedPetIdProvider.notifier).select(newPet.id);

    if (avatarPath != null && avatarPath.trim().isNotEmpty) {
      try {
        final uploaded = await api.uploadPetPhoto(
          newPet.id,
          PetPhotoInput(
            fileName: _fileName(avatarPath),
            contentType: _contentType(avatarPath),
            bytes: await ref.read(petPhotoBytesReaderProvider)(avatarPath),
          ),
          accessToken: accessToken,
        );
        _upsert(uploaded);
      } on Object catch (error) {
        ref.invalidate(petBackendListProvider);
        throw PetPhotoSaveException(petId: newPet.id, cause: error);
      }
    }

    ref.invalidate(petBackendListProvider);
    return newPet.id;
  }

  Future<PetProfile> updatePet(
    String petId,
    UpdatePetProfileInput input, {
    String? avatarPath,
  }) async {
    final accessToken = await _requireAccessToken();
    final api = ref.read(petApiProvider);
    var updated = await api.updatePet(petId, input, accessToken: accessToken);
    _upsert(updated);

    if (avatarPath != null && avatarPath.trim().isNotEmpty) {
      try {
        updated = await api.uploadPetPhoto(
          petId,
          PetPhotoInput(
            fileName: _fileName(avatarPath),
            contentType: _contentType(avatarPath),
            bytes: await ref.read(petPhotoBytesReaderProvider)(avatarPath),
          ),
          accessToken: accessToken,
        );
        _upsert(updated);
      } on Object catch (error) {
        ref.invalidate(petBackendListProvider);
        throw PetPhotoSaveException(petId: petId, cause: error);
      }
    }

    ref.invalidate(petBackendListProvider);
    return updated;
  }

  Future<void> deletePet(String petId) async {
    final accessToken = await _requireAccessToken();
    await ref.read(petApiProvider).deletePet(petId, accessToken: accessToken);
    state = state.where((pet) => pet.id != petId).toList(growable: false);
    _normalizeSelection();
    ref.invalidate(petBackendListProvider);
  }

  Future<PetProfile> uploadPetPhoto(String petId, PetPhotoInput photo) async {
    final accessToken = await _requireAccessToken();
    final updated = await ref
        .read(petApiProvider)
        .uploadPetPhoto(petId, photo, accessToken: accessToken);
    _upsert(updated);
    ref.invalidate(petBackendListProvider);
    return updated;
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await ref.read(petAccessTokenProvider);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const PetApiException(
        'Bạn cần đăng nhập để quản lý hồ sơ thú cưng.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    return accessToken;
  }

  void _upsert(PetProfile pet) {
    final index = state.indexWhere((item) => item.id == pet.id);
    if (index < 0) {
      state = [...state, pet];
      return;
    }
    final next = [...state];
    next[index] = pet;
    state = next;
  }

  void _normalizeSelection() {
    final selectedId = ref.read(selectedPetIdProvider);
    final hasSelection = state.any((pet) => pet.id == selectedId);
    if (!hasSelection) {
      ref
          .read(selectedPetIdProvider.notifier)
          .select(state.isEmpty ? null : state.first.id);
    }
  }

  String _fileName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  String _contentType(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

class SelectedPetIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(petSessionRevisionProvider);
    return null;
  }

  void select(String? petId) {
    state = petId;
  }
}

class PetPhotoSaveException implements Exception {
  const PetPhotoSaveException({required this.petId, required this.cause});

  final String petId;
  final Object cause;

  @override
  String toString() => 'Đã lưu hồ sơ nhưng chưa thể tải ảnh lên.';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';

final petFormDraftProvider =
    NotifierProvider<PetFormDraftNotifier, PetFormDraft>(
      PetFormDraftNotifier.new,
    );

class PetFormDraft {
  const PetFormDraft({
    this.petId,
    this.avatarPath,
    this.name = '',
    this.species = 'dog',
    this.breed = '',
    this.dateOfBirth,
    this.weightText = '',
    this.color = '',
    this.microchip = '',
  });

  final String? petId;
  final String? avatarPath;
  final String name;
  final String species;
  final String breed;
  final DateTime? dateOfBirth;
  final String weightText;
  final String color;
  final String microchip;

  bool get isEmpty {
    return petId == null &&
        avatarPath == null &&
        name.isEmpty &&
        species == 'dog' &&
        breed.isEmpty &&
        dateOfBirth == null &&
        weightText.isEmpty &&
        color.isEmpty &&
        microchip.isEmpty;
  }

  PetFormDraft copyWith({
    String? petId,
    bool clearPetId = false,
    String? avatarPath,
    bool clearAvatar = false,
    String? name,
    String? species,
    String? breed,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? weightText,
    String? color,
    String? microchip,
  }) {
    return PetFormDraft(
      petId: clearPetId ? null : petId ?? this.petId,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      weightText: weightText ?? this.weightText,
      color: color ?? this.color,
      microchip: microchip ?? this.microchip,
    );
  }
}

class PetFormDraftNotifier extends Notifier<PetFormDraft> {
  @override
  PetFormDraft build() {
    ref.watch(authSessionRevisionProvider);
    return const PetFormDraft();
  }

  void replace(PetFormDraft draft) {
    state = draft;
  }

  void update(PetFormDraft Function(PetFormDraft current) update) {
    state = update(state);
  }

  void clear() {
    state = const PetFormDraft();
  }
}

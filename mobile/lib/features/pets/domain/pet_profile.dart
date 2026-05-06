class PetProfile {
  const PetProfile({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    required this.dateOfBirth,
    required this.weightKg,
    required this.healthStatus,
    this.avatarPath,
    this.color,
    this.microchip,
    this.isNeutered = false,
  });

  final String id;
  final String name;
  final String species;
  final String breed;
  final String gender;
  final DateTime dateOfBirth;
  final double weightKg;
  final String healthStatus;
  final String? avatarPath;
  final String? color;
  final String? microchip;
  final bool isNeutered;

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      species: json['species']?.toString() ?? 'other',
      breed: json['breed']?.toString() ?? 'Other',
      gender: json['gender']?.toString() ?? 'unknown',
      dateOfBirth: _parseDate(json['dob']?.toString()) ?? DateTime.now(),
      weightKg: _readDouble(json['weight']) ?? 0,
      healthStatus: json['healthStatus']?.toString() ?? 'unknown',
      avatarPath: _readOptionalString(json['avatarUrl']),
      color: _readOptionalString(json['color']),
      microchip: _readOptionalString(json['microchip']),
      isNeutered: json['isNeutered'] == true,
    );
  }
}

class CreatePetProfileInput {
  const CreatePetProfileInput({
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    required this.dateOfBirth,
    required this.weightKg,
    required this.healthStatus,
    this.color,
    this.microchip,
    this.isNeutered = false,
  });

  final String name;
  final String species;
  final String breed;
  final String gender;
  final DateTime dateOfBirth;
  final double weightKg;
  final String healthStatus;
  final String? color;
  final String? microchip;
  final bool isNeutered;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'species': species,
      'breed': breed.trim(),
      'gender': gender,
      'dob': _formatDate(dateOfBirth),
      'weight': weightKg,
      'healthStatus': healthStatus,
      if (color != null && color!.trim().isNotEmpty) 'color': color!.trim(),
      if (microchip != null && microchip!.trim().isNotEmpty)
        'microchip': microchip!.trim(),
      'isNeutered': isNeutered,
    };
  }
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

double? _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

String? _readOptionalString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

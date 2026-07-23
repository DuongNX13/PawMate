class PetProfile {
  const PetProfile({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.gender,
    this.dateOfBirth,
    this.weightKg,
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
  final DateTime? dateOfBirth;
  final double? weightKg;
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
      breed: json['breed']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'unknown',
      dateOfBirth: _parseDate(json['dob']?.toString()),
      weightKg: _readDouble(json['weight']),
      healthStatus: json['healthStatus']?.toString() ?? 'unknown',
      avatarPath: _readOptionalString(json['avatarUrl']),
      color: _readOptionalString(json['color']),
      microchip: _readOptionalString(json['microchip']),
      isNeutered: json['isNeutered'] == true,
    );
  }

  PetProfile copyWith({
    String? name,
    String? species,
    String? breed,
    String? gender,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    double? weightKg,
    bool clearWeight = false,
    String? healthStatus,
    String? avatarPath,
    bool clearAvatar = false,
    String? color,
    bool clearColor = false,
    String? microchip,
    bool clearMicrochip = false,
    bool? isNeutered,
  }) {
    return PetProfile(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      weightKg: clearWeight ? null : weightKg ?? this.weightKg,
      healthStatus: healthStatus ?? this.healthStatus,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
      color: clearColor ? null : color ?? this.color,
      microchip: clearMicrochip ? null : microchip ?? this.microchip,
      isNeutered: isNeutered ?? this.isNeutered,
    );
  }
}

class CreatePetProfileInput {
  const CreatePetProfileInput({
    required this.name,
    required this.species,
    required this.breed,
    required this.color,
    this.gender = 'unknown',
    this.dateOfBirth,
    this.weightKg,
    this.healthStatus = 'healthy',
    this.microchip,
    this.isNeutered = false,
  });

  final String name;
  final String species;
  final String breed;
  final String gender;
  final DateTime? dateOfBirth;
  final double? weightKg;
  final String healthStatus;
  final String color;
  final String? microchip;
  final bool isNeutered;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'species': species,
      'breed': breed.trim(),
      if (gender != 'unknown') 'gender': gender,
      if (dateOfBirth != null) 'dob': _formatDate(dateOfBirth!),
      if (weightKg != null) 'weight': weightKg,
      if (healthStatus != 'healthy') 'healthStatus': healthStatus,
      'color': color.trim(),
      if (microchip != null && microchip!.trim().isNotEmpty)
        'microchip': microchip!.trim(),
      if (isNeutered) 'isNeutered': true,
    };
  }
}

class UpdatePetProfileInput {
  const UpdatePetProfileInput({
    required this.name,
    required this.species,
    required this.breed,
    required this.color,
    this.gender,
    this.dateOfBirth,
    this.weightKg,
    this.healthStatus,
    this.microchip,
    this.isNeutered,
  });

  final String name;
  final String species;
  final String breed;
  final String color;
  final String? gender;
  final DateTime? dateOfBirth;
  final double? weightKg;
  final String? healthStatus;
  final String? microchip;
  final bool? isNeutered;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'species': species,
      'breed': breed.trim(),
      'color': color.trim(),
      if (gender != null) 'gender': gender,
      'dob': dateOfBirth == null ? null : _formatDate(dateOfBirth!),
      'weight': weightKg,
      if (healthStatus != null) 'healthStatus': healthStatus,
      'microchip': _readOptionalString(microchip),
      if (isNeutered != null) 'isNeutered': isNeutered,
    };
  }
}

class PetPhotoInput {
  const PetPhotoInput({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final List<int> bytes;
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

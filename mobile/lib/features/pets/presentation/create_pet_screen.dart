import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/image_picker_service.dart';
import '../application/pet_list_provider.dart';

class CreatePetScreen extends ConsumerStatefulWidget {
  const CreatePetScreen({super.key});

  @override
  ConsumerState<CreatePetScreen> createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends ConsumerState<CreatePetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _colorController = TextEditingController();
  final _microchipController = TextEditingController();
  String _species = 'dog';
  String? _breed;
  String _gender = 'unknown';
  String _healthStatus = 'healthy';
  DateTime? _dateOfBirth;
  String? _avatarPath;
  bool _isNeutered = false;
  bool _isSubmitting = false;
  String? _submitError;

  static const _speciesOptions = ['dog', 'cat', 'bird', 'rabbit', 'other'];
  static const _genderOptions = ['male', 'female', 'unknown'];
  static const _healthStatusOptions = [
    'healthy',
    'monitoring',
    'chronic',
    'recovery',
    'unknown',
  ];
  static const _breedsBySpecies = {
    'dog': ['Poodle', 'Pug', 'Golden Retriever', 'Shiba'],
    'cat': ['British Shorthair', 'Siamese', 'Maine Coon'],
    'bird': ['Parrot', 'Cockatiel', 'Canary'],
    'rabbit': ['Holland Lop', 'Mini Rex'],
    'other': ['Other'],
  };

  @override
  void initState() {
    super.initState();
    _breed = _breedsBySpecies[_species]?.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _colorController.dispose();
    _microchipController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ref.read(imagePickerProvider);
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      _avatarPath = file.path;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _dateOfBirth ?? DateTime.now(),
    );
    if (selectedDate == null || !mounted) {
      return;
    }
    setState(() {
      _dateOfBirth = selectedDate;
    });
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Vui lòng nhập tên thú cưng';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final weight = double.tryParse((value ?? '').trim());
    if (weight == null || weight <= 0) {
      return 'Cân nặng phải lớn hơn 0';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày sinh')));
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final petId = await ref
          .read(petListProvider.notifier)
          .createPet(
            name: _nameController.text.trim(),
            species: _species,
            breed: _breed ?? 'Other',
            gender: _gender,
            dateOfBirth: _dateOfBirth!,
            weightKg: double.parse(_weightController.text.trim()),
            healthStatus: _healthStatus,
            avatarPath: _avatarPath,
            color: _colorController.text.trim().isEmpty
                ? null
                : _colorController.text.trim(),
            microchip: _microchipController.text.trim().isEmpty
                ? null
                : _microchipController.text.trim(),
            isNeutered: _isNeutered,
          );

      if (!mounted) {
        return;
      }
      context.go('/pets/$petId');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = 'Không thể lưu hồ sơ thú cưng. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final breeds = _breedsBySpecies[_species] ?? const ['Other'];

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm thú cưng')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 42,
                backgroundImage: _avatarPath == null
                    ? null
                    : FileImage(File(_avatarPath!)),
                child: _avatarPath == null
                    ? const Icon(Icons.add_a_photo_outlined)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Ten'),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _species,
                  items: _speciesOptions
                      .map(
                        (species) => DropdownMenuItem(
                          value: species,
                          child: Text(_displaySpecies(species)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _species = value;
                      _breed =
                          (_breedsBySpecies[value] ?? const ['Other']).first;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Loài'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_species),
                  initialValue: _breed,
                  items: breeds
                      .map(
                        (breed) =>
                            DropdownMenuItem(value: breed, child: Text(breed)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _breed = value;
                  }),
                  decoration: const InputDecoration(labelText: 'Giống'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  items: _genderOptions
                      .map(
                        (gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(_displayGender(gender)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _gender = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Giới tính'),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ngày sinh'),
                    child: Text(
                      _dateOfBirth == null
                          ? 'Chọn ngày'
                          : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cân nặng',
                    suffixText: 'kg',
                  ),
                  validator: _validateWeight,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _colorController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Màu sắc'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _microchipController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Microchip'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _healthStatus,
                  items: _healthStatusOptions
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_displayHealthStatus(status)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _healthStatus = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Tình trạng sức khỏe',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đã triệt sản'),
                  value: _isNeutered,
                  onChanged: (value) => setState(() {
                    _isNeutered = value;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_submitError != null) ...[
            Text(
              _submitError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Đang lưu...' : 'Lưu hồ sơ'),
          ),
        ],
      ),
    );
  }

  String _displayGender(String value) {
    switch (value) {
      case 'male':
        return 'Đực';
      case 'female':
        return 'Cái';
      default:
        return 'Chưa rõ';
    }
  }

  String _displaySpecies(String value) {
    switch (value) {
      case 'dog':
        return 'Chó';
      case 'cat':
        return 'Mèo';
      case 'bird':
        return 'Chim';
      case 'rabbit':
        return 'Thỏ';
      default:
        return 'Khác';
    }
  }

  String _displayHealthStatus(String value) {
    switch (value) {
      case 'monitoring':
        return 'Cần theo dõi';
      case 'chronic':
        return 'Bệnh mạn tính';
      case 'recovery':
        return 'Đang hồi phục';
      case 'healthy':
        return 'Ổn định';
      default:
        return 'Chưa rõ';
    }
  }
}

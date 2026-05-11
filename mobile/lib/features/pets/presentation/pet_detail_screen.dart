import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/pet_list_provider.dart';

class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendPetsState = ref.watch(petBackendListProvider);
    final pet = ref.watch(petByIdProvider(petId));
    if (pet == null) {
      if (backendPetsState.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết thú cưng')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết thú cưng')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  backendPetsState.hasError
                      ? 'Chưa đồng bộ được hồ sơ thú cưng'
                      : 'Không tìm thấy thú cưng',
                  textAlign: TextAlign.center,
                ),
                if (backendPetsState.hasError) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(petBackendListProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(pet.name)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: _avatarImage(pet.avatarPath),
              child: pet.avatarPath == null
                  ? const Icon(Icons.pets, size: 40)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${_toDisplaySpecies(pet.species)} • ${pet.breed}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(label: 'Giới tính', value: _toDisplayGender(pet.gender)),
          _InfoTile(
            label: 'Ngày sinh',
            value:
                '${pet.dateOfBirth.day}/${pet.dateOfBirth.month}/${pet.dateOfBirth.year}',
          ),
          _InfoTile(
            label: 'Cân nặng',
            value: '${pet.weightKg.toStringAsFixed(1)} kg',
          ),
          _InfoTile(
            label: 'Tình trạng sức khỏe',
            value: _toDisplayHealthStatus(pet.healthStatus),
          ),
          if (pet.color != null) _InfoTile(label: 'Màu sắc', value: pet.color!),
          if (pet.microchip != null)
            _InfoTile(label: 'Microchip', value: pet.microchip!),
          _InfoTile(
            label: 'Trạng thái triệt sản',
            value: pet.isNeutered ? 'Đã triệt sản' : 'Chưa triệt sản',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/pets'),
              child: const Text('Quay lại danh sách'),
            ),
          ),
        ],
      ),
    );
  }

  String _toDisplaySpecies(String species) {
    switch (species) {
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

  String _toDisplayGender(String gender) {
    switch (gender) {
      case 'male':
        return 'Đực';
      case 'female':
        return 'Cái';
      default:
        return 'Chưa rõ';
    }
  }

  String _toDisplayHealthStatus(String healthStatus) {
    switch (healthStatus) {
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

  ImageProvider<Object>? _avatarImage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }
    return FileImage(File(value));
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(title: Text(label), subtitle: Text(value)),
    );
  }
}

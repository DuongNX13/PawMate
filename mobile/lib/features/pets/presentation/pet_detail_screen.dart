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
          appBar: AppBar(title: const Text('Chi tiet thu cung')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiet thu cung')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  backendPetsState.hasError
                      ? 'Chua dong bo duoc ho so thu cung'
                      : 'Khong tim thay thu cung',
                  textAlign: TextAlign.center,
                ),
                if (backendPetsState.hasError) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(petBackendListProvider),
                    child: const Text('Thu lai'),
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
          _InfoTile(label: 'Gioi tinh', value: _toDisplayGender(pet.gender)),
          _InfoTile(
            label: 'Ngay sinh',
            value:
                '${pet.dateOfBirth.day}/${pet.dateOfBirth.month}/${pet.dateOfBirth.year}',
          ),
          _InfoTile(
            label: 'Can nang',
            value: '${pet.weightKg.toStringAsFixed(1)} kg',
          ),
          _InfoTile(
            label: 'Tinh trang suc khoe',
            value: _toDisplayHealthStatus(pet.healthStatus),
          ),
          if (pet.color != null) _InfoTile(label: 'Mau sac', value: pet.color!),
          if (pet.microchip != null)
            _InfoTile(label: 'Microchip', value: pet.microchip!),
          _InfoTile(
            label: 'Trang thai triet san',
            value: pet.isNeutered ? 'Da triet san' : 'Chua triet san',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/pets'),
              child: const Text('Quay lai danh sach'),
            ),
          ),
        ],
      ),
    );
  }

  String _toDisplaySpecies(String species) {
    switch (species) {
      case 'dog':
        return 'Cho';
      case 'cat':
        return 'Meo';
      case 'bird':
        return 'Chim';
      case 'rabbit':
        return 'Tho';
      default:
        return 'Khac';
    }
  }

  String _toDisplayGender(String gender) {
    switch (gender) {
      case 'male':
        return 'Duc';
      case 'female':
        return 'Cai';
      default:
        return 'Chua ro';
    }
  }

  String _toDisplayHealthStatus(String healthStatus) {
    switch (healthStatus) {
      case 'monitoring':
        return 'Can theo doi';
      case 'chronic':
        return 'Benh man tinh';
      case 'recovery':
        return 'Dang hoi phuc';
      case 'healthy':
        return 'On dinh';
      default:
        return 'Chua ro';
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

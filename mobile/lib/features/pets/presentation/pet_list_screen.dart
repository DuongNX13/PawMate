import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/pet_list_provider.dart';
import '../domain/pet_profile.dart';

class PetListScreen extends ConsumerWidget {
  const PetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedPets = ref.watch(petListProvider);
    final backendPetsState = ref.watch(petBackendListProvider);
    final pets = backendPetsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu cung cua toi'),
        actions: [
          IconButton(
            onPressed: () => context.go('/vets/list'),
            icon: const Icon(Icons.local_hospital_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (pets.isEmpty && backendPetsState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (pets.isEmpty && backendPetsState.hasError) {
            return _PetSyncError(
              message: _petSyncErrorMessage(backendPetsState.error!),
              onRetry: () => ref.invalidate(petBackendListProvider),
            );
          }

          if (pets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.pets_outlined,
                        size: 36,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chua co thu cung nao',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Them ho so dau tien de theo doi thong tin va suc khoe cua be.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.go('/pets/create'),
                      icon: const Icon(Icons.add),
                      label: const Text('Them thu cung'),
                    ),
                  ],
                ),
              ),
            );
          }

          final crossAxisCount = constraints.maxWidth < 390 ? 1 : 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (backendPetsState.hasError) ...[
                      _PetSyncBanner(
                        message: _petSyncErrorMessage(backendPetsState.error!),
                        onRetry: () => ref.invalidate(petBackendListProvider),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Quan ly danh sach thu cung trong mot cho de xem nhanh thong tin chinh.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${pets.length} ho so dang co',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: crossAxisCount == 1 ? 1.7 : 0.92,
                  ),
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return _PetCard(
                      pet: pet,
                      onTap: () => context.go('/pets/${pet.id}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/pets/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PetSyncBanner extends StatelessWidget {
  const _PetSyncBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Thu lai')),
        ],
      ),
    );
  }
}

class _PetSyncError extends StatelessWidget {
  const _PetSyncError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Chua tai duoc ho so thu cung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thu lai')),
          ],
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet, required this.onTap});

  final PetProfile pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                child: pet.avatarPath == null
                    ? Icon(Icons.pets, color: colorScheme.primary)
                    : Icon(Icons.image_outlined, color: colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                pet.name,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${_toDisplaySpecies(pet.species)} • ${pet.breed}',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _healthStatusColor(
                    context,
                    pet.healthStatus,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _toDisplayHealthStatus(pet.healthStatus),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _healthStatusColor(context, pet.healthStatus),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${pet.weightKg.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _toDisplaySpecies(String species) {
    switch (species) {
      case 'dog':
        return 'Dog';
      case 'cat':
        return 'Cat';
      case 'bird':
        return 'Bird';
      case 'rabbit':
        return 'Rabbit';
      default:
        return 'Other';
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

  Color _healthStatusColor(BuildContext context, String healthStatus) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (healthStatus) {
      case 'monitoring':
        return colorScheme.secondary;
      case 'chronic':
        return colorScheme.error;
      case 'recovery':
        return Colors.teal;
      case 'healthy':
        return Colors.green;
      default:
        return colorScheme.outline;
    }
  }
}

String _petSyncErrorMessage(Object error) {
  return 'Khong the dong bo ho so thu cung. Vui long thu lai.';
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PetListScreen extends StatelessWidget {
  const PetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu cung cua ban'),
        actions: [
          IconButton(
            onPressed: () => context.go('/vets/list'),
            icon: const Icon(Icons.local_hospital_outlined),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: const [
          _PetCard(name: 'Milo', species: 'Dog'),
          _PetCard(name: 'Lua', species: 'Cat'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/pets/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.name, required this.species});

  final String name;
  final String species;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.pets)),
            const Spacer(),
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            Text(species),
          ],
        ),
      ),
    );
  }
}

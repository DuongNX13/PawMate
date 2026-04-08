import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VetListScreen extends StatelessWidget {
  const VetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phong kham'),
        actions: [
          IconButton(
            onPressed: () => context.go('/vets/map'),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _VetTile(
            title: 'PawMate Vet Center',
            subtitle: '2.1 km • Open now',
            onTap: () => context.go('/vets/vet-001'),
          ),
          _VetTile(
            title: 'Happy Tails Clinic',
            subtitle: '4.8 km • 24h support',
            onTap: () => context.go('/vets/vet-002'),
          ),
        ],
      ),
    );
  }
}

class _VetTile extends StatelessWidget {
  const _VetTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

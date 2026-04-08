import 'package:flutter/material.dart';

class VetDetailScreen extends StatelessWidget {
  const VetDetailScreen({super.key, required this.vetId});

  final String vetId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiet phong kham')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vet ID: $vetId'),
            const SizedBox(height: 16),
            const Text(
              'Thong tin chi tiet, call CTA, va directions CTA se duoc mo rong o Day 2.',
            ),
          ],
        ),
      ),
    );
  }
}

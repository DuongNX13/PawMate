import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class VetMapScreen extends StatelessWidget {
  const VetMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Vet Map',
      subtitle:
          'Map canvas, permission state, and selected marker flow will land in Day 2.',
    );
  }
}

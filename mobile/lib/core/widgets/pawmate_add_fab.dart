import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Round "+" action button from Figma v0.34 (`FAB/Add`). Width never switches
/// to an extended label; the action name is carried by the tooltip.
class PawMateAddFab extends StatelessWidget {
  const PawMateAddFab({
    super.key,
    required this.heroTag,
    required this.tooltip,
    required this.onPressed,
  });

  final Object heroTag;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    heroTag: heroTag,
    tooltip: tooltip,
    shape: const CircleBorder(),
    backgroundColor: AppColors.primary500,
    foregroundColor: AppColors.white,
    onPressed: onPressed,
    child: const Icon(Icons.add_rounded),
  );
}

import 'package:flutter/material.dart';

import 'pawmate_button.dart';

@Deprecated('Use PawMateButton for new primary actions.')
class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PawMateButton(label: label, onPressed: onPressed);
  }
}

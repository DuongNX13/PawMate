import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

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
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: onPressed != null
                  ? AppGradients.primary
                  : const LinearGradient(
                      colors: [Color(0xFFCFD4D8), Color(0xFFCFD4D8)],
                    ),
              boxShadow: AppShadows.soft,
            ),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Text(label, style: labelStyle),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppColors {
  static const primary500 = Color(0xFFFF8A5B);
  static const primary700 = Color(0xFFC55A28);
  static const primarySoft = Color(0xFFFCE7DD);
  static const secondary500 = Color(0xFF2D5A88);
  static const secondarySoft = Color(0xFFEAF3FF);
  static const tertiary500 = Color(0xFFFFD700);
  static const tertiarySoft = Color(0xFFFFF6D5);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFE1E3E4);
  static const border = Color(0xFFE1E3E4);
  static const textPrimary = Color(0xFF191C1D);
  static const textSecondary = Color(0xFF6B7280);
  static const label = Color(0xFF8A726A);
  static const icon = Color(0xFF64748B);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFE11D48);
  static const shadow = Color(0x1F174976);
  static const darkBackground = Color(0xFF131618);
  static const darkSurface = Color(0xFF1D2226);
  static const darkBorder = Color(0xFF2D3338);
  static const darkTextSecondary = Color(0xFF9AA5B5);
}

class AppSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class AppShadows {
  static const soft = [
    BoxShadow(color: AppColors.shadow, blurRadius: 32, offset: Offset(0, 16)),
  ];
}

class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary700, AppColors.primary500],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4F7FB), Color(0xFFFFF5F0)],
  );
}

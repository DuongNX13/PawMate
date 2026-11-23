import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/health_hub/presentation/health_hub_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';

// Same provider override as pumpDay118HealthHub; Android owns the viewport.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: [petListProvider.overrideWith(_GoldenPetListNotifier.new)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HealthHubScreen(),
      ),
    ),
  );
}

class _GoldenPetListNotifier extends PetListNotifier {
  @override
  List<PetProfile> build() => const [
    PetProfile(
      id: 'pet-mochi',
      name: 'Mochi',
      species: 'dog',
      breed: 'Golden Retriever',
      gender: 'female',
      weightKg: 12.4,
      healthStatus: 'healthy',
    ),
  ];
}

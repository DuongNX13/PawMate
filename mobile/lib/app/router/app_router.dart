import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/placeholder_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/health/presentation/health_timeline_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/pets/presentation/create_pet_screen.dart';
import '../../features/pets/presentation/pet_list_screen.dart';
import '../../features/vets/presentation/vet_detail_screen.dart';
import '../../features/vets/presentation/vet_list_screen.dart';
import '../../features/vets/presentation/vet_map_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: '/pets',
        builder: (context, state) => const PetListScreen(),
      ),
      GoRoute(
        path: '/pets/create',
        builder: (context, state) => const CreatePetScreen(),
      ),
      GoRoute(
        path: '/vets/map',
        builder: (context, state) => const VetMapScreen(),
      ),
      GoRoute(
        path: '/vets/list',
        builder: (context, state) => const VetListScreen(),
      ),
      GoRoute(
        path: '/vets/:id',
        builder: (context, state) =>
            VetDetailScreen(vetId: state.pathParameters['id'] ?? 'unknown-vet'),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthTimelineScreen(),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Community',
          subtitle: 'Deferred after the MVP core flow is stable.',
        ),
      ),
      GoRoute(
        path: '/rescue',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Rescue',
          subtitle: 'Deferred after the MVP core flow is stable.',
        ),
      ),
    ],
  );
});

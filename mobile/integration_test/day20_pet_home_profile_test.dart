import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = String.fromEnvironment(
  'PAWMATE_E2E_EMAIL',
  defaultValue: 'mobile-e2e-owner@pawmate.test',
);
const _password = String.fromEnvironment(
  'PAWMATE_E2E_PASSWORD',
  defaultValue: 'Pawmate123',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day20 persists a pet through List, Form, Home, and Profile', (
    tester,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final authApi = AuthApi(dio);
    final petApi = PetApi(dio);
    final session = await authApi.login(email: _email, password: _password);
    final runId = DateTime.now().millisecondsSinceEpoch;
    final petName = 'Day20 E2E $runId';
    String? createdPetId;

    final router = GoRouter(
      initialLocation: '/pets/list',
      routes: [
        GoRoute(
          path: '/pets',
          builder: (context, state) => const PetHomeScreen(),
        ),
        GoRoute(
          path: '/pets/list',
          builder: (context, state) => const PetListScreen(),
        ),
        GoRoute(
          path: '/pets/create',
          builder: (context, state) =>
              CreatePetScreen(returnTo: state.uri.queryParameters['returnTo']),
        ),
        GoRoute(
          path: '/pets/:id',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Pet detail target'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/controls',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Profile controls target')),
          ),
        ),
        GoRoute(
          path: '/profile/privacy',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Profile privacy target')),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Notifications target'))),
        ),
        GoRoute(
          path: '/health/reminders',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Reminder target'))),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Vet target'))),
        ),
      ],
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWith((ref) => dio),
            authenticatedDioProvider.overrideWith((ref) => dio),
            authSessionSnapshotProvider.overrideWith((ref) async => session),
            petAccessTokenProvider.overrideWith(
              (ref) async => session.accessToken,
            ),
            upcomingRemindersProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              overscroll: false,
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(PetListScreen), findsOneWidget);

      router.go('/pets/create?returnTo=/pets/list');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('pet-form-name-field')),
          matching: find.byType(TextFormField),
        ),
        petName,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('pet-form-breed-field')),
          matching: find.byType(TextFormField),
        ),
        'Golden Retriever',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('pet-form-color-field')),
          matching: find.byType(TextFormField),
        ),
        'Vàng kem',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('pet-form-save-button')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('pet-form-save-button')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      for (
        var attempt = 0;
        attempt < 20 &&
            router.routeInformationProvider.value.uri.path == '/pets/create';
        attempt++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(router.routeInformationProvider.value.uri.path, '/pets/list');
      expect(find.text(petName), findsAtLeastNWidgets(1));

      final persistedPets = await petApi.listPets(
        accessToken: session.accessToken,
      );
      final persistedPet = persistedPets.firstWhere(
        (pet) => pet.name == petName,
      );
      createdPetId = persistedPet.id;

      router.go('/pets');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(PetHomeScreen), findsOneWidget);
      expect(find.text(petName), findsAtLeastNWidgets(1));
      expect(
        find.byKey(Key('home-pet-avatar-${persistedPet.id}')),
        findsOneWidget,
      );

      router.go('/profile');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text(_email), findsOneWidget);
      expect(find.text(petName), findsAtLeastNWidgets(1));
    } finally {
      if (createdPetId != null) {
        await petApi.deletePet(createdPetId, accessToken: session.accessToken);
      }
      router.dispose();
    }
  });
}

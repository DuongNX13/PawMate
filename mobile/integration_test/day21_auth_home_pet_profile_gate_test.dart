import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/app/pawmate_app.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = String.fromEnvironment(
  'PAWMATE_QA_AUTH_EMAIL',
  defaultValue: 'mobile-e2e-owner@pawmate.test',
);
const _password = String.fromEnvironment(
  'PAWMATE_QA_AUTH_PASSWORD',
  defaultValue: 'Pawmate123',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Day21 integrates authenticated Home, Pet, and Profile consumers',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
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
      final petName = 'Day21 Gate $runId';
      PetProfile? createdPet;

      try {
        createdPet = await petApi.createPet(
          CreatePetProfileInput(
            name: petName,
            species: 'dog',
            breed: 'Golden Retriever',
            color: 'Vàng kem',
            gender: 'unknown',
            healthStatus: 'healthy',
            isNeutered: false,
          ),
          accessToken: session.accessToken,
        );
        final homePet = (await petApi.listPets(
          accessToken: session.accessToken,
        )).first;

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
            child: const PawMateApp(),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        for (var attempt = 0; attempt < 30; attempt++) {
          if (find.byType(PetHomeScreen).evaluate().isNotEmpty) {
            break;
          }
          await tester.pump(const Duration(seconds: 1));
        }

        expect(find.byType(PetHomeScreen), findsOneWidget);
        expect(find.text(petName), findsAtLeastNWidgets(1));

        final homePetDestination = find.byKey(
          Key('home-pet-avatar-${homePet.id}'),
        );
        expect(homePetDestination, findsOneWidget);
        await tester.tap(homePetDestination);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.byType(PetDetailScreen), findsOneWidget);
        expect(find.text(homePet.name), findsAtLeastNWidgets(1));
        await tester.scrollUntilVisible(
          find.text('Quay lại danh sách'),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Quay lại danh sách'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        final profileDestination = find.bySemanticsLabel('Profile');
        expect(profileDestination, findsOneWidget);
        await tester.tap(profileDestination);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text(_email), findsOneWidget);
        expect(find.text(petName), findsAtLeastNWidgets(1));
      } finally {
        if (createdPet != null) {
          await petApi.deletePet(
            createdPet.id,
            accessToken: session.accessToken,
          );
        }
      }
    },
  );
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/health/application/health_record_providers.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
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

  testWidgets(
    'persists a backend-backed health event after reopening the health screen',
    (tester) async {
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
      final pet = await petApi.createPet(
        CreatePetProfileInput(
          name: 'Bap E2E $runId',
          species: 'dog',
          breed: 'Golden Retriever',
          gender: 'male',
          dateOfBirth: DateTime(2022, 4, 12),
          weightKg: 12.4,
          healthStatus: 'healthy',
          isNeutered: true,
        ),
        accessToken: session.accessToken,
      );
      final note = 'E2E persistence note $runId';

      await _pumpHealthScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );

      expect(find.text(pet.name), findsAtLeastNWidgets(1));
      expect(find.text('Chưa có sự kiện'), findsOneWidget);

      await tester.tap(find.text('Thêm sự kiện').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, note);
      await tester.tap(find.text('Lưu sự kiện'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text(note), findsOneWidget);

      await _pumpHealthScreen(
        tester,
        dio: dio,
        accessToken: session.accessToken,
      );

      expect(find.text(pet.name), findsAtLeastNWidgets(1));
      expect(find.text(note), findsOneWidget);
    },
  );
}

Future<void> _pumpHealthScreen(
  WidgetTester tester, {
  required Dio dio,
  required String accessToken,
}) async {
  final router = GoRouter(
    initialLocation: '/health',
    routes: [
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthTimelineScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith((ref) => dio),
        petAccessTokenProvider.overrideWith((ref) async => accessToken),
        healthRecordAccessTokenProvider.overrideWith(
          (ref) async => accessToken,
        ),
        reminderAccessTokenProvider.overrideWith((ref) async => accessToken),
      ],
      child: MaterialApp.router(theme: _testTheme(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

ThemeData _testTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFFFF8A5B),
  );
}

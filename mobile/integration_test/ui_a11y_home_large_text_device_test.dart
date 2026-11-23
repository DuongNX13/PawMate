import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P1-07 Home keeps visible copy readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/pets',
        routes: [
          GoRoute(
            path: '/pets',
            builder: (context, state) => const PetHomeScreen(),
          ),
          _targetRoute('/health', 'Health target'),
          _targetRoute('/health/reminders', 'Reminder target'),
          _targetRoute('/rescue', 'Rescue target'),
          _targetRoute('/adoption', 'Adoption target'),
          _targetRoute('/vets/list', 'Vets target'),
          _targetRoute('/vets/map', 'Vet map target'),
          _targetRoute('/vets/:id', 'Vet target'),
          _targetRoute('/profile', 'Profile target'),
          _targetRoute('/notifications', 'Notifications target'),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async => [_samplePet()]),
            upcomingRemindersProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'PawMate',
        'LỊCH NHẮC SỨC KHỎE',
        'Chưa có lịch nhắc cho Mochi',
        'Tạo lịch tiêm phòng, tẩy giun hoặc tái khám.',
        'Mất Poodle trắng tại phường Tân Quý',
        'PHÒNG KHÁM GẦN BẠN',
        'PetHome Q7',
        '★ 4.8 (120+)',
        'Tìm nhà cho Golden',
        '2 tháng tuổi • Hiền lành',
        'NHẬN NUÔI',
        'Xem thêm',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        final text = find.text(label);
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: 'Visible Home copy must not ellipsize: $label',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}

GoRoute _targetRoute(String path, String label) => GoRoute(
  path: path,
  builder: (context, state) => Scaffold(body: Center(child: Text(label))),
);

PetProfile _samplePet() => PetProfile(
  id: 'home-large-text-pet',
  name: 'Mochi',
  species: 'dog',
  breed: 'Golden Retriever',
  gender: 'male',
  dateOfBirth: DateTime(2022, 5, 11),
  weightKg: 12.4,
  healthStatus: 'healthy',
);

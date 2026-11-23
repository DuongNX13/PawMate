import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P1-05 pet list keeps visible copy readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith(
              (ref) async => [_petMochi(), _petKem()],
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: PetListScreen(now: DateTime(2024, 5, 20)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectVisibleTextIsReadable(String label) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: 'Visible pet-list copy must not ellipsize: $label',
        );
      }

      for (final label in const [
        'PawMate',
        'Chào buổi sáng, Nam!',
        'Cùng chăm sóc các bạn nhỏ hôm nay nhé.',
        'Mochi',
        'Mèo tam thể • 2 tuổi',
      ]) {
        expectVisibleTextIsReadable(label);
      }
      await tester.dragUntilVisible(
        find.byKey(const Key('pet-list-card-kem')),
        find.byKey(const Key('pet-list-scroll')),
        const Offset(0, -260),
      );
      for (final label in const ['Kem', 'Chó • 2 tuổi']) {
        expectVisibleTextIsReadable(label);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

PetProfile _petMochi() => PetProfile(
  id: 'mochi',
  name: 'Mochi',
  species: 'cat',
  breed: 'Mèo tam thể',
  gender: 'unknown',
  dateOfBirth: DateTime(2022, 4, 12),
  healthStatus: 'healthy',
);

PetProfile _petKem() => PetProfile(
  id: 'kem',
  name: 'Kem',
  species: 'dog',
  breed: 'Samoyed',
  gender: 'unknown',
  dateOfBirth: DateTime(2022, 4, 12),
  healthStatus: 'healthy',
);

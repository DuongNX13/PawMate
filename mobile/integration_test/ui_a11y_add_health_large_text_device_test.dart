import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/health/presentation/add_health_event_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P1-13 keeps header, pet and event labels readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));
      final pet = PetProfile(
        id: 'long-name',
        name: 'Bông Tuyết Golden Retriever Siêu Dễ Thương 2026',
        species: 'dog',
        breed: 'Golden Retriever',
        gender: 'unknown',
        dateOfBirth: DateTime(2022, 4, 12),
        healthStatus: 'healthy',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWith((ref) async => [pet]),
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
            home: const AddHealthEventScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectVisibleTextIsReadable(Finder text, String label) {
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: 'Visible add-health copy must not ellipsize: $label',
        );
      }

      expect(find.bySemanticsLabel('Thêm sự kiện sức khỏe'), findsOneWidget);
      expectVisibleTextIsReadable(find.text('Thêm sự kiện'), 'Thêm sự kiện');
      expectVisibleTextIsReadable(find.text(pet.name), pet.name);
      final eventLabel = find.text('Khám định kỳ');
      await tester.scrollUntilVisible(
        eventLabel,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expectVisibleTextIsReadable(eventLabel, 'Khám định kỳ');
      expect(tester.takeException(), isNull);
    },
  );
}

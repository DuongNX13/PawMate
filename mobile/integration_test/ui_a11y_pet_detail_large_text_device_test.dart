import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> prepareScreenshot() async {
    try {
      await binding.convertFlutterSurfaceToImage();
      return true;
    } on MissingPluginException catch (error) {
      debugPrint('ANDROID_SCREENSHOT_SKIPPED: $error');
      return false;
    }
  }

  testWidgets(
    'P1 pet detail keeps long profile copy readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));
      final pet = PetProfile(
        id: 'long-copy',
        name: 'Bông Tuyết Golden Retriever Siêu Dễ Thương 2026',
        species: 'dog',
        breed: 'Golden Retriever lai lông dài màu kem đậm',
        gender: 'unknown',
        dateOfBirth: DateTime(2022, 4, 12),
        weightKg: 12.4,
        healthStatus: 'healthy',
        color: 'Vàng kem chuyển nâu nhạt với mảng lông trắng ở ngực',
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
            home: const PetDetailScreen(petId: 'long-copy'),
          ),
        ),
      );
      final canTakeScreenshot = await prepareScreenshot();
      await tester.pumpAndSettle();

      void expectVisibleTextIsReadable(Finder text, String label) {
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: 'Visible pet-detail copy must not ellipsize: $label',
        );
      }

      expect(
        find.bySemanticsLabel('Hồ sơ thú cưng của ${pet.name}'),
        findsOneWidget,
      );
      expectVisibleTextIsReadable(find.text(pet.name), pet.name);
      if (canTakeScreenshot) {
        await binding.takeScreenshot('day91-pet-detail-large-text-android');
      }
      final detailScroll = find.byType(Scrollable).first;
      final breed = find.textContaining('Golden Retriever lai lông dài');
      await tester.scrollUntilVisible(breed, 220, scrollable: detailScroll);
      expectVisibleTextIsReadable(breed, 'Chó • ${pet.breed}');
      await tester.scrollUntilVisible(
        find.text(pet.color!),
        260,
        scrollable: detailScroll,
      );
      expectVisibleTextIsReadable(find.text(pet.color!), pet.color!);
      expect(tester.takeException(), isNull);
      if (canTakeScreenshot) {
        await binding.takeScreenshot(
          'day91-pet-detail-large-text-scrolled-android',
        );
      }
    },
  );
}

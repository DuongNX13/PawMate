import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';

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
    'P1-06 Create Pet header and field labels remain readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const CreatePetScreen(returnTo: '/pets/list'),
          ),
        ),
      );
      final canTakeScreenshot = await prepareScreenshot();
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Hồ sơ thú cưng'), findsOneWidget);
      final header = find.text('Hồ sơ');
      expect(header, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(header).didExceedMaxLines,
        isFalse,
      );

      final microchipLabel = find.text('Số Microchip (nếu có)');
      await tester.scrollUntilVisible(
        microchipLabel,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.renderObject<RenderParagraph>(microchipLabel).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      if (canTakeScreenshot) {
        await binding.takeScreenshot('day91-create-pet-large-text-android');
      }
    },
  );
}

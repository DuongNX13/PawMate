import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_report_review_sheet.dart';

import 'day122_android_responsive_test.dart' show restoreNativeMetrics122;
import 'day122_closure_checkpoint.dart';
import 'day122_closure_recipes.dart';
import 'day122_fixture_config.dart';

// Native-render fixture recapture only. Never TalkBack gesture proof.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Day122FixtureConfig config;
  String getRun() => config.run;
  const bridge =
      '/data/user/0/com.pawmate.pawmate_mobile/files/day122-closure-r4';
  late Size size;
  final previous = Directory.current;
  Directory? assets;
  late ClosureCheckpoint transport;
  setUpAll(() async {
    config = Day122FixtureConfig.fromJson(
      jsonDecode(File('$bridge/identity.json').readAsStringSync())
        as Map<String, dynamic>,
    );
    size = Size(config.width.toDouble(), config.height.toDouble());
    binding.reportData = {'run': getRun(), 'family': config.family,
      'native_acceptance': false, 'input_method': 'WIDGET_FIXTURE_RENDER_ONLY'};
    transport = ClosureCheckpoint(run: getRun(), bridge: bridge);
    assets = await Directory.systemTemp.createTemp('day122-closure-assets-');
    Directory.current = assets!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final name in manifest.listAssets().where(
      (name) =>
          name.startsWith('assets/images/') || name.startsWith('assets/icons/'),
    )) {
      final bytes = await rootBundle.load(name);
      final file = File(name);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
  });
  tearDownAll(() async {
    Directory.current = previous;
    await assets?.delete(recursive: true);
  });
  testWidgets(
    'Seven allowlisted corrected fixtures — one host identity per launch',
    (tester) async {
      final family = config.family;
      final native = ui.PlatformDispatcher.instance.views.single;
      expect(native.physicalSize / native.devicePixelRatio, size);
      late Finder screen;
      late String screenName;
      late List<String> keys;
      late Finder middle;
      late Finder end;
      if (family == 'DT-08') {
        await pumpClosureReportReview(
          tester,
          size,
          restoreNativeMetrics: () => restoreNativeMetrics122(tester),
        );
        screen = find.byType(RescueReportReviewSheet);
        screenName = 'RescueReportReviewSheet';
        keys = ['rescue-report-review-sheet'];
        middle = find.byKey(const Key('rescue-review-location'));
        end = find.byKey(const Key('rescue-review-back'));
      } else {
        final edit = family == 'DT-02';
        await pumpClosurePet(
          tester,
          size,
          edit: edit,
          restoreNativeMetrics: () => restoreNativeMetrics122(tester),
        );
        screen = edit
            ? find.byType(CreatePetScreen)
            : find.byType(PetDetailScreen);
        screenName = edit ? 'CreatePetScreen' : 'PetDetailScreen';
        keys = [edit ? 'pet-form-avatar-picker' : 'pet-detail-avatar'];
        middle = find.byKey(
          Key(edit ? 'pet-form-weight-field' : 'pet-detail-identity-card'),
        );
        end = find.byKey(
          Key(edit ? 'pet-form-microchip-field' : 'pet-detail-identity-card'),
        );
      }
      Future<void> capture(String stage) => transport.capture(
        tester,
        id: config.id,
        stage: stage,
        screenName: screenName,
        screen: screen,
        foregroundKeys: keys,
      );
      try {
        await capture('top');
        await tester.ensureVisible(middle);
        await tester.pumpAndSettle();
        await capture('middle');
        await closureScrollToEnd(tester, end);
        await capture('end');
        expect(tester.takeException(), isNull);
      } finally {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    timeout: const Timeout(Duration(seconds: 100)),
  );
}

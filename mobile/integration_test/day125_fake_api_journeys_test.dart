// Day 125 fallback for journeys without a local-backend test: real widgets and
// router, fake API sources from the D122 closure harness. Not DB evidence.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import 'day122_closure_stages.dart';

const _journeys = ['TB-AUTH', 'TB-VET', 'TB-RESCUE'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previous = Directory.current;
  Directory? assets;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Harness image widgets read asset paths from disk, so mirror the bundle.
    assets = await Directory.systemTemp.createTemp('day125-journey-assets-');
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

  for (final journey in _journeys) {
    testWidgets('Day125 $journey stages in order', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final session = await pumpClosureJourney(
          tester,
          journey,
          const Size(360, 800),
          restoreMetrics: () {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          },
        );
        final targets = closureStageTargets(journey).keys.toList();
        final seen = <String>[];
        await session.rehearse(tester, (stage) async {
          expect(stage, targets[seen.length]);
          seen.add(stage);
        });
        expect(seen, targets);
        // ignore: avoid_print
        print('DAY125 $journey ${seen.length}/${targets.length} PASS');
      } finally {
        semantics.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

// Mount fixture once, then wait for externally driven native input.
// Host requests can only inspect state. This entry never calls rehearse/tap.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import 'day122_closure_journeys.dart';
import 'day122_closure_stages.dart';
import 'day122_passive_binding.dart';
import 'day122_passive_home_observer.dart';
import 'day122_q3_action_witness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureDay122PassiveBinding(binding);
  const bridge = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-passive';
  testWidgets('Observe externally driven Home/Pet only', (tester) async {
    final config = ClosureLaunchConfig.fromJson(
      jsonDecode(File('$bridge/identity.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(config.journey, 'TB-HOME-PET');
    final native = ui.PlatformDispatcher.instance.views.single;
    expect(native.physicalSize / native.devicePixelRatio,
        Size(config.width.toDouble(), config.height.toDouble()));
    GoogleFonts.config.allowRuntimeFetching = false;
    final previous = Directory.current;
    final assets = await Directory.systemTemp.createTemp('day122-passive-');
    Directory.current = assets;
    final semantics = tester.ensureSemantics();
    Day122Q3ActionWitness? actionWitness;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final name in manifest.listAssets().where((name) =>
          name.startsWith('assets/images/') || name.startsWith('assets/icons/'))) {
        final bytes = await rootBundle.load(name);
        final file = File(name);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List(
            bytes.offsetInBytes, bytes.lengthInBytes));
      }
      final harness = await pumpClosureHomePetJourney(tester,
          Size(config.width.toDouble(), config.height.toDouble()),
          restoreNativeMetrics: () {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
      });
      expect(MediaQuery.textScalerOf(tester.element(
          closureStageTargets(config.journey)[passiveHomeStages.first]!.screen))
          .scale(1), config.font.toDouble());
      void publish(String name, Map<String, Object?> value) {
        final file = File('$bridge/$name.json');
        if (file.existsSync()) throw StateError('Preserve first observation');
        final temp = File('${file.path}.tmp');
        temp.writeAsStringSync(jsonEncode(value), flush: true);
        temp.renameSync(file.path);
      }
      if (config.run.startsWith('closure-c3-q3-')) {
        actionWitness = Day122Q3ActionWitness(
          run: config.run,
          sink: File('$bridge/engine-actions.jsonl'),
          root: (viewId) => binding.renderViews
              .where((view) => view.flutterView.viewId == viewId)
              .single.owner?.semanticsOwner?.rootSemanticsNode,
          route: () => harness.router.routerDelegate.currentConfiguration.last.matchedLocation,
        );
      }
      publish('ready', {'run': config.run, 'at': DateTime.now().toUtc().toIso8601String(),
        'input_method': 'NONE_OBSERVER_ONLY', 'talkback_acceptance': false});
      Object? failure;
      StackTrace? failureStack;
      final done = await tester.runAsync(() async {
        try {
          final clock = Stopwatch()..start();
          var next = 1;
          final hold = config.run.endsWith('-c5');
          while (next <= passiveHomeStages.length || hold) {
            if (clock.elapsed >= const Duration(seconds: 180)) {
              throw StateError('Passive native journey deadline');
            }
            final query = File('$bridge/query-$next.json');
            final release = File('$bridge/release.json');
            if (hold && release.existsSync()) {
              final request = jsonDecode(release.readAsStringSync());
              if (request is! Map || request.length != 2 ||
                  request['run'] != config.run || request['command'] != 'RELEASE' ||
                  next < passiveHomeStages.length) {
                throw StateError('Invalid close authorization');
              }
              break;
            }
            if (next <= passiveHomeStages.length && query.existsSync()) {
              final request = jsonDecode(query.readAsStringSync()) as Map<String, dynamic>;
              validatePassiveHomeRequest(request, run: config.run, nextSequence: next);
              publish('observation-$next', {'run': config.run, 'sequence': next,
                'at': DateTime.now().toUtc().toIso8601String(),
                ...observePassiveHome(tester, harness, request['stage'] as String)});
              next++;
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          return true;
        } catch (error, stack) {
          failure = error; failureStack = stack; return false;
        }
      });
      if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
      if (actionWitness?.failure case final error?) {
        Error.throwWithStackTrace(error, actionWitness!.failureStack!);
      }
      expect(done, isTrue);
      binding.reportData = {'run': config.run, 'observations': 3,
        'proof_scope': 'PASSIVE_QA_STATE_OBSERVATION_NOT_INPUT_PROOF',
        'talkback_acceptance': false};
    } finally {
      actionWitness?.dispose();
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      Directory.current = previous;
      await assets.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 220)));
}

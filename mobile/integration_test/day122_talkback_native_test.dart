// Fixture mounting plus a read-only state/field observer for the host runner.
// Only the host's emulator-console driver generates gestures.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_support/day119_detail_support.dart' as detail;
import 'day122_closure_stages.dart';
import 'day122_passive_binding.dart';
import 'day122_talkback_stage_oracle.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureDay122PassiveBinding(binding);
  const bridge = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-passive';
  testWidgets(
    'Observe Day122 journey with external real Android input',
    (tester) async {
      final config = ClosureLaunchConfig.fromJson(
        jsonDecode(File('$bridge/identity.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(config.journey, isNot('TB-HOME-PET'));
      final native = ui.PlatformDispatcher.instance.views.single;
      final size = Size(config.width.toDouble(), config.height.toDouble());
      expect(native.physicalSize / native.devicePixelRatio, size);
      GoogleFonts.config.allowRuntimeFetching = false;
      final previous = Directory.current;
      final assets = await Directory.systemTemp.createTemp('day122-talkback-');
      Directory.current = assets;
      final semantics = tester.ensureSemantics();
      final dispatcher = ui.PlatformDispatcher.instance;
      final previousAction = dispatcher.onSemanticsActionEvent;
      Object? actionWriteError;
      bool witnessInstalled = false;
      void publish(String name, Map<String, Object?> data) {
        final file = File('$bridge/$name.json');
        if (file.existsSync()) {
          throw StateError('First observation is immutable');
        }
        final tmp = File('${file.path}.tmp');
        tmp.writeAsStringSync(
          jsonEncode({
            'run': config.run,
            'journey': config.journey,
            'device_wall_ms': DateTime.now().millisecondsSinceEpoch,
            ...data,
          }),
          flush: true,
        );
        tmp.renameSync(file.path);
      }

      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        for (final name in manifest.listAssets().where(
          (name) =>
              name.startsWith('assets/images/') ||
              name.startsWith('assets/icons/'),
        )) {
          final bytes = await rootBundle.load(name);
          final file = File(name);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        }
        final session = await pumpClosureJourney(
          tester,
          config.journey,
          size,
          restoreMetrics: () {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewInsets();
            tester.view.resetViewPadding();
            tester.view.resetPadding();
          },
        );
        final stages = closureStageTargets(config.journey);
        expect(
          MediaQuery.textScalerOf(
            tester.element(stages.values.first.screen),
          ).scale(1),
          config.font.toDouble(),
        );
        final previous = previousAction;
        if (previous == null) {
          throw StateError('No Flutter semantics dispatcher');
        }
        final actions = File('$bridge/engine-actions.jsonl');
        actions.createSync(exclusive: true);
        dispatcher.onSemanticsActionEvent = (event) {
          try {
            if (event.type == ui.SemanticsAction.tap) {
              final root = binding.renderViews
                  .singleWhere(
                    (view) => view.flutterView.viewId == event.viewId,
                  )
                  .owner
                  ?.semanticsOwner
                  ?.rootSemanticsNode;
              final node = _findNode(root, event.nodeId);
              final data = node?.getSemanticsData();
              actions.writeAsStringSync(
                '${jsonEncode({'run': config.run, 'case_id': config.journey, 'pid': pid, 'type': 'ENGINE_SEMANTICS_TAP', 'node_id': event.nodeId, 'label': data?.label, 'tooltip': data?.tooltip, 'supports_tap': data?.hasAction(ui.SemanticsAction.tap), 'device_wall_ms': DateTime.now().millisecondsSinceEpoch})}\n',
                mode: FileMode.append,
                flush: true,
              );
            }
          } catch (error) {
            actionWriteError ??= error;
          } finally {
            previous(event);
          }
        };
        witnessInstalled = true;
        publish('ready', {
          'rescue_case_id': detail.day119FirstCaseId,
          'input_method': 'NONE_OBSERVER_ONLY',
          'pid': pid,
        });
        (Object, StackTrace)? failure;
        final result = await tester.runAsync(() async {
          try {
            final clock = Stopwatch()..start();
            var next = 1, stageIndex = 0;
            while (clock.elapsed < const Duration(seconds: 1800)) {
              if (actionWriteError case final error?) {
                throw StateError('Semantics witness: $error');
              }
              final query = File('$bridge/request-$next.json');
              if (!query.existsSync()) {
                await Future<void>.delayed(const Duration(milliseconds: 50));
                continue;
              }
              final request =
                  jsonDecode(query.readAsStringSync()) as Map<String, dynamic>;
              if (request['run'] != config.run || request['sequence'] != next) {
                throw StateError('Wrong request identity');
              }
              if (request['op'] == 'release') return stageIndex;
              final answer = <String, Object?>{'sequence': next};
              switch (request['op']) {
                case 'node':
                  final key = request['key'] as String;
                  final finder = find.byKey(ValueKey<String>(key));
                  expect(
                    finder,
                    findsOneWidget,
                    reason: 'Expected unique fixture control',
                  );
                  final node = tester.getSemantics(finder);
                  final data = node.getSemanticsData();
                  answer.addAll({
                    'key': key,
                    'node_id': node.id,
                    'label': data.label,
                    'tooltip': data.tooltip,
                    'hint': data.hint,
                    'supports_tap': data.hasAction(ui.SemanticsAction.tap),
                  });
                case 'field':
                  final value = readTalkBackField(
                    tester,
                    request['field'] as String,
                  );
                  answer['value'] = value;
                case 'stage':
                  final name = request['stage'] as String;
                  if (stageIndex >= stages.length ||
                      name != stages.keys.elementAt(stageIndex)) {
                    throw StateError('Stage sequence drift');
                  }
                  // The wrapper never changes app state to satisfy the oracle.
                  try {
                    answer.addAll(observeTalkBackStage(tester, session, name));
                    answer['sequence'] = ++stageIndex;
                  } on TestFailure catch (error) {
                    // Screen mount, modal transitions and provider data need
                    // not be ready in the same frame as the input event.
                    // Return the failed oracle, never advance the stage and
                    // never drive the app to satisfy it.
                    answer['pending_stage'] = name;
                    answer['oracle_reason'] = error.message;
                    answer['assertions_met'] = false;
                  }
                case 'fixture':
                  transitionTalkBackFixture(
                    session,
                    request['fixture'] as String,
                  );
                  answer['fixture_boundary'] = 'SYNTHETIC_BACKEND_ONLY';
                default:
                  throw StateError('Unknown observer request');
              }
              publish('answer-$next', answer);
              next++;
            }
            throw StateError('Native observer deadline reached');
          } catch (error, stack) {
            failure = (error, stack);
            return null;
          }
        });
        if (failure case (final error, final stack)) {
          Error.throwWithStackTrace(error, stack);
        }
        binding.reportData = {
          'run': config.run,
          'observations': result,
          'input_method': 'NONE_OBSERVER_ONLY',
          'talkback_acceptance': false,
        };
      } finally {
        if (witnessInstalled) {
          dispatcher.onSemanticsActionEvent = previousAction;
        }
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        Directory.current = previous;
        await assets.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 1900)),
  );
}

SemanticsNode? _findNode(SemanticsNode? root, int id) {
  if (root == null || root.id == id) return root;
  SemanticsNode? found;
  root.visitChildren((child) {
    found = _findNode(child, id);
    return found == null;
  });
  return found;
}

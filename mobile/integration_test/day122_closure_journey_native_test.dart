// Native-render/stage capture entry. Actions are widget APIs, NOT TalkBack proof.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import 'day122_closure_checkpoint.dart';
import 'day122_closure_capture_sync.dart';
import 'day122_closure_stages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late ClosureLaunchConfig config;
  const bridge =
      '/data/user/0/com.pawmate.pawmate_mobile/files/day122-closure-journey';
  Size getSize() => Size(config.width.toDouble(), config.height.toDouble());
  final previous = Directory.current;
  Directory? assets;
  late ClosureCheckpoint transport;
  setUpAll(() async {
    config = ClosureLaunchConfig.fromJson(
      jsonDecode(File('$bridge/identity.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    transport = ClosureCheckpoint(run: config.run, bridge: bridge);
    binding.reportData = {
      'run': config.run,
      'journey': config.journey,
      'proof_scope': closureRehearsalScope,
      'talkback_acceptance': false,
    };
    GoogleFonts.config.allowRuntimeFetching = false;
    assets = await Directory.systemTemp.createTemp('day122-journey-assets-');
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
    'Native render rehearsal selected by pinned host identity',
    (tester) async {
      final native = ui.PlatformDispatcher.instance.views.single;
      expect(native.physicalSize / native.devicePixelRatio, getSize());
      final semantics = tester.ensureSemantics();
      try {
        final session = await pumpClosureJourney(
          tester,
          config.journey,
          getSize(),
          restoreMetrics: () {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewInsets();
            tester.view.resetViewPadding();
            tester.view.resetPadding();
          },
        );
        final targets = closureStageTargets(config.journey);
        final stages = <String>[];
        await session.rehearse(tester, (stage) async {
          expect(stage, targets.keys.elementAt(stages.length));
          final target = targets[stage]!;
          expect(
            MediaQuery.textScalerOf(tester.element(target.screen)).scale(1),
            config.font.toDouble(),
          );
          await transport.capture(
            tester,
            id: 'ANDROID-REHEARSAL-${config.journey}-${config.width}x${config.height}',
            stage: stage,
            screenName: target.screenName,
            screen: target.screen,
            foregroundKeys: [if (target.key != null) target.key!],
            inspectAfterPump: () async {
              final expectation = closureImeExpectation(config.journey);
              if (expectation == ClosureImeExpectation.hidden) {
                FocusManager.instance.primaryFocus?.unfocus();
                await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
              }
              final metricClock = Stopwatch()..start();
              final stableMetrics = await awaitClosureCaptureMetrics(
                read: () => closureViewMetrics(ui.PlatformDispatcher.instance.views.single),
                pump: () => tester.pump(),
                wait: () async {
                  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
                },
                elapsedMs: () => metricClock.elapsedMilliseconds,
                expectation: expectation,
                keyboardRequested: closureKeyboardRequested(config.journey, stage),
              );
              final timings = <ui.FrameTiming>[];
              void observe(List<ui.FrameTiming> values) =>
                  timings.addAll(values);
              binding.addTimingsCallback(observe);
              try {
                await tester.pump();
                final requestedPresentation =
                    binding.currentSystemFrameTimeStamp.inMicroseconds;
                final requestedFrame =
                    ui.PlatformDispatcher.instance.frameData.frameNumber;
                if (requestedFrame < 0) {
                  throw StateError('Engine did not provide a frame identity');
                }
                Map<String, Object> diagnostic() => {
                  'stage': stage,
                  'requested_frame_number': requestedFrame,
                  'requested_presentation_us': requestedPresentation,
                  'sample_count': timings.length,
                  'samples_tail': timings.reversed
                      .take(8)
                      .map(
                        (timing) => {
                          'frame_number': timing.frameNumber,
                          for (final phase in [
                            ui.FramePhase.vsyncStart,
                            ui.FramePhase.buildStart,
                            ui.FramePhase.buildFinish,
                            ui.FramePhase.rasterStart,
                            ui.FramePhase.rasterFinish,
                          ])
                            phase.name: timing.timestampInMicroseconds(phase),
                        },
                      )
                      .toList(),
                };
                debugPrint('D122_RASTER_REQUEST ${jsonEncode(diagnostic())}');
                // runAsync reports uncaught errors and returns null. Retain the
                // original failure once, instead of adding "Missing raster".
                (Object, StackTrace)? failure;
                final raster = await tester.runAsync(() async {
                  try {
                    final clock = Stopwatch()..start();
                    while (!timings.any(
                      (timing) => timing.frameNumber == requestedFrame,
                    )) {
                      if (clock.elapsed > const Duration(seconds: 3)) {
                        throw StateError(
                          'Native raster timing deadline: ${jsonEncode(diagnostic())}',
                        );
                      }
                      await Future<void>.delayed(
                        const Duration(milliseconds: 20),
                      );
                    }
                    return closureRasterTiming(timings, requestedFrame);
                  } catch (error, stack) {
                    failure = (error, stack);
                    return null;
                  }
                });
                if (failure != null) {
                  Error.throwWithStackTrace(failure!.$1, failure!.$2);
                }
                if (raster == null) throw StateError('Missing raster evidence');
                return {
                  ...inspectClosureStage(
                    tester,
                    config.journey,
                    stage,
                    stableMetrics,
                  ),
                  'capture_stability': {
                    'expected_ime': expectation.name,
                    'keyboard_requested': closureKeyboardRequested(config.journey, stage),
                    'stable_ms': 200,
                    'wait_ms': metricClock.elapsedMilliseconds,
                  },
                  'raster_fence': {
                    ...raster,
                    // Diagnostic only: presentation time is NOT vsyncStart.
                    'requested_presentation_us': requestedPresentation,
                  },
                };
              } finally {
                binding.removeTimingsCallback(observe);
              }
            },
          );
          stages.add(stage);
          expect(tester.takeException(), isNull);
        });
        expect(stages, targets.keys.toList());
      } finally {
        semantics.dispose();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    timeout: const Timeout(Duration(seconds: 200)),
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../integration_test/day122_closure_stages.dart';
import '../../integration_test/day122_closure_checkpoint.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  test(
    'QA runtime identity only selects declared journeys and viewport pairs',
    () {
      final value = <String, dynamic>{
        'run': 'closure-r8-home-360',
        'journey': 'TB-HOME-PET',
        'width': 360,
        'height': 800,
        'font_scale': 1,
      };
      expect(ClosureLaunchConfig.fromJson(value).journey, 'TB-HOME-PET');
      for (final patch in [
        {'run': 'other'},
        {'journey': 'UNKNOWN'},
        {'width': 320},
        {'height': 932},
        {'font_scale': 0.5},
      ]) {
        expect(
          () => ClosureLaunchConfig.fromJson({...value, ...patch}),
          throwsStateError,
        );
      }
    },
  );
  test(
    'stage catalog has exactly seven families and 41 distinct stage identities',
    () {
      expect(closureJourneyIds.toSet(), hasLength(7));
      expect(
        closureJourneyIds.expand((id) => closureStageTargets(id).keys),
        hasLength(41),
      );
      expect(() => closureStageTargets('wrong'), throwsStateError);
    },
  );
  test(
    'frame identity selects the requested frame, not a newer batch member',
    () {
      // Synthetic timings: engine batches can contain several completed frames.
      // The requested presentation timestamp (1016667) is not vsyncStart (1000000).
      ui.FrameTiming frame(int number, int vsync) => ui.FrameTiming(
        vsyncStart: vsync,
        buildStart: vsync + 1000,
        buildFinish: vsync + 2000,
        rasterStart: vsync + 3000,
        rasterFinish: vsync + 4000,
        rasterFinishWallTime: 123456789,
        frameNumber: number,
      );
      final value = closureRasterTiming([
        frame(41, 983333),
        frame(42, 1000000),
        frame(43, 1016667),
      ], 42);
      expect(value['frame_number'], 42);
      expect(value['requested_frame_number'], 42);
      expect(value['identity_method'], 'ENGINE_FRAME_NUMBER');
      expect(
        () => closureRasterTiming([frame(43, 1016667)], 42),
        throwsStateError,
      );
      expect(
        () => closureRasterTiming([frame(41, 983333)], 42),
        throwsStateError,
      );
      expect(
        () => closureRasterTiming([frame(42, 1000000), frame(42, 1000000)], 42),
        throwsStateError,
      );
    },
  );
  test('raster fence rejects stale or missing engine timings', () {
    ui.FrameTiming frame(int vsync, int number) => ui.FrameTiming(
      vsyncStart: vsync,
      buildStart: vsync + 1,
      buildFinish: vsync + 2,
      rasterStart: vsync + 3,
      rasterFinish: vsync + 4,
      rasterFinishWallTime: 123456,
      frameNumber: number,
    );
    expect(() => closureRasterTiming([], 10), throwsStateError);
    expect(() => closureRasterTiming([frame(9, 1)], 10), throwsStateError);
    expect(() => closureRasterTiming([frame(10, -1)], 10), throwsStateError);
    expect(() => closureRasterTiming([frame(10, 1)], -1), throwsStateError);
    final value = closureRasterTiming([frame(9, 1), frame(10, 2)], 2);
    expect(value['frame_number'], 2);
    expect(value['source'], 'ENGINE_FRAME_TIMING');
  });
  for (final journey in closureJourneyIds) {
    testWidgets('$journey local stage transport and metric-restoration contract', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var restored = false;
        // Deliberately different from pump viewport. This is a LOCAL fixture,
        // not PlatformDispatcher/native metrics or an Android acceptance proof.
        void restoreFixture() {
          if (const bool.fromEnvironment('D122_MUTATE_STAGE_METRICS')) return;
          tester.view.devicePixelRatio = 2;
          tester.view.physicalSize = const Size(860, 1864);
          tester.view.viewInsets = const FakeViewPadding();
          tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 68);
          tester.view.padding = const FakeViewPadding(top: 48, bottom: 68);
          restored = true;
        }

        addTearDown(() {
          tester.view.resetPadding();
          tester.view.resetViewPadding();
        });
        final session = await pumpClosureJourney(
          tester,
          journey,
          const Size(360, 800),
          restoreMetrics: restoreFixture,
        );
        expect(
          restored,
          isTrue,
          reason: 'Every journey must restore final metrics before actions',
        );
        final expected = closureViewMetrics(tester.view);
        final plan = closureStageTargets(journey);
        final seen = <String>[];
        await session.rehearse(tester, (stage) async {
          expect(stage, plan.keys.elementAt(seen.length));
          final metadata = inspectClosureStage(
            tester,
            journey,
            stage,
            expected,
          );
          expect(metadata['input_method'], 'flutter_widget_test_api');
          expect(metadata['talkback_acceptance'], false);
          expect(metadata['mounted_route'], plan[stage]!.route);
          expect(metadata['view_metrics'], expected);
          expectNoFlutterOverflow(tester);
          debugPrint(
            'D122_STAGE ${jsonEncode({
              'stage': stage,
              'screen': plan[stage]!.screenName,
              'foreground_keys': [if (plan[stage]!.key != null) plan[stage]!.key!],
              ...metadata,
            })}',
          );
          seen.add(stage);
        });
        expect(seen, plan.keys.toList());
      } finally {
        semantics.dispose();
      }
    });
  }
  testWidgets('stage guard rejects stale metrics and covered foreground', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpClosureJourney(
        tester,
        'TB-HOME-PET',
        const Size(360, 800),
        restoreMetrics: () {},
      );
      final metrics = closureViewMetrics(tester.view);
      inspectClosureStage(
        tester,
        'TB-HOME-PET',
        'home-first-pet-selected',
        metrics,
      );
      expect(
        () => inspectClosureStage(tester, 'TB-HOME-PET', 'unknown', metrics),
        throwsStateError,
      );
      expect(
        () => inspectClosureStage(
          tester,
          'TB-HOME-PET',
          'home-first-pet-selected',
          {...metrics, 'dpr': 99.0},
        ),
        throwsA(isA<TestFailure>()),
      );
      final screen = closureStageTargets(
        'TB-HOME-PET',
      )['home-first-pet-selected']!.screen;
      final dialog = showDialog<void>(
        context: tester.element(screen),
        builder: (_) => const AlertDialog(content: Text('QA foreground modal')),
      );
      await tester.pumpAndSettle();
      expect(
        () => inspectClosureStage(
          tester,
          'TB-HOME-PET',
          'home-first-pet-selected',
          metrics,
        ),
        throwsA(isA<TestFailure>()),
      );
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await dialog;
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('capture context cannot replace reserved run identity', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('d122-context-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/identity.json').writeAsStringSync(
      jsonEncode({
        'run': 'closure-local-context',
        'apk_sha256': 'a' * 64,
        'source_fingerprint': 'b' * 64,
      }),
    );
    final transport = ClosureCheckpoint(
      run: 'closure-local-context',
      bridge: directory.path,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Text('QA context fixture')),
    );
    Object? failure;
    try {
      await transport.capture(
        tester,
        id: 'QA-CONTEXT',
        stage: 'local',
        screenName: 'Text',
        screen: find.text('QA context fixture'),
        foregroundKeys: [],
        context: {'run': 'forged-run'},
      );
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<StateError>());
    expect(File('${directory.path}/pending.json').existsSync(), isFalse);
  });
  testWidgets('route padding guard rejects view-only readiness before layout', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(tester.view.resetPadding);
    try {
      await pumpClosureJourney(
        tester,
        'TB-HOME-PET',
        const Size(360, 800),
        restoreMetrics: () {},
      );
      // Native view changed but the route has not received a layout frame yet.
      // Old guard only compared view metrics, and wrongly accepted this state.
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 24);
      final expected = closureViewMetrics(tester.view);
      expect(
        () => inspectClosureStage(
          tester,
          'TB-HOME-PET',
          'home-first-pet-selected',
          expected,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'View equality alone cannot establish route padding readiness',
      );
      await tester.pump();
      inspectClosureStage(
        tester,
        'TB-HOME-PET',
        'home-first-pet-selected',
        expected,
      );
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('route MediaQuery diagnostic matches restored view safe area', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(() {
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    try {
      final session = await pumpClosureJourney(
        tester,
        'TB-HOME-PET',
        const Size(360, 800),
        restoreMetrics: () {
          tester.view.devicePixelRatio = 3;
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.viewInsets = const FakeViewPadding();
          tester.view.viewPadding = const FakeViewPadding(top: 136, bottom: 72);
          tester.view.padding = const FakeViewPadding(top: 136, bottom: 72);
        },
      );
      final observations = <Map<String, Object?>>[];
      await session.rehearse(tester, (stage) async {
        final screen = closureStageTargets('TB-HOME-PET')[stage]!.screen;
        final media = MediaQuery.of(tester.element(screen));
        final expected = MediaQueryData.fromView(tester.view);
        final appBar = find.byType(AppBar);
        final back = find.byType(BackButton);
        final observation = <String, Object?>{
          'stage': stage,
          'expected_padding': expected.padding.toString(),
          'route_padding': media.padding.toString(),
          'route_view_padding': media.viewPadding.toString(),
          'appbar_bounds': appBar.evaluate().length == 1
              ? tester.getRect(appBar).toString()
              : null,
          'back_bounds': back.evaluate().length == 1
              ? tester.getRect(back).toString()
              : null,
        };
        final metadata = inspectClosureStage(
          tester,
          'TB-HOME-PET',
          stage,
          closureViewMetrics(tester.view),
        );
        final routeMedia = metadata['route_media']! as Map<String, Object>;
        expect(routeMedia['padding'], [0.0, 136 / 3, 0.0, 24.0]);
        if (stage == 'second-pet-detail') {
          final controls = metadata['control_geometry']! as List;
          final backControl = controls.cast<Map>().singleWhere(
            (item) => item['kind'] == 'BackButton',
          );
          final bounds = backControl['bounds'] as List<double>;
          expect(bounds[1], greaterThanOrEqualTo(136 / 3));
          expect(bounds[2] - bounds[0], greaterThanOrEqualTo(48));
          expect(bounds[3] - bounds[1], greaterThanOrEqualTo(48));
        }
        observations.add(observation);
        debugPrint('D122_MEDIA_PROBE ${jsonEncode(observation)}');
      });
      for (final observation in observations) {
        expect(
          observation['route_padding'],
          observation['expected_padding'],
          reason:
              '${observation['stage']}: route must receive actual safe area',
        );
      }
    } finally {
      semantics.dispose();
    }
  });
}

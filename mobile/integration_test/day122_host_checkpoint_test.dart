import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import 'day122_android_responsive_test.dart' as prior;
import '../test/test_support/day119_detail_support.dart' as details;
import '../test/visual/day120_support_scaling_test.dart' as support;

// Test-only host checkpoint transport. No Flutter surface conversion or
// takeScreenshot: pixels are captured by the owning host with adb screencap.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const run = String.fromEnvironment('D122_RUN');
  const selection = String.fromEnvironment('D122_FAMILIES');
  const width = int.fromEnvironment('D122_WIDTH', defaultValue: 390);
  const height = int.fromEnvironment('D122_HEIGHT', defaultValue: 844);
  const bridgePath = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-r2';
  final bridge = Directory(bridgePath);
  final size = Size(width.toDouble(), height.toDouble());
  final families = selection.split(',').where((s) => s.isNotEmpty).toList();
  final previousDirectory = Directory.current;
  Directory? assets;
  var sequence = 0;
  binding.reportData = {
    'day': 122,
    'run': run,
    'rows': <Map<String, Object?>>[],
  };

  Future<void> checkpoint(WidgetTester t, String id, String stage) async {
    await t.pump(const Duration(milliseconds: 500));
    final native = ui.PlatformDispatcher.instance.views.single;
    final request = {
      'run': run,
      'sequence': ++sequence,
      'id': id,
      'stage': stage,
      'at': DateTime.now().toUtc().toIso8601String(),
      'physical': [native.physicalSize.width, native.physicalSize.height],
      'dpr': native.devicePixelRatio,
      'visible_text': find
          .byType(Text)
          .evaluate()
          .map(
            (e) =>
                (e.widget as Text).data ??
                (e.widget as Text).textSpan?.toPlainText() ??
                '',
          )
          .where((s) => s.isNotEmpty)
          .toList(),
      'fixture_boundaries': 'BACKEND_MAP_CLOCK_DOUBLES_NOT_LIVE',
    };
    await t.runAsync(() async {
      final pending = File('$bridgePath/pending.json');
      if (await pending.exists()) throw StateError('Unacknowledged checkpoint');
      await pending.writeAsString(jsonEncode(request), flush: true);
      final ack = File('$bridgePath/ack-$sequence.json');
      final clock = Stopwatch()..start();
      while (!await ack.exists()) {
        if (clock.elapsed > const Duration(seconds: 25)) {
          throw StateError('Host checkpoint deadline: $id/$stage');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final result =
          jsonDecode(await ack.readAsString()) as Map<String, dynamic>;
      if (result['run'] != run ||
          result['sequence'] != sequence ||
          result['id'] != id) {
        throw StateError('Wrong checkpoint acknowledgement');
      }
      await pending.delete();
    });
  }

  setUpAll(() async {
    if (!RegExp(r'^host-[a-z0-9-]+$').hasMatch(run) ||
        families.isEmpty ||
        !const [360, 390, 430].contains(width)) {
      throw StateError('Explicit bounded host run and selection required');
    }
    if (!bridge.existsSync()) throw StateError('Host bridge preflight absent');
    final hero = File('$bridgePath/hero.png');
    if (!hero.existsSync() || hero.lengthSync() < 1000) {
      throw StateError('Exact host fixture preflight absent');
    }
    assets = await Directory.systemTemp.createTemp('day122-host-assets-');
    Directory.current = assets!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where(
      (s) => s.startsWith('assets/images/') || s.startsWith('assets/icons/'),
    )) {
      final bytes = await rootBundle.load(asset);
      final f = File(asset);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
    final target = File('test/fixtures/images/golden_retriever_hero_v1.png');
    await target.parent.create(recursive: true);
    await hero.copy(target.absolute.path);
    binding.reportData!['fixture'] = {
      'source': hero.path,
      'target': target.absolute.path,
      'bytes': target.lengthSync(),
      'temporary_directory': Directory.systemTemp.path,
    };
  });
  tearDownAll(() async {
    Directory.current = previousDirectory;
    await assets?.delete(recursive: true);
  });

  for (final family in families) {
    final id = 'ANDROID-$family-${width}x$height';
    testWidgets('D122 host checkpoint $id', (t) async {
      final native = ui.PlatformDispatcher.instance.views.single;
      expect(
        native.physicalSize.width / native.devicePixelRatio,
        closeTo(width, .1),
      );
      expect(
        native.physicalSize.height / native.devicePixelRatio,
        closeTo(height, .1),
      );
      if (prior.mainFamilies.containsKey(family)) {
        await prior.mainFamilies[family]!(t, size);
      } else if (const ['DT-01', 'DT-03', 'DT-04', 'DT-05'].contains(family)) {
        await details.pumpDay119(t, family, size);
      } else {
        if (!support.families.contains(family)) {
          throw StateError('Unknown family $family');
        }
        await support.pumpFamily(t, family, size);
      }
      prior.restoreNativeMetrics122(t);
      await t.pump(const Duration(milliseconds: 500));
      if (family == 'DT-04' || family == 'DT-05') {
        final target = family == 'DT-04'
            ? find.byKey(const Key('rescue-load-more'))
            : find.byKey(
                ValueKey('rescue-marker-${details.day119FirstCaseId}'),
              );
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        await t.tap(target);
        await t.pumpAndSettle();
        expect(
          family == 'DT-04'
              ? find.text('Thu gọn')
              : find.byKey(const Key('rescue-selected-case-card')),
          findsOneWidget,
        );
      }
      expect(t.view.viewInsets.bottom, native.viewInsets.bottom);
      expect(t.view.viewPadding.bottom, native.viewPadding.bottom);
      final nav = find.byType(PawMateBottomNav);
      if (nav.evaluate().isNotEmpty) {
        expect(
          t.getRect(nav.first).bottom,
          closeTo(height, .6),
          reason: 'Navigation shell must remain at physical bottom',
        );
      }
      expect(t.takeException(), isNull);
      await checkpoint(t, id, 'top');
      final scroll = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      if (scroll.evaluate().isNotEmpty) {
        final p = t.state<ScrollableState>(scroll.first).position;
        for (var i = 0; i < 5 && p.extentAfter > .5; i++) {
          p.jumpTo(p.maxScrollExtent);
          await t.pump(const Duration(milliseconds: 300));
        }
        expect(p.extentAfter, lessThanOrEqualTo(.5));
      }
      expect(t.takeException(), isNull);
      await checkpoint(t, id, 'end');
      (binding.reportData!['rows'] as List<Map<String, Object?>>).add({
        'id': id,
        'run': run,
        'at': DateTime.now().toUtc().toIso8601String(),
        'verdict': 'RUNTIME_ASSERTIONS_PASS_HOST_VISUAL_REVIEW_REQUIRED',
        'talkback_proof': false,
      });
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}

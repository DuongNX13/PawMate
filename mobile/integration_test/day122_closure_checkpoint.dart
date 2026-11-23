import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reuses the r3 host-screencap/ACK protocol with explicit screen and stage.
/// This transport cannot certify pixels, TalkBack, or backend behavior.
class ClosureCheckpoint {
  ClosureCheckpoint({required this.run, required this.bridge}) {
    if (!RegExp(r'^closure-[a-z0-9-]+$').hasMatch(run)) {
      throw StateError('Explicit closure run required');
    }
    final identity =
        jsonDecode(File('$bridge/identity.json').readAsStringSync())
            as Map<String, dynamic>;
    if (identity['run'] != run) throw StateError('Wrong host identity');
    apkSha = identity['apk_sha256'] as String;
    sourceSha = identity['source_fingerprint'] as String;
    for (final hash in [apkSha, sourceSha]) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw StateError('Unpinned build/source identity');
      }
    }
  }

  final String run;
  final String bridge;
  late final String apkSha;
  late final String sourceSha;
  int sequence = 0;

  Future<void> capture(
    WidgetTester tester, {
    required String id,
    required String stage,
    required String screenName,
    required Finder screen,
    required List<String> foregroundKeys,
    Map<String, Object?> context = const {},
    Future<Map<String, Object?>> Function()? inspectAfterPump,
  }) async {
    expect(
      screen,
      findsOneWidget,
      reason: 'Correct production screen required',
    );
    for (final key in foregroundKeys) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    await tester.pump(const Duration(milliseconds: 300));
    final inspected = inspectAfterPump == null
        ? context
        : await inspectAfterPump();
    final native = ui.PlatformDispatcher.instance.views.single;
    final request = <String, Object?>{
      'run': run,
      'sequence': ++sequence,
      'id': id,
      'stage': stage,
      'screen': screenName,
      'foreground_keys': foregroundKeys,
      'at': DateTime.now().toUtc().toIso8601String(),
      'apk_sha256': apkSha,
      'source_fingerprint': sourceSha,
      'physical': [native.physicalSize.width, native.physicalSize.height],
      'dpr': native.devicePixelRatio,
      'font_scale': MediaQuery.textScalerOf(tester.element(screen)).scale(1),
      'native_ime_bottom': native.viewInsets.bottom / native.devicePixelRatio,
      'visible_text': find
          .byType(Text)
          .evaluate()
          .map((element) {
            final widget = element.widget as Text;
            return widget.data ?? widget.textSpan?.toPlainText() ?? '';
          })
          .where((text) => text.isNotEmpty)
          .toList(),
      'fixture_boundaries': 'QA_BACKEND_AUTH_MAP_FIXTURES_NOT_LIVE',
    };
    if (inspected.keys.any(request.containsKey)) {
      throw StateError('Checkpoint context cannot replace reserved identity');
    }
    request.addAll(inspected);
    await tester.runAsync(() async {
      final pending = File('$bridge/pending.json');
      if (pending.existsSync()) throw StateError('Outstanding checkpoint');
      final temporary = File('$bridge/pending.tmp');
      await temporary.writeAsString(jsonEncode(request), flush: true);
      await temporary.rename(pending.path);
      final ack = File('$bridge/ack-$sequence.json');
      final clock = Stopwatch()..start();
      while (!ack.existsSync()) {
        if (clock.elapsed > const Duration(seconds: 20)) {
          throw StateError('Host ACK deadline: $id/$stage');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final actual =
          jsonDecode(await ack.readAsString()) as Map<String, dynamic>;
      for (final field in ['run', 'sequence', 'id', 'stage']) {
        if (actual[field] != request[field]) {
          throw StateError('Mismatched ACK $field');
        }
      }
      await pending.delete();
    });
  }
}

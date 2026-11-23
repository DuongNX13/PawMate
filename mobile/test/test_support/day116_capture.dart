import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_test_helpers.dart';

/// Test-only foreground capture; await decoded local assets, not a timed guess.
Future<void> captureDay116(WidgetTester tester, String id) async {
  final output = Platform.environment['D116_SCREENSHOTS'];
  if (output == null || output.isEmpty) return;
  if (!RegExp(r'^[A-Z0-9][A-Za-z0-9-]+$').hasMatch(id)) throw ArgumentError(id);
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    await loadPawMateTestFonts();
    for (final root in ['assets/images', 'assets/icons']) {
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>()) {
        final asset = file.path.replaceAll(r'\', '/');
        if (!RegExp(r'\.(png|jpg|jpeg|webp)$').hasMatch(asset)) continue;
        Object? failure;
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (error, _) => failure = error,
        );
        if (failure != null) {
          throw StateError('Asset decode failed: $asset: $failure');
        }
      }
    }
  });
  // Pump resolved streams/font metrics without waiting for loading animations.
  await tester.pump();
  final semantics = tester.ensureSemantics();
  await tester.pump();
  expectNoFlutterOverflow(tester);
  String? tree;
  void visitPipeline(PipelineOwner owner) {
    tree ??= owner.semanticsOwner?.rootSemanticsNode?.toStringDeep();
    owner.visitChildren(visitPipeline);
  }

  visitPipeline(tester.binding.rootPipelineOwner);
  final semanticTree = tree;
  if (semanticTree == null) throw StateError('No semantics root');
  final texts = <Map<String, Object?>>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final box = element.findRenderObject();
    Rect? bounds;
    if (box is RenderBox && box.hasSize) {
      bounds = box.localToGlobal(Offset.zero) & box.size;
    }
    texts.add({
      'text': widget.data ?? widget.textSpan?.toPlainText(),
      'bounds': bounds == null
          ? null
          : [bounds.left, bounds.top, bounds.right, bounds.bottom],
    });
  }
  await tester.runAsync(() async {
    final image = await captureImage(context);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encoding failed');
    final dir = Directory(output)..createSync(recursive: true);
    for (final suffix in ['png', 'json', 'semantics.txt']) {
      if (File('${dir.path}/$id.$suffix').existsSync()) {
        throw StateError('Capture exists: $id.$suffix');
      }
    }
    final png = File('${dir.path}/$id.png');
    await png.writeAsBytes(data.buffer.asUint8List(), flush: true);
    await File(
      '${dir.path}/$id.semantics.txt',
    ).writeAsString(semanticTree, flush: true);
    await File('${dir.path}/$id.json').writeAsString(
      jsonEncode({
        'id': id,
        'test': tester.testDescription,
        'width': image.width,
        'height': image.height,
        'bytes': png.lengthSync(),
        'capture_strategy': 'app-root-overlay-composite',
        'asset_readiness': 'precache-all-declared-local-images',
        'texts': texts,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'kind': 'widget-production-owner-declared-doubles-not-native',
      }),
      flush: true,
    );
    image.dispose();
  });
  semantics.dispose();
}

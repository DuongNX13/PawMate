import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_helpers.dart';
import 'day116_capture.dart';

/// Opt-in, test-only capture of a real production owner widget, not a state
/// gallery. Fake API/clock inputs remain declared in the owning testcase.
Future<void> captureDay114(WidgetTester tester, String id) async {
  if (Platform.environment['D116_SCREENSHOTS']?.isNotEmpty ?? false) {
    await captureDay116(tester, id);
    return;
  }
  final output = Platform.environment['D114_SCREENSHOTS'];
  if (output == null || output.isEmpty) return;
  if (!RegExp(r'^ST-\d{2}(?:-[a-z0-9-]+)?$').hasMatch(id)) {
    throw ArgumentError.value(id, 'id');
  }
  await tester.runAsync(loadPawMateTestFonts);
  await tester.pump(const Duration(milliseconds: 100));
  expectNoFlutterOverflow(tester);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final boundaries = tester.allRenderObjects.whereType<RenderRepaintBoundary>();
  final boundary = boundaries.firstWhere(
    (node) => node.hasSize && node.size == size && !node.debugNeedsPaint,
    orElse: () => throw StateError('No painted full-viewport owner boundary'),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encoding failed');
    final directory = Directory(output)..createSync(recursive: true);
    final file = File('${directory.path}/$id.png');
    if (file.existsSync()) throw StateError('Capture already exists: $id');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    await File('${directory.path}/$id.json').writeAsString(
      jsonEncode({
        'id': id,
        'kind': 'production-owner-widget-with-declared-test-doubles',
        'viewport': {'width': image.width, 'height': image.height},
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'bytes': file.lengthSync(),
        'test': tester.testDescription,
      }),
      flush: true,
    );
    image.dispose();
  });
}

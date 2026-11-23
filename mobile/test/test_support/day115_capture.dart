import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_test_helpers.dart';
import 'day116_capture.dart';

Future<ui.Image> captureDay115Viewport(WidgetTester tester) async {
  // Capture the app ancestor enclosing Navigator's Overlay. A route-sized
  // repaint boundary can match the viewport while omitting a foreground sheet.
  return captureImage(tester.element(find.byType(MaterialApp)));
}

Future<void> captureDay115(WidgetTester tester, String id) async {
  if (Platform.environment['D116_SCREENSHOTS']?.isNotEmpty ?? false) {
    await captureDay116(tester, id);
    return;
  }
  final output = Platform.environment['D115_SCREENSHOTS'];
  if (output == null || output.isEmpty) return;
  if (!RegExp(r'^[A-Z0-9][A-Za-z0-9-]+$').hasMatch(id)) throw ArgumentError(id);
  await tester.runAsync(loadPawMateTestFonts);
  await tester.pump(const Duration(milliseconds: 100));
  expectNoFlutterOverflow(tester);
  await tester.runAsync(() async {
    final image = await captureDay115Viewport(tester);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encoding failed');
    final directory = Directory(output)..createSync(recursive: true);
    final file = File('${directory.path}/$id.png');
    if (file.existsSync()) throw StateError('Capture exists: $id');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    await File('${directory.path}/$id.json').writeAsString(
      jsonEncode({
        'id': id,
        'test': tester.testDescription,
        'kind': 'production-owner-widget-with-declared-test-doubles',
        'capture_strategy': 'app-root-overlay-composite',
        'width': image.width,
        'height': image.height,
        'bytes': file.lengthSync(),
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    image.dispose();
  });
}

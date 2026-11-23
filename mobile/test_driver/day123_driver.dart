import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

// Writes Day 123 iOS screenshots and the report into a fresh directory.
Future<void> main() async {
  final out = Platform.environment['D123_CAPTURE_DIR'];
  if (out == null) throw StateError('Explicit fresh D123_CAPTURE_DIR required');
  final directory = Directory(out);
  if (directory.existsSync()) throw StateError('Capture directory exists');
  directory.createSync(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (!RegExp(r'^D123-[a-z0-9-]+$').hasMatch(name)) {
            throw StateError('Unexpected capture name');
          }
          File('$out/$name.png').writeAsBytesSync(bytes, flush: true);
          return bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80;
        },
    responseDataCallback: (data) async {
      await File('$out/response.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    },
  );
}

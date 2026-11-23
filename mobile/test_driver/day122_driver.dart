import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final out = Platform.environment['D122_CAPTURE_DIR'];
  if (out == null) throw StateError('Explicit fresh D122_CAPTURE_DIR required');
  final directory = Directory(out);
  if (directory.existsSync()) {
    throw StateError('Immutable capture directory exists');
  }
  directory.createSync(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (!RegExp(r'^D122-[a-z0-9-]+$').hasMatch(name)) {
            throw StateError('Unexpected capture name');
          }
          final f = File('$out/$name.png');
          if (f.existsSync()) throw StateError('Capture exists');
          f.writeAsBytesSync(bytes, flush: true);
          return bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80;
        },
    responseDataCallback: (data) async {
      final f = File('$out/response.json');
      if (f.existsSync()) throw StateError('Response exists');
      await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    },
  );
}

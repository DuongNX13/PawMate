import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Platform.environment['D122_HOST_OUTPUT'];
  if (output == null) throw StateError('Explicit host output required');
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final file = File('$output/response.json');
      if (file.existsSync()) throw StateError('Immutable response exists');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    },
  );
}

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDirectory = Directory(
    Platform.environment['PAWMATE_SCREENSHOT_DIR'] ??
        'build/integration_screenshots',
  );
  outputDirectory.createSync(recursive: true);

  await integrationDriver(
    onScreenshot:
        (
          String screenshotName,
          List<int> screenshotBytes, [
          Map<String, Object?>? args,
        ]) async {
          final image = File('${outputDirectory.path}/$screenshotName.png');
          image.writeAsBytesSync(screenshotBytes);
          return image.lengthSync() > 0;
        },
  );
}

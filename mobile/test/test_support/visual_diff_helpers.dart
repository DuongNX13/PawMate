import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

class PawMateVisualDiffResult {
  const PawMateVisualDiffResult({
    required this.expectedWidth,
    required this.expectedHeight,
    required this.actualWidth,
    required this.actualHeight,
    required this.differentPixels,
    required this.totalPixels,
    required this.maxChannelDelta,
  });

  final int expectedWidth;
  final int expectedHeight;
  final int actualWidth;
  final int actualHeight;
  final int differentPixels;
  final int totalPixels;
  final int maxChannelDelta;

  bool get dimensionsMatch =>
      expectedWidth == actualWidth && expectedHeight == actualHeight;

  double get diffPercent =>
      totalPixels == 0 ? 100 : (differentPixels / totalPixels) * 100;
}

Future<PawMateVisualDiffResult> comparePawMatePng(
  Uint8List expected,
  Uint8List actual, {
  int channelTolerance = 0,
}) async {
  final expectedImage = await _decode(expected);
  final actualImage = await _decode(actual);
  try {
    if (expectedImage.width != actualImage.width ||
        expectedImage.height != actualImage.height) {
      return PawMateVisualDiffResult(
        expectedWidth: expectedImage.width,
        expectedHeight: expectedImage.height,
        actualWidth: actualImage.width,
        actualHeight: actualImage.height,
        differentPixels: expectedImage.width * expectedImage.height,
        totalPixels: expectedImage.width * expectedImage.height,
        maxChannelDelta: 255,
      );
    }

    final expectedBytes = await _rgba(expectedImage);
    final actualBytes = await _rgba(actualImage);
    var differentPixels = 0;
    var maxChannelDelta = 0;
    for (var offset = 0; offset < expectedBytes.length; offset += 4) {
      var pixelDiffers = false;
      for (var channel = 0; channel < 4; channel++) {
        final delta =
            (expectedBytes[offset + channel] - actualBytes[offset + channel])
                .abs();
        if (delta > maxChannelDelta) maxChannelDelta = delta;
        if (delta > channelTolerance) pixelDiffers = true;
      }
      if (pixelDiffers) differentPixels++;
    }

    return PawMateVisualDiffResult(
      expectedWidth: expectedImage.width,
      expectedHeight: expectedImage.height,
      actualWidth: actualImage.width,
      actualHeight: actualImage.height,
      differentPixels: differentPixels,
      totalPixels: expectedImage.width * expectedImage.height,
      maxChannelDelta: maxChannelDelta,
    );
  } finally {
    expectedImage.dispose();
    actualImage.dispose();
  }
}

void enforcePawMateVisualTolerance(
  PawMateVisualDiffResult result, {
  required double maxDiffPercent,
}) {
  if (!result.dimensionsMatch || result.diffPercent > maxDiffPercent) {
    throw TestFailure(
      'Visual diff ${result.diffPercent.toStringAsFixed(4)}% exceeds '
      '$maxDiffPercent%; expected '
      '${result.expectedWidth}x${result.expectedHeight}, actual '
      '${result.actualWidth}x${result.actualHeight}, max channel delta '
      '${result.maxChannelDelta}.',
    );
  }
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) {
    throw StateError('Unable to decode image pixels.');
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

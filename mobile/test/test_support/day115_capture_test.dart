import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'day115_capture.dart';
import 'ui_test_helpers.dart';

void main() {
  testWidgets(
    'D115 capture includes visible modal instead of underlying route',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      late BuildContext owner;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            bottomSheetTheme: const BottomSheetThemeData(
              surfaceTintColor: Colors.transparent,
            ),
          ),
          home: Builder(
            builder: (context) {
              owner = context;
              return const Scaffold(
                body: ColoredBox(color: Colors.red, child: SizedBox.expand()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(
        context: owner,
        backgroundColor: const Color(0xff0000ff),
        builder: (_) => const SizedBox(height: 240, width: double.infinity),
      );
      await tester.pumpAndSettle();
      final image = await tester.runAsync(() => captureDay115Viewport(tester));
      expect(image, isNotNull);
      expect(image!.width, 390);
      expect(image.height, 844);
      final pixels = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final offset = (750 * image.width + 195) * 4;
      expect(
        pixels!.getUint8(offset),
        0,
        reason: 'foreground sheet must be blue, not red route',
      );
      expect(pixels.getUint8(offset + 2), 255);
      image.dispose();
    },
  );
}

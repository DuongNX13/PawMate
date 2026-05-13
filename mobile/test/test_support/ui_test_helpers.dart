import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setTestViewport(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double keyboardInset = 0,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
}

Future<void> setKeyboardInset(
  WidgetTester tester, {
  double bottom = 300,
}) async {
  tester.view.viewInsets = FakeViewPadding(bottom: bottom);
  await tester.pump();
}

TransitionBuilder testTextScaleBuilder(double scale) {
  return (context, child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: child ?? const SizedBox.shrink(),
    );
  };
}

void expectNoFlutterOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

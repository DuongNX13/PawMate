import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadPawMateTestFonts() async {
  final loader = FontLoader('BeVietnamPro');
  for (final asset in const [
    'assets/fonts/BeVietnamPro-Regular.ttf',
    'assets/fonts/BeVietnamPro-Medium.ttf',
    'assets/fonts/BeVietnamPro-SemiBold.ttf',
    'assets/fonts/BeVietnamPro-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
  await _loadMaterialIconsFont();
}

Future<void> _loadMaterialIconsFont() async {
  final executable = File(Platform.resolvedExecutable);
  final flutterRoot = executable.parent.parent.parent.parent.parent;
  final candidates = [
    File(
      '${flutterRoot.path}${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts${Platform.pathSeparator}materialicons-regular.otf',
    ),
    File(
      'D:/mp/tools/flutter/bin/cache/artifacts/material_fonts/'
      'materialicons-regular.otf',
    ),
    File(
      'D:/My Playground/tools/flutter/bin/cache/artifacts/material_fonts/'
      'materialicons-regular.otf',
    ),
  ];
  final fontFile = candidates.where((file) => file.existsSync()).firstOrNull;
  if (fontFile == null) {
    throw StateError(
      'MaterialIcons font not found. Checked: '
      '${candidates.map((file) => file.path).join(', ')}',
    );
  }
  final bytes = await fontFile.readAsBytes();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> setTestViewport(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double keyboardInset = 0,
}) async {
  // Configure the FlutterView itself so both render constraints and
  // MediaQuery observe the same mobile viewport. setSurfaceSize() alone only
  // changes the render surface on recent Flutter versions and can leave
  // MediaQuery reporting the default 2400px-wide physical test view.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(() {
    tester.view.resetPhysicalSize();
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
  final exception = tester.takeException();
  final diagnostic = exception is FlutterError
      ? exception.toStringDeep()
      : exception?.toString();
  final flexDetails = exception == null
      ? const <String>[]
      : _describeOverflowingFlexes(tester);
  expect(
    exception,
    isNull,
    reason: [
      ?diagnostic,
      if (flexDetails.isNotEmpty)
        'Overflow candidates:\n${flexDetails.join('\n')}',
    ].join('\n'),
  );
}

List<String> _describeOverflowingFlexes(WidgetTester tester) {
  final results = <String>[];
  for (final element in tester.allElements) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderFlex || !renderObject.hasSize) {
      continue;
    }

    RenderBox? child = renderObject.firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      final childEnd = renderObject.direction == Axis.horizontal
          ? data.offset.dx + child.size.width
          : data.offset.dy + child.size.height;
      final available = renderObject.direction == Axis.horizontal
          ? renderObject.size.width
          : renderObject.size.height;
      if (childEnd > available + 0.5) {
        final labels = <String>[];
        void collectLabels(Element current) {
          final widget = current.widget;
          if (widget is Text && widget.data != null && labels.length < 4) {
            labels.add(widget.data!);
          }
          if (labels.length < 4) {
            current.visitChildElements(collectLabels);
          }
        }

        collectLabels(element);
        final ancestors = <String>[];
        element.visitAncestorElements((ancestor) {
          if (ancestors.length >= 5) {
            return false;
          }
          ancestors.add(ancestor.widget.runtimeType.toString());
          return true;
        });
        results.add(
          '${element.widget.runtimeType} ${renderObject.direction.name}: '
          'childEnd=${childEnd.toStringAsFixed(1)}, '
          'available=${available.toStringAsFixed(1)}, '
          'labels=${labels.join(' | ')}, '
          'ancestors=${ancestors.join(' > ')}, '
          'creator=${renderObject.debugCreator}',
        );
        break;
      }
      child = renderObject.childAfter(child);
    }
  }
  return results;
}

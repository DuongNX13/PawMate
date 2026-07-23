import 'package:flutter_test/flutter_test.dart';

import 'ui_test_helpers.dart';

void main() {
  group('inferFlutterSdkRoot', () {
    test('finds the Codemagic macOS Flutter root without duplicating bin', () {
      expect(
        inferFlutterSdkRoot(
          '/Users/builder/programs/flutter/bin/cache/dart-sdk/bin/dart',
        ),
        '/Users/builder/programs/flutter',
      );
    });

    test('finds a Windows Flutter root with spaces', () {
      expect(
        inferFlutterSdkRoot(
          r'D:\My Playground\tools\flutter\bin\cache\dart-sdk\bin\dart.exe',
        ),
        'D:/My Playground/tools/flutter',
      );
    });

    test('returns null for an executable outside a Flutter SDK', () {
      expect(inferFlutterSdkRoot('/usr/local/bin/dart'), isNull);
    });
  });
}

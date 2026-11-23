import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/day122_fixture_config.dart';

void main() {
  Map<String, dynamic> value(String family, int width, int height) => {
    'run': 'closure-r27-${family.toLowerCase().replaceAll('-', '')}-$width',
    'family': family, 'width': width, 'height': height,
  };
  test('Exactly seven independent corrected-fixture identities', () {
    final ids = <String>{};
    for (final row in Day122FixtureConfig.allowed) {
      final parts = row.split(':');
      final c = Day122FixtureConfig.fromJson(value(
        parts[0], int.parse(parts[1]), int.parse(parts[2]),
      ));
      ids.add(c.id);
    }
    expect(ids.length, 7);
  });
  test('Reject arbitrary families, non-endpoint edits and wrong heights', () {
    for (final json in [value('P1-03', 360, 800), value('DT-02', 390, 844),
      value('DT-08', 360, 844), value('DT-01', 320, 568)]) {
      expect(() => Day122FixtureConfig.fromJson(json), throwsStateError);
    }
  });
  test('Run identity must match family and viewport', () {
    final json = value('DT-01', 360, 800);
    json['run'] = 'closure-r27-dt08-360';
    expect(() => Day122FixtureConfig.fromJson(json), throwsStateError);
  });
}

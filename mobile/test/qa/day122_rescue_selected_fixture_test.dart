import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/day122_rescue_selected_actions_app.dart';
import '../features/rescue/rescue_test_fixtures.dart';

void main() {
  test('selected marker and route resolve to the same complete case', () async {
    final fixture = RescueSelectedActionFixture();
    final source = const bool.fromEnvironment('D122_LEGACY_RESCUE_DETAIL')
        ? FakeRescueSource()
        : fixture;
    final selected = fixture.expected;
    final detail = await source.getCase(selected.caseId);
    expect(detail.caseId, selected.caseId);
    expect(detail.petName, selected.petName);
    expect(detail.identifyingFeatures, rescueDetailMarker);
    await expectLater(
      source.getCase('22222222-2222-4222-8222-222222222222'),
      throwsStateError,
    );
  });
}

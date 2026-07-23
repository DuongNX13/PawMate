import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/router/app_feature_availability.dart';

void main() {
  test('Day 40 feature profile preserves fail-closed defaults', () {
    const profile = String.fromEnvironment('PAWMATE_FEATURE_PROFILE');
    const availability = AppFeatureAvailability.fromEnvironment();

    if (profile == 'day40-rescue-create-staging') {
      expect(availability.rescueBrowse, isTrue);
      expect(availability.rescueCreate, isTrue);
    } else {
      expect(availability.rescueBrowse, isFalse);
      expect(availability.rescueCreate, isFalse);
    }
  });
}

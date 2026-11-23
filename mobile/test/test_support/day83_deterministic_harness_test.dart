import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day83_deterministic_harness.dart';
import 'ui_test_helpers.dart';

void main() {
  test('fake services keep clock, network, location and map deterministic', () {
    const services = Day83DeterministicServices();

    expect(services.now(), day83FixedNow);
    expect(day83Timezone, 'Asia/Bangkok');
    expect(services.location().latitude, 10.7769);
    expect(services.location().longitude, 106.7009);
    expect(services.networkResponse('/pets'), {
      'endpoint': '/pets',
      'status': 200,
      'seed': day83Seed,
    });
    expect(services.mapMarkerId(3), 'day83-marker-3');
  });

  testWidgets('harness locks vi_VN, 24-hour time and disabled animation', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    late MediaQueryData media;
    late Locale locale;
    late Day83DeterministicServices services;

    await tester.pumpWidget(
      buildDay83GoldenHarness(
        home: Builder(
          builder: (context) {
            media = MediaQuery.of(context);
            locale = Localizations.localeOf(context);
            services = Day83GoldenEnvironment.of(context).services;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(locale, day83Locale);
    expect(media.alwaysUse24HourFormat, isTrue);
    expect(media.disableAnimations, isTrue);
    expect(media.accessibleNavigation, isTrue);
    expect(services.now(), day83FixedNow);
  });
}

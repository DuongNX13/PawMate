import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';

const day83Locale = Locale('vi', 'VN');
const day83Timezone = 'Asia/Bangkok';
const day83Seed = 830083;
// Keep the logical wall-clock fields independent from the host timezone. The
// accompanying [day83Timezone] identifies how the fixture must be interpreted.
final day83FixedNow = DateTime.utc(2026, 8, 27, 9, 41);

@immutable
class Day83FakeLocation {
  const Day83FakeLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class Day83DeterministicServices {
  const Day83DeterministicServices();

  DateTime now() => day83FixedNow;

  Day83FakeLocation location() =>
      const Day83FakeLocation(latitude: 10.7769, longitude: 106.7009);

  Map<String, Object> networkResponse(String endpoint) => {
    'endpoint': endpoint,
    'status': 200,
    'seed': day83Seed,
  };

  String mapMarkerId(int index) => 'day83-marker-$index';
}

class Day83GoldenEnvironment extends InheritedWidget {
  const Day83GoldenEnvironment({
    super.key,
    required this.services,
    required super.child,
  });

  final Day83DeterministicServices services;

  static Day83GoldenEnvironment of(BuildContext context) {
    final environment = context
        .dependOnInheritedWidgetOfExactType<Day83GoldenEnvironment>();
    assert(environment != null, 'Day83GoldenEnvironment is missing.');
    return environment!;
  }

  @override
  bool updateShouldNotify(Day83GoldenEnvironment oldWidget) => false;
}

Widget buildDay83GoldenHarness({
  required Widget home,
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
}) {
  return Day83GoldenEnvironment(
    services: const Day83DeterministicServices(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(platform: platform),
      locale: day83Locale,
      supportedLocales: const [day83Locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(textScale),
            alwaysUse24HourFormat: true,
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    ),
  );
}

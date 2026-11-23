/// Host-owned configuration for seven previously misbound QA fixtures only.
/// No route, asset path, or product action can be supplied by the host.
class Day122FixtureConfig {
  Day122FixtureConfig.fromJson(Map<String, dynamic> json)
    : run = json['run'] as String,
      family = json['family'] as String,
      width = json['width'] as int,
      height = json['height'] as int {
    if (!RegExp(r'^closure-r27-dt(?:01|02|08)-(360|390|430)$').hasMatch(run) ||
        !allowed.contains('$family:$width:$height') ||
        run != 'closure-r27-${family.toLowerCase().replaceAll('-', '')}-$width') {
      throw StateError('Explicit allowlisted fixture/viewport required');
    }
  }

  static const allowed = {
    'DT-01:360:800', 'DT-01:390:844', 'DT-01:430:932',
    'DT-02:360:800', 'DT-02:430:932',
    'DT-08:360:800', 'DT-08:430:932',
  };
  final String run;
  final String family;
  final int width;
  final int height;
  String get id => 'ANDROID-$family-${width}x$height';
}

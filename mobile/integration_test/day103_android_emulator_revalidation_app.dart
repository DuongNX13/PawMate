import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_location_picker_sheet.dart';

void main() {
  runApp(const ProviderScope(child: Day103AndroidRevalidationApp()));
}

class Day103AndroidRevalidationApp extends StatelessWidget {
  const Day103AndroidRevalidationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawMate Day 103 Android Revalidation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _RevalidationLauncher(),
    );
  }
}

class _RevalidationLauncher extends StatefulWidget {
  const _RevalidationLauncher();

  @override
  State<_RevalidationLauncher> createState() => _RevalidationLauncherState();
}

class _RevalidationLauncherState extends State<_RevalidationLauncher> {
  RescueDraftLocation? _selected;
  final List<String> _probeResults = [];

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('D103_GPS_DIAGNOSTIC')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _probeGps());
    }
  }

  // Test-only diagnostic: never overrides the production picker service.
  Future<void> _probeGps() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    for (final mode in [
      'production-cold',
      'fused-high',
      'manager-high',
      'production-warm',
    ]) {
      final timer = Stopwatch()..start();
      final row = <String, Object?>{
        'mode': mode,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      };
      debugPrint('D103_PROBE_START ${jsonEncode(row)}');
      try {
        if (mode.startsWith('production')) {
          final p = await GeolocatorRescueLocationService()
              .resolveCurrentLocation();
          row.addAll({'latitude': p.latitude, 'longitude': p.longitude});
        } else {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: mode == 'manager-high',
              timeLimit: const Duration(seconds: 8),
            ),
          );
          row.addAll({
            'latitude': p.latitude,
            'longitude': p.longitude,
            'accuracy': p.accuracy,
            'mocked': p.isMocked,
          });
        }
        row['outcome'] = 'POSITION';
      } catch (error) {
        row.addAll({'outcome': 'ERROR', 'error': error.toString()});
      }
      row['elapsed_ms'] = timer.elapsedMilliseconds;
      debugPrint('D103_PROBE_RESULT ${jsonEncode(row)}');
      if (mounted) setState(() => _probeResults.add(jsonEncode(row)));
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    debugPrint('D103_PROBE_COMPLETE');
  }

  Future<void> _openPicker({bool forceMapUnavailable = false}) async {
    final selected = await showModalBottomSheet<RescueDraftLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProviderScope(
        overrides: [
          rescueLocationServiceProvider.overrideWithValue(
            _ObservedLocationService(),
          ),
          if (forceMapUnavailable)
            rescuePickerMapBuilderProvider.overrideWithValue(
              (selected, onSelect, onUnavailable) =>
                  _UnavailableMap(onUnavailable: onUnavailable),
            ),
        ],
        child: RescueLocationPickerSheet(initialLocation: _selected),
      ),
    );
    if (!mounted || selected == null) return;
    debugPrint(
      'D103_PICKER_CONFIRMED ${jsonEncode({'latitude': selected.latitude, 'longitude': selected.longitude})}',
    );
    setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Day 103 Android QA')),
      body: const bool.fromEnvironment('D103_GPS_DIAGNOSTIC')
          ? SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('TEST ONLY: real GPS provider diagnostics'),
                  ..._probeResults.map((row) => Text(row)),
                ],
              ),
            )
          : SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          'Rescue Location Picker — system revalidation',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        key: const Key('day103-android-open-picker'),
                        onPressed: () => _openPicker(),
                        child: const Text('Mở bộ chọn vị trí'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const Key(
                          'day103-android-open-unavailable-picker',
                        ),
                        onPressed: () => _openPicker(forceMapUnavailable: true),
                        child: const Text('Mở trạng thái bản đồ lỗi'),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        key: const Key('day103-android-result'),
                        liveRegion: true,
                        label: selected == null
                            ? 'Chưa xác nhận vị trí'
                            : 'Đã xác nhận vị trí thử nghiệm',
                        child: Text(
                          selected == null
                              ? 'RESULT: NONE'
                              : 'RESULT: CONFIRMED\n'
                                    'LAT: ${selected.latitude.toStringAsFixed(6)}\n'
                                    'LON: ${selected.longitude.toStringAsFixed(6)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _TalkBackCanary(),
                          ),
                        ),
                        child: const Text('Kiểm tra TalkBack'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Observability only: delegates unchanged to the actual production service.
class _ObservedLocationService implements RescueLocationService {
  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    final timer = Stopwatch()..start();
    final gpsTimer = Stopwatch();
    final observed = _ObservedRequest(request, (phase) {
      if (phase == RescueLocationPhase.acquiringPosition) gpsTimer.start();
      debugPrint(
        'D103_LOCATION_PHASE ${jsonEncode({'phase': phase.name, 'elapsed_ms': timer.elapsedMilliseconds})}',
      );
    });
    debugPrint('D103_PICKER_GPS_START');
    try {
      final point = await GeolocatorRescueLocationService()
          .resolveCurrentLocation(request: observed);
      debugPrint(
        'D103_PICKER_GPS_RESULT ${jsonEncode({'latitude': point.latitude, 'longitude': point.longitude, 'elapsed_ms': timer.elapsedMilliseconds, 'acquisition_ms': gpsTimer.elapsedMilliseconds})}',
      );
      return point;
    } catch (error) {
      debugPrint(
        'D103_PICKER_GPS_ERROR ${jsonEncode({'error': error.toString(), 'elapsed_ms': timer.elapsedMilliseconds})}',
      );
      rethrow;
    }
  }
}

class _ObservedRequest extends RescueLocationRequest {
  _ObservedRequest(this.source, ValueChanged<RescueLocationPhase> observer)
    : super(id: source?.id ?? -1, onPhase: observer);
  final RescueLocationRequest? source;
  @override
  void checkActive() {
    source?.checkActive();
    super.checkActive();
  }
}

class _TalkBackCanary extends StatefulWidget {
  const _TalkBackCanary();
  @override
  State<_TalkBackCanary> createState() => _TalkBackCanaryState();
}

class _TalkBackCanaryState extends State<_TalkBackCanary> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TalkBack canary')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final label in ['Canary một', 'Canary hai', 'Canary ba'])
          ElevatedButton(
            onPressed: () {
              setState(() => count++);
              debugPrint(
                'D103_CANARY_ACTION ${jsonEncode({'label': label, 'count': count})}',
              );
            },
            child: Text(label),
          ),
        Semantics(liveRegion: true, child: Text('CANARY COUNT: $count')),
      ],
    ),
  );
}

class _UnavailableMap extends StatefulWidget {
  const _UnavailableMap({required this.onUnavailable});

  final VoidCallback onUnavailable;

  @override
  State<_UnavailableMap> createState() => _UnavailableMapState();
}

class _UnavailableMapState extends State<_UnavailableMap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnavailable();
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF3F4F4),
    child: Center(child: Text('QA map unavailable trigger')),
  );
}

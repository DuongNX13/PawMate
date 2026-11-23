import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_location_picker_sheet.dart';

// QA target only: no production router, flags, auth, submission or fake map.
void main() => runApp(const ProviderScope(child: Day122PermissionQaApp()));

class Day122PermissionQaApp extends StatelessWidget {
  const Day122PermissionQaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const _Launcher(),
  );
}

class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  RescueDraftLocation? _confirmed;

  Future<void> _open() async {
    // A new sheet starts empty on every open, including after manual fallback.
    final result = await showModalBottomSheet<RescueDraftLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProviderScope(
        overrides: [
          rescueLocationServiceProvider.overrideWithValue(_ObservedLocation()),
        ],
        child: const RescueLocationPickerSheet(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _confirmed = result);
    _record('CONFIRMED', {
      'latitude': result.latitude,
      'longitude': result.longitude,
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Day 122 Android Permission QA')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _open,
            child: const Text('Mở bộ chọn vị trí'),
          ),
          Text(switch (_confirmed) {
            final point? =>
              'RESULT: CONFIRMED LAT: ${point.latitude} '
                  'LON: ${point.longitude}',
            null => 'RESULT: NONE',
          }),
        ],
      ),
    ),
  );
}

void _record(String event, Map<String, Object?> data) =>
    debugPrint('D122_PERMISSION_$event ${jsonEncode(data)}');

// Only adds observability; permission, GPS accuracy and timeout are production.
class _ObservedLocation implements RescueLocationService {
  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    final acquisition = Stopwatch();
    final observed = _ObservedRequest(request, (phase) {
      if (phase == RescueLocationPhase.acquiringPosition) acquisition.start();
      _record('PHASE', {'request': request?.id, 'phase': phase.name});
    });
    try {
      final point = await GeolocatorRescueLocationService()
          .resolveCurrentLocation(request: observed);
      _record('GPS', {
        'request': request?.id,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'acquisition_ms': acquisition.elapsedMilliseconds,
      });
      return point;
    } on RescueLocationException catch (error) {
      _record('ERROR', {'request': request?.id, 'kind': error.type.name});
      rethrow;
    }
  }
}

class _ObservedRequest extends RescueLocationRequest {
  _ObservedRequest(this.original, ValueChanged<RescueLocationPhase> observe)
    : super(id: original?.id ?? -1, onPhase: observe);

  final RescueLocationRequest? original;

  @override
  void checkActive() {
    original?.checkActive();
    super.checkActive();
  }

  @override
  void enter(RescueLocationPhase phase) {
    original?.enter(phase);
    super.enter(phase);
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';

class _Platform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0;
  int positionCalls = 0;
  LocationSettings? settings;
  Object? error;
  Completer<LocationPermission>? permissionPending;
  Completer<Position>? positionPending;
  Duration? positionDelay;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    if (permissionPending != null) return permissionPending!.future;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settings = locationSettings;
    positionCalls++;
    if (error != null) throw error!;
    if (positionPending != null) return positionPending!.future;
    if (positionDelay != null) {
      // Contract fake: model the platform deadline supplied by production.
      // Native timing remains covered separately by emulator evidence.
      await Future<void>.delayed(
        positionDelay!,
      ).timeout(locationSettings!.timeLimit!);
    }
    return Position(
      latitude: 10.7769,
      longitude: 106.7009,
      timestamp: DateTime.utc(2026, 9, 7),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  late _Platform platform;
  late GeolocatorRescueLocationService service;
  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = _Platform();
    GeolocatorPlatform.instance = platform;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    service = GeolocatorRescueLocationService();
  });
  tearDown(() {
    GeolocatorPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'Android cold one-shot requests high accuracy without warming call',
    () async {
      final result = await service.resolveCurrentLocation();
      expect(platform.settings?.accuracy, LocationAccuracy.high);
      expect(platform.settings?.timeLimit, const Duration(seconds: 8));
      expect(platform.positionCalls, 1);
      expect(result.latitude, 10.7769);
      expect(result.longitude, 106.7009);
    },
  );
  test(
    'permission cancellation prevents a late grant from starting GPS',
    () async {
      platform.permission = LocationPermission.denied;
      platform.permissionPending = Completer<LocationPermission>();
      final phases = <RescueLocationPhase>[];
      final request = RescueLocationRequest(id: 1, onPhase: phases.add);
      final future = service.resolveCurrentLocation(request: request);
      final assertion = expectLater(
        future,
        throwsA(isA<RescueLocationCancelled>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(phases.last, RescueLocationPhase.awaitingPermission);
      request.cancel();
      platform.permissionPending!.complete(LocationPermission.whileInUse);
      await assertion;
      expect(platform.positionCalls, 0);
    },
  );
  test('concurrent permission requests share one Android prompt', () async {
    platform.permission = LocationPermission.denied;
    platform.permissionPending = Completer<LocationPermission>();
    final first = service.resolveCurrentLocation();
    final second = GeolocatorRescueLocationService().resolveCurrentLocation();
    await Future<void>.delayed(Duration.zero);
    expect(platform.requests, 1);
    platform.permissionPending!.complete(LocationPermission.denied);
    await Future.wait([
      expectLater(first, throwsA(isA<RescueLocationException>())),
      expectLater(second, throwsA(isA<RescueLocationException>())),
    ]);
    expect(platform.positionCalls, 0);
  });
  test('cancelled request never enters platform checks', () async {
    final request = RescueLocationRequest(id: 2)..cancel();
    await expectLater(
      service.resolveCurrentLocation(request: request),
      throwsA(isA<RescueLocationCancelled>()),
    );
    expect(platform.positionCalls, 0);
    expect(platform.requests, 0);
  });
  for (final target in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('$target retains existing medium accuracy and deadline', () async {
      debugDefaultTargetPlatformOverride = target;
      await service.resolveCurrentLocation();
      expect(platform.settings?.accuracy, LocationAccuracy.medium);
      expect(platform.settings?.timeLimit, const Duration(seconds: 8));
    });
  }
  test('disabled service does not request permission or GPS', () async {
    platform.enabled = false;
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(
        isA<RescueLocationException>().having(
          (e) => e.type,
          'type',
          RescueLocationFailureType.serviceDisabled,
        ),
      ),
    );
    expect(platform.requests, 0);
    expect(platform.positionCalls, 0);
  });
  test('fresh grant requests permission once then resolves', () async {
    platform.permission = LocationPermission.denied;
    await service.resolveCurrentLocation();
    expect(platform.requests, 1);
    expect(platform.positionCalls, 1);
  });
  for (final denied in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('$denied returns typed failure without GPS', () async {
      platform.permission = denied;
      platform.requested = denied;
      await expectLater(
        service.resolveCurrentLocation(),
        throwsA(
          isA<RescueLocationException>().having(
            (e) => e.type,
            'type',
            RescueLocationFailureType.permissionDenied,
          ),
        ),
      );
      expect(platform.positionCalls, 0);
      expect(platform.requests, denied == LocationPermission.denied ? 1 : 0);
    });
  }
  test('timeout retains fallback failure type', () async {
    platform.error = TimeoutException('test');
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(
        isA<RescueLocationException>().having(
          (e) => e.type,
          'type',
          RescueLocationFailureType.timeout,
        ),
      ),
    );
  });
  testWidgets('GPS deadline boundary accepts 7999ms after delayed permission', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = null;
    platform.permission = LocationPermission.denied;
    platform.permissionPending = Completer<LocationPermission>();
    platform.positionDelay = const Duration(milliseconds: 7999);
    Object? failure;
    var completed = false;
    final pending = service.resolveCurrentLocation().then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error) {
        failure = error;
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(platform.positionCalls, 0);
    expect(completed, false);
    expect(failure, isNull);
    platform.permissionPending!.complete(LocationPermission.whileInUse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 7998));
    expect(completed, false);
    await tester.pump(const Duration(milliseconds: 1));
    await pending;
    expect(completed, true);
    expect(failure, isNull);
    expect(platform.requests, 1);
  });
  testWidgets('GPS deadline boundary rejects at 8000ms and ignores late fix', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = null;
    platform.positionDelay = const Duration(milliseconds: 8001);
    Object? failure;
    var completed = false;
    final pending = service.resolveCurrentLocation().then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error) {
        failure = error;
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 7999));
    expect(completed, false);
    expect(failure, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      failure,
      isA<RescueLocationException>().having(
        (error) => error.type,
        'type',
        RescueLocationFailureType.timeout,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await pending;
    expect(completed, false);
    expect(platform.positionCalls, 1);
  });
  test('platform error retains unknown failure type', () async {
    platform.error = StateError('test');
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(
        isA<RescueLocationException>().having(
          (e) => e.type,
          'type',
          RescueLocationFailureType.unknown,
        ),
      ),
    );
  });
}

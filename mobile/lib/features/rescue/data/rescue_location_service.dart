import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/rescue_map_models.dart';

final rescueLocationServiceProvider = Provider<RescueLocationService>((ref) {
  return GeolocatorRescueLocationService();
});

enum RescueLocationFailureType {
  permissionDenied,
  serviceDisabled,
  timeout,
  unknown,
}

class RescueLocationException implements Exception {
  const RescueLocationException(this.type, this.message);

  final RescueLocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

abstract interface class RescueLocationService {
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  });
}

enum RescueLocationPhase {
  checkingService,
  awaitingPermission,
  acquiringPosition,
}

/// Logical cancellation only; an already-started native GPS call owns its 8s limit.
class RescueLocationRequest {
  RescueLocationRequest({required this.id, this.onPhase});
  final int id;
  final ValueChanged<RescueLocationPhase>? onPhase;
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void checkActive() {
    if (_cancelled) throw const RescueLocationCancelled();
  }

  void enter(RescueLocationPhase phase) {
    checkActive();
    onPhase?.call(phase);
  }
}

class RescueLocationCancelled implements Exception {
  const RescueLocationCancelled();
}

class GeolocatorRescueLocationService implements RescueLocationService {
  static Future<LocationPermission>? _permissionInFlight;

  Future<LocationPermission> _requestPermission() async {
    final pending = _permissionInFlight ??= Geolocator.requestPermission();
    try {
      return await pending;
    } finally {
      if (identical(_permissionInFlight, pending)) _permissionInFlight = null;
    }
  }

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    request?.enter(RescueLocationPhase.checkingService);
    final enabled = await Geolocator.isLocationServiceEnabled();
    request?.checkActive();
    if (!enabled) {
      throw const RescueLocationException(
        RescueLocationFailureType.serviceDisabled,
        'Thiết bị đang tắt định vị. Bạn vẫn có thể xem danh sách theo thời gian.',
      );
    }

    var permission = await Geolocator.checkPermission();
    request?.checkActive();
    if (permission == LocationPermission.denied) {
      request?.enter(RescueLocationPhase.awaitingPermission);
      permission = await _requestPermission();
      request?.checkActive();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const RescueLocationException(
        RescueLocationFailureType.permissionDenied,
        'Chưa có quyền vị trí. Danh sách công khai vẫn dùng được.',
      );
    }

    try {
      request?.enter(RescueLocationPhase.acquiringPosition);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // Balanced accuracy can wait for a network fix without starting GPS
          // on Android. This explicit one-shot request must work from cold.
          accuracy: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? LocationAccuracy.high
              : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        ),
      );
      request?.checkActive();
      return RescueMapLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on RescueLocationCancelled {
      rethrow;
    } on TimeoutException {
      throw const RescueLocationException(
        RescueLocationFailureType.timeout,
        'Thiết bị phản hồi vị trí quá chậm. Danh sách vẫn dùng được.',
      );
    } catch (_) {
      throw const RescueLocationException(
        RescueLocationFailureType.unknown,
        'Không xác định được vị trí hiện tại. Danh sách vẫn dùng được.',
      );
    }
  }
}

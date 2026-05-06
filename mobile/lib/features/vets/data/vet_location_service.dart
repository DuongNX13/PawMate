import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/vet_map_models.dart';

final vetLocationServiceProvider = Provider<VetLocationService>((ref) {
  return GeolocatorVetLocationService();
});

enum VetLocationFailureType {
  permissionDenied,
  serviceDisabled,
  timeout,
  unknown,
}

class VetLocationException implements Exception {
  const VetLocationException(this.type, this.message);

  final VetLocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

abstract class VetLocationService {
  Future<VetMapLocation> resolveCurrentLocation();
}

class GeolocatorVetLocationService implements VetLocationService {
  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const VetLocationException(
        VetLocationFailureType.serviceDisabled,
        'Thiết bị đang tắt dịch vụ vị trí.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const VetLocationException(
        VetLocationFailureType.permissionDenied,
        'PawMate chưa được cấp quyền truy cập vị trí.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return VetMapLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const VetLocationException(
        VetLocationFailureType.timeout,
        'Thiết bị phản hồi vị trí quá chậm, hãy thử lại.',
      );
    } catch (_) {
      throw const VetLocationException(
        VetLocationFailureType.unknown,
        'Không xác định được vị trí hiện tại.',
      );
    }
  }
}

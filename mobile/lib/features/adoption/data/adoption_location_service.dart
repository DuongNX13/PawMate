import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/adoption_models.dart';

final adoptionLocationSourceProvider = Provider<AdoptionLocationSource>((ref) {
  return GeolocatorAdoptionLocationSource();
});

enum AdoptionLocationFailureType {
  permissionDenied,
  serviceDisabled,
  timeout,
  unknown,
}

class AdoptionLocationException implements Exception {
  const AdoptionLocationException(this.type, this.message);

  final AdoptionLocationFailureType type;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AdoptionLocationSource {
  Future<AdoptionCoordinates> resolveCurrentLocation();
}

class GeolocatorAdoptionLocationSource implements AdoptionLocationSource {
  @override
  Future<AdoptionCoordinates> resolveCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AdoptionLocationException(
        AdoptionLocationFailureType.serviceDisabled,
        'Thiết bị đang tắt định vị. Bạn vẫn có thể xem các bé được gợi ý.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AdoptionLocationException(
        AdoptionLocationFailureType.permissionDenied,
        'Chưa có quyền vị trí. Bạn vẫn có thể xem các bé được gợi ý.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return AdoptionCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const AdoptionLocationException(
        AdoptionLocationFailureType.timeout,
        'Thiết bị phản hồi vị trí quá chậm. Danh sách gợi ý vẫn dùng được.',
      );
    } catch (_) {
      throw const AdoptionLocationException(
        AdoptionLocationFailureType.unknown,
        'Không xác định được vị trí hiện tại. Danh sách gợi ý vẫn dùng được.',
      );
    }
  }
}

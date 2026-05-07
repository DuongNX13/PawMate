import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/vet_models.dart';

Future<void> launchVetCall(BuildContext context, String phone) async {
  final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(scheme: 'tel', path: cleanedPhone);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched) {
    if (!context.mounted) {
      return;
    }
    _showFailure(context, 'Không thể mở ứng dụng gọi điện trên thiết bị này.');
  }
}

Future<void> launchVetDirections(BuildContext context, VetSummary vet) async {
  for (final candidate in _buildDirectionCandidates(vet)) {
    try {
      final launched = await launchUrl(
        candidate,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
    } catch (_) {
      // Try the next provider so directions still work if one app is missing.
    }
  }

  if (!context.mounted) {
    return;
  }
  _showFailure(context, 'Không thể mở chỉ đường từ PawMate.');
}

List<Uri> _buildDirectionCandidates(VetSummary vet) {
  final destination = _locationQueryFor(vet);
  final encodedDestination = Uri.encodeComponent(destination);
  final latLng = vet.latitude != null && vet.longitude != null
      ? '${vet.latitude},${vet.longitude}'
      : null;

  final googleWeb = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$encodedDestination',
  );

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return [
        Uri(scheme: 'maps', queryParameters: {'daddr': destination}),
        if (latLng != null)
          Uri.parse('https://waze.com/ul?ll=$latLng&navigate=yes'),
        googleWeb,
      ];
    case TargetPlatform.android:
      return [
        if (latLng != null)
          Uri(scheme: 'google.navigation', queryParameters: {'q': latLng}),
        googleWeb,
        if (latLng != null)
          Uri.parse('https://waze.com/ul?ll=$latLng&navigate=yes'),
      ];
    default:
      return [
        googleWeb,
        if (latLng != null)
          Uri.parse('https://waze.com/ul?ll=$latLng&navigate=yes'),
      ];
  }
}

String _locationQueryFor(VetSummary vet) {
  if (vet.latitude != null && vet.longitude != null) {
    return '${vet.latitude!},${vet.longitude!}';
  }

  return '${vet.address}, ${vet.district}, ${vet.city}';
}

void _showFailure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

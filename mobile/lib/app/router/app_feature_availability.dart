import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compile-time feature contract for routes that are present before their
/// backend/UI lane is released. Missing values always fail closed.
@immutable
class AppFeatureAvailability {
  const AppFeatureAvailability({
    required this.rescueBrowse,
    required bool rescueCreate,
  }) : rescueCreate = rescueBrowse && rescueCreate;

  const AppFeatureAvailability.fromEnvironment()
    : rescueBrowse = const bool.fromEnvironment(
        'PAWMATE_RESCUE_BROWSE_ENABLED',
        defaultValue: false,
      ),
      rescueCreate =
          const bool.fromEnvironment(
            'PAWMATE_RESCUE_BROWSE_ENABLED',
            defaultValue: false,
          ) &&
          const bool.fromEnvironment(
            'PAWMATE_RESCUE_CREATE_ENABLED',
            defaultValue: false,
          );

  final bool rescueBrowse;
  final bool rescueCreate;
}

final appFeatureAvailabilityProvider = Provider<AppFeatureAvailability>(
  (ref) => const AppFeatureAvailability.fromEnvironment(),
);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../domain/adoption_models.dart';

final adoptionAccessTokenProvider = Provider<Future<String?>>((ref) {
  return ref.watch(authAccessTokenProvider.future);
});

final adoptionSessionRevisionProvider = Provider<int>((ref) {
  return ref.watch(authSessionRevisionProvider);
});

final adoptionClockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc();
});

typedef AdoptionCancelScheduled = void Function();
typedef AdoptionDecisionScheduler =
    AdoptionCancelScheduled Function(
      Duration delay,
      Future<void> Function() action,
    );

final adoptionDecisionSchedulerProvider = Provider<AdoptionDecisionScheduler>((
  ref,
) {
  return (delay, action) {
    final timer = Timer(delay, () {
      unawaited(action());
    });
    return timer.cancel;
  };
});

final adoptionUndoDurationProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 4);
});

typedef AdoptionIdempotencyKeyFactory =
    String Function(
      AdoptionDecision decision,
      String listingId,
      DateTime timestamp,
      int sequence,
    );

final adoptionIdempotencyKeyFactoryProvider =
    Provider<AdoptionIdempotencyKeyFactory>((ref) {
      return (decision, listingId, timestamp, sequence) {
        final safeListingId = listingId.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'),
          '-',
        );
        return 'pawmate-day54-${decision.wireValue}-$safeListingId-'
            '${timestamp.microsecondsSinceEpoch}-$sequence';
      };
    });

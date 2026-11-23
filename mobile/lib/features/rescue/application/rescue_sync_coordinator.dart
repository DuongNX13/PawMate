import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rescue_case_models.dart';
import 'rescue_case_detail_provider.dart';
import 'rescue_home_provider.dart';
import 'rescue_map_provider.dart';

final rescueSyncCoordinatorProvider = Provider<RescueSyncCoordinator>(
  RescueSyncCoordinator.new,
);

/// Keeps the three public Rescue projections coherent after an authoritative
/// write response. The coordinator never fabricates a case: publish and status
/// callers must pass the detail returned by the backend.
class RescueSyncCoordinator {
  RescueSyncCoordinator(this.ref);

  final Ref ref;

  Future<void> synchronizePublished(RescueCaseDetail detail) async {
    ref.read(rescueHomeProvider.notifier).applyPublishedCase(detail);
    ref.invalidate(rescueCaseDetailProvider(detail.caseId));
    final mapSubscription = ref.listen(rescueMapProvider, (_, _) {});
    try {
      await ref.read(rescueMapProvider.notifier).refresh();
    } finally {
      mapSubscription.close();
    }
  }

  void synchronizeStatus(RescueCaseDetail detail) {
    ref.read(rescueHomeProvider.notifier).applyStatusUpdate(detail);
    ref.read(rescueMapProvider.notifier).applyStatusUpdate(detail);
    ref.invalidate(rescueCaseDetailProvider(detail.caseId));
  }
}

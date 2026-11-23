import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rescue_api.dart';
import '../domain/rescue_case_models.dart';

final rescueCaseDetailProvider = FutureProvider.autoDispose
    .family<RescueCaseDetail, String>(
      (ref, caseId) {
        return ref.watch(rescueApiProvider).getCase(caseId);
      },
      retry: (retryCount, error) {
        if (error is RescueApiException &&
            (error.statusCode == 404 ||
                error.code == 'RESCUE_CASE_NOT_FOUND')) {
          return null;
        }
        return ProviderContainer.defaultRetry(retryCount, error);
      },
    );

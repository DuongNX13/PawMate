import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/vet_api.dart';
import '../domain/vet_models.dart';

final vetSearchProvider =
    FutureProvider.family<VetSearchResult, VetSearchRequest>((ref, request) {
      return ref.watch(vetApiProvider).search(request);
    });

final vetDetailProvider = FutureProvider.family<VetDetail, String>(
  (ref, vetId) {
    return ref.watch(vetApiProvider).getDetail(vetId);
  },
  retry: (retryCount, error) {
    if (error is VetApiException && error.statusCode == 404) return null;
    return ProviderContainer.defaultRetry(retryCount, error);
  },
);

final vetReviewListProvider = FutureProvider.family<VetReviewResult, String>((
  ref,
  vetId,
) {
  return ref.watch(vetApiProvider).listReviews(vetId);
});

final vetReviewAccessTokenProvider = authAccessTokenProvider;

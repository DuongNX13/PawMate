import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';

void main() {
  test(
    'loads server-authoritative request summaries with a trimmed token',
    () async {
      final source = _RequestListSource([
        AdoptionRequestSummary.fromJson(_summaryJson()),
      ]);
      final container = ProviderContainer(
        overrides: [
          adoptionAccessTokenProvider.overrideWith(
            (ref) => Future<String?>.value(' day72-token '),
          ),
          adoptionSessionRevisionProvider.overrideWithValue(72),
          adoptionRequestListSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        myAdoptionRequestsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final requests = await container.read(myAdoptionRequestsProvider.future);

      expect(requests.single.petName, 'Golden');
      expect(source.accessTokens, ['day72-token']);
      expect(source.calls, 1);
    },
  );

  test(
    'fails typed and never calls API when the session has no token',
    () async {
      final source = _RequestListSource([]);
      final container = ProviderContainer(
        overrides: [
          adoptionAccessTokenProvider.overrideWith(
            (ref) => Future<String?>.value(null),
          ),
          adoptionSessionRevisionProvider.overrideWithValue(72),
          adoptionRequestListSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final errorState = Completer<AsyncValue<List<AdoptionRequestSummary>>>();
      final subscription = container.listen(myAdoptionRequestsProvider, (
        _,
        next,
      ) {
        if (next.hasError && !errorState.isCompleted) {
          errorState.complete(next);
        }
      });
      addTearDown(subscription.close);

      final result = await errorState.future;

      expect(
        result.error,
        isA<AdoptionApiException>().having(
          (error) => error.code,
          'code',
          'AUTH_REQUIRED',
        ),
      );
      expect(source.calls, 0);
    },
  );
}

class _RequestListSource implements AdoptionRequestListSource {
  _RequestListSource(this.requests);

  final List<AdoptionRequestSummary> requests;
  final List<String> accessTokens = [];
  int calls = 0;

  @override
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  }) async {
    calls += 1;
    accessTokens.add(accessToken);
    return requests;
  }
}

Map<String, dynamic> _summaryJson() => {
  'requestId': 'request-1',
  'listingId': '11111111-1111-4111-8111-111111111111',
  'petName': 'Golden',
  'status': 'submitted',
  'listingAvailability': 'available',
  'threadId': '33333333-3333-4333-8333-333333333333',
  'createdAt': '2026-07-28T05:00:00.000Z',
  'updatedAt': '2026-07-29T05:00:00.000Z',
};

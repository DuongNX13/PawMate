import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adoption_api.dart';
import '../data/adoption_request_chat_api.dart';
import '../domain/adoption_request_chat_models.dart';
import 'adoption_runtime_providers.dart';

final myAdoptionRequestsProvider =
    FutureProvider.autoDispose<List<AdoptionRequestSummary>>((ref) async {
      ref.watch(adoptionSessionRevisionProvider);
      final accessToken = await ref.watch(adoptionAccessTokenProvider);
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const AdoptionApiException(
          'Bạn cần đăng nhập để xem các đơn nhận nuôi.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }
      return ref
          .watch(adoptionRequestListSourceProvider)
          .listMyRequests(accessToken: accessToken.trim());
    });

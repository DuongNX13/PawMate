import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adoption_api.dart';
import '../domain/adoption_models.dart';
import 'adoption_runtime_providers.dart';

final adoptionProfileProvider = FutureProvider.autoDispose
    .family<AdoptionListingDetail, String>((ref, listingId) async {
      final accessToken = await ref.watch(adoptionAccessTokenProvider);
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const AdoptionApiException(
          'Bạn cần đăng nhập để xem hồ sơ nhận nuôi.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }
      return ref
          .watch(adoptionSourceProvider)
          .getListing(listingId, accessToken: accessToken.trim());
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_session_store.dart';
import '../data/health_record_api.dart';
import '../domain/health_record.dart';

final healthRecordAccessTokenProvider = FutureProvider<String?>((ref) async {
  final session = await ref.watch(authSessionStoreProvider).read();
  final token = session?.accessToken.trim();
  return token == null || token.isEmpty ? null : token;
});

final healthRecordListProvider =
    FutureProvider.family<HealthRecordListResult, HealthRecordListQuery>((
      ref,
      query,
    ) async {
      final accessToken = await ref.watch(
        healthRecordAccessTokenProvider.future,
      );
      if (accessToken == null) {
        throw const HealthRecordApiException(
          'Bạn cần đăng nhập để đồng bộ hồ sơ sức khỏe.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }

      return ref
          .watch(healthRecordApiProvider)
          .listRecords(query, accessToken: accessToken);
    });

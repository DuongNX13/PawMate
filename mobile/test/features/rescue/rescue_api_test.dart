import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';

void main() {
  test(
    'sends the Day 39 query and parses only public allowlisted fields',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'data': [
                      {
                        'caseId': '11111111-1111-4111-8111-111111111111',
                        'petName': 'Golden',
                        'species': 'dog',
                        'status': 'missing',
                        'lostAt': '2026-07-23T08:00:00.000Z',
                        'publicLocation': {
                          'areaLabel': 'Q. 3',
                          'approximateLatitude': 10.8,
                          'approximateLongitude': 106.7,
                          'privacyRadiusMeters': 500,
                          'privateLocation': {
                            'formattedAddress': 'must never be read',
                          },
                        },
                        'media': [],
                        'commentCount': 0,
                        'createdAt': '2026-07-23T08:00:00.000Z',
                        'updatedAt': '2026-07-23T08:00:00.000Z',
                        'ownerUserId': 'private',
                        'contactPreference': 'phone_with_consent',
                      },
                    ],
                    'pageInfo': {
                      'nextCursor': 'opaque',
                      'hasMore': true,
                      'limit': 5,
                    },
                  },
                ),
              );
            },
          ),
        );

      final page = await RescueApi(dio).listCases(
        const RescueCaseQuery(
          status: RescueCaseStatus.missing,
          species: RescueSpecies.dog,
          sort: RescueCaseSort.recent,
          cursor: 'previous',
          limit: 5,
        ),
      );

      expect(request.uri.path, '/rescue/cases');
      expect(request.queryParameters['status'], 'missing');
      expect(request.queryParameters['species'], 'dog');
      expect(request.queryParameters['sort'], 'recent');
      expect(request.queryParameters['cursor'], 'previous');
      expect(request.queryParameters['limit'], 5);
      expect(page.items.single.petName, 'Golden');
      expect(page.items.single.publicLocation.areaLabel, 'Q. 3');
      expect(
        page.items.single.publicLocation.runtimeType.toString(),
        contains('RescuePublicLocation'),
      );
      expect(page.pageInfo.nextCursor, 'opaque');
    },
  );

  test('maps a server error to safe RescueApiException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 500,
                data: {
                  'error': {
                    'code': 'SYS_001',
                    'message': 'Máy chủ đang bảo trì.',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );

    await expectLater(
      RescueApi(dio).listCases(const RescueCaseQuery()),
      throwsA(
        isA<RescueApiException>()
            .having((error) => error.code, 'code', 'SYS_001')
            .having(
              (error) => error.message,
              'message',
              'Máy chủ đang bảo trì.',
            ),
      ),
    );
  });
}

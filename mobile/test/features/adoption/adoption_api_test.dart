import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';

import 'adoption_test_fixtures.dart';

void main() {
  test('list uses authenticatedDio contract and exact query', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: adoptionPageJson(
                  nextCursor: 'opaque-next',
                  hasMore: true,
                ),
              ),
            );
          },
        ),
      );

    final page = await AdoptionApi(dio).listListings(
      const AdoptionListQuery(
        species: AdoptionSpecies.dog,
        ageGroup: AdoptionAgeGroup.underOne,
        coordinates: AdoptionCoordinates(
          latitude: 10.7769,
          longitude: 106.7009,
        ),
        distanceKm: 5,
        sort: AdoptionReadSort.distance,
        cursor: 'opaque-before',
      ),
      accessToken: ' access-token ',
    );

    expect(request.uri.path, '/adoption/listings');
    expect(request.queryParameters, {
      'species': 'dog',
      'ageGroup': 'under_1',
      'lat': 10.7769,
      'lng': 106.7009,
      'distanceKm': 5.0,
      'sort': 'distance',
      'cursor': 'opaque-before',
      'limit': 20,
    });
    expect(request.headers['Authorization'], 'Bearer access-token');
    expect(request.headers['Cache-Control'], 'no-store');
    expect(request.extra['pawmate.cache'], 'disabled');
    expect(page.pageInfo.nextCursor, 'opaque-next');
  });

  test('detail encodes id and parses fail-closed viewer permissions', () async {
    late RequestOptions request;
    final payload = adoptionDetailJson()..remove('viewerPermissions');
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {'data': payload},
              ),
            );
          },
        ),
      );

    final detail = await AdoptionApi(
      dio,
    ).getListing('listing/unsafe', accessToken: 'token');

    expect(request.uri.path, '/adoption/listings/listing%2Funsafe');
    expect(detail.viewerPermissions.canLike, isFalse);
    expect(detail.viewerPermissions.canRequest, isFalse);
  });

  test('decision sends exact payload and stable idempotency header', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'listingId': 'listing-1',
                    'adopterUserId': 'adopter-1',
                    'decision': 'like',
                    'createdAt': '2026-07-28T04:00:00.000Z',
                  },
                },
              ),
            );
          },
        ),
      );

    final result = await AdoptionApi(dio).recordDecision(
      'listing-1',
      AdoptionDecision.like,
      accessToken: 'token',
      idempotencyKey: 'day54-like-listing-1',
    );

    expect(request.uri.path, '/adoption/listings/listing-1/decisions');
    expect(request.data, {'decision': 'like'});
    expect(request.headers['Idempotency-Key'], 'day54-like-listing-1');
    expect(result.decision, AdoptionDecision.like);
  });

  test('maps backend error envelope to typed AdoptionApiException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: {
                    'error': {
                      'code': 'ADOPTION_003',
                      'message': 'Không tìm thấy hồ sơ nhận nuôi.',
                    },
                    'requestId': 'request-day54-42',
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

    await expectLater(
      AdoptionApi(dio).getListing('deleted', accessToken: 'token'),
      throwsA(
        isA<AdoptionApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.code, 'code', 'ADOPTION_003')
            .having((error) => error.requestId, 'requestId', 'request-day54-42')
            .having((error) => error.isUnavailable, 'isUnavailable', isTrue),
      ),
    );
  });
}

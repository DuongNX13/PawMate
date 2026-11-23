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

  test(
    'gets Day 41 public detail with no-store and ignores private fields',
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
                  data: {'data': _detailPayload()},
                ),
              );
            },
          ),
        );

      final detail = await RescueApi(
        dio,
      ).getCase('11111111-1111-4111-8111-111111111111');

      expect(
        request.uri.path,
        '/rescue/cases/11111111-1111-4111-8111-111111111111',
      );
      expect(request.headers['Cache-Control'], 'no-store');
      expect(request.extra['pawmate.cache'], 'disabled');
      expect(detail.identifyingFeatures, contains('vòng cổ'));
      expect(detail.version, 3);
      expect(detail.behaviorHint, contains('nhút nhát'));
      expect(detail.viewerPermissions.canComment, isTrue);
      expect(detail.viewerPermissions.canUpdateStatus, isFalse);
      expect(detail.viewerPermissions.canViewPrivateContact, isFalse);
      expect(detail.publicLocation.areaLabel, 'Q. Tân Bình');
      expect(detail.runtimeType.toString(), 'RescueCaseDetail');
    },
  );

  test('missing viewer permissions fail closed to all false', () {
    final payload = _detailPayload()..remove('viewerPermissions');

    final detail = RescueCaseDetail.fromJson(payload);

    expect(detail.viewerPermissions.canComment, isFalse);
    expect(detail.viewerPermissions.canUpdateStatus, isFalse);
    expect(detail.viewerPermissions.canViewPrivateContact, isFalse);
  });

  test('maps deleted case to a typed unavailable error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 404,
                data: {
                  'error': {
                    'code': 'RESCUE_CASE_NOT_FOUND',
                    'message': 'Không tìm thấy tin báo.',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );

    await expectLater(
      RescueApi(dio).getCase('deleted'),
      throwsA(
        isA<RescueApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.code, 'code', 'RESCUE_CASE_NOT_FOUND'),
      ),
    );
  });
}

Map<String, dynamic> _detailPayload() => {
  'caseId': '11111111-1111-4111-8111-111111111111',
  'petName': 'LuLu',
  'species': 'dog',
  'status': 'missing',
  'lostAt': '2026-07-23T08:00:00.000Z',
  'publicLocation': {
    'areaLabel': 'Q. Tân Bình',
    'approximateLatitude': 10.8,
    'approximateLongitude': 106.7,
    'privacyRadiusMeters': 500,
  },
  'media': <Map<String, dynamic>>[],
  'commentCount': 3,
  'createdAt': '2026-07-23T08:00:00.000Z',
  'updatedAt': '2026-07-23T08:00:00.000Z',
  'breedOrColor': 'Poodle màu nâu',
  'ageLabel': '2 tuổi',
  'version': 3,
  'identifyingFeatures': 'Đeo vòng cổ màu xanh.',
  'behaviorHint': 'Bé hơi nhút nhát.',
  'viewerPermissions': {
    'canComment': true,
    'canUpdateStatus': false,
    'canViewPrivateContact': false,
  },
  'ownerUserId': 'private-owner',
  'privateLocation': {
    'latitude': 10.812345,
    'longitude': 106.712345,
    'formattedAddress': 'private-address',
  },
  'phone': '0900000000',
};

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// Test-only platform fake for deterministic service/permission/location states.
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_saved_listings_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_location_service.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_share_service.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';

import 'adoption_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adoption API defensive branches', () {
    test('default provider uses the authenticated Dio instance', () {
      final dio = Dio();
      final container = ProviderContainer(
        overrides: [authenticatedDioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      expect(container.read(adoptionSourceProvider), isA<AdoptionApi>());
    });

    test(
      'typed exception helpers cover auth/conflict/offline/legacy states',
      () {
        expect(
          const AdoptionApiException('', code: 'AUTH_001').isAuthRequired,
          isTrue,
        );
        expect(
          const AdoptionApiException('', code: 'AUTH_013').isAuthRequired,
          isTrue,
        );
        expect(
          const AdoptionApiException(
            '',
            code: 'ADOPTION_LISTING_NOT_FOUND',
          ).isUnavailable,
          isTrue,
        );
        expect(
          const AdoptionApiException('', code: 'IDEMPOTENCY_001').isConflict,
          isTrue,
        );
        expect(
          const AdoptionApiException('', statusCode: 409).isConflict,
          isTrue,
        );
        expect(
          const AdoptionApiException(
            'Mất kết nối',
            code: 'NETWORK_OFFLINE',
          ).isOffline,
          isTrue,
        );
        expect(const AdoptionApiException('Thông báo').toString(), 'Thông báo');
      },
    );

    test('invalid list envelope becomes a safe typed response error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: <Object, Object>{
                    'data': 'not-a-list',
                    'pageInfo': <Object, Object>{'hasMore': false, 'limit': 20},
                  },
                ),
              );
            },
          ),
        );

      await expectLater(
        AdoptionApi(
          dio,
        ).listListings(const AdoptionListQuery(), accessToken: 'token'),
        throwsA(
          isA<AdoptionApiException>()
              .having((error) => error.code, 'code', 'INVALID_RESPONSE')
              .having(
                (error) => error.message,
                'message',
                contains('danh sách nhận nuôi không hợp lệ'),
              ),
        ),
      );
    });

    test('non-network Dio failure uses the generic safe fallback', () async {
      final dio = _rejectingDio(DioExceptionType.badResponse, statusCode: 503);

      await expectLater(
        AdoptionApi(
          dio,
        ).listListings(const AdoptionListQuery(), accessToken: 'token'),
        throwsA(
          isA<AdoptionApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.code, 'code', isNull)
              .having((error) => error.isOffline, 'isOffline', isFalse)
              .having(
                (error) => error.message,
                'message',
                'Không tải được dữ liệu nhận nuôi. Vui lòng thử lại.',
              ),
        ),
      );
    });

    for (final type in const [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      test('$type maps to the offline-safe error', () async {
        final dio = _rejectingDio(type);

        await expectLater(
          AdoptionApi(
            dio,
          ).listListings(const AdoptionListQuery(), accessToken: 'token'),
          throwsA(
            isA<AdoptionApiException>()
                .having((error) => error.isOffline, 'isOffline', isTrue)
                .having(
                  (error) => error.message,
                  'message',
                  'Không thể kết nối tới máy chủ nhận nuôi.',
                ),
          ),
        );
      });
    }
  });

  group('Adoption model defensive branches', () {
    test('covers every public species and listing-status label', () {
      expect(AdoptionSpecies.other.label, 'Khác');
      expect(AdoptionSpecies.fromJson('cat'), AdoptionSpecies.cat);
      expect(AdoptionSpecies.fromJson('other'), AdoptionSpecies.other);
      expect(AdoptionListingStatus.pending.label, 'Đang xem xét');
      expect(AdoptionListingStatus.adopted.label, 'Đã có gia đình');
      expect(AdoptionListingStatus.closed.label, 'Đã đóng');
    });

    test('normalizes a non-string-key nested map', () {
      final json = adoptionSummaryJson();
      json['heroMedia'] = Map<Object, Object>.from(adoptionMediaJson());

      expect(
        AdoptionListingSummary.fromJson(json).heroMedia.mediaId,
        'media-1',
      );
    });

    test('rejects missing map, string, integer, and invalid date fields', () {
      final missingMap = adoptionSummaryJson()..remove('heroMedia');
      expect(
        () => AdoptionListingSummary.fromJson(missingMap),
        throwsFormatException,
      );

      final missingString = adoptionSummaryJson()..['petName'] = ' ';
      expect(
        () => AdoptionListingSummary.fromJson(missingString),
        throwsFormatException,
      );

      final missingInteger = adoptionSummaryJson();
      (missingInteger['heroMedia'] as Map<String, dynamic>)['sizeBytes'] =
          'large';
      expect(
        () => AdoptionListingSummary.fromJson(missingInteger),
        throwsFormatException,
      );

      final invalidDate = adoptionSummaryJson()..['createdAt'] = 'not-a-date';
      expect(
        () => AdoptionListingSummary.fromJson(invalidDate),
        throwsFormatException,
      );
    });

    test('accepts an integral finite double for integer media fields', () {
      final json = adoptionSummaryJson();
      (json['heroMedia'] as Map<String, dynamic>)['sizeBytes'] = 2048.0;

      expect(AdoptionListingSummary.fromJson(json).heroMedia.sizeBytes, 2048);
    });
  });

  group('Adoption runtime providers', () {
    test(
      'exposes auth token, UTC clock, duration, and safe key factory',
      () async {
        final container = ProviderContainer(
          overrides: [
            authAccessTokenProvider.overrideWith(
              (ref) async => 'runtime-token',
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          await container.read(adoptionAccessTokenProvider),
          'runtime-token',
        );
        expect(container.read(adoptionClockProvider)().isUtc, isTrue);
        expect(
          container.read(adoptionUndoDurationProvider),
          const Duration(seconds: 4),
        );
        expect(
          container.read(adoptionIdempotencyKeyFactoryProvider)(
            AdoptionDecision.like,
            'listing/with spaces',
            DateTime.fromMicrosecondsSinceEpoch(42, isUtc: true),
            3,
          ),
          'pawmate-day54-like-listing-with-spaces-42-3',
        );
      },
    );

    test(
      'default scheduler runs once and its cancel handle suppresses work',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final scheduler = container.read(adoptionDecisionSchedulerProvider);
        final fired = Completer<void>();

        scheduler(Duration.zero, () async => fired.complete());
        await fired.future;

        var cancelledActionRan = false;
        final cancel = scheduler(
          const Duration(milliseconds: 20),
          () async => cancelledActionRan = true,
        );
        cancel();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(cancelledActionRan, isFalse);
      },
    );

    test('default adapter providers construct their production sources', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(adoptionLocationSourceProvider),
        isA<GeolocatorAdoptionLocationSource>(),
      );
      expect(
        container.read(adoptionShareSourceProvider),
        isA<NativeAdoptionShareSource>(),
      );
    });
  });

  group('Geolocator adoption adapter', () {
    late GeolocatorPlatform originalPlatform;

    setUp(() {
      originalPlatform = GeolocatorPlatform.instance;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalPlatform;
    });

    test(
      'reports disabled location service without checking permission',
      () async {
        final platform = _FakeGeolocatorPlatform(serviceEnabled: false);
        GeolocatorPlatform.instance = platform;

        await expectLater(
          GeolocatorAdoptionLocationSource().resolveCurrentLocation(),
          throwsA(
            isA<AdoptionLocationException>().having(
              (error) => error.type,
              'type',
              AdoptionLocationFailureType.serviceDisabled,
            ),
          ),
        );
        expect(platform.checkCalls, 0);
      },
    );

    for (final deniedResult in const [
      LocationPermission.denied,
      LocationPermission.deniedForever,
    ]) {
      test(
        'reports $deniedResult after an explicit permission request',
        () async {
          final platform = _FakeGeolocatorPlatform(
            checkedPermission: LocationPermission.denied,
            requestedPermission: deniedResult,
          );
          GeolocatorPlatform.instance = platform;

          await expectLater(
            GeolocatorAdoptionLocationSource().resolveCurrentLocation(),
            throwsA(
              isA<AdoptionLocationException>().having(
                (error) => error.type,
                'type',
                AdoptionLocationFailureType.permissionDenied,
              ),
            ),
          );
          expect(platform.requestCalls, 1);
        },
      );
    }

    test(
      'returns coordinates with the bounded medium-accuracy request',
      () async {
        final platform = _FakeGeolocatorPlatform(
          checkedPermission: LocationPermission.whileInUse,
          position: _position(latitude: 10.7769, longitude: 106.7009),
        );
        GeolocatorPlatform.instance = platform;

        final result = await GeolocatorAdoptionLocationSource()
            .resolveCurrentLocation();

        expect(result.latitude, 10.7769);
        expect(result.longitude, 106.7009);
        expect(platform.lastSettings?.accuracy, LocationAccuracy.medium);
        expect(platform.lastSettings?.timeLimit, const Duration(seconds: 8));
      },
    );

    test(
      'maps platform timeout to a typed retryable location failure',
      () async {
        GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
          checkedPermission: LocationPermission.whileInUse,
          positionError: TimeoutException('slow location'),
        );

        await expectLater(
          GeolocatorAdoptionLocationSource().resolveCurrentLocation(),
          throwsA(
            isA<AdoptionLocationException>()
                .having(
                  (error) => error.type,
                  'type',
                  AdoptionLocationFailureType.timeout,
                )
                .having(
                  (error) => error.toString(),
                  'message',
                  contains('quá chậm'),
                ),
          ),
        );
      },
    );

    test('maps unknown platform errors without leaking internals', () async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        checkedPermission: LocationPermission.whileInUse,
        positionError: StateError('GPS driver detail'),
      );

      await expectLater(
        GeolocatorAdoptionLocationSource().resolveCurrentLocation(),
        throwsA(
          isA<AdoptionLocationException>()
              .having(
                (error) => error.type,
                'type',
                AdoptionLocationFailureType.unknown,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('driver')),
              ),
        ),
      );
    });
  });

  test(
    'saved notifier handles loading, validation, save and remove branches',
    () async {
      final store = _DelayedSavedStore();
      final container = ProviderContainer(
        overrides: [adoptionSavedListingStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(adoptionSavedListingsProvider.notifier);

      expect(notifier.isSaved('listing-1'), isFalse);
      final firstToggle = notifier.toggle('listing-1');
      store.initial.complete(const {});
      expect(await firstToggle, isTrue);
      expect(notifier.isSaved('listing-1'), isTrue);

      await expectLater(notifier.toggle('  '), throwsArgumentError);
      expect(await notifier.toggle('listing-1'), isFalse);
      expect(notifier.isSaved('listing-1'), isFalse);
      expect(store.writes, 2);
    },
  );
}

Dio _rejectingDio(DioExceptionType type, {int? statusCode}) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: type,
              response: statusCode == null
                  ? null
                  : Response<dynamic>(
                      requestOptions: options,
                      statusCode: statusCode,
                    ),
            ),
          );
        },
      ),
    );
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 7, 28),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.checkedPermission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    Position? position,
    this.positionError,
  }) : position = position ?? _position(latitude: 10.7, longitude: 106.6);

  final bool serviceEnabled;
  final LocationPermission checkedPermission;
  final LocationPermission requestedPermission;
  final Position position;
  final Object? positionError;
  int checkCalls = 0;
  int requestCalls = 0;
  LocationSettings? lastSettings;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkCalls += 1;
    return checkedPermission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls += 1;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    lastSettings = locationSettings;
    if (positionError != null) throw positionError!;
    return position;
  }
}

class _DelayedSavedStore implements AdoptionSavedListingStore {
  final Completer<Set<String>> initial = Completer<Set<String>>();
  int writes = 0;

  @override
  Future<Set<String>> readAll() => initial.future;

  @override
  Future<void> writeAll(Set<String> listingIds) async {
    writes += 1;
  }
}

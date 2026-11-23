import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';

const _userId = '59000000-0000-4000-8000-000000000001';
final _updatedAt = DateTime.utc(2026, 7, 29, 8);

NotificationPreferences _notification({int version = 1}) {
  return NotificationPreferences(
    userId: _userId,
    version: version,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: _updatedAt,
  );
}

PrivacyDefaults _privacy({int version = 1}) {
  return PrivacyDefaults(
    userId: _userId,
    version: version,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: _updatedAt,
  );
}

void main() {
  group('Day 59 preference DTO/API contract', () {
    test('parses strict defaults and emits expectedVersion on save', () {
      final model = NotificationPreferences.fromJson({
        'userId': _userId,
        'version': 3,
        'nearbyLostCases': true,
        'chatMessages': false,
        'adoptionUpdates': true,
        'quietHoursEnabled': true,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '06:00',
        'updatedAt': '2026-07-29T08:00:00.000Z',
      });

      expect(model.version, 3);
      expect(model.toUpdateJson(), {
        'expectedVersion': 3,
        'nearbyLostCases': true,
        'chatMessages': false,
        'adoptionUpdates': true,
        'quietHoursEnabled': true,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '06:00',
      });
    });

    test('rejects inconsistent disabled quiet hours', () {
      expect(
        () => NotificationPreferences.fromJson({
          'userId': _userId,
          'version': 1,
          'nearbyLostCases': true,
          'chatMessages': true,
          'adoptionUpdates': true,
          'quietHoursEnabled': false,
          'quietHoursStart': '22:00',
          'updatedAt': '2026-07-29T08:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('uses the four locked owner endpoints and bearer auth', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              final isNotification = options.path.contains('notification');
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': isNotification
                        ? {
                            'userId': _userId,
                            'version': options.method == 'PUT' ? 2 : 1,
                            'nearbyLostCases': true,
                            'chatMessages': true,
                            'adoptionUpdates': true,
                            'quietHoursEnabled': false,
                            'updatedAt': '2026-07-29T08:00:00.000Z',
                          }
                        : {
                            'userId': _userId,
                            'version': options.method == 'PUT' ? 2 : 1,
                            'hideHouseNumber': true,
                            'hidePhoneByDefault': true,
                            'reviewMediaBeforePublish': true,
                            'updatedAt': '2026-07-29T08:00:00.000Z',
                          },
                  },
                ),
              );
            },
          ),
        );
      final api = PreferenceApi(dio);

      final notification = await api.getNotificationPreferences(
        accessToken: 'owner-token',
      );
      await api.updateNotificationPreferences(
        notification,
        accessToken: 'owner-token',
      );
      final privacy = await api.getPrivacyDefaults(accessToken: 'owner-token');
      await api.updatePrivacyDefaults(privacy, accessToken: 'owner-token');

      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /me/notification-preferences',
        'PUT /me/notification-preferences',
        'GET /me/privacy-defaults',
        'PUT /me/privacy-defaults',
      ]);
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer owner-token',
        ),
        isTrue,
      );
      expect(
        requests
            .where((request) => request.method == 'PUT')
            .every(
              (request) =>
                  (request.data as Map<String, dynamic>)['expectedVersion'] ==
                  1,
            ),
        isTrue,
      );
    });
  });

  group('Day 59 account-scoped providers', () {
    test(
      'loads and saves server-authoritative notification preferences',
      () async {
        final source = _FakePreferenceSource();
        final container = ProviderContainer(
          overrides: [
            authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
            preferenceSourceProvider.overrideWithValue(source),
          ],
        );
        addTearDown(container.dispose);

        final loaded = await container.read(
          notificationPreferencesProvider.future,
        );
        final saved = await container
            .read(notificationPreferencesProvider.notifier)
            .save(loaded.copyWith(chatMessages: false));

        expect(saved, isTrue);
        expect(
          container.read(notificationPreferencesProvider).requireValue.version,
          2,
        );
        expect(source.lastAccessToken, 'owner-token');
      },
    );

    test('retains recoverable state when save fails', () async {
      final source = _FakePreferenceSource(failPrivacySave: true);
      final container = ProviderContainer(
        overrides: [
          authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
          preferenceSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(privacyDefaultsProvider.future);
      final saved = await container
          .read(privacyDefaultsProvider.notifier)
          .save(loaded.copyWith(hidePhoneByDefault: false));

      expect(saved, isFalse);
      expect(container.read(privacyDefaultsProvider).hasError, isTrue);
      expect(
        container.read(privacyDefaultsProvider.notifier).lastSuccessful,
        loaded,
      );
    });
  });
}

class _FakePreferenceSource implements PreferenceSource {
  _FakePreferenceSource({this.failPrivacySave = false});

  final bool failPrivacySave;
  String? lastAccessToken;

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    return _notification();
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    return NotificationPreferences(
      userId: preferences.userId,
      version: preferences.version + 1,
      nearbyLostCases: preferences.nearbyLostCases,
      chatMessages: preferences.chatMessages,
      adoptionUpdates: preferences.adoptionUpdates,
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietHoursStart: preferences.quietHoursStart,
      quietHoursEnd: preferences.quietHoursEnd,
      updatedAt: _updatedAt,
    );
  }

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    return _privacy();
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    if (failPrivacySave) {
      throw const PreferenceApiException(
        'Không thể lưu.',
        code: 'NETWORK_OFFLINE',
      );
    }
    return PrivacyDefaults(
      userId: defaults.userId,
      version: defaults.version + 1,
      hideHouseNumber: defaults.hideHouseNumber,
      hidePhoneByDefault: defaults.hidePhoneByDefault,
      reviewMediaBeforePublish: defaults.reviewMediaBeforePublish,
      updatedAt: _updatedAt,
    );
  }
}

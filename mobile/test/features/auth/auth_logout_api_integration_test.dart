import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runLocalIntegration = bool.fromEnvironment('RUN_LOCAL_AUTH_INTEGRATION');
const _baseUrl = String.fromEnvironment(
  'PAWMATE_AUTH_INTEGRATION_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000',
);

void main() {
  test(
    'production logout revokes refresh and access tokens across sessions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final api = AuthApi(dio);
      final store = _IntegrationSessionStore();
      final coordinator = AuthSessionCoordinator(store, api);
      final firstSession = await api.login(
        email: 'mobile-e2e-owner@pawmate.test',
        password: 'Pawmate123',
      );
      final secondSession = await api.login(
        email: 'mobile-e2e-owner@pawmate.test',
        password: 'Pawmate123',
      );
      await coordinator.saveSession(firstSession);

      await coordinator.logout();

      expect(store.session, isNull);
      await expectLater(
        api.refresh(refreshToken: secondSession.refreshToken),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.code, 'code', 'AUTH_009'),
        ),
      );
      await _expectProtectedAccessDenied(dio, firstSession.accessToken);
      await _expectProtectedAccessDenied(dio, secondSession.accessToken);
    },
    skip: _runLocalIntegration
        ? false
        : 'Requires the local PawMate backend and seeded mobile E2E account.',
  );
}

Future<void> _expectProtectedAccessDenied(Dio dio, String accessToken) async {
  await expectLater(
    dio.get<dynamic>(
      '/pets',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    ),
    throwsA(
      isA<DioException>().having(
        (error) => error.response?.statusCode,
        'statusCode',
        401,
      ),
    ),
  );
}

class _IntegrationSessionStore extends AuthSessionStore {
  _IntegrationSessionStore() : super(const FlutterSecureStorage());

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

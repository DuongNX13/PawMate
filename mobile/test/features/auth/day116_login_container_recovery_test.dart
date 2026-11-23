import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:pawmate_mobile/features/auth/presentation/login_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R23 ST-02 P1-02 text$scale real login retry and owned provider disposal',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final api = _Api();
        final store = _Store();
        final marker = _Marker();
        final router = GoRouter(
          initialLocation: '/auth/login',
          routes: [
            GoRoute(
              path: '/auth/login',
              builder: (_, _) => const LoginScreen(),
            ),
            GoRoute(path: '/pets', builder: (_, _) => const PetHomeScreen()),
          ],
        );
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            authApiProvider.overrideWithValue(api),
            authSessionStoreProvider.overrideWithValue(store),
            authSessionMarkerStoreProvider.overrideWithValue(marker),
            petBackendListProvider.overrideWith((_) async => []),
            upcomingRemindersProvider.overrideWith((_) async => []),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                builder: testTextScaleBuilder(scale),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Finder field(String key) => find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextFormField),
          );
          final email = field('login-email-field');
          final password = field('login-password-field');
          await tester.enterText(email, 'fixture@example.test');
          await tester.enterText(password, 'Fixture-only-Password1!');
          final submit = find.byKey(const Key('login-submit-button'));
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(api.inputs, hasLength(1));
          expect(store.writes, 0);
          expect(marker.active, false);
          expect(find.byKey(const Key('login-error-banner')), findsOneWidget);
          expect(
            tester.widget<TextFormField>(email).controller!.text,
            'fixture@example.test',
          );
          expect(
            tester.widget<TextFormField>(password).controller!.text,
            'Fixture-only-Password1!',
          );
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
          await captureDay116(
            tester,
            'R23-ST02-P102-failed-text${scale.toString().replaceAll('.', '-')}',
          );
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(api.inputs, hasLength(2));
          expect(api.inputs[1], api.inputs[0]);
          expect(store.writes, 1);
          expect(store.session, _session);
          expect(marker.active, true);
          expect(marker.signedOut, false);
          expect(find.byType(PetHomeScreen), findsOneWidget);
          expect(router.routeInformationProvider.value.uri.path, '/pets');
          expect(find.byKey(const Key('login-error-banner')), findsNothing);
          expect(find.text('Chưa có thú cưng nào'), findsOneWidget);
          // Force the real snapshot and its production refresh lifecycle to be
          // observed. The test owns its provider lifetime, not the widget tree.
          expect(
            await container.read(authSessionSnapshotProvider.future),
            _session,
          );
          await captureDay116(
            tester,
            'R23-ST02-P102-ready-text${scale.toString().replaceAll('.', '-')}',
          );
          expectNoFlutterOverflow(tester);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          router.dispose();
          await tester.pump();
        }
      },
    );
  }
}

class _Api extends AuthApi {
  _Api() : super(Dio());
  final inputs = <Map<String, String>>[];
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    inputs.add({'email': email, 'password': password});
    if (inputs.length == 1) {
      throw const AuthApiException(
        'Máy chủ tạm lỗi. Vui lòng thử lại.',
        statusCode: 503,
        code: 'SYS_001',
      );
    }
    return _session;
  }
}

class _Store extends AuthSessionStore {
  _Store() : super(const FlutterSecureStorage());
  AuthSession? session;
  int writes = 0;
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> save(AuthSession value) async {
    writes++;
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class _Marker implements AuthSessionMarkerStore {
  bool active = false, signedOut = false;
  @override
  Future<bool> isSignedOut() async => signedOut;
  @override
  Future<void> write({required bool active, required bool signedOut}) async {
    this.active = active;
    this.signedOut = signedOut;
  }
}

const _session = AuthSession(
  user: AuthUser(
    id: 'r23-owner',
    email: 'fixture@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'fixture-token',
  refreshToken: 'fixture-refresh',
  accessTokenExpiresAt: '2099-01-01T00:00:00Z',
  refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
);

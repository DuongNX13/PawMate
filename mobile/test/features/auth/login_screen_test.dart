import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:pawmate_mobile/features/auth/presentation/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('login success routes to Phase 1 Home at /pets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final session = _sampleSession();
    final fakeApi = _FakeAuthApi(session);
    final fakeStore = _FakeAuthSessionStore();
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Home target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWith((ref) => fakeApi),
          authSessionStoreProvider.overrideWith((ref) => fakeStore),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'nam@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(fakeApi.loginCalled, isTrue);
    expect(fakeStore.savedSession, session);
    expect(find.text('Home target'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasActiveSession'), isTrue);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('login resumes the protected returnTo route and query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeAuthApi(_sampleSession());
    final fakeStore = _FakeAuthSessionStore();
    final router = GoRouter(
      initialLocation:
          '/auth/login?returnTo=${Uri.encodeQueryComponent('/vets/list?availability=24h')}',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (context, state) =>
              LoginScreen(returnTo: state.uri.queryParameters['returnTo']),
        ),
        GoRoute(
          path: '/vets/list',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'Vet target: ${state.uri.queryParameters['availability']}',
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWith((ref) => fakeApi),
          authSessionStoreProvider.overrideWith((ref) => fakeStore),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _enterValidCredentials(tester);
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Vet target: 24h'), findsOneWidget);
  });

  testWidgets('login shows v0.27 content and keeps API error inline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeAuthApi(
      _sampleSession(),
      errorMessage: 'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.',
    );
    final fakeStore = _FakeAuthSessionStore();
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/pets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Home target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWith((ref) => fakeApi),
          authSessionStoreProvider.overrideWith((ref) => fakeStore),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mừng bạn đã trở lại'), findsOneWidget);
    expect(
      find.text('Đăng nhập để theo dõi sức khỏe thú cưng của bạn.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'nam@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(fakeApi.loginCalled, isTrue);
    expect(fakeStore.savedSession, isNull);
    expect(
      find.text('Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.'),
      findsOneWidget,
    );
    expect(find.text('Mừng bạn đã trở lại'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('login register CTA wraps cleanly at large text', (tester) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(320, 568));
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Register target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(1.5),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký ngay'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Minh họa bác sĩ thú y đang chăm sóc chó cưng cho màn đăng nhập',
      ),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);

    await tester.ensureVisible(find.byKey(const Key('login-register-cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-register-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Register target'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('login validates fields before calling API', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final fakeApi = _FakeAuthApi(_sampleSession());
    final router = _loginRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authApiProvider.overrideWith((ref) => fakeApi)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(fakeApi.loginCallCount, 0);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('login exposes loading state and blocks duplicate submit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final response = Completer<AuthSession>();
    final fakeApi = _FakeAuthApi(_sampleSession(), response: response);
    final router = _loginRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWith((ref) => fakeApi),
          authSessionStoreProvider.overrideWith(
            (ref) => _FakeAuthSessionStore(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _enterValidCredentials(tester);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fakeApi.loginCallCount, 1);
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();
    expect(fakeApi.loginCallCount, 1);

    response.complete(_sampleSession());
    await tester.pumpAndSettle();
    expect(find.text('Home target'), findsOneWidget);
  });

  testWidgets(
    'login routes unverified account to OTP with email and returnTo',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await setTestViewport(tester, size: const Size(390, 844));
      final fakeApi = _FakeAuthApi(
        _sampleSession(),
        errorMessage: 'Tài khoản chưa xác minh.',
        errorCode: 'AUTH_006',
      );
      final router = _loginRouter(returnTo: '/vets/list?availability=24h');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authApiProvider.overrideWith((ref) => fakeApi)],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _enterValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('OTP target: nam@example.com'), findsOneWidget);
      expect(
        find.text('OTP returnTo: /vets/list?availability=24h'),
        findsOneWidget,
      );
    },
  );

  testWidgets('login does not activate session when secure save fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _loginRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWith((ref) => _FakeAuthApi(_sampleSession())),
          authSessionStoreProvider.overrideWith(
            (ref) => _ThrowingAuthSessionStore(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _enterValidCredentials(tester);
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Đăng nhập chưa hoàn tất. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Home target'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasActiveSession'), isNot(true));
  });

  testWidgets('register link passes the entered email only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _loginRouter();

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login-email-field')),
        matching: find.byType(TextFormField),
      ),
      'nam@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('login-register-cta')));
    await tester.tap(find.byKey(const Key('login-register-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Register target: nam@example.com'), findsOneWidget);
    expect(find.textContaining('secret123'), findsNothing);
  });
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi(
    this._session, {
    this.errorMessage,
    this.errorCode,
    this.response,
  }) : super(Dio());

  final AuthSession _session;
  final String? errorMessage;
  final String? errorCode;
  final Completer<AuthSession>? response;
  bool loginCalled = false;
  int loginCallCount = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    loginCalled = true;
    loginCallCount += 1;
    expect(email, 'nam@example.com');
    expect(password, 'secret123');
    if (errorMessage != null) {
      throw AuthApiException(errorMessage!, code: errorCode);
    }
    if (response != null) return response!.future;
    return _session;
  }
}

class _FakeAuthSessionStore extends AuthSessionStore {
  _FakeAuthSessionStore() : super(const FlutterSecureStorage());

  AuthSession? savedSession;

  @override
  Future<void> save(AuthSession session) async {
    savedSession = session;
  }

  @override
  Future<AuthSession?> read() async => savedSession;

  @override
  Future<void> clear() async {
    savedSession = null;
  }
}

class _ThrowingAuthSessionStore extends AuthSessionStore {
  _ThrowingAuthSessionStore() : super(const FlutterSecureStorage());

  @override
  Future<void> save(AuthSession session) async {
    throw StateError('secure storage unavailable');
  }

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

GoRouter _loginRouter({String? returnTo}) {
  return GoRouter(
    initialLocation: Uri(
      path: '/auth/login',
      queryParameters: returnTo == null ? null : {'returnTo': returnTo},
    ).toString(),
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            LoginScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/pets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home target'))),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              children: [
                Text('OTP target: ${state.uri.queryParameters['email']}'),
                Text('OTP returnTo: ${state.uri.queryParameters['returnTo']}'),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              children: [
                Text('Register target: ${state.uri.queryParameters['email']}'),
                Text(
                  'Register returnTo: ${state.uri.queryParameters['returnTo']}',
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _enterValidCredentials(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'nam@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
}

AuthSession _sampleSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'user-1',
      email: 'nam@example.com',
      authProvider: 'email',
      emailVerified: true,
      displayName: 'Nam',
    ),
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    accessTokenExpiresAt: '2026-07-08T10:00:00Z',
    refreshTokenExpiresAt: '2026-08-08T10:00:00Z',
  );
}

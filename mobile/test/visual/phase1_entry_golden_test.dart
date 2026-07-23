import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:pawmate_mobile/features/auth/presentation/login_screen.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_support/ui_test_helpers.dart';

const _viewport = Size(390, 844);
const _tierAExtraViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];
const _goldenRootKey = Key('day13-phase1-entry-golden-root');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-01 onboarding golden at 390x844', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGolden(
      tester,
      router: _buildOnboardingRouter(),
      api: _GoldenAuthApi(),
    );

    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day13/p1-01-onboarding-390x844.png'),
    );
  });

  testWidgets('P1-02 login error golden at 390x844', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGolden(
      tester,
      router: _buildLoginRouter(),
      api: _GoldenAuthApi(
        loginError: 'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.',
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'nam@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day13/p1-02-login-error-390x844.png'),
    );
  });

  for (final viewport in _tierAExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';

    testWidgets('P1-01 onboarding responsive golden at $tag', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpGolden(
        tester,
        router: _buildOnboardingRouter(),
        api: _GoldenAuthApi(),
        viewport: viewport,
      );

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day13/p1-01-onboarding-$tag.png'),
      );
    });

    testWidgets('P1-02 login error responsive golden at $tag', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpGolden(
        tester,
        router: _buildLoginRouter(),
        api: _GoldenAuthApi(
          loginError: 'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.',
        ),
        viewport: viewport,
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'nam@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.byKey(const Key('login-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day13/p1-02-login-error-$tag.png'),
      );
    });
  }
}

GoRouter _buildOnboardingRouter() => GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);

GoRouter _buildLoginRouter() => GoRouter(
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

Future<void> _pumpGolden(
  WidgetTester tester, {
  required GoRouter router,
  required _GoldenAuthApi api,
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWith((ref) => api),
        authSessionStoreProvider.overrideWith((ref) => _GoldenSessionStore()),
      ],
      child: RepaintBoundary(
        key: _goldenRootKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byKey(_goldenRootKey));
  for (final asset in const [
    'assets/images/auth/onboarding_dog.png',
    'assets/images/auth/login_vet_dog.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pumpAndSettle();
}

class _GoldenAuthApi extends AuthApi {
  _GoldenAuthApi({this.loginError}) : super(Dio());

  final String? loginError;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (loginError != null) throw AuthApiException(loginError!);
    throw StateError('Unexpected successful login in a golden test.');
  }
}

class _GoldenSessionStore extends AuthSessionStore {
  _GoldenSessionStore() : super(const FlutterSecureStorage());

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

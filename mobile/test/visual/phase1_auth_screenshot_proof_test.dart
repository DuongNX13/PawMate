import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:pawmate_mobile/features/auth/presentation/login_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_support/ui_test_helpers.dart';

const _viewport = Size(390, 844);
const _captureRootKey = ValueKey('phase1-auth-screenshot-root');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('captures P1-01 to P1-04 runtime screenshots at 390x844', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final outputDir = _screenshotOutputDir();
    outputDir.createSync(recursive: true);

    await _pumpForScreenshot(
      tester,
      router: GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/auth/register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/auth/login',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
      ),
      api: _VisualAuthApi(),
    );
    await _captureScreen(tester, outputDir, 'p1-01-onboarding.png');

    await _pumpForScreenshot(
      tester,
      router: GoRouter(
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
      ),
      api: _VisualAuthApi(),
    );
    await _captureScreen(tester, outputDir, 'p1-02-login.png');

    await _pumpForScreenshot(
      tester,
      router: GoRouter(
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
      ),
      api: _VisualAuthApi(
        loginError: 'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.',
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'nam@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await _pumpFrame(tester);
    await _captureScreen(tester, outputDir, 'p1-02-login-error.png');

    await _pumpForScreenshot(
      tester,
      router: _registerRouter(),
      api: _VisualAuthApi(),
    );
    await _captureScreen(tester, outputDir, 'p1-03-register-top.png');

    await tester.enterText(find.byType(TextFormField).at(0), 'nam@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), '0901234567');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(3), 'different123');
    await tester.ensureVisible(find.byKey(const Key('register-submit-button')));
    await _pumpFrame(tester);
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
    await _captureScreen(
      tester,
      outputDir,
      'p1-03-register-validation-error.png',
    );

    await _pumpForScreenshot(
      tester,
      router: _otpRouter(),
      api: _VisualAuthApi(),
    );
    await _captureScreen(tester, outputDir, 'p1-04-otp.png');

    await tester.enterText(find.byType(PinCodeTextField), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('otp-confirm-button')));
    await _pumpFrame(tester);
    expect(
      find.text('Mã OTP không chính xác. Vui lòng thử lại.'),
      findsWidgets,
    );
    await _captureScreen(tester, outputDir, 'p1-04-otp-error.png');

    await _pumpForScreenshot(
      tester,
      router: _expiredOtpRouter(),
      api: _VisualAuthApi(),
    );
    await _captureScreen(tester, outputDir, 'p1-04-otp-expired.png');
  });
}

Future<void> _pumpForScreenshot(
  WidgetTester tester, {
  required GoRouter router,
  required _VisualAuthApi api,
}) async {
  await setTestViewport(tester, size: _viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWith((ref) => api),
        authSessionStoreProvider.overrideWith((ref) => _VisualSessionStore()),
      ],
      child: RepaintBoundary(
        key: _captureRootKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await _pumpFrame(tester);
  await _precacheAuthImages(tester);
}

Future<void> _precacheAuthImages(WidgetTester tester) async {
  final context = tester.element(find.byKey(_captureRootKey));
  const assets = [
    'assets/images/auth/onboarding_dog.png',
    'assets/images/auth/login_vet_dog.png',
    'assets/images/auth/register_dog.png',
    'assets/images/auth/otp_verification_dog.png',
    'assets/images/auth/otp_expired_dog.png',
  ];
  for (final asset in assets) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

GoRouter _registerRouter() {
  return GoRouter(
    initialLocation: '/auth/register',
    routes: [
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login target'))),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) =>
            OtpScreen(email: state.uri.queryParameters['email']),
      ),
    ],
  );
}

GoRouter _otpRouter() {
  final now = DateTime(2026, 7, 14, 18);
  return GoRouter(
    initialLocation: '/auth/otp?email=nam@example.com',
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login target'))),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpScreen(
          email: state.uri.queryParameters['email'],
          verificationExpiresAt: now.add(const Duration(minutes: 5)),
          resendAvailableAt: now.add(const Duration(seconds: 57)),
          now: () => now,
        ),
      ),
      GoRoute(
        path: '/pets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home target'))),
      ),
    ],
  );
}

GoRouter _expiredOtpRouter() {
  final now = DateTime(2026, 7, 14, 18);
  return GoRouter(
    initialLocation: '/auth/otp',
    routes: [
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpScreen(
          email: 'nam@example.com',
          verificationExpiresAt: now.subtract(const Duration(seconds: 1)),
          resendAvailableAt: now.subtract(const Duration(seconds: 1)),
          now: () => now,
        ),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Register target'))),
      ),
    ],
  );
}

Directory _screenshotOutputDir() {
  return Directory(
    '${Directory.current.parent.path}/temp/proof/day14_20260714/runtime_screenshots',
  );
}

Future<void> _captureScreen(
  WidgetTester tester,
  Directory outputDir,
  String fileName,
) async {
  // ignore: avoid_print
  print('CAPTURE_START $fileName');
  expectNoFlutterOverflow(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureRootKey),
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  expect(image, isNotNull);
  final capturedImage = image!;
  expect(capturedImage.width, _viewport.width.toInt());
  expect(capturedImage.height, _viewport.height.toInt());

  final bytes = await tester.runAsync(
    () => capturedImage.toByteData(format: ui.ImageByteFormat.png),
  );
  expect(bytes, isNotNull);
  final file = File('${outputDir.path}/$fileName');
  await tester.runAsync(
    () => file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true),
  );
  expect(file.lengthSync(), greaterThan(0));
  // ignore: avoid_print
  print('CAPTURE_DONE $fileName ${file.lengthSync()}');
}

Future<void> _pumpFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _VisualAuthApi extends AuthApi {
  _VisualAuthApi({this.loginError}) : super(Dio());

  final String? loginError;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (loginError != null) {
      throw AuthApiException(loginError!);
    }
    return _sampleSession();
  }

  @override
  Future<RegisterResponse> register({
    required String email,
    required String password,
    String? phone,
    String? displayName,
  }) async {
    return const RegisterResponse(
      userId: 'user-1',
      message: 'Đã gửi mã xác minh',
    );
  }

  @override
  Future<VerifyEmailResponse> verifyEmail({
    required String email,
    required String token,
  }) async {
    throw const AuthApiException('Mã OTP không chính xác. Vui lòng thử lại.');
  }
}

class _VisualSessionStore extends AuthSessionStore {
  _VisualSessionStore() : super(const FlutterSecureStorage());

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 7, 14, 18);
  });

  testWidgets('OTP shows email copy, real state controls, and disabled CTA', (
    tester,
  ) async {
    final fakeApi = _FakeAuthApi();
    final fakeStore = _FakeAuthSessionStore();
    await _pumpOtp(tester, api: fakeApi, store: fakeStore, now: () => now);

    expect(find.text('Xác minh tài khoản'), findsOneWidget);
    expect(find.text('Xác minh mã OTP'), findsOneWidget);
    expect(find.textContaining('email n***@example.com'), findsOneWidget);
    expect(find.textContaining('hộp thư'), findsOneWidget);
    expect(find.text('HỆ THỐNG ĐANG SẴN SÀNG'), findsOneWidget);
    expect(_otpButton(tester).onPressed, isNull);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'OTP resend copy is canonical at 57, 9, and 0 seconds without overlap',
    (tester) async {
      await _pumpOtp(
        tester,
        api: _FakeAuthApi(),
        store: _FakeAuthSessionStore(),
        now: () => now,
        resendAt: now.add(const Duration(seconds: 57)),
        viewport: const Size(320, 568),
        textScale: 1.3,
      );

      final resendButton = find.byKey(const ValueKey('otp-resend-button'));
      expect(
        find.descendant(
          of: resendButton,
          matching: find.text('Gửi lại mã (57s)'),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(resendButton).height, greaterThanOrEqualTo(48));
      expectNoFlutterOverflow(tester);

      now = now.add(const Duration(seconds: 48));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: resendButton,
          matching: find.text('Gửi lại mã (9s)'),
        ),
        findsOneWidget,
      );
      expectNoFlutterOverflow(tester);

      now = now.add(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(of: resendButton, matching: find.text('Gửi lại mã')),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(resendButton).onPressed, isNotNull);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('OTP success persists session atomically and routes to Home', (
    tester,
  ) async {
    final session = _sampleSession();
    final fakeApi = _FakeAuthApi(
      verifyResponse: VerifyEmailResponse(
        userId: 'user-1',
        email: 'nam@example.com',
        message: 'Email đã được xác minh',
        session: session,
      ),
    );
    final fakeStore = _FakeAuthSessionStore();
    await _pumpOtp(tester, api: fakeApi, store: fakeStore, now: () => now);

    await tester.enterText(find.byType(PinCodeTextField), '123456');
    await tester.pump();
    expect(_otpButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
    await tester.pumpAndSettle();

    expect(fakeApi.verifyCalls, 1);
    expect(fakeApi.lastToken, '123456');
    expect(fakeStore.savedSession, session);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isTrue,
    );
    expect(find.text('Home target'), findsOneWidget);
  });

  testWidgets('OTP success resumes the protected returnTo route and query', (
    tester,
  ) async {
    final fakeApi = _FakeAuthApi(
      verifyResponse: VerifyEmailResponse(
        userId: 'user-1',
        email: 'nam@example.com',
        message: 'Email đã được xác minh',
        session: _sampleSession(),
      ),
    );
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
      returnTo: '/vets/list?availability=24h',
    );

    await tester.enterText(find.byType(PinCodeTextField), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('Vet target: 24h'), findsOneWidget);
  });

  testWidgets(
    'OTP does not activate a partial session when secure save fails',
    (tester) async {
      final fakeApi = _FakeAuthApi(
        verifyResponse: VerifyEmailResponse(
          userId: 'user-1',
          email: 'nam@example.com',
          message: 'Email đã được xác minh',
          session: _sampleSession(),
        ),
      );
      final fakeStore = _FakeAuthSessionStore(throwOnSave: true);
      await _pumpOtp(tester, api: fakeApi, store: fakeStore, now: () => now);

      await tester.enterText(find.byType(PinCodeTextField), '123456');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(fakeApi.verifyCalls, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
        isNot(true),
      );
      expect(find.text('Home target'), findsNothing);
      expect(
        find.textContaining('không thể lưu phiên đăng nhập'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Invalid OTP is inline and preserves all entered digits', (
    tester,
  ) async {
    final fakeApi = _FakeAuthApi(
      verifyError: const AuthApiException(
        'Mã OTP không chính xác. Vui lòng thử lại.',
        code: 'AUTH_015',
      ),
    );
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
    );

    await tester.enterText(find.byType(PinCodeTextField), '999999');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fakeApi.verifyCalls, 1);
    expect(
      find.text('Mã OTP không chính xác. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(_otpText(tester), '999999');
    expect(find.text('Xác minh mã OTP'), findsOneWidget);
    expect(find.text('Home target'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('OTP expires after five minutes without calling verify API', (
    tester,
  ) async {
    final fakeApi = _FakeAuthApi();
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAt: now.add(const Duration(seconds: 60)),
    );

    now = now.add(const Duration(minutes: 5, seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('otp-expired-state')), findsOneWidget);
    expect(find.text('Mã xác thực đã hết hạn'), findsOneWidget);
    expect(fakeApi.verifyCalls, 0);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('OTP resyncs expiry when the app resumes', (tester) async {
    final fakeApi = _FakeAuthApi();
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAt: now.add(const Duration(seconds: 60)),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5, seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(const ValueKey('otp-expired-state')), findsOneWidget);
    expect(fakeApi.verifyCalls, 0);
  });

  testWidgets('AUTH_017 response moves OTP to expired state', (tester) async {
    final fakeApi = _FakeAuthApi(
      verifyError: const AuthApiException(
        'Mã OTP đã hết hạn. Vui lòng gửi lại mã mới.',
        code: 'AUTH_017',
      ),
    );
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
    );

    await tester.enterText(find.byType(PinCodeTextField), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('otp-expired-state')), findsOneWidget);
    expect(find.text('Mã xác thực đã hết hạn'), findsOneWidget);
    expect(fakeApi.verifyCalls, 1);
  });

  testWidgets('Resend clears OTP and applies server verification window', (
    tester,
  ) async {
    final newExpiry = now.add(const Duration(minutes: 5));
    final newResendAt = now.add(const Duration(seconds: 60));
    final fakeApi = _FakeAuthApi(
      resendResponse: ResendVerificationResponse(
        message: 'Đã gửi lại email xác minh',
        verificationExpiresAt: newExpiry,
        resendAvailableAt: newResendAt,
      ),
    );
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
      resendAt: now,
    );

    await tester.enterText(find.byType(PinCodeTextField), '123456');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('otp-resend-button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fakeApi.resendCalls, 1);
    expect(_otpText(tester), isEmpty);
    expect(find.text('Đã gửi lại email xác minh'), findsOneWidget);
    expect(find.text('Gửi lại mã (60s)'), findsOneWidget);
  });

  testWidgets('Resend failure stays on OTP and exposes recovery message', (
    tester,
  ) async {
    final fakeApi = _FakeAuthApi(
      resendError: const AuthApiException(
        'Không thể gửi lại mã lúc này. Vui lòng thử lại.',
        code: 'AUTH_016',
      ),
    );
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
      resendAt: now,
    );

    await tester.tap(find.byKey(const ValueKey('otp-resend-button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fakeApi.resendCalls, 1);
    expect(
      find.text('Không thể gửi lại mã lúc này. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Xác minh mã OTP'), findsOneWidget);
  });

  testWidgets('Expired OTP can resend and return to normal verification', (
    tester,
  ) async {
    final fakeApi = _FakeAuthApi(
      resendResponse: ResendVerificationResponse(
        message: 'Đã gửi lại email xác minh',
        verificationExpiresAt: now.add(const Duration(minutes: 5)),
        resendAvailableAt: now.add(const Duration(seconds: 60)),
      ),
    );
    await _pumpOtp(
      tester,
      api: fakeApi,
      store: _FakeAuthSessionStore(),
      now: () => now,
      expiresAt: now.subtract(const Duration(seconds: 1)),
      resendAt: now.subtract(const Duration(seconds: 1)),
    );

    await tester.tap(find.byKey(const ValueKey('otp-resend-expired-button')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fakeApi.resendCalls, 1);
    expect(find.byKey(const ValueKey('otp-expired-state')), findsNothing);
    expect(find.text('Xác minh mã OTP'), findsOneWidget);
  });

  testWidgets('Expired OTP change-email action preserves email', (
    tester,
  ) async {
    await _pumpOtp(
      tester,
      api: _FakeAuthApi(),
      store: _FakeAuthSessionStore(),
      now: () => now,
      expiresAt: now.subtract(const Duration(seconds: 1)),
      resendAt: now.subtract(const Duration(seconds: 1)),
    );

    await tester.tap(find.byKey(const ValueKey('otp-change-email-button')));
    await tester.pumpAndSettle();

    expect(find.text('Register target: nam@example.com'), findsOneWidget);
  });
}

Future<void> _pumpOtp(
  WidgetTester tester, {
  required _FakeAuthApi api,
  required _FakeAuthSessionStore store,
  required DateTime Function() now,
  DateTime? expiresAt,
  DateTime? resendAt,
  String? returnTo,
  Size viewport = const Size(390, 844),
  double textScale = 1,
}) async {
  await setTestViewport(tester, size: viewport);
  final router = GoRouter(
    initialLocation: '/auth/otp',
    routes: [
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpScreen(
          email: 'nam@example.com',
          registrationId: 'user-1',
          verificationExpiresAt: expiresAt,
          resendAvailableAt: resendAt,
          returnTo: returnTo,
          now: now,
        ),
      ),
      GoRoute(
        path: '/pets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home target'))),
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
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login target'))),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Register target: ${state.uri.queryParameters['email']}',
            ),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWith((ref) => api),
        authSessionStoreProvider.overrideWith((ref) => store),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        builder: textScale == 1 ? null : testTextScaleBuilder(textScale),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

PawMateButton _otpButton(WidgetTester tester) {
  return tester.widget<PawMateButton>(
    find.byKey(const ValueKey('otp-confirm-button')),
  );
}

String _otpText(WidgetTester tester) {
  return tester
      .widget<EditableText>(find.byType(EditableText).first)
      .controller
      .text;
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({
    this.verifyResponse,
    this.verifyError,
    this.resendResponse,
    this.resendError,
  }) : super(Dio());

  final VerifyEmailResponse? verifyResponse;
  final AuthApiException? verifyError;
  final ResendVerificationResponse? resendResponse;
  final AuthApiException? resendError;
  int verifyCalls = 0;
  int resendCalls = 0;
  String? lastToken;

  @override
  Future<VerifyEmailResponse> verifyEmail({
    required String email,
    required String token,
  }) async {
    verifyCalls += 1;
    lastToken = token;
    expect(email, 'nam@example.com');
    if (verifyError != null) {
      throw verifyError!;
    }
    return verifyResponse ??
        const VerifyEmailResponse(
          userId: 'user-1',
          email: 'nam@example.com',
          message: 'Email đã được xác minh',
        );
  }

  @override
  Future<ResendVerificationResponse> resendVerification({
    required String email,
  }) async {
    resendCalls += 1;
    expect(email, 'nam@example.com');
    if (resendError != null) {
      throw resendError!;
    }
    return resendResponse ??
        const ResendVerificationResponse(message: 'Đã gửi lại email xác minh');
  }
}

class _FakeAuthSessionStore extends AuthSessionStore {
  _FakeAuthSessionStore({this.throwOnSave = false})
    : super(const FlutterSecureStorage());

  final bool throwOnSave;
  AuthSession? savedSession;
  int clearCalls = 0;

  @override
  Future<void> save(AuthSession session) async {
    if (throwOnSave) {
      throw StateError('secure storage unavailable');
    }
    savedSession = session;
  }

  @override
  Future<AuthSession?> read() async => savedSession;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    savedSession = null;
  }
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

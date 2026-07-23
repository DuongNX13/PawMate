import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('Register requires all SRS fields and enables CTA when valid', (
    tester,
  ) async {
    final fakeApi = _FakeRegisterAuthApi();
    await _pumpRegister(tester, fakeApi);

    expect(find.text('Tạo tài khoản'), findsWidgets);
    expect(
      find.text('Hãy cùng bắt đầu hành trình chăm sóc thú cưng của bạn'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('register-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('register-phone-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('register-password-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('register-confirm-password-field')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);
    expect(_registerButton(tester).onPressed, isNull);

    await tester.enterText(_field('register-email-field'), 'nam@example.com');
    await tester.enterText(_field('register-phone-field'), '901234567');
    await tester.enterText(_field('register-password-field'), 'secret123');
    await tester.enterText(
      _field('register-confirm-password-field'),
      'secret123',
    );
    await tester.pump();
    expect(_registerButton(tester).onPressed, isNull);

    await tester.enterText(_field('register-phone-field'), '0901234567');
    await tester.pump();
    expect(_registerButton(tester).onPressed, isNotNull);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Register success routes to OTP with verification window', (
    tester,
  ) async {
    final expiresAt = DateTime(2026, 7, 14, 18, 5);
    final resendAt = DateTime(2026, 7, 14, 18, 1);
    final fakeApi = _FakeRegisterAuthApi(
      response: RegisterResponse(
        userId: 'user-1',
        message: 'Đã gửi mã xác minh',
        verificationExpiresAt: expiresAt,
        resendAvailableAt: resendAt,
      ),
    );
    await _pumpRegister(
      tester,
      fakeApi,
      returnTo: '/vets/list?availability=24h',
    );
    await _enterValidRegistration(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('register-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('register-submit-button')));
    await tester.pumpAndSettle();

    expect(fakeApi.registerCalls, 1);
    expect(fakeApi.lastEmail, 'nam@example.com');
    expect(fakeApi.lastPhone, '0901234567');
    expect(find.text('OTP target: nam@example.com'), findsOneWidget);
    expect(find.text('Registration: user-1'), findsOneWidget);
    expect(
      find.text('Expires: ${expiresAt.millisecondsSinceEpoch}'),
      findsOneWidget,
    );
    expect(
      find.text('Resend: ${resendAt.millisecondsSinceEpoch}'),
      findsOneWidget,
    );
    expect(find.text('ReturnTo: /vets/list?availability=24h'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Register API field error is inline and preserves input', (
    tester,
  ) async {
    final fakeApi = _FakeRegisterAuthApi(
      error: const AuthApiException(
        'Email đã được sử dụng.',
        code: 'AUTH_004',
        field: 'email',
      ),
    );
    await _pumpRegister(tester, fakeApi);
    await _enterValidRegistration(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('register-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Email đã được sử dụng.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(_field('register-email-field'))
          .controller
          ?.text,
      'nam@example.com',
    );
    expect(find.textContaining('OTP target:'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Register network error stays inline and allows retry', (
    tester,
  ) async {
    final fakeApi = _FakeRegisterAuthApi(
      error: const AuthApiException(
        'Không thể kết nối tới máy chủ PawMate.',
        code: 'NET_001',
      ),
    );
    await _pumpRegister(tester, fakeApi, textScale: 1.3);
    await _enterValidRegistration(tester);

    final submit = find.byKey(const ValueKey('register-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(fakeApi.registerCalls, 1);
    expect(find.text('Không thể kết nối tới máy chủ PawMate.'), findsOneWidget);
    expect(_registerButton(tester).isLoading, isFalse);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(tester.getTopLeft(submit).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(submit).dy, lessThanOrEqualTo(844));
    expect(find.textContaining('OTP target:'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('Register loading state prevents duplicate requests', (
    tester,
  ) async {
    final completer = Completer<RegisterResponse>();
    final fakeApi = _FakeRegisterAuthApi(completer: completer);
    await _pumpRegister(tester, fakeApi);
    await _enterValidRegistration(tester);

    final submit = find.byKey(const ValueKey('register-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();

    expect(fakeApi.registerCalls, 1);
    expect(_registerButton(tester).isLoading, isTrue);

    completer.complete(
      const RegisterResponse(userId: 'user-1', message: 'Đã gửi mã xác minh'),
    );
    await tester.pumpAndSettle();
    expect(find.text('OTP target: nam@example.com'), findsOneWidget);
  });
}

Future<void> _pumpRegister(
  WidgetTester tester,
  _FakeRegisterAuthApi fakeApi, {
  String? returnTo,
  double textScale = 1,
}) async {
  await setTestViewport(tester, size: const Size(390, 844));
  final router = _registerRouter(returnTo: returnTo);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authApiProvider.overrideWith((ref) => fakeApi)],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        builder: textScale == 1 ? null : testTextScaleBuilder(textScale),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterValidRegistration(WidgetTester tester) async {
  await tester.enterText(_field('register-email-field'), 'nam@example.com');
  await tester.enterText(_field('register-phone-field'), '0901234567');
  await tester.enterText(_field('register-password-field'), 'secret123');
  await tester.enterText(
    _field('register-confirm-password-field'),
    'secret123',
  );
  await tester.pump();
}

Finder _field(String key) {
  return find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );
}

PawMateButton _registerButton(WidgetTester tester) {
  return tester.widget<PawMateButton>(
    find.byKey(const ValueKey('register-submit-button')),
  );
}

GoRouter _registerRouter({String? returnTo}) {
  return GoRouter(
    initialLocation: Uri(
      path: '/auth/register',
      queryParameters: returnTo == null ? null : {'returnTo': returnTo},
    ).toString(),
    routes: [
      GoRoute(
        path: '/auth/register',
        builder: (context, state) =>
            RegisterScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login target'))),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text('OTP target: ${state.uri.queryParameters['email']}'),
              Text(
                'Registration: ${state.uri.queryParameters['registrationId']}',
              ),
              Text('Expires: ${state.uri.queryParameters['expiresAt']}'),
              Text('Resend: ${state.uri.queryParameters['resendAt']}'),
              Text('ReturnTo: ${state.uri.queryParameters['returnTo']}'),
            ],
          ),
        ),
      ),
    ],
  );
}

class _FakeRegisterAuthApi extends AuthApi {
  _FakeRegisterAuthApi({this.response, this.error, this.completer})
    : super(Dio());

  final RegisterResponse? response;
  final AuthApiException? error;
  final Completer<RegisterResponse>? completer;
  int registerCalls = 0;
  String? lastEmail;
  String? lastPhone;

  @override
  Future<RegisterResponse> register({
    required String email,
    required String password,
    String? phone,
    String? displayName,
  }) async {
    registerCalls += 1;
    lastEmail = email;
    lastPhone = phone;
    expect(password, 'secret123');
    if (error != null) {
      throw error!;
    }
    if (completer != null) {
      return completer!.future;
    }
    return response ??
        const RegisterResponse(userId: 'user-1', message: 'Đã gửi mã xác minh');
  }
}

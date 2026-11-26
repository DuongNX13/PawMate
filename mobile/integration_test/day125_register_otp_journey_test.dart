// Day 125 journey 1: Register -> OTP -> authenticated landing, against the
// local backend, which verifies email through the real Supabase Auth project.
// The operator reads the code from the inbox and writes it into the app's
// private files dir:
//   adb shell run-as com.pawmate.pawmate_mobile sh -c 'echo 123456 > files/day125-otp.txt'
// Run with --dart-define=DAY125_EMAIL=<inbox the user approved>.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/presentation/login_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = String.fromEnvironment('DAY125_EMAIL');
const _otpFile = '/data/user/0/com.pawmate.pawmate_mobile/files/day125-otp.txt';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day125 journey 1 register, OTP and landing on local backend', (
    tester,
  ) async {
    expect(_email, isNotEmpty, reason: 'Pass --dart-define=DAY125_EMAIL');
    final otp = File(_otpFile);
    if (otp.existsSync()) otp.deleteSync();
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final router = GoRouter(
      initialLocation: '/auth/register',
      routes: [
        GoRoute(
          path: '/auth/register',
          builder: (_, s) => RegisterScreen(
            initialEmail: s.uri.queryParameters['email'],
            returnTo: s.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (_, s) => OtpScreen(
            email: s.uri.queryParameters['email'],
            registrationId: s.uri.queryParameters['registrationId'],
            verificationExpiresAt: _epoch(s.uri.queryParameters['expiresAt']),
            resendAvailableAt: _epoch(s.uri.queryParameters['resendAt']),
            returnTo: s.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (_, s) => LoginScreen(
            initialEmail: s.uri.queryParameters['email'],
            showVerifiedMessage: s.uri.queryParameters['verified'] == '1',
            returnTo: s.uri.queryParameters['returnTo'],
          ),
        ),
        // Authenticated landing. Login -> Home itself is covered by day21.
        GoRoute(
          path: '/pets',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('DAY125-HOME'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWith((ref) => dio)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('register-email-field')),
      _email,
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-phone-field')),
      '0901125125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'Day125Otp!x',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'Day125Otp!x',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // "Done" on the last field already submits the form.
    final submit = find.byKey(const ValueKey('register-submit-button'));
    if (submit.evaluate().isNotEmpty) {
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
    }
    await _waitFor(
      tester,
      find.byKey(const ValueKey('otp-code-field')),
      orFail: find.byKey(const ValueKey('register-general-error')),
      timeout: const Duration(seconds: 40),
    );
    // ignore: avoid_print
    print('DAY125 OTP-SCREEN READY');

    final deadline = DateTime.now().add(const Duration(minutes: 9));
    while (!otp.existsSync() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(otp.existsSync(), isTrue, reason: 'OTP file not provided');
    final code = otp.readAsStringSync().trim();
    otp.deleteSync();

    await tester.enterText(find.byKey(const ValueKey('otp-code-field')), code);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
    final home = find.text('DAY125-HOME');
    final login = find.byType(LoginScreen);
    await _waitFor(
      tester,
      find.byWidgetPredicate((_) => home.evaluate().isNotEmpty || login.evaluate().isNotEmpty),
      timeout: const Duration(seconds: 40),
    );
    expect(tester.takeException(), isNull);
    final landed = home.evaluate().isNotEmpty ? 'home' : 'login-verified';
    // ignore: avoid_print
    print('DAY125 REGISTER-OTP PASS landed=$landed');
  }, timeout: const Timeout(Duration(minutes: 12)));
}

DateTime? _epoch(String? value) {
  final ms = int.tryParse(value ?? '');
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Finder? orFail,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
    if (orFail != null && orFail.evaluate().isNotEmpty) {
      final text = tester
          .widgetList<Text>(
            find.descendant(of: orFail, matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .join(' ');
      fail('Register error: $text');
    }
  }
  expect(finder, findsAtLeastNWidgets(1));
}

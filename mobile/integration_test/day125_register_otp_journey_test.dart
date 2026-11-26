// Day 125/126 journey 1: Register -> verification email link -> Login -> Home,
// against the local backend, which verifies email through the real Supabase
// Auth project. After clicking the link in the inbox, the operator signals the
// test by writing a marker into the app's private files dir:
//   adb shell run-as com.pawmate.pawmate_mobile sh -c 'touch files/day125-verified.txt'
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
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/verify_email_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = String.fromEnvironment('DAY125_EMAIL');
const _markerFile =
    '/data/user/0/com.pawmate.pawmate_mobile/files/day125-verified.txt';
const _password = 'Day125Otp!x';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day125 journey 1 register, email link and login on local backend', (
    tester,
  ) async {
    expect(_email, isNotEmpty, reason: 'Pass --dart-define=DAY125_EMAIL');
    final marker = File(_markerFile);
    if (marker.existsSync()) marker.deleteSync();
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
          path: '/auth/verify-email',
          builder: (_, s) => VerifyEmailScreen(
            email: s.uri.queryParameters['email'],
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
      _password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      _password,
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
      find.byKey(const ValueKey('verify-email-login-button')),
      orFail: find.byKey(const ValueKey('register-general-error')),
      timeout: const Duration(seconds: 40),
    );
    // ignore: avoid_print
    print('DAY125 VERIFY-EMAIL-SCREEN READY');

    final deadline = DateTime.now().add(const Duration(minutes: 9));
    while (!marker.existsSync() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(marker.existsSync(), isTrue, reason: 'Verified marker not provided');
    marker.deleteSync();

    await tester.tap(find.byKey(const ValueKey('verify-email-login-button')));
    await _waitFor(tester, find.byType(LoginScreen));
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      _password,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final loginSubmit = find.byKey(const Key('login-submit-button'));
    final home = find.text('DAY125-HOME');
    if (home.evaluate().isEmpty && loginSubmit.evaluate().isNotEmpty) {
      await tester.ensureVisible(loginSubmit);
      await tester.pumpAndSettle();
      await tester.tap(loginSubmit);
    }
    await _waitFor(
      tester,
      home,
      orFail: find.byKey(const Key('login-error-banner')),
      timeout: const Duration(seconds: 40),
    );
    expect(tester.takeException(), isNull);
    // ignore: avoid_print
    print('DAY125 REGISTER-LINK-LOGIN PASS');
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

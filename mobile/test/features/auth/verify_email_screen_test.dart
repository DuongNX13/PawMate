import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/presentation/verify_email_screen.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(Dio());
  int resendCalls = 0;

  @override
  Future<ResendVerificationResponse> resendVerification({
    required String email,
  }) async {
    resendCalls++;
    return ResendVerificationResponse.fromJson(const {
      'message': 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
      'verificationStatus': 'pending',
    });
  }
}

void main() {
  late DateTime clock;
  late _FakeAuthApi api;

  Future<GoRouter> pump(WidgetTester tester, {DateTime? resendAt}) async {
    final router = GoRouter(
      initialLocation: '/auth/verify-email',
      routes: [
        GoRoute(
          path: '/auth/verify-email',
          builder: (_, _) => VerifyEmailScreen(
            email: 'owner@example.test',
            resendAvailableAt: resendAt,
            now: () => clock,
          ),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (_, s) =>
              Scaffold(body: Text('Login ${s.uri.queryParameters['email']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  setUp(() {
    clock = DateTime(2026, 11, 26, 12);
    api = _FakeAuthApi();
  });

  testWidgets('shows the masked email and no code field', (tester) async {
    await pump(tester);
    expect(find.textContaining('o***@example.test'), findsOneWidget);
    expect(find.textContaining('owner@example.test'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('resend waits for the cooldown', (tester) async {
    await pump(tester, resendAt: clock.add(const Duration(seconds: 30)));
    await tester.tap(find.byKey(const ValueKey('verify-email-resend-button')));
    await tester.pump();
    expect(api.resendCalls, 0);

    clock = clock.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('verify-email-resend-button')));
    await tester.pump();
    expect(api.resendCalls, 1);
  });

  testWidgets('login button opens Login with the email filled in', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('verify-email-login-button')));
    await tester.pumpAndSettle();
    expect(find.text('Login owner@example.test'), findsOneWidget);
  });
}

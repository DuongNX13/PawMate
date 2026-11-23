import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _viewport = Size(390, 844);
const _registerExtraViewports = <Size>[
  Size(320, 568),
  Size(360, 844),
  Size(412, 915),
  Size(430, 932),
];
const _otpExtraViewports = <Size>[Size(360, 844), Size(430, 932)];
const _goldenRootKey = Key('day14-register-otp-golden-root');

Future<void> pumpDay120Auth(
  WidgetTester tester,
  Size size, {
  required bool otp,
}) async {
  final now = DateTime(2026, 7, 14, 18);
  await _pumpGolden(
    tester,
    otp
        ? OtpScreen(
            email: 'nam@example.com',
            registrationId: 'user-1',
            verificationExpiresAt: now.add(const Duration(minutes: 5)),
            resendAvailableAt: now.add(const Duration(seconds: 57)),
            now: () => now,
          )
        : const RegisterScreen(),
    viewport: size,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-03 Register golden at 390x844', (tester) async {
    await _pumpGolden(tester, const RegisterScreen());

    expectNoFlutterOverflow(tester);
    expect(find.text('0/254'), findsNothing);
    expect(find.text('0/11'), findsNothing);
    expect(find.text('0/64'), findsNothing);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('register-login-cta')))
          .dy,
      lessThanOrEqualTo(_viewport.height),
    );
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day14/p1-03-register-390x844.png'),
    );
    await _disposeGolden(tester);
  });

  testWidgets('P1-04 OTP golden at 390x844', (tester) async {
    final now = DateTime(2026, 7, 14, 18);
    await _pumpGolden(
      tester,
      OtpScreen(
        email: 'nam@example.com',
        registrationId: 'user-1',
        verificationExpiresAt: now.add(const Duration(minutes: 5)),
        resendAvailableAt: now.add(const Duration(seconds: 57)),
        now: () => now,
      ),
    );
    await _enterRejectedOtp(tester);

    expectNoFlutterOverflow(tester);
    expect(find.text('Gửi lại mã (57s)'), findsOneWidget);
    final otpIllustrationSize = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('otp-illustration')),
        matching: find.byType(Image),
      ),
    );
    expect(otpIllustrationSize.width, inInclusiveRange(160, 168));
    expect(otpIllustrationSize.height, otpIllustrationSize.width);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const ValueKey('otp-confirm-button')),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .height,
      AppControlSize.compactButtonVisualHeight,
    );
    expect(
      find.text('Mã OTP không chính xác. Vui lòng thử lại.'),
      findsOneWidget,
    );
    _expectOtpFieldsInsideViewport(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day14/p1-04-otp-390x844.png'),
    );
    await _disposeGolden(tester);
  });

  testWidgets('ST-17 OTP expired golden at 390x844', (tester) async {
    final now = DateTime(2026, 7, 14, 18);
    await _pumpGolden(
      tester,
      OtpScreen(
        email: 'nam@example.com',
        registrationId: 'user-1',
        verificationExpiresAt: now.subtract(const Duration(seconds: 1)),
        resendAvailableAt: now.subtract(const Duration(seconds: 1)),
        now: () => now,
      ),
    );

    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenRootKey),
      matchesGoldenFile('goldens/day14/st-17-otp-expired-390x844.png'),
    );
    await _disposeGolden(tester);
  });

  for (final viewport in _registerExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-03 Register responsive golden at $tag', (tester) async {
      await _pumpGolden(tester, const RegisterScreen(), viewport: viewport);

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day14/p1-03-register-$tag.png'),
      );
      await _disposeGolden(tester);
    });
  }

  for (final viewport in _otpExtraViewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P1-04 OTP responsive golden at $tag', (tester) async {
      final now = DateTime(2026, 7, 14, 18);
      await _pumpGolden(
        tester,
        OtpScreen(
          email: 'nam@example.com',
          registrationId: 'user-1',
          verificationExpiresAt: now.add(const Duration(minutes: 5)),
          resendAvailableAt: now.add(const Duration(seconds: 57)),
          now: () => now,
        ),
        viewport: viewport,
      );
      await _enterRejectedOtp(tester);

      expectNoFlutterOverflow(tester);
      expect(find.text('Gửi lại mã (57s)'), findsOneWidget);
      _expectOtpFieldsInsideViewport(tester);
      await expectLater(
        find.byKey(_goldenRootKey),
        matchesGoldenFile('goldens/day14/p1-04-otp-$tag.png'),
      );
      await _disposeGolden(tester);
    });
  }
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget screen, {
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authApiProvider.overrideWith((ref) => _GoldenAuthApi())],
      child: RepaintBoundary(
        key: _goldenRootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byKey(_goldenRootKey));
  for (final asset in const [
    'assets/images/auth/register_dog.png',
    'assets/images/auth/otp_verification_dog.png',
    'assets/images/auth/otp_expired_dog.png',
  ]) {
    await tester.runAsync(() => precacheImage(AssetImage(asset), context));
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _disposeGolden(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _enterRejectedOtp(WidgetTester tester) async {
  final input = find.descendant(
    of: find.byKey(const ValueKey('otp-code-field')),
    matching: find.byType(EditableText),
  );
  await tester.enterText(input, '123456');
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('otp-confirm-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  final scrollable = find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );
  tester.state<ScrollableState>(scrollable.first).position.jumpTo(0);
  await tester.pump();
}

void _expectOtpFieldsInsideViewport(WidgetTester tester) {
  final fields = find.descendant(
    of: find.byKey(const ValueKey('otp-code-field')),
    matching: find.byType(AnimatedContainer),
  );
  expect(fields, findsNWidgets(6));
  final viewportWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (final element in fields.evaluate()) {
    final rect = tester.getRect(
      find.byElementPredicate((candidate) {
        return identical(candidate, element);
      }),
    );
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(viewportWidth));
  }
}

class _GoldenAuthApi extends AuthApi {
  _GoldenAuthApi() : super(Dio());

  @override
  Future<VerifyEmailResponse> verifyEmail({
    required String email,
    required String token,
  }) async {
    throw const AuthApiException(
      'Mã OTP không chính xác. Vui lòng thử lại.',
      code: 'AUTH_016',
    );
  }
}

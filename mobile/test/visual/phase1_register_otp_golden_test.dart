import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P1-03 Register golden at 390x844', (tester) async {
    await _pumpGolden(tester, const RegisterScreen());

    expectNoFlutterOverflow(tester);
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

    expectNoFlutterOverflow(tester);
    expect(find.text('Gửi lại mã (57s)'), findsOneWidget);
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

      expectNoFlutterOverflow(tester);
      expect(find.text('Gửi lại mã (57s)'), findsOneWidget);
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

class _GoldenAuthApi extends AuthApi {
  _GoldenAuthApi() : super(Dio());
}

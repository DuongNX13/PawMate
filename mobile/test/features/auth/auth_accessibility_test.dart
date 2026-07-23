import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('Register remains usable at 1.3 text scale with a 48dp CTA', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.3),
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey('register-submit-button'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(
        'Minh họa chó cưng chào đón người dùng tạo tài khoản',
      ),
      findsOneWidget,
    );
    expect(find.text('Tạo tài khoản'), findsWidgets);
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('OTP remains usable at 1.3 text scale with a 48dp CTA', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.3),
          home: OtpScreen(
            email: 'nam@example.com',
            verificationExpiresAt: DateTime.now().add(
              const Duration(minutes: 5),
            ),
            resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
          ),
        ),
      ),
    );
    await tester.pump();

    final submit = find.byKey(const ValueKey('otp-confirm-button'));
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel('Minh họa chó cưng cho bước xác minh tài khoản'),
      findsOneWidget,
    );
    expect(find.text('Xác minh mã OTP'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });
}

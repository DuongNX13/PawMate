import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P1-04 OTP header and readiness note remain readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: OtpScreen(
            email: 'nam@example.com',
            verificationExpiresAt: DateTime(2026, 8, 5, 12),
            resendAvailableAt: DateTime(2026, 8, 5, 11, 1),
            now: () => DateTime(2026, 8, 5, 11),
          ),
        ),
      );
      // OtpScreen owns a one-second countdown timer, so this route never
      // reaches a perpetual "settled" state in the integration harness.
      await tester.pump();

      for (final label in ['Xác minh tài khoản', 'HỆ THỐNG ĐANG SẴN SÀNG']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      for (final finder in [
        find.text('Xác minh').first,
        find.text('SẴN SÀNG'),
      ]) {
        expect(finder, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}

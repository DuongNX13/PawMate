import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';

void main() {
  test('RegisterResponse parses the server verification window', () {
    final response = RegisterResponse.fromJson({
      'userId': 'user-1',
      'message': 'Check your email',
      'verificationStatus': 'pending',
      'verificationExpiresAt': '2026-07-14T11:05:00.000Z',
      'resendAvailableAt': '2026-07-14T11:01:00.000Z',
    });

    expect(response.userId, 'user-1');
    expect(response.requiresVerification, isTrue);
    expect(
      response.verificationExpiresAt?.toUtc(),
      DateTime.utc(2026, 7, 14, 11, 5),
    );
    expect(
      response.resendAvailableAt?.toUtc(),
      DateTime.utc(2026, 7, 14, 11, 1),
    );
  });

  test('RegisterResponse recognizes an already verified account', () {
    final response = RegisterResponse.fromJson({
      'userId': 'user-2',
      'message': 'You can log in now',
      'verificationStatus': 'verified',
    });

    expect(response.requiresVerification, isFalse);
    expect(response.verificationExpiresAt, isNull);
    expect(response.resendAvailableAt, isNull);
  });

  test('ResendVerificationResponse parses a fresh verification window', () {
    final response = ResendVerificationResponse.fromJson({
      'message': 'Verification email resent',
      'verificationStatus': 'pending',
      'verificationExpiresAt': '2026-07-14T12:05:00.000Z',
      'resendAvailableAt': '2026-07-14T12:01:00.000Z',
    });

    expect(response.verificationStatus, 'pending');
    expect(
      response.verificationExpiresAt?.difference(response.resendAvailableAt!),
      const Duration(minutes: 4),
    );
  });
}

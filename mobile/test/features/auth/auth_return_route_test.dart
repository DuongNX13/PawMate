import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/presentation/auth_return_route.dart';

void main() {
  group('sanitizeAuthenticatedReturnRoute', () {
    test('preserves an internal protected route and query', () {
      expect(
        sanitizeAuthenticatedReturnRoute('/vets/list?availability=24h'),
        '/vets/list?availability=24h',
      );
    });

    test('rejects absolute and protocol-relative external destinations', () {
      expect(
        sanitizeAuthenticatedReturnRoute('https://evil.example/profile'),
        isNull,
      );
      expect(
        sanitizeAuthenticatedReturnRoute('//evil.example/profile'),
        isNull,
      );
      expect(
        sanitizeAuthenticatedReturnRoute('/%2F%2Fevil.example/profile'),
        isNull,
      );
      expect(
        sanitizeAuthenticatedReturnRoute('/%5C%5Cevil.example/profile'),
        isNull,
      );
      expect(
        sanitizeAuthenticatedReturnRoute(r'/\evil.example\profile'),
        isNull,
      );
    });

    test('rejects auth and launch-loop destinations', () {
      expect(sanitizeAuthenticatedReturnRoute('/auth/login'), isNull);
      expect(sanitizeAuthenticatedReturnRoute('/auth/register'), isNull);
      expect(sanitizeAuthenticatedReturnRoute('/launch'), isNull);
      expect(sanitizeAuthenticatedReturnRoute('/onboarding'), isNull);
    });

    test('rejects unknown internal-looking destinations', () {
      expect(sanitizeAuthenticatedReturnRoute('/totally-unknown'), isNull);
      expect(
        sanitizeAuthenticatedReturnRoute('/pets/not-safe%2Fchild'),
        isNull,
      );
      expect(
        sanitizeAuthenticatedReturnRoute('/rescue/case-1/unknown'),
        isNull,
      );
    });

    test('falls back to Phase 1 Home for a rejected destination', () {
      expect(
        resolveAuthenticatedReturnRoute('https://evil.example/profile'),
        defaultAuthenticatedRoute,
      );
    });
  });
}

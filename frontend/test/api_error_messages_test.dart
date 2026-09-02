import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_error_messages.dart';
import 'package:frontend/services/auth_service.dart';

/// easy_localization returns the key itself when no translations are loaded,
/// so these assert which *key* the mapping selects. That is the logic worth
/// pinning; the wording lives in assets/translations and can change freely.
void main() {
  group('describeApiError', () {
    test('a duplicate phone gets its own actionable message', () {
      final message = describeApiError(
        PhoneAlreadyRegisteredException(),
        fallbackKey: 'auth.request_failed',
      );

      expect(message, 'auth.phone_already_registered');
    });

    test('401 defaults to session-expired', () {
      final message = describeApiError(
        AuthException('nope', statusCode: 401),
        fallbackKey: 'eligibility.save_failed',
      );

      expect(message, 'auth.session_expired');
    });

    test('401 uses the caller override, so login can say "wrong password"', () {
      final message = describeApiError(
        AuthException('nope', statusCode: 401),
        fallbackKey: 'auth.request_failed',
        unauthorizedKey: 'auth.invalid_credentials',
      );

      expect(message, 'auth.invalid_credentials');
    });

    test('another explained status falls back to the screen message', () {
      for (final status in [400, 409, 422, 500]) {
        expect(
          describeApiError(
            AuthException('boom', statusCode: status),
            fallbackKey: 'location.save_failed',
          ),
          'location.save_failed',
          reason: 'status $status should use the screen fallback',
        );
      }
    });

    test('an AuthException with no status reads as a connection problem', () {
      final message = describeApiError(
        AuthException('no status'),
        fallbackKey: 'location.save_failed',
      );

      expect(message, 'auth.request_failed');
    });

    test('a raw socket/client failure reads as a connection problem', () {
      // http surfaces an unreachable host as ClientException, which never
      // passes through AuthService's status handling.
      final message = describeApiError(
        Exception('Connection refused'),
        fallbackKey: 'eligibility.save_failed',
      );

      expect(message, 'auth.request_failed');
    });
  });

  group('isUnauthorized', () {
    test('true only for a 401 AuthException', () {
      expect(isUnauthorized(AuthException('x', statusCode: 401)), isTrue);
      expect(isUnauthorized(AuthException('x', statusCode: 403)), isFalse);
      expect(isUnauthorized(AuthException('x')), isFalse);
      expect(isUnauthorized(PhoneAlreadyRegisteredException()), isFalse);
      expect(isUnauthorized(Exception('offline')), isFalse);
    });
  });
}

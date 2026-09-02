import 'package:easy_localization/easy_localization.dart';

import '../../services/auth_service.dart';

/// Translates a thrown request failure into a message worth showing a user.
///
/// Three kinds of failure reach the wizard screens:
///
///   * [PhoneAlreadyRegisteredException] — the one case with a genuinely
///     actionable message ("log in instead"), so it is matched first.
///   * [AuthException] — an HTTP status the backend explained. A 401 is
///     deliberately *not* handled here because it means different things per
///     screen: wrong credentials on login, an expired session everywhere
///     else. Callers pass the right [unauthorizedKey].
///   * anything else — `http` surfaces connection failures as raw
///     `ClientException`/`SocketException`, so an unrecognised error is
///     reported as a connectivity problem rather than swallowed.
///
/// [fallbackKey] is the screen's own "this operation failed, try again" string.
String describeApiError(
  Object error, {
  required String fallbackKey,
  String unauthorizedKey = 'auth.session_expired',
}) {
  if (error is PhoneAlreadyRegisteredException) {
    return 'auth.phone_already_registered'.tr();
  }
  if (error is AuthException) {
    if (error.statusCode == 401) return unauthorizedKey.tr();
    // A status the server explained (409, 422, 5xx...): the screen's own
    // message is more useful to a user than the raw backend detail string.
    if (error.statusCode != null) return fallbackKey.tr();
    return 'auth.request_failed'.tr();
  }
  return 'auth.request_failed'.tr();
}

/// Whether [error] means the stored token is no longer accepted.
///
/// Only meaningful for calls that sent a token; a 401 from login means bad
/// credentials, not an expired session.
bool isUnauthorized(Object error) =>
    error is AuthException && error.statusCode == 401;

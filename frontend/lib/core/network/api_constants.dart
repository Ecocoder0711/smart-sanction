import 'package:flutter/foundation.dart';

/// Resolves the backend base URL for local development.
///
/// The host that reaches "your machine" differs per target, so the default is
/// chosen from the platform rather than hardcoded in one place:
///
///   * Android emulator      -> 10.0.2.2   (the emulator's alias for the host)
///   * iOS simulator/desktop -> 127.0.0.1  (shares the host's loopback)
///
/// Neither default works from a *physical* device, which must reach the host
/// over the LAN. Supply the machine's LAN address at build/run time instead of
/// editing this file:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000/api
///
/// The same switch points the app at a staging or HTTPS deployment later, so
/// no IP address ever needs to be committed.
class ApiConstants {
  ApiConstants._();

  /// Compile-time override; empty when `--dart-define=API_BASE_URL` is unset.
  static const String _overrideBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const int _defaultPort = 8000;
  static const String _apiPrefix = '/api';

  /// Host that reaches the developer machine from the current target.
  static String get _defaultHost {
    if (kIsWeb) return 'localhost';
    return defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
  }

  /// Base URL for every backend call, e.g. `http://10.0.2.2:8000/api`.
  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    return 'http://$_defaultHost:$_defaultPort$_apiPrefix';
  }

  /// True when the resolved URL is plaintext HTTP, which the platform network
  /// configuration only permits for local development.
  static bool get isCleartext => baseUrl.startsWith('http://');
}

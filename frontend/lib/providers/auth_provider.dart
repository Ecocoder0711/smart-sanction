import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const String _tokenKey = 'access_token';

  final AuthService _authService;

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;

  /// Last known profile from the backend, or null before one is loaded.
  Map<String, dynamic>? get user => _user;

  /// Backend-derived flag: false while annual_income, category, or gender are
  /// still missing. Eligibility and matching reject incomplete profiles, so
  /// this is the signal for whether the applicant still owes profile details.
  bool get isProfileComplete => _user?['profile_complete'] == true;

  Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    notifyListeners();
  }

  Future<void> login({required String phone, required String password}) async {
    await _run(() async {
      final result = await _authService.login(phone: phone, password: password);
      _user = result.user;
      await _persistToken(result.accessToken);
    });
  }

  /// Registers with credentials only and logs straight in.
  ///
  /// The profile fields are supplied afterwards through [updateProfile]; the
  /// backend stores them as null until then rather than inventing defaults.
  Future<void> registerMinimal({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    await _run(() async {
      await _authService.register(
        fullName: fullName,
        phone: phone,
        password: password,
      );
      // Registration returns the profile but no token; log in to obtain one.
      final result = await _authService.login(phone: phone, password: password);
      _user = result.user;
      await _persistToken(result.accessToken);
    });
  }

  /// Registers with a full profile in one call, then logs in.
  ///
  /// Kept for the existing single-screen registration flow; the wizard uses
  /// [registerMinimal] plus [updateProfile] instead.
  Future<void> register({
    required String fullName,
    required String phone,
    required String password,
    double? annualIncome,
    String? category,
    String? gender,
    double? latitude,
    double? longitude,
  }) async {
    await _run(() async {
      await _authService.register(
        fullName: fullName,
        phone: phone,
        password: password,
        annualIncome: annualIncome,
        category: category,
        gender: gender,
        latitude: latitude,
        longitude: longitude,
      );
      final result = await _authService.login(phone: phone, password: password);
      _user = result.user;
      await _persistToken(result.accessToken);
    });
  }

  /// Sends a partial profile update and stores the refreshed user.
  ///
  /// Used for both the profile step (income/category/gender/state/district)
  /// and the location step (latitude/longitude).
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final token = _token;
    if (token == null) {
      throw AuthException('Not signed in', statusCode: 401);
    }

    await _run(() async {
      _user = await _authService.updateProfile(fields: fields, token: token);
    });
  }

  /// Refreshes the cached profile, e.g. after restoring a stored token.
  Future<void> refreshUser() async {
    final token = _token;
    if (token == null) return;

    await _run(() async {
      _user = await _authService.fetchCurrentUser(token: token);
    });
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  /// Runs an operation with the loading flag set, always clearing it.
  Future<void> _run(Future<void> Function() operation) async {
    _isLoading = true;
    notifyListeners();
    try {
      await operation();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    notifyListeners();
  }
}

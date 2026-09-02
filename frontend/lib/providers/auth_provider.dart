import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const String _tokenKey = 'access_token';

  final AuthService _authService;

  String? _token;
  bool _isLoading = false;

  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;

  Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    notifyListeners();
  }

  Future<void> login({required String phone, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.login(phone: phone, password: password);
      await _persistToken(result.accessToken);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String password,
    required double annualIncome,
    required String category,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.register(
        fullName: fullName,
        phone: phone,
        password: password,
        annualIncome: annualIncome,
        category: category,
        latitude: latitude,
        longitude: longitude,
      );
      // Registration alone returns no token; log in immediately to obtain one.
      final result = await _authService.login(phone: phone, password: password);
      await _persistToken(result.accessToken);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> _persistToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    notifyListeners();
  }
}

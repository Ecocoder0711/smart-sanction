import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/api_constants.dart';

class PhoneAlreadyRegisteredException implements Exception {
  PhoneAlreadyRegisteredException([
    this.message = 'Phone number is already registered',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResult {
  AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final Map<String, dynamic> user;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String password,
    required double annualIncome,
    required String category,
    double? latitude,
    double? longitude,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/auth/register');

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'phone': phone,
        'password': password,
        'annual_income': annualIncome,
        'category': category,
        'latitude': ?latitude,
        'longitude': ?longitude,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 409) {
      throw PhoneAlreadyRegisteredException();
    }

    throw AuthException(
      _extractDetail(response.body) ?? 'Registration failed',
      statusCode: response.statusCode,
    );
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/auth/login');

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthResult(
        accessToken: data['access_token'] as String,
        user: data['user'] as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 401) {
      throw AuthException('Invalid phone or password', statusCode: 401);
    }

    throw AuthException(
      _extractDetail(response.body) ?? 'Login failed',
      statusCode: response.statusCode,
    );
  }

  String? _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // Response body was not JSON; fall through to the generic message.
    }
    return null;
  }
}

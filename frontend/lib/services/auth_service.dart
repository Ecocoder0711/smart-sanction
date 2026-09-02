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

  /// Registers an applicant.
  ///
  /// Only [fullName], [phone], and [password] are required: the backend
  /// supports multi-step registration, so the profile fields may be supplied
  /// later through [updateProfile]. Omitted fields are left null rather than
  /// defaulted, which keeps the account's `profile_complete` false until the
  /// applicant actually answers them.
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String password,
    double? annualIncome,
    String? category,
    String? gender,
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
        'annual_income': ?annualIncome,
        'category': ?category,
        'gender': ?gender,
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

  /// Applies a partial profile update through `PUT /api/users/me`.
  ///
  /// [fields] must contain only keys the backend's UserUpdate schema accepts
  /// (full_name, phone, annual_income, category, gender, state, district,
  /// latitude, longitude); it forbids unknown keys. Absent values should be
  /// omitted rather than sent as null. Returns the updated user, whose
  /// `profile_complete` flag reports whether eligibility and matching can run.
  Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> fields,
    required String token,
  }) async {
    if (fields.isEmpty) {
      throw AuthException('No profile fields to update');
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}/users/me');
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(fields),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      throw AuthException('Session expired; sign in again', statusCode: 401);
    }

    throw AuthException(
      _extractDetail(response.body) ?? 'Profile update failed',
      statusCode: response.statusCode,
    );
  }

  /// Loads the token owner's profile from `GET /api/users/me`.
  Future<Map<String, dynamic>> fetchCurrentUser({required String token}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/users/me');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      throw AuthException('Session expired; sign in again', statusCode: 401);
    }

    throw AuthException(
      _extractDetail(response.body) ?? 'Could not load profile',
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

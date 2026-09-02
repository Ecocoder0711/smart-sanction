import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/api_constants.dart';
import '../models/match_result.dart';
import '../models/scheme.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<dynamic> _get(String endpoint, {String? token}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    try {
      final response = await _client.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw ApiException(
        'Request to $endpoint failed with status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to reach $endpoint: $error');
    }
  }

  Future<dynamic> _post(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw ApiException(
        'Request to $endpoint failed with status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to reach $endpoint: $error');
    }
  }

  Future<dynamic> _put(
    String endpoint, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    try {
      final response = await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw ApiException(
        'Request to $endpoint failed with status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Failed to reach $endpoint: $error');
    }
  }

  /// Updates the applicant's income and category.
  ///
  /// The backend's UserUpdate schema also accepts gender, state, district,
  /// latitude, and longitude. For partial updates across the registration
  /// wizard use `AuthService.updateProfile`, which sends an arbitrary subset
  /// and returns the refreshed user including `profile_complete`.
  Future<void> updateProfile({
    required double annualIncome,
    required String category,
    required String token,
  }) async {
    await _put(
      '/users/me',
      body: {'annual_income': annualIncome, 'category': category},
      token: token,
    );
  }

  Future<MatchResult> fetchMatches({
    required double requestedAmount,
    required int tenureMonths,
    required String token,
  }) async {
    final data = await _post(
      '/match',
      body: {
        'requested_amount': requestedAmount,
        'tenure_months': tenureMonths,
      },
      token: token,
    );

    return MatchResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Scheme>> fetchSchemes({String? token}) async {
    final data = await _get('/schemes', token: token);

    final List<dynamic> rawItems;
    if (data is Map<String, dynamic> && data['items'] is List) {
      rawItems = data['items'] as List<dynamic>;
    } else if (data is List<dynamic>) {
      rawItems = data;
    } else {
      throw ApiException('Unexpected response shape for /schemes');
    }

    return rawItems
        .map((item) => Scheme.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

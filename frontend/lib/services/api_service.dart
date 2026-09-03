import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/api_constants.dart';
import '../core/network/request_formatting.dart';
import '../models/loan_application.dart';
import '../models/match_result.dart';
import '../models/scheme.dart';
import '../models/scheme_calculation.dart';

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
    // Most endpoints answer 200; creation answers 201.
    int expectedStatus = 200,
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

      if (response.statusCode == expectedStatus) {
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

  /// Calculates repayment for one scheme using its stored interest rate.
  ///
  /// Public endpoint — no token — and the rate comes from the server, so a
  /// stale client-side rate cannot skew the result. Amounts are rounded to
  /// paise first because the contract is `Decimal(decimal_places=2)`.
  ///
  /// Throws [ApiException] with statusCode 404 for an unknown scheme and 400
  /// for an inactive one. Note the endpoint deliberately does not reject an
  /// amount above the scheme's limit: it is a projection, not an eligibility
  /// check.
  Future<SchemeCalculation> calculateSchemeLoan({
    required int schemeId,
    required double requestedAmount,
    required int tenureMonths,
  }) async {
    final data = await _post(
      '/schemes/$schemeId/calculate',
      body: {
        'requested_amount': roundToPaise(requestedAmount),
        'tenure_months': tenureMonths,
      },
    );

    return SchemeCalculation.fromJson(data as Map<String, dynamic>);
  }

  /// Lists the token owner's own applications, newest-first as ordered by the
  /// backend.
  ///
  /// Ownership is enforced server-side from the bearer token, so no user id is
  /// sent and none can be spoofed. A brand-new applicant legitimately gets an
  /// empty list rather than an error.
  Future<List<LoanApplication>> fetchOwnApplications({
    required String token,
  }) async {
    final data = await _get('/applications', token: token);

    final List<dynamic> rawItems;
    if (data is Map<String, dynamic> && data['items'] is List) {
      rawItems = data['items'] as List<dynamic>;
    } else if (data is List<dynamic>) {
      rawItems = data;
    } else {
      throw ApiException('Unexpected response shape for /applications');
    }

    return rawItems
        .map((item) => LoanApplication.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Saves an application the applicant has not sent yet.
  ///
  /// [partnerId] is omitted when no centre has been chosen: a draft may
  /// legitimately have none, and the backend only requires one on submission.
  /// The status is pinned to `draft` here — this method never submits.
  Future<LoanApplication> saveApplicationDraft({
    required int schemeId,
    required double requestedAmount,
    required String token,
    int? partnerId,
  }) async {
    final data = await _post(
      '/applications',
      body: {
        'scheme_id': schemeId,
        'requested_amount': roundToPaise(requestedAmount),
        'status': 'draft',
        'partner_id': ?partnerId,
      },
      token: token,
      expectedStatus: 201,
    );

    return LoanApplication.fromJson(data as Map<String, dynamic>);
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

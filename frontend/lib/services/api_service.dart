import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/api_constants.dart';
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

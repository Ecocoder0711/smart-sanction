import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Captures the last request so assertions can inspect the outgoing payload.
class _Captured {
  http.Request? request;

  Map<String, dynamic> get body =>
      jsonDecode(request!.body) as Map<String, dynamic>;
}

AuthService _serviceReturning(
  _Captured captured, {
  required int statusCode,
  required Map<String, dynamic> payload,
}) {
  final client = MockClient((request) async {
    captured.request = request;
    return http.Response(
      jsonEncode(payload),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
  return AuthService(client: client);
}

void main() {
  group('AuthService.register', () {
    test('sends only credentials for a minimal registration', () async {
      final captured = _Captured();
      final service = _serviceReturning(
        captured,
        statusCode: 201,
        payload: {'id': 1, 'profile_complete': false},
      );

      await service.register(
        fullName: 'Asha Devi',
        phone: '9880000001',
        password: 'CorrectHorse123!',
      );

      expect(captured.body.keys, containsAll(['full_name', 'phone', 'password']));
      // Absent profile fields must be omitted, not sent as null: the backend
      // stores them as NULL and keeps profile_complete false.
      expect(captured.body.containsKey('annual_income'), isFalse);
      expect(captured.body.containsKey('category'), isFalse);
      expect(captured.body.containsKey('gender'), isFalse);
    });

    test('includes profile fields when they are supplied', () async {
      final captured = _Captured();
      final service = _serviceReturning(
        captured,
        statusCode: 201,
        payload: {'id': 1, 'profile_complete': true},
      );

      await service.register(
        fullName: 'Asha Devi',
        phone: '9880000001',
        password: 'CorrectHorse123!',
        annualIncome: 325000,
        category: 'General',
        gender: 'Female',
      );

      expect(captured.body['annual_income'], 325000);
      expect(captured.body['category'], 'General');
      expect(captured.body['gender'], 'Female');
    });

    test('maps 409 to PhoneAlreadyRegisteredException', () async {
      final service = _serviceReturning(
        _Captured(),
        statusCode: 409,
        payload: {'detail': 'Phone number is already registered'},
      );

      expect(
        () => service.register(
          fullName: 'Asha Devi',
          phone: '9880000001',
          password: 'CorrectHorse123!',
        ),
        throwsA(isA<PhoneAlreadyRegisteredException>()),
      );
    });
  });

  group('AuthService.updateProfile', () {
    test('PUTs the supplied subset with a bearer token', () async {
      final captured = _Captured();
      final service = _serviceReturning(
        captured,
        statusCode: 200,
        payload: {'id': 1, 'profile_complete': true},
      );

      final user = await service.updateProfile(
        fields: {'annual_income': 325000, 'category': 'GENERAL'},
        token: 'test-token',
      );

      expect(captured.request!.method, 'PUT');
      expect(captured.request!.url.path, endsWith('/users/me'));
      expect(captured.request!.headers['Authorization'], 'Bearer test-token');
      expect(captured.body, {'annual_income': 325000, 'category': 'GENERAL'});
      expect(user['profile_complete'], isTrue);
    });

    test('rejects an empty update instead of calling the API', () async {
      final captured = _Captured();
      final service = _serviceReturning(
        captured,
        statusCode: 200,
        payload: const {},
      );

      await expectLater(
        service.updateProfile(fields: const {}, token: 'test-token'),
        throwsA(isA<AuthException>()),
      );
      expect(captured.request, isNull);
    });

    test('surfaces an expired session as a 401 AuthException', () async {
      final service = _serviceReturning(
        _Captured(),
        statusCode: 401,
        payload: {'detail': 'Could not validate credentials'},
      );

      await expectLater(
        service.updateProfile(fields: {'category': 'SC'}, token: 'stale'),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('AuthService.fetchCurrentUser', () {
    test('GETs the profile with a bearer token', () async {
      final captured = _Captured();
      final service = _serviceReturning(
        captured,
        statusCode: 200,
        payload: {'id': 7, 'profile_complete': false},
      );

      final user = await service.fetchCurrentUser(token: 'test-token');

      expect(captured.request!.method, 'GET');
      expect(captured.request!.headers['Authorization'], 'Bearer test-token');
      expect(user['id'], 7);
      expect(user['profile_complete'], isFalse);
    });
  });
}

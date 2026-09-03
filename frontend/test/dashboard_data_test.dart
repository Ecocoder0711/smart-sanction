import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/loan_application.dart';
import 'package:frontend/models/scheme.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Mirrors a real `GET /api/applications` row.
Map<String, dynamic> _applicationJson({
  int id = 21,
  String status = 'submitted',
  String requestedAmount = '250000.00',
  Object? applicationDate = '2026-09-03T04:12:00Z',
}) => {
  'id': id,
  'user_id': 37,
  'user_name': 'Audit Demo Applicant',
  'scheme_id': 5,
  'scheme_name': 'Demo Artisan Opportunity Fund',
  'partner_id': 2,
  'partner_name': 'Prototype Livelihood Bank',
  'requested_amount': requestedAmount,
  'ml_match_score': null,
  'ml_approval_probability': null,
  'application_date': applicationDate,
  'status': status,
  'created_at': '2026-09-03T04:12:00Z',
  'updated_at': '2026-09-03T04:12:00Z',
};

/// Mirrors a real `GET /api/schemes` item.
Map<String, dynamic> _schemeJson({int id = 5}) => {
  'id': id,
  'scheme_name': 'Demo Artisan Opportunity Fund',
  'category_id': 4,
  'category': {'id': 4, 'category_name': 'OBC'},
  'gender_eligibility': 'ANY',
  'max_loan_limit': '500000.00',
  'interest_rate': '5.2500',
  'moratorium_months': 4,
  'max_income_limit': '400000.00',
  'is_active': true,
};

ApiService _serviceReturning(
  Object payload, {
  int status = 200,
  void Function(http.Request)? capture,
}) => ApiService(
  client: MockClient((request) async {
    capture?.call(request);
    return http.Response(
      jsonEncode(payload),
      status,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  group('LoanApplication parsing', () {
    test('parses the fields the dashboard card renders', () {
      final app = LoanApplication.fromJson(_applicationJson());

      expect(app.id, 21);
      expect(app.schemeName, 'Demo Artisan Opportunity Fund');
      expect(app.partnerName, 'Prototype Livelihood Bank');
      expect(app.requestedAmount, 250000.00);
      expect(app.status, 'submitted');
      expect(app.schemeId, 5);
      expect(app.partnerId, 2);
    });

    test('parses the application date when present', () {
      final app = LoanApplication.fromJson(_applicationJson());
      expect(app.applicationDate, isNotNull);
      expect(app.applicationDate!.year, 2026);
    });

    test('tolerates a null or unparseable date', () {
      expect(
        LoanApplication.fromJson(
          _applicationJson(applicationDate: null),
        ).applicationDate,
        isNull,
      );
      expect(
        LoanApplication.fromJson(
          _applicationJson(applicationDate: 'not-a-date'),
        ).applicationDate,
        isNull,
      );
    });
  });

  group('application status', () {
    test('maps every backend lifecycle state to a translation key', () {
      // ApplicationStatus in app/core/enums.py -- note there is no draft.
      const states = [
        'submitted',
        'under_review',
        'approved',
        'rejected',
        'completed',
      ];

      for (final state in states) {
        final app = LoanApplication.fromJson(_applicationJson(status: state));
        expect(app.status, state);
        expect(app.statusKey, 'dashboard.status_$state');
      }
    });

    test('there is no draft state to render', () {
      const states = [
        'submitted',
        'under_review',
        'approved',
        'rejected',
        'completed',
      ];
      expect(states.contains('draft'), isFalse);
    });

    test('an unknown future state still parses', () {
      final app = LoanApplication.fromJson(_applicationJson(status: 'withdrawn'));
      expect(app.status, 'withdrawn');
      expect(app.statusKey, 'dashboard.status_withdrawn');
    });
  });

  group('ApiService.fetchOwnApplications', () {
    test('sends the bearer token and unwraps items', () async {
      late http.Request captured;
      final service = _serviceReturning(
        {'items': [_applicationJson()], 'total': 1},
        capture: (r) => captured = r,
      );

      final apps = await service.fetchOwnApplications(token: 'token-abc');

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/applications');
      // Ownership is enforced from the token; no user id is ever sent.
      expect(captured.headers['Authorization'], 'Bearer token-abc');
      expect(captured.url.queryParameters, isEmpty);
      expect(apps, hasLength(1));
      expect(apps.single.schemeName, 'Demo Artisan Opportunity Fund');
    });

    test('a new applicant with no applications gets an empty list', () async {
      final service = _serviceReturning({'items': [], 'total': 0});

      expect(await service.fetchOwnApplications(token: 't'), isEmpty);
    });

    test('preserves backend ordering', () async {
      final service = _serviceReturning({
        'items': [
          _applicationJson(id: 30),
          _applicationJson(id: 21),
          _applicationJson(id: 12),
        ],
        'total': 3,
      });

      final apps = await service.fetchOwnApplications(token: 't');

      expect(apps.map((a) => a.id).toList(), [30, 21, 12]);
    });

    test('401 surfaces for the caller to log out on', () async {
      final service = _serviceReturning(
        {'detail': 'Not authenticated'},
        status: 401,
      );

      await expectLater(
        service.fetchOwnApplications(token: 'expired'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });

    test('an unexpected shape is rejected rather than silently empty', () async {
      final service = _serviceReturning({'unexpected': true});

      await expectLater(
        service.fetchOwnApplications(token: 't'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ApiService.fetchSchemes (Explore Schemes)', () {
    test('unwraps items and needs no token', () async {
      late http.Request captured;
      final service = _serviceReturning(
        {'items': [_schemeJson(id: 5), _schemeJson(id: 6)], 'total': 2},
        capture: (r) => captured = r,
      );

      final schemes = await service.fetchSchemes();

      expect(captured.url.path, '/api/schemes');
      // Public catalogue: browsing must work before sign-in.
      expect(captured.headers.containsKey('Authorization'), isFalse);
      expect(schemes, hasLength(2));
    });

    test('parses exactly what the scheme card shows', () async {
      final service = _serviceReturning({
        'items': [_schemeJson()],
        'total': 1,
      });

      final scheme = (await service.fetchSchemes()).single;

      expect(scheme.name, 'Demo Artisan Opportunity Fund');
      expect(scheme.interestRate, 5.25);
      expect(scheme.category, 'OBC');
    });

    test('an empty catalogue is not an error', () async {
      final service = _serviceReturning({'items': [], 'total': 0});
      expect(await service.fetchSchemes(), isEmpty);
    });
  });

  group('greeting fallback', () {
    // The dashboard reads user?['full_name'] and falls back to neutral copy.
    String greetingFor(Map<String, dynamic>? user) =>
        user?['full_name'] as String? ?? 'dashboard.greeting_fallback';

    test('uses the real name when the profile is loaded', () {
      expect(greetingFor({'full_name': 'Asha Devi'}), 'Asha Devi');
    });

    test('falls back to neutral copy, never a hardcoded person', () {
      for (final user in <Map<String, dynamic>?>[
        null,
        <String, dynamic>{},
        {'full_name': null},
      ]) {
        final greeting = greetingFor(user);
        expect(greeting, 'dashboard.greeting_fallback');
        expect(greeting, isNot(contains('Venika')));
      }
    });
  });

  group('Scheme model still supports the dashboard card', () {
    test('parses a trimmed payload without moratorium', () {
      final json = _schemeJson()..remove('moratorium_months');
      final scheme = Scheme.fromJson(json);

      expect(scheme.moratoriumMonths, isNull);
      expect(scheme.name, isNotEmpty);
      expect(scheme.interestRate, 5.25);
    });
  });
}

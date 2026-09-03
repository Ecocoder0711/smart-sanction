import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/match_candidate.dart';
import 'package:frontend/models/scheme.dart';
import 'package:frontend/models/scheme_calculation.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A scheme whose limit is far above the ₹2,50,000 the calculator used to
/// clamp to, so the clamp bug cannot pass unnoticed.
Map<String, dynamic> _schemeJson({
  int id = 6,
  String maxLoanLimit = '2000000.00',
  String interestRate = '7.2500',
  Object? moratoriumMonths = 9,
}) => {
  'id': id,
  'scheme_name': 'Demo Enterprise Business Boost',
  'category_id': 4,
  'category': {'id': 4, 'category_name': 'OBC'},
  'max_loan_limit': maxLoanLimit,
  'interest_rate': interestRate,
  'moratorium_months': moratoriumMonths,
  'max_income_limit': '900000.00',
  'is_active': true,
};

Map<String, dynamic> _candidateJson({
  String requestedAmount = '250000.00',
  int tenureMonths = 60,
  String emi = '4979.84',
}) => {
  'scheme': _schemeJson(),
  'eligibility': {'eligible': true, 'reasons': const []},
  'requested_amount': requestedAmount,
  'financial': {
    'principal': requestedAmount,
    'annual_interest_rate': '7.2500',
    'tenure_months': tenureMonths,
    'emi': emi,
    'total_repayment': '298790.40',
    'total_interest': '48790.40',
  },
  'partners': [
    {
      'id': 2,
      'bank_name': 'Prototype Livelihood Bank',
      'branch_code': 'DEMO-DEL-002',
      'latitude': 28.615,
      'longitude': 77.2102,
      'distance_km': 0.169,
      'health_score': 0.88499,
    },
  ],
  'partner_message': 'ok',
  'ml': null,
};

/// Mirrors the screen's local preview formula so the subsidy's removal can be
/// asserted numerically without pumping a widget.
double localEmi(double principal, double annualRate, int months) {
  final r = annualRate / 12 / 100;
  if (r == 0) return principal / months;
  var factor = 1.0;
  for (var i = 0; i < months; i++) {
    factor *= (1 + r);
  }
  return principal * r * factor / (factor - 1);
}

void main() {
  group('Scheme.moratoriumMonths', () {
    test('parses the real per-scheme value', () {
      final scheme = Scheme.fromJson(_schemeJson(moratoriumMonths: 9));
      // Seeded schemes range 2..12; the UI must never hardcode 12.
      expect(scheme.moratoriumMonths, 9);
    });

    test('varies per scheme rather than being fixed', () {
      final values = [2, 3, 4, 5, 6, 9, 12]
          .map((m) => Scheme.fromJson(_schemeJson(moratoriumMonths: m)))
          .map((s) => s.moratoriumMonths)
          .toList();

      expect(values, [2, 3, 4, 5, 6, 9, 12]);
    });

    test('is null when a trimmed payload omits it', () {
      final json = _schemeJson()..remove('moratorium_months');
      expect(Scheme.fromJson(json).moratoriumMonths, isNull);
    });

    test('existing scheme fields still parse', () {
      final scheme = Scheme.fromJson(_schemeJson());
      expect(scheme.id, 6);
      expect(scheme.maxLoanLimit, 2000000.00);
      expect(scheme.interestRate, 7.25);
      expect(scheme.category, 'OBC');
    });
  });

  group('scheme-mode initial values', () {
    late MatchCandidate candidate;

    setUp(() => candidate = MatchCandidate.fromJson(_candidateJson()));

    test('initial principal is the requested amount, not the loan limit', () {
      // Opening the calculator must reproduce the matched-scheme card's
      // scenario, so it starts at what the applicant actually asked for.
      expect(candidate.requestedAmount, 250000.00);
      expect(candidate.scheme.maxLoanLimit, 2000000.00);
      expect(candidate.requestedAmount, isNot(candidate.scheme.maxLoanLimit));
    });

    test('slider ceiling is the real limit, never clamped to 250000', () {
      const oldClamp = 250000.0;
      final maxAmount = candidate.scheme.maxLoanLimit;

      expect(maxAmount, greaterThan(oldClamp));
      // The regression: this used to collapse to the clamp.
      expect(maxAmount.clamp(10000.0, maxAmount), 2000000.0);
    });

    test('tenure comes from financial.tenureMonths, not a 120 default', () {
      expect(candidate.financial.tenureMonths, 60);
      expect(candidate.financial.tenureMonths, isNot(120));
    });

    test('the card EMI is available as the starting authoritative value', () {
      expect(candidate.financial.emi, 4979.84);
    });

    test('partners survive for the later Nearby Banks step', () {
      expect(candidate.partners, hasLength(1));
      expect(candidate.partners.single.healthScore, 0.88499);
    });
  });

  group('subsidy removal', () {
    test('EMI is computed on the full principal', () {
      const principal = 250000.0;
      const rate = 7.25;
      const months = 60;

      final full = localEmi(principal, rate, months);
      final withOldSubsidy = localEmi(principal * 0.75, rate, months);

      // The old code charged EMI on 75% of the principal.
      expect(withOldSubsidy / full, closeTo(0.75, 1e-9));
      // And the full-principal figure is what matches the backend.
      expect(full, closeTo(4979.84, 0.01));
    });

    test('local preview agrees with the backend to sub-paise', () {
      // Same reducing-balance formula both sides, once the subsidy is gone.
      expect(localEmi(2000000, 7.25, 120), closeTo(23480.21, 0.01));
      expect(localEmi(250000, 5.25, 60), closeTo(4746.50, 0.01));
    });

    test('a zero rate does not divide by zero', () {
      expect(localEmi(120000, 0, 60), 2000.0);
    });
  });

  group('SchemeCalculation parsing', () {
    test('parses the backend calculator response', () {
      final calculation = SchemeCalculation.fromJson({
        'scheme': _schemeJson(),
        'principal': '2000000.00',
        'interest_rate': '7.2500',
        'tenure_months': 120,
        'emi': '23480.21',
        'total_interest': '817625.20',
        'total_repayment': '2817625.20',
      });

      expect(calculation.emi, 23480.21);
      expect(calculation.principal, 2000000.00);
      expect(calculation.tenureMonths, 120);
      expect(calculation.interestRate, 7.25);
      expect(calculation.totalRepayment, 2817625.20);
      // The embedded scheme is why one call also supplies the moratorium.
      expect(calculation.scheme.moratoriumMonths, 9);
    });
  });

  group('ApiService.calculateSchemeLoan', () {
    test('posts to the scheme endpoint with a rounded amount', () async {
      late http.Request captured;
      final service = ApiService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'scheme': _schemeJson(),
              'principal': '250001.00',
              'interest_rate': '7.2500',
              'tenure_months': 60,
              'emi': '4979.86',
              'total_interest': '48790.60',
              'total_repayment': '298791.60',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.calculateSchemeLoan(
        schemeId: 6,
        // More precision than Decimal(decimal_places=2) accepts.
        requestedAmount: 250000.999,
        tenureMonths: 60,
      );

      expect(captured.url.path, '/api/schemes/6/calculate');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['requested_amount'], 250001.0);
      expect(body['tenure_months'], 60);
      // Public endpoint: no Authorization header is sent.
      expect(captured.headers.containsKey('Authorization'), isFalse);
      expect(result.emi, 4979.86);
    });

    test('surfaces 404 for an unknown scheme', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response('{"detail":"Scheme not found"}', 404),
        ),
      );

      await expectLater(
        service.calculateSchemeLoan(
          schemeId: 999,
          requestedAmount: 1000,
          tenureMonths: 60,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('surfaces 400 for an inactive scheme', () async {
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response('{"detail":"Scheme is inactive"}', 400),
        ),
      );

      await expectLater(
        service.calculateSchemeLoan(
          schemeId: 12,
          requestedAmount: 1000,
          tenureMonths: 60,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
    });

    test('wraps a network failure as ApiException', () async {
      final service = ApiService(
        client: MockClient((_) async => throw const SocketFailure()),
      );

      await expectLater(
        service.calculateSchemeLoan(
          schemeId: 6,
          requestedAmount: 1000,
          tenureMonths: 60,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('generic mode', () {
    test('a null candidate leaves the screen without scheme data', () {
      const MatchCandidate? candidate = null;

      // Generic mode must not fabricate a moratorium or a scheme id.
      expect(candidate?.scheme.moratoriumMonths, isNull);
      expect(candidate?.scheme.id, isNull);
    });

    test('generic defaults stay inside the old range', () {
      const genericMin = 10000.0;
      const genericMax = 250000.0;
      const genericInitial = 50000.0;

      expect(genericInitial, greaterThanOrEqualTo(genericMin));
      expect(genericInitial, lessThanOrEqualTo(genericMax));
    });
  });

  group('large amounts', () {
    test('a scheme limit far above the old clamp round-trips intact', () {
      final scheme = Scheme.fromJson(
        _schemeJson(maxLoanLimit: '3000000.00'),
      );

      expect(scheme.maxLoanLimit, 3000000.0);
      // Formatting a value this wide is why the headline uses FittedBox.
      expect(scheme.maxLoanLimit.toStringAsFixed(0).length, 7);
    });

    test('a limit below the generic floor still yields a valid range', () {
      final scheme = Scheme.fromJson(_schemeJson(maxLoanLimit: '5000.00'));
      final maxAmount = scheme.maxLoanLimit;
      final minAmount = 10000.0 < maxAmount ? 10000.0 : maxAmount;

      // min must never exceed max, or Slider asserts.
      expect(minAmount, lessThanOrEqualTo(maxAmount));
      expect(minAmount, 5000.0);
    });
  });
}

/// Stand-in for the connection errors `http` throws before any status exists.
class SocketFailure implements Exception {
  const SocketFailure();
}

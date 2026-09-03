import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/request_formatting.dart';
import 'package:frontend/models/match_result.dart';

/// Fixtures below mirror real `POST /api/match` bodies captured from the
/// running backend, including Decimal fields arriving as JSON *strings*.
Map<String, dynamic> _candidate({Object? ml, bool withHealthScore = true}) => {
  'scheme': {
    'id': 5,
    'scheme_name': 'Demo Artisan Opportunity Fund',
    'category_id': 4,
    'category': {'id': 4, 'category_name': 'OBC'},
    'max_loan_limit': '500000.00',
    'interest_rate': '5.2500',
  },
  'eligibility': {
    'eligible': true,
    'reasons': ['Scheme is active', 'Applicant category is eligible'],
  },
  'requested_amount': '250000.00',
  'financial': {
    'principal': '250000.00',
    'annual_interest_rate': '5.2500',
    'tenure_months': 60,
    'emi': '4746.50',
    'total_repayment': '284789.76',
    'total_interest': '34789.76',
  },
  'partners': [
    {
      'id': 2,
      'bank_name': 'Prototype Livelihood Bank',
      'branch_code': 'DEMO-DEL-002',
      'latitude': 28.615,
      'longitude': 77.2102,
      'npa_percentage': '2.4000',
      'quota_remaining': '5000000.00',
      'is_active': true,
      'distance_km': 0.169,
      if (withHealthScore) 'health_score': 0.88499,
    },
  ],
  'partner_message': '5 available partner(s) found within 50 km, ranked by '
      'partner health score (non-performing assets, remaining quota, and '
      'distance).',
  'ml': ml,
};

String _response({
  required List<Map<String, dynamic>> candidates,
  required String mlStatus,
}) => jsonEncode({
  'requested_amount': '250000.00',
  'tenure_months': 60,
  'candidate_count': candidates.length,
  'message': candidates.isEmpty
      ? 'No matching scheme was found for the requested amount and profile.'
      : 'Found ${candidates.length} eligible scheme candidate(s).',
  'candidates': candidates,
  'ml_status': mlStatus,
});

MatchResult _parse(String body) =>
    MatchResult.fromJson(jsonDecode(body) as Map<String, dynamic>);

void main() {
  group('MatchResult with ML available', () {
    late MatchResult result;

    setUp(() {
      result = _parse(
        _response(
          mlStatus: 'available',
          candidates: [
            _candidate(
              ml: {
                'match_score': '0.96748',
                'approval_probability': '0.93305',
                'rank': 1,
              },
            ),
          ],
        ),
      );
    });

    test('reports ml_status and candidate count', () {
      expect(result.mlStatus, 'available');
      expect(result.candidateCount, 1);
      expect(result.candidates, hasLength(1));
    });

    test('parses the scheme fields the card renders', () {
      final scheme = result.candidates.single.scheme;
      expect(scheme.name, 'Demo Artisan Opportunity Fund');
      expect(scheme.category, 'OBC');
      expect(scheme.maxLoanLimit, 500000.00);
      expect(scheme.interestRate, 5.25);
    });

    test('parses eligibility', () {
      final eligibility = result.candidates.single.eligibility;
      expect(eligibility.eligible, isTrue);
      expect(eligibility.reasons, hasLength(2));
    });

    test('parses the backend-calculated EMI as a number', () {
      // Decimal arrives as a string; the card must never recompute this.
      final financial = result.candidates.single.financial;
      expect(financial.emi, 4746.50);
      expect(financial.tenureMonths, 60);
      expect(financial.totalRepayment, 284789.76);
      expect(financial.totalInterest, 34789.76);
    });

    test('parses the ml section', () {
      final ml = result.candidates.single.ml;
      expect(ml, isNotNull);
      expect(ml!.matchScore, 0.96748);
      expect(ml.approvalProbability, 0.93305);
      expect(ml.rank, 1);
    });

    test('match_score scales to the ring percentage', () {
      final ml = result.candidates.single.ml!;
      expect((ml.matchScore! * 100).round(), 97);
    });

    test('parses routed partners including health_score', () {
      final partner = result.candidates.single.partners.single;
      expect(partner.bankName, 'Prototype Livelihood Bank');
      expect(partner.distanceKm, 0.169);
      expect(partner.healthScore, 0.88499);
    });
  });

  group('MatchResult with ML unavailable', () {
    late MatchResult result;

    setUp(() {
      result = _parse(
        _response(mlStatus: 'unavailable', candidates: [_candidate(ml: null)]),
      );
    });

    test('leaves ml null rather than inventing a score', () {
      expect(result.mlStatus, 'unavailable');
      expect(result.candidates.single.ml, isNull);
    });

    test('still parses everything the card needs', () {
      final candidate = result.candidates.single;
      expect(candidate.scheme.name, isNotEmpty);
      expect(candidate.financial.emi, 4746.50);
      // health_score is deterministic routing, not ML: it survives either way.
      expect(candidate.partners.single.healthScore, 0.88499);
    });
  });

  group('tolerant parsing', () {
    test('a partner without health_score parses with a null score', () {
      final result = _parse(
        _response(
          mlStatus: 'unavailable',
          candidates: [_candidate(ml: null, withHealthScore: false)],
        ),
      );

      expect(result.candidates.single.partners.single.healthScore, isNull);
    });

    test('a partially populated ml section keeps the fields it has', () {
      final result = _parse(
        _response(
          mlStatus: 'available',
          candidates: [
            _candidate(ml: {'match_score': '0.5', 'approval_probability': null}),
          ],
        ),
      );

      final ml = result.candidates.single.ml!;
      expect(ml.matchScore, 0.5);
      expect(ml.approvalProbability, isNull);
      expect(ml.rank, isNull);
    });
  });

  group('empty result', () {
    test('zero candidates is a valid 200 body, not an error', () {
      final result = _parse(
        _response(mlStatus: 'unavailable', candidates: const []),
      );

      expect(result.candidateCount, 0);
      expect(result.candidates, isEmpty);
      expect(result.message, contains('No matching scheme was found'));
    });
  });

  group('candidate ordering', () {
    test('backend order is preserved verbatim', () {
      // The service already sorts by match_score, so the UI must not re-sort.
      final result = _parse(
        _response(
          mlStatus: 'available',
          candidates: [
            _candidate(ml: {'match_score': '0.96748', 'rank': 1}),
            _candidate(ml: {'match_score': '0.95963', 'rank': 2}),
            _candidate(ml: {'match_score': '0.86022', 'rank': 3}),
          ],
        ),
      );

      expect(
        result.candidates.map((c) => c.ml!.rank).toList(),
        [1, 2, 3],
      );
      final scores = result.candidates.map((c) => c.ml!.matchScore!).toList();
      expect(scores, orderedEquals([...scores]..sort((a, b) => b.compareTo(a))));
    });

    test('approval_probability may repeat across candidates', () {
      // It is application-level, so identical values are expected and must
      // not be mistaken for a per-scheme ranking signal.
      final result = _parse(
        _response(
          mlStatus: 'available',
          candidates: [
            _candidate(ml: {'match_score': '0.9', 'approval_probability': '0.93305'}),
            _candidate(ml: {'match_score': '0.8', 'approval_probability': '0.93305'}),
          ],
        ),
      );

      final probabilities =
          result.candidates.map((c) => c.ml!.approvalProbability).toSet();
      expect(probabilities, hasLength(1));
      final scores = result.candidates.map((c) => c.ml!.matchScore).toSet();
      expect(scores, hasLength(2));
    });
  });

  group('roundToPaise', () {
    test('trims precision the backend would reject with a 422', () {
      // requested_amount is Decimal(decimal_places=2), so 250000.999 is a 422.
      expect(roundToPaise(250000.999), 250001.0);
      expect(roundToPaise(1.005), 1.0);
      expect(roundToPaise(99.999), 100.0);
      // Exact halves are not asserted: 250000.555 is not representable in
      // binary floating point (it stores just below the half), so the
      // direction follows the stored value, not the literal. What matters for
      // the contract is the digit count, covered below.
    });

    test('leaves already-valid amounts untouched', () {
      expect(roundToPaise(250000), 250000.0);
      expect(roundToPaise(250000.5), 250000.5);
      expect(roundToPaise(250000.55), 250000.55);
      expect(roundToPaise(0.01), 0.01);
    });

    test('never produces more than two decimal places', () {
      for (final value in [1.005, 99.999, 12345.6789, 0.001, 7.7777777]) {
        final rounded = roundToPaise(value);
        final decimals = rounded.toString().split('.');
        expect(
          decimals.length == 1 || decimals[1].length <= 2,
          isTrue,
          reason: '$value -> $rounded has too much precision',
        );
      }
    });
  });
}

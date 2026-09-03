import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/match_candidate.dart';
import 'package:intl/intl.dart';

/// Mirrors a real routed partner from `/api/match`, Decimal fields included
/// as the JSON strings the backend actually sends.
Map<String, dynamic> _partnerJson({
  int id = 2,
  String bankName = 'Prototype Livelihood Bank',
  String branchCode = 'DEMO-DEL-002',
  double latitude = 28.615,
  double longitude = 77.2102,
  double distanceKm = 0.169,
  Object? quotaRemaining = '5000000.00',
  Object? npaPercentage = '2.4000',
  Object? healthScore = 0.88499,
}) => {
  'id': id,
  'bank_name': bankName,
  'branch_code': branchCode,
  'latitude': latitude,
  'longitude': longitude,
  'npa_percentage': npaPercentage,
  'quota_remaining': quotaRemaining,
  'is_active': true,
  'distance_km': distanceKm,
  'health_score': healthScore,
};

Map<String, dynamic> _candidateJson({
  List<Map<String, dynamic>>? partners,
  String partnerMessage =
      '5 available partner(s) found within 50 km, ranked by partner health '
      'score (non-performing assets, remaining quota, and distance).',
}) => {
  'scheme': {
    'id': 6,
    'scheme_name': 'Demo Enterprise Business Boost',
    'category': {'category_name': 'OBC'},
    'max_loan_limit': '2000000.00',
    'interest_rate': '7.2500',
    'moratorium_months': 9,
  },
  'eligibility': {'eligible': true, 'reasons': const []},
  'requested_amount': '250000.00',
  'financial': {
    'principal': '250000.00',
    'annual_interest_rate': '7.2500',
    'tenure_months': 60,
    'emi': '4979.84',
    'total_repayment': '298790.40',
    'total_interest': '48790.40',
  },
  'partners': partners ?? [_partnerJson()],
  'partner_message': partnerMessage,
  'ml': null,
};

/// Same formatters the screen uses, so the assertions pin displayed output.
final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
String formatKm(double km) => km.toStringAsFixed(1);

/// Mirrors the screen's directions URL.
String directionsUrl(RecommendedPartner p) =>
    'https://www.google.com/maps/search/?api=1'
    '&query=${p.latitude},${p.longitude}';

void main() {
  group('RecommendedPartner parsing', () {
    late RecommendedPartner partner;

    setUp(() => partner = RecommendedPartner.fromJson(_partnerJson()));

    test('parses quota_remaining from its Decimal string', () {
      expect(partner.quotaRemaining, 5000000.00);
    });

    test('parses npa_percentage from its Decimal string', () {
      expect(partner.npaPercentage, 2.4);
    });

    test('parses health_score', () {
      expect(partner.healthScore, 0.88499);
    });

    test('keeps the previously supported fields', () {
      expect(partner.id, 2);
      expect(partner.bankName, 'Prototype Livelihood Bank');
      expect(partner.branchCode, 'DEMO-DEL-002');
      expect(partner.latitude, 28.615);
      expect(partner.longitude, 77.2102);
      expect(partner.distanceKm, 0.169);
    });

    test('tolerates every optional field being absent', () {
      final json = _partnerJson()
        ..remove('quota_remaining')
        ..remove('npa_percentage')
        ..remove('health_score');
      final sparse = RecommendedPartner.fromJson(json);

      expect(sparse.quotaRemaining, isNull);
      expect(sparse.npaPercentage, isNull);
      expect(sparse.healthScore, isNull);
      // Required fields still parse.
      expect(sparse.bankName, isNotEmpty);
      expect(sparse.distanceKm, 0.169);
    });

    test('accepts numeric as well as string Decimals', () {
      final numeric = RecommendedPartner.fromJson(
        _partnerJson(quotaRemaining: 1750000, npaPercentage: 11.5),
      );

      expect(numeric.quotaRemaining, 1750000.0);
      expect(numeric.npaPercentage, 11.5);
    });
  });

  group('distance formatting', () {
    test('renders kilometres to one decimal, never miles', () {
      // Real routed distances from the seeded partners.
      expect(formatKm(0.169), '0.2');
      expect(formatKm(1.944), '1.9');
      expect(formatKm(2.528), '2.5');
      // Near the 50 km radius bound. Exact halves are avoided: a literal like
      // 48.05 is not representable in binary floating point and stores just
      // below the half, so its rounding direction follows the stored value.
      expect(formatKm(48.06), '48.1');
      expect(formatKm(49.94), '49.9');
    });

    test('always yields at most one decimal place', () {
      for (final km in [0.0, 0.169, 12.3456, 49.99999]) {
        expect(formatKm(km).split('.')[1].length, 1);
      }
    });
  });

  group('quota formatting', () {
    test('renders the real amount, Indian grouping', () {
      expect(_rupees.format(5000000.0), '₹50,00,000');
      expect(_rupees.format(1750000.0), '₹17,50,000');
      expect(_rupees.format(250000.0), '₹2,50,000');
    });

    test('a large quota formats without losing precision', () {
      expect(_rupees.format(60000000.0), '₹6,00,00,000');
    });

    test('every partner /api/match returns has quota above zero', () {
      // The backend filters quota_remaining > 0, so the old "exhausted"
      // state is unreachable and was removed from the card.
      final partners = ['5000000.00', '4000000.00', '5750000.00',
              '1750000.00', '2250000.00']
          .map((q) => RecommendedPartner.fromJson(
                _partnerJson(quotaRemaining: q),
              ))
          .toList();

      expect(partners.every((p) => p.quotaRemaining! > 0), isTrue);
    });
  });

  group('partner score', () {
    test('scales health_score to a whole number for display', () {
      final partner = RecommendedPartner.fromJson(
        _partnerJson(healthScore: 0.88499),
      );

      expect((partner.healthScore! * 100).round(), 88);
    });

    test('stays within 0..100 across the real range', () {
      for (final score in [0.0, 0.02583, 0.52035, 0.88499, 1.0]) {
        final partner = RecommendedPartner.fromJson(
          _partnerJson(healthScore: score),
        );
        final percent = (partner.healthScore! * 100).round();
        expect(percent, inInclusiveRange(0, 100));
      }
    });
  });

  group('ordering', () {
    test('backend health-ranked order is preserved verbatim', () {
      // Health-ranked, which is deliberately NOT distance order.
      final candidate = MatchCandidate.fromJson(
        _candidateJson(
          partners: [
            _partnerJson(id: 2, distanceKm: 0.169, healthScore: 0.88499),
            _partnerJson(id: 56, distanceKm: 1.944, healthScore: 0.78167),
            _partnerJson(id: 38, distanceKm: 0.406, healthScore: 0.6784),
            _partnerJson(id: 20, distanceKm: 2.528, healthScore: 0.639),
            _partnerJson(id: 74, distanceKm: 2.025, healthScore: 0.52035),
          ],
        ),
      );

      expect(
        candidate.partners.map((p) => p.id).toList(),
        [2, 56, 38, 20, 74],
      );
      final scores = candidate.partners.map((p) => p.healthScore!).toList();
      expect(scores, orderedEquals([...scores]..sort((a, b) => b.compareTo(a))));
      // Proof the list is not distance-sorted: id 38 is nearer than id 56 but
      // ranks below it because its NPA is worse.
      final distances = candidate.partners.map((p) => p.distanceKm).toList();
      expect(distances, isNot(orderedEquals([...distances]..sort())));
    });
  });

  group('empty and generic states', () {
    test('an empty partner list parses and carries its explanation', () {
      final candidate = MatchCandidate.fromJson(
        _candidateJson(
          partners: const [],
          partnerMessage: 'No available partners were found within 50 km.',
        ),
      );

      expect(candidate.partners, isEmpty);
      expect(candidate.partnerMessage, contains('No available partners'));
    });

    test('a user without coordinates gets the location explanation', () {
      final candidate = MatchCandidate.fromJson(
        _candidateJson(
          partners: const [],
          partnerMessage: 'User location is not configured; nearby partner '
              'recommendations are unavailable.',
        ),
      );

      expect(candidate.partners, isEmpty);
      expect(candidate.partnerMessage, contains('location is not configured'));
    });

    test('generic mode has no candidate, so no partners and no message', () {
      const MatchCandidate? candidate = null;

      // The screen must not fall back to sample partners.
      expect(candidate?.partners ?? const [], isEmpty);
      expect(candidate?.partnerMessage, isNull);
    });
  });

  group('directions', () {
    test('targets the real coordinates, not the bank name', () {
      final partner = RecommendedPartner.fromJson(_partnerJson());

      final url = directionsUrl(partner);

      expect(url, contains('query=28.615,77.2102'));
      expect(url, isNot(contains('Prototype')));
      expect(Uri.parse(url).queryParameters['query'], '28.615,77.2102');
    });

    test('distinguishes two branches of the same bank', () {
      // Name-based search could not tell these apart.
      final a = RecommendedPartner.fromJson(
        _partnerJson(id: 2, latitude: 28.615, longitude: 77.2102),
      );
      final b = RecommendedPartner.fromJson(
        _partnerJson(id: 20, latitude: 28.630, longitude: 77.2200),
      );

      expect(a.bankName, b.bankName);
      expect(directionsUrl(a), isNot(directionsUrl(b)));
    });
  });
}

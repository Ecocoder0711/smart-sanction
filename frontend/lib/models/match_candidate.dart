import 'scheme.dart';

class CandidateEligibility {
  const CandidateEligibility({required this.eligible, required this.reasons});

  final bool eligible;
  final List<String> reasons;

  factory CandidateEligibility.fromJson(Map<String, dynamic> json) {
    return CandidateEligibility(
      eligible: json['eligible'] as bool,
      reasons: (json['reasons'] as List<dynamic>)
          .map((reason) => reason as String)
          .toList(),
    );
  }
}

class MatchFinancial {
  const MatchFinancial({
    required this.principal,
    required this.annualInterestRate,
    required this.tenureMonths,
    required this.emi,
    required this.totalRepayment,
    required this.totalInterest,
  });

  final double principal;
  final double annualInterestRate;
  final int tenureMonths;
  final double emi;
  final double totalRepayment;
  final double totalInterest;

  factory MatchFinancial.fromJson(Map<String, dynamic> json) {
    return MatchFinancial(
      principal: double.parse(json['principal'].toString()),
      annualInterestRate: double.parse(
        json['annual_interest_rate'].toString(),
      ),
      tenureMonths: json['tenure_months'] as int,
      emi: double.parse(json['emi'].toString()),
      totalRepayment: double.parse(json['total_repayment'].toString()),
      totalInterest: double.parse(json['total_interest'].toString()),
    );
  }
}

class RecommendedPartner {
  const RecommendedPartner({
    required this.id,
    required this.bankName,
    required this.branchCode,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.healthScore,
  });

  final int id;
  final String bankName;
  final String branchCode;
  final double latitude;
  final double longitude;
  final double distanceKm;

  /// Deterministic Partner Health Score in `[0, 1]` over the branch's NPA,
  /// remaining quota, and distance. Not an ML output, and unrelated to
  /// `ml_status`: `/api/match` returns it whether or not ML is enabled.
  ///
  /// Nullable only so an older backend without routed partners still parses.
  final double? healthScore;

  factory RecommendedPartner.fromJson(Map<String, dynamic> json) {
    final healthScore = json['health_score'];

    return RecommendedPartner(
      id: json['id'] as int,
      bankName: json['bank_name'] as String,
      branchCode: json['branch_code'] as String,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      distanceKm: double.parse(json['distance_km'].toString()),
      healthScore: healthScore == null
          ? null
          : double.parse(healthScore.toString()),
    );
  }
}

/// The optional ML section of one candidate.
///
/// Present only when the backend reports `ml_status: "available"`; every field
/// stays nullable because the contract declares them individually optional.
class MlResult {
  const MlResult({this.matchScore, this.approvalProbability, this.rank});

  /// Applicant-to-scheme financial fit, `[0, 1]`. This is **scheme-level**:
  /// it differs per candidate and is what the backend orders results by, so
  /// it is the value a per-scheme card should show.
  final double? matchScore;

  /// Predicted approval likelihood, `[0, 1]`. This is **application-level**:
  /// every Random Forest feature is applicant-level, so within one response
  /// it is identical for every candidate. It must not be rendered as a
  /// per-scheme score.
  final double? approvalProbability;

  /// 1-based position derived from [matchScore].
  final int? rank;

  factory MlResult.fromJson(Map<String, dynamic> json) {
    final matchScore = json['match_score'];
    final approvalProbability = json['approval_probability'];

    return MlResult(
      matchScore: matchScore == null
          ? null
          : double.parse(matchScore.toString()),
      approvalProbability: approvalProbability == null
          ? null
          : double.parse(approvalProbability.toString()),
      rank: json['rank'] as int?,
    );
  }
}

class MatchCandidate {
  const MatchCandidate({
    required this.scheme,
    required this.eligibility,
    required this.requestedAmount,
    required this.financial,
    required this.partners,
    required this.partnerMessage,
    this.ml,
  });

  final Scheme scheme;
  final CandidateEligibility eligibility;
  final double requestedAmount;
  final MatchFinancial financial;
  final List<RecommendedPartner> partners;
  final String partnerMessage;

  /// Null whenever the response reports `ml_status: "unavailable"` — the
  /// backend leaves it out rather than inventing a score, so callers must
  /// treat an absent section as "no score", never as zero.
  final MlResult? ml;

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    final ml = json['ml'];

    return MatchCandidate(
      scheme: Scheme.fromJson(json['scheme'] as Map<String, dynamic>),
      eligibility: CandidateEligibility.fromJson(
        json['eligibility'] as Map<String, dynamic>,
      ),
      requestedAmount: double.parse(json['requested_amount'].toString()),
      financial: MatchFinancial.fromJson(
        json['financial'] as Map<String, dynamic>,
      ),
      partners: (json['partners'] as List<dynamic>? ?? const [])
          .map(
            (partner) =>
                RecommendedPartner.fromJson(partner as Map<String, dynamic>),
          )
          .toList(),
      partnerMessage: json['partner_message'] as String,
      ml: ml == null ? null : MlResult.fromJson(ml as Map<String, dynamic>),
    );
  }
}

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
  });

  final int id;
  final String bankName;
  final String branchCode;
  final double latitude;
  final double longitude;
  final double distanceKm;

  factory RecommendedPartner.fromJson(Map<String, dynamic> json) {
    return RecommendedPartner(
      id: json['id'] as int,
      bankName: json['bank_name'] as String,
      branchCode: json['branch_code'] as String,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      distanceKm: double.parse(json['distance_km'].toString()),
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
  });

  final Scheme scheme;
  final CandidateEligibility eligibility;
  final double requestedAmount;
  final MatchFinancial financial;
  final List<RecommendedPartner> partners;
  final String partnerMessage;

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    return MatchCandidate(
      scheme: Scheme.fromJson(json['scheme'] as Map<String, dynamic>),
      eligibility: CandidateEligibility.fromJson(
        json['eligibility'] as Map<String, dynamic>,
      ),
      requestedAmount: double.parse(json['requested_amount'].toString()),
      financial: MatchFinancial.fromJson(
        json['financial'] as Map<String, dynamic>,
      ),
      partners: (json['partners'] as List<dynamic>)
          .map(
            (partner) =>
                RecommendedPartner.fromJson(partner as Map<String, dynamic>),
          )
          .toList(),
      partnerMessage: json['partner_message'] as String,
    );
  }
}

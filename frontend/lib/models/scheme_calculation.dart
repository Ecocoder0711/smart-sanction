import 'scheme.dart';

/// Result of `POST /api/schemes/{id}/calculate`.
///
/// The backend computes this with Decimal precision and half-up rounding to
/// paise, so it is the authoritative figure; the screen's local formula is
/// only a preview while the slider moves.
///
/// The embedded [scheme] carries the full stored record, which is why this
/// single call also supplies the real `moratorium_months`.
class SchemeCalculation {
  const SchemeCalculation({
    required this.scheme,
    required this.principal,
    required this.interestRate,
    required this.tenureMonths,
    required this.emi,
    required this.totalInterest,
    required this.totalRepayment,
  });

  final Scheme scheme;
  final double principal;
  final double interestRate;
  final int tenureMonths;
  final double emi;
  final double totalInterest;
  final double totalRepayment;

  factory SchemeCalculation.fromJson(Map<String, dynamic> json) {
    return SchemeCalculation(
      scheme: Scheme.fromJson(json['scheme'] as Map<String, dynamic>),
      principal: double.parse(json['principal'].toString()),
      interestRate: double.parse(json['interest_rate'].toString()),
      tenureMonths: json['tenure_months'] as int,
      emi: double.parse(json['emi'].toString()),
      totalInterest: double.parse(json['total_interest'].toString()),
      totalRepayment: double.parse(json['total_repayment'].toString()),
    );
  }
}

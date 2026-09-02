import 'match_candidate.dart';

class MatchResult {
  const MatchResult({
    required this.requestedAmount,
    required this.tenureMonths,
    required this.candidateCount,
    required this.message,
    required this.candidates,
    required this.mlStatus,
  });

  final double requestedAmount;
  final int tenureMonths;
  final int candidateCount;
  final String message;
  final List<MatchCandidate> candidates;
  final String mlStatus;

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      requestedAmount: double.parse(json['requested_amount'].toString()),
      tenureMonths: json['tenure_months'] as int,
      candidateCount: json['candidate_count'] as int,
      message: json['message'] as String,
      candidates: (json['candidates'] as List<dynamic>)
          .map(
            (candidate) =>
                MatchCandidate.fromJson(candidate as Map<String, dynamic>),
          )
          .toList(),
      mlStatus: json['ml_status'] as String,
    );
  }
}

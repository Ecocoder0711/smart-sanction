import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/match_candidate.dart';
import '../auth/widgets/trust_footer.dart';
import '../calculator/emi_calculator_screen.dart';

/// Formats rupee amounts the way the mock strings did: grouped, no paise.
final NumberFormat _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Renders a stored rate without trailing zeros: 5.2500 -> "5.25", 7 -> "7".
String _formatRate(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

class MatchedSchemesScreen extends StatelessWidget {
  const MatchedSchemesScreen({
    super.key,
    required this.candidates,
    this.mlStatus = 'unavailable',
  });

  /// Eligible candidates from `POST /api/match`, in backend order.
  ///
  /// That order is the ranking: the service sorts by `ml.match_score` when ML
  /// supplied one, so this list is rendered as-is and never re-sorted here.
  final List<MatchCandidate> candidates;

  /// `"available"` or `"unavailable"`, straight from the response.
  final String mlStatus;

  static const Color _backgroundColor = Color(0xFFF9FAFB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'scheme_matching.results_step_label'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'scheme_matching.results_title'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'scheme_matching.results_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (candidates.isEmpty)
                        const _EmptyResults()
                      else
                        for (final candidate in candidates) ...[
                          _MatchCard(candidate: candidate),
                          const SizedBox(height: 16),
                        ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '← ${'scheme_matching.previous_step_button'.tr()}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const TrustFooter(),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.candidate});

  final MatchCandidate candidate;

  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _scoreBoxColor = Color(0xFFD9E3F4);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.emeraldGreen),
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.scheme.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.emeraldGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'scheme_matching.eligible_label'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emeraldGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• ${'scheme_matching.loan_limit_prefix'.tr()}: '
                        '${_rupees.format(candidate.scheme.maxLoanLimit)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '• ${'scheme_matching.interest_prefix'.tr()}: '
                        '${_formatRate(candidate.scheme.interestRate)}%',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        // Backend-calculated EMI at 60 months; never
                        // recomputed here.
                        '• ${'scheme_matching.emi_prefix'.tr()}: '
                        '${_rupees.format(candidate.financial.emi)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmiCalculatorScreen(
                                initialPrincipal:
                                    candidate.scheme.maxLoanLimit,
                                interestRate: candidate.scheme.interestRate,
                                schemeName: candidate.scheme.name,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'scheme_matching.calculate_loan_button'.tr(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: AppColors.deepNavy,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _scoreBoxColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // match_score is the scheme-level fit and is the
                            // only score that belongs on a per-scheme card.
                            // approval_probability is application-level --
                            // identical for every candidate in one response --
                            // so it is deliberately not shown here.
                            _MatchScoreRing(
                              matchScore: candidate.ml?.matchScore,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              candidate.ml?.matchScore == null
                                  ? 'scheme_matching.score_unavailable_label'
                                        .tr()
                                  : 'scheme_matching.match_score_label'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchScoreRing extends StatelessWidget {
  const _MatchScoreRing({required this.matchScore});

  /// Scheme-level fit in `[0, 1]`, or null when ML is unavailable.
  final double? matchScore;

  @override
  Widget build(BuildContext context) {
    final score = matchScore;
    // No score: the ring renders empty with a dash rather than 0% or an
    // invented number, so an unavailable model never reads as a bad match.
    final percent = score == null ? null : (score * 100).round();

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: percent == null ? 0 : percent / 100,
              strokeWidth: 4,
              backgroundColor: const Color(0xFFD1D5DB),
              valueColor: const AlwaysStoppedAnimation(AppColors.emeraldGreen),
            ),
          ),
          Text(
            percent == null
                ? 'scheme_matching.score_unavailable'.tr()
                : '$percent%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the backend legitimately matched nothing (HTTP 200, zero
/// candidates). Uses the same card shell, spacing and colours as a result
/// card so the screen keeps its shape.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _MatchCard._borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 40, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'scheme_matching.empty_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'scheme_matching.empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          // Pops back to the intake form, the same destination as the
          // screen's existing "previous step" button.
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepNavy,
              side: const BorderSide(color: _MatchCard._borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'scheme_matching.empty_edit_button'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

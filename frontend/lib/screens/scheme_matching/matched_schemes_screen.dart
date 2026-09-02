import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../auth/widgets/trust_footer.dart';
import '../calculator/emi_calculator_screen.dart';

class _MockMatch {
  const _MockMatch({
    required this.name,
    required this.matchScore,
    required this.loanLimit,
    required this.interestRate,
    required this.emi,
    required this.loanLimitValue,
    required this.interestRateValue,
  });

  final String name;
  final int matchScore;
  final String loanLimit;
  final String interestRate;
  final String emi;

  // Raw numeric values (the fields above are pre-formatted display strings)
  // so "Calculate Loan" can pass real numbers to EmiCalculatorScreen.
  final double loanLimitValue;
  final double interestRateValue;
}

class MatchedSchemesScreen extends StatelessWidget {
  const MatchedSchemesScreen({super.key});

  static const Color _backgroundColor = Color(0xFFF9FAFB);

  // Mock data only — no backend calls.
  static const List<_MockMatch> _mockMatches = [
    _MockMatch(
      name: 'First Home Owner Grant Plus',
      matchScore: 98,
      loanLimit: '₹5,00,000',
      interestRate: '8.5%',
      emi: '₹10,200',
      loanLimitValue: 500000,
      interestRateValue: 8.5,
    ),
    _MockMatch(
      name: 'Regional Housing Support Initiative',
      matchScore: 92,
      loanLimit: '₹8,00,000',
      interestRate: '7.25%',
      emi: '₹15,400',
      loanLimitValue: 800000,
      interestRateValue: 7.25,
    ),
    _MockMatch(
      name: 'Family Density Growth Fund',
      matchScore: 85,
      loanLimit: '₹12,00,000',
      interestRate: '9.0%',
      emi: '₹21,600',
      loanLimitValue: 1200000,
      interestRateValue: 9.0,
    ),
  ];

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
                      for (final match in _mockMatches) ...[
                        _MatchCard(match: match),
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
  const _MatchCard({required this.match});

  final _MockMatch match;

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
                        match.name,
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
                        '${match.loanLimit}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '• ${'scheme_matching.interest_prefix'.tr()}: '
                        '${match.interestRate}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '• ${'scheme_matching.emi_prefix'.tr()}: ${match.emi}',
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
                                initialPrincipal: match.loanLimitValue,
                                interestRate: match.interestRateValue,
                                schemeName: match.name,
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
                            _MatchScoreRing(score: match.matchScore),
                            const SizedBox(height: 8),
                            Text(
                              'scheme_matching.match_score_label'.tr(),
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
  const _MatchScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
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
              value: score / 100,
              strokeWidth: 4,
              backgroundColor: const Color(0xFFD1D5DB),
              valueColor: const AlwaysStoppedAnimation(AppColors.emeraldGreen),
            ),
          ),
          Text(
            '$score%',
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

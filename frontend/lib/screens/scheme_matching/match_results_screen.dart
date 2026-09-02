import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/match_candidate.dart';

class MatchResultsScreen extends StatelessWidget {
  const MatchResultsScreen({super.key, required this.candidates});

  final List<MatchCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matched Schemes'),
        backgroundColor: AppColors.deepNavy,
        foregroundColor: Colors.white,
      ),
      body: candidates.isEmpty
          ? const Center(child: Text('No matching schemes found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final isEligible = candidate.eligibility.eligible;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                candidate.scheme.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isEligible
                                    ? AppColors.emeraldGreen.withValues(
                                        alpha: 0.12,
                                      )
                                    : AppColors.errorRed.withValues(
                                        alpha: 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isEligible ? 'Eligible' : 'Ineligible',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isEligible
                                      ? AppColors.emeraldGreen
                                      : AppColors.errorRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${candidate.scheme.category} • ${candidate.scheme.interestRate}% interest',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Monthly EMI: ₹${candidate.financial.emi.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isEligible &&
                            candidate.eligibility.reasons.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...candidate.eligibility.reasons.map(
                            (reason) => Text(
                              '• $reason',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

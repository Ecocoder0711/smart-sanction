import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../auth/widgets/trust_footer.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({
    super.key,
    this.initialPrincipal,
    this.interestRate,
    this.schemeName,
  });

  final double? initialPrincipal;
  final double? interestRate;
  final String? schemeName;

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _progressTrackColor = Color(0xFFD9E3F4);
  static const double _minAmount = 10000;
  static const double _maxAmount = 250000;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  late double _loanAmount;
  late double _interestRate;
  late int _tenureMonths;

  @override
  void initState() {
    super.initState();
    _loanAmount = (widget.initialPrincipal ?? 50000).clamp(
      _minAmount,
      _maxAmount,
    );
    _interestRate = widget.interestRate ?? 6.5;
    _tenureMonths = 120;
  }

  double get _subsidy => _loanAmount * 0.25;

  double get _netLoan => _loanAmount - _subsidy;

  double get _emi {
    final r = _interestRate / 12 / 100;
    final n = _tenureMonths;
    if (r == 0) return _netLoan / n;
    final factor = pow(1 + r, n);
    return _netLoan * r * factor / (factor - 1);
  }

  void _showNearbyBanksPending() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('calculator.nearby_banks_pending'.tr())),
    );
  }

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'calculator.step_label'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'calculator.header_label'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(
                          value: 0.75,
                          minHeight: 8,
                          backgroundColor: _progressTrackColor,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.emeraldGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'calculator.title'.tr(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'calculator.subtitle'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'calculator.loan_amount_label'.tr(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _currencyFormat.format(_loanAmount),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.deepNavy,
                                inactiveTrackColor: AppColors.softGray,
                                thumbColor: AppColors.deepNavy,
                                overlayColor: AppColors.deepNavy.withValues(
                                  alpha: 0.12,
                                ),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _loanAmount,
                                min: _minAmount,
                                max: _maxAmount,
                                onChanged: (value) {
                                  setState(() => _loanAmount = value);
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _currencyFormat.format(_minAmount),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(_maxAmount),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoCard(
                              icon: Icons.savings,
                              iconColor: AppColors.emeraldGreen,
                              label: 'calculator.subsidy_label'.tr(),
                              labelColor: AppColors.deepNavy,
                              value: _currencyFormat.format(_subsidy),
                              valueColor: AppColors.emeraldGreen,
                              subtitle: 'calculator.subsidy_subtitle'.tr(),
                              subtitleColor: Colors.grey.shade600,
                              backgroundColor: Colors.white,
                              border: Border.all(color: _borderColor),
                            ),
                            const SizedBox(height: 12),
                            _InfoCard(
                              icon: Icons.calendar_month,
                              iconColor: Colors.white,
                              label: 'calculator.emi_label'.tr(),
                              labelColor: Colors.white,
                              value: _currencyFormat.format(_emi),
                              valueColor: Colors.white,
                              subtitle: 'calculator.emi_subtitle'.tr(
                                namedArgs: {
                                  'rate': _interestRate.toStringAsFixed(1),
                                },
                              ),
                              subtitleColor: const Color(0xFFB6C6EF),
                              backgroundColor: AppColors.deepNavy,
                              border: null,
                            ),
                            const SizedBox(height: 12),
                            _InfoCard(
                              icon: Icons.hourglass_bottom,
                              iconColor: AppColors.deepNavy,
                              label: 'calculator.moratorium_label'.tr(),
                              labelColor: AppColors.deepNavy,
                              value: 'calculator.moratorium_value'.tr(),
                              valueColor: AppColors.deepNavy,
                              subtitle: 'calculator.moratorium_subtitle'.tr(),
                              subtitleColor: Colors.grey.shade600,
                              backgroundColor: Colors.white,
                              border: Border.all(color: _borderColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'calculator.footer_text'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showNearbyBanksPending,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'calculator.find_banks_button'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.location_on, size: 20),
                            ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.valueColor,
    required this.subtitle,
    required this.subtitleColor,
    required this.backgroundColor,
    required this.border,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final String value;
  final Color valueColor;
  final String subtitle;
  final Color subtitleColor;
  final Color backgroundColor;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
        ],
      ),
    );
  }
}

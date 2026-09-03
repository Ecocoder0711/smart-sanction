import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/match_candidate.dart';
import '../../services/api_service.dart';
import '../auth/widgets/trust_footer.dart';
import '../scheme_matching/nearby_banks_screen.dart';

class EmiCalculatorScreen extends StatefulWidget {
  /// Opens in generic mode when [candidate] is null (the Dashboard entry), and
  /// in scheme mode when a matched scheme is supplied.
  ///
  /// The whole candidate is carried rather than a handful of primitives so the
  /// screen keeps the scheme id it needs for server-side calculation, and so
  /// `candidate.partners` stays available for the Nearby Banks step.
  const EmiCalculatorScreen({super.key, this.candidate});

  final MatchCandidate? candidate;

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _progressTrackColor = Color(0xFFD9E3F4);

  // Generic-mode defaults, used only when no scheme was supplied.
  static const double _genericMinAmount = 10000;
  static const double _genericMaxAmount = 250000;
  static const double _genericInitialAmount = 50000;
  static const double _genericInterestRate = 6.5;
  static const int _genericTenureMonths = 120;

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final _apiService = ApiService();

  late double _loanAmount;
  late double _minAmount;
  late double _maxAmount;
  late double _interestRate;
  late int _tenureMonths;

  /// Server-calculated EMI for the amount currently on the slider, or null
  /// while none has been confirmed yet. Authoritative whenever present.
  double? _backendEmi;
  bool _isCalculating = false;
  String? _calculationError;

  /// Guards against a slow earlier response overwriting a newer one.
  int _calculationSeq = 0;

  MatchCandidate? get _candidate => widget.candidate;

  @override
  void initState() {
    super.initState();
    final candidate = _candidate;

    if (candidate != null) {
      // Scheme mode reproduces exactly the scenario the matched-scheme card
      // showed: the applicant's own requested amount at the scheme's rate and
      // the tenure /api/match used -- not the scheme's maximum.
      _maxAmount = candidate.scheme.maxLoanLimit;
      _minAmount = _genericMinAmount < _maxAmount
          ? _genericMinAmount
          : _maxAmount;
      _loanAmount = candidate.requestedAmount.clamp(_minAmount, _maxAmount);
      _interestRate = candidate.scheme.interestRate;
      _tenureMonths = candidate.financial.tenureMonths;
      // The card's EMI is already a server figure for this exact scenario,
      // so it is trusted until the amount is changed.
      _backendEmi = candidate.financial.emi;
    } else {
      _minAmount = _genericMinAmount;
      _maxAmount = _genericMaxAmount;
      _loanAmount = _genericInitialAmount;
      _interestRate = _genericInterestRate;
      _tenureMonths = _genericTenureMonths;
    }
  }

  /// Local reducing-balance EMI, used only for instant slider feedback.
  ///
  /// Calculated on the full selected principal. There is no subsidy: the
  /// backend has no such field, so applying one here understated every EMI.
  double get _localEmi {
    final r = _interestRate / 12 / 100;
    final n = _tenureMonths;
    if (r == 0) return _loanAmount / n;
    final factor = pow(1 + r, n);
    return _loanAmount * r * factor / (factor - 1);
  }

  /// What the EMI card shows: the server figure when one is confirmed for the
  /// current amount, otherwise the on-device preview.
  double get _displayedEmi => _backendEmi ?? _localEmi;

  /// Renders a stored rate without trailing zeros: 5.2500 -> "5.25".
  static String _formatRate(double rate) {
    final text = rate.toStringAsFixed(2);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }

  /// Re-runs the calculation server-side once the slider settles.
  ///
  /// Called from onChangeEnd rather than onChanged, so dragging does not fire
  /// a request per pixel.
  Future<void> _refreshFromBackend() async {
    final candidate = _candidate;
    if (candidate == null) return;

    final seq = ++_calculationSeq;
    setState(() {
      _isCalculating = true;
      _calculationError = null;
    });

    try {
      final result = await _apiService.calculateSchemeLoan(
        schemeId: candidate.scheme.id,
        requestedAmount: _loanAmount,
        tenureMonths: _tenureMonths,
      );
      // A newer drag already superseded this request.
      if (!mounted || seq != _calculationSeq) return;
      setState(() {
        _backendEmi = result.emi;
        _isCalculating = false;
      });
    } on ApiException catch (error) {
      if (!mounted || seq != _calculationSeq) return;
      setState(() {
        _isCalculating = false;
        // Keep showing the local estimate rather than blanking the card, and
        // never navigate away over a failed calculation.
        _backendEmi = null;
        _calculationError = error.statusCode == 404 || error.statusCode == 400
            ? 'calculator.scheme_unavailable'.tr()
            : 'calculator.calc_failed'.tr();
      });
    } on Exception {
      if (!mounted || seq != _calculationSeq) return;
      setState(() {
        _isCalculating = false;
        _backendEmi = null;
        _calculationError = 'calculator.calc_failed'.tr();
      });
    }
  }

  void _goToNearbyBanks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Carries the routed partners /api/match already returned, so the
        // next screen needs no request of its own.
        builder: (context) => NearbyBanksScreen(candidate: _candidate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only scheme mode has a moratorium; generic mode hides the card rather
    // than inventing a value.
    final moratoriumMonths = _candidate?.scheme.moratoriumMonths;

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
                                const SizedBox(width: 12),
                                // Shrinks instead of overflowing: a real
                                // scheme limit such as Rs 20,00,000 is far
                                // wider than the old Rs 2,50,000 cap.
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _currencyFormat.format(_loanAmount),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.deepNavy,
                                      ),
                                    ),
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
                                  setState(() {
                                    _loanAmount = value;
                                    // The confirmed figure no longer matches
                                    // the amount on screen; fall back to the
                                    // local preview until the server answers.
                                    _backendEmi = null;
                                  });
                                },
                                // Fires once per drag, not per pixel.
                                onChangeEnd: (_) => _refreshFromBackend(),
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
                            // The subsidy card that stood here has been
                            // removed: it applied a hardcoded 25% that no
                            // backend field supports, and it understated
                            // every EMI. The tenure -- previously invisible
                            // despite driving the figure -- takes its slot.
                            _InfoCard(
                              icon: Icons.event_repeat,
                              iconColor: AppColors.deepNavy,
                              label: 'calculator.tenure_label'.tr(),
                              labelColor: AppColors.deepNavy,
                              value: 'calculator.tenure_value'.tr(
                                namedArgs: {'months': '$_tenureMonths'},
                              ),
                              valueColor: AppColors.deepNavy,
                              subtitle: 'calculator.tenure_subtitle'.tr(),
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
                              value: _currencyFormat.format(_displayedEmi),
                              valueColor: Colors.white,
                              // Says what is actually modelled. The old copy
                              // read "post-moratorium", which the formula
                              // never accounted for.
                              subtitle: 'calculator.emi_subtitle_v2'.tr(
                                namedArgs: {
                                  'rate': _formatRate(_interestRate),
                                  'months': '$_tenureMonths',
                                },
                              ),
                              subtitleColor: const Color(0xFFB6C6EF),
                              backgroundColor: AppColors.deepNavy,
                              border: null,
                              trailing: _isCalculating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            // Moratorium is scheme data. Generic mode has no
                            // scheme, so the card is hidden rather than
                            // showing an invented number.
                            if (moratoriumMonths != null) ...[
                              const SizedBox(height: 12),
                              _InfoCard(
                                icon: Icons.hourglass_bottom,
                                iconColor: AppColors.deepNavy,
                                label: 'calculator.moratorium_label'.tr(),
                                labelColor: AppColors.deepNavy,
                                value: 'calculator.moratorium_value_months'.tr(
                                  namedArgs: {'months': '$moratoriumMonths'},
                                ),
                                valueColor: AppColors.deepNavy,
                                subtitle: 'calculator.moratorium_subtitle_v2'
                                    .tr(),
                                subtitleColor: Colors.grey.shade600,
                                backgroundColor: Colors.white,
                                border: Border.all(color: _borderColor),
                              ),
                            ],
                            if (_calculationError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _calculationError!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
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
                          onPressed: _goToNearbyBanks,
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
    this.trailing,
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

  /// Optional widget pinned to the right of the label row; used for the
  /// refresh spinner so it costs no extra vertical space.
  final Widget? trailing;

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
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
        ],
      ),
    );
  }
}

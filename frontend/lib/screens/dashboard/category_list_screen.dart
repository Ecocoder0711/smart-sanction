import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/scheme.dart';
import '../../services/api_service.dart';
import '../scheme_matching/scheme_intake_screen.dart';

const Color _backgroundColor = Color(0xFFF9FAFB);
const Color _borderColor = Color(0xFFD1D5DB);

/// Rupee amounts, grouped Indian-style with no paise.
final NumberFormat _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// The full list behind the Dashboard's "more..." link.
///
/// [title] is the section heading that opened this screen, shown verbatim in
/// the app bar. It is display text, not a filter: the Dashboard now has a
/// single generic "Explore Schemes" entry point, so this lists every active
/// scheme rather than a category slice. `/api/schemes` does support
/// `?category=`, which a later filter UI could use.
class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key, required this.title, this.apiService});

  final String title;

  /// Injection seam for tests, matching how ApiService and AuthService take an
  /// optional client. Production callers omit it and get the default.
  final ApiService? apiService;

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  late final ApiService _apiService = widget.apiService ?? ApiService();

  List<Scheme> _schemes = const [];
  bool _isLoading = true;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  Future<void> _loadSchemes() async {
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });
    try {
      // Public catalogue endpoint; no token required to browse.
      final schemes = await _apiService.fetchSchemes();
      if (!mounted) return;
      setState(() {
        _schemes = schemes;
        _isLoading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasFailed = true;
      });
    }
  }

  /// Schemes are browsed here, then applied for in intake, which is where a
  /// requested amount is actually collected. Nothing financial is pre-filled.
  void _goToSchemeIntake() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SchemeIntakeScreen()),
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
        title: Text(widget.title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasFailed) {
      return _CentredNotice(
        message: 'dashboard.schemes_failed'.tr(),
        onRetry: _loadSchemes,
      );
    }

    if (_schemes.isEmpty) {
      return _CentredNotice(
        message: 'dashboard.schemes_empty'.tr(),
        onRetry: null,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _schemes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _SchemeListCard(
        scheme: _schemes[index],
        onTap: _goToSchemeIntake,
      ),
    );
  }
}

/// Empty and failure states, with an optional retry.
class _CentredNotice extends StatelessWidget {
  const _CentredNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'dashboard.retry_button'.tr(),
                  style: const TextStyle(
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-width scheme row using the Dashboard card's colours, radius and
/// typography, laid out vertically since there is no horizontal constraint.
///
/// Shows only stored scheme facts. No eligibility, match score or approval
/// probability appears here: none of those exist without a requested amount.
class _SchemeListCard extends StatelessWidget {
  const _SchemeListCard({required this.scheme, required this.onTap});

  final Scheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scheme.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${scheme.interestRate}% p.a.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'dashboard.scheme_max_loan'.tr(
                      namedArgs: {
                        'amount': _rupees.format(scheme.maxLoanLimit),
                      },
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.softGray,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                scheme.category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

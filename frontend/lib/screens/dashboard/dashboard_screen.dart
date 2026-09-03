import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_error_messages.dart';
import '../../models/loan_application.dart';
import '../../models/scheme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../calculator/emi_calculator_screen.dart';
import '../scheme_matching/scheme_intake_screen.dart';
import '../wizard/login_screen.dart';
import 'category_list_screen.dart';

/// Rupee amounts, grouped Indian-style with no paise.
final NumberFormat _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '\u20B9',
  decimalDigits: 0,
);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);

  /// Public catalogue for browsing. Not personalised: the Dashboard has no
  /// requested amount, so it cannot honestly rank or filter by eligibility --
  /// that happens in Scheme Intake, where an amount is actually collected.
  List<Scheme> _schemes = const [];
  bool _schemesLoading = true;
  bool _schemesFailed = false;

  /// The applicant's own applications. Loaded independently of the schemes so
  /// one failing section does not blank the other.
  List<LoanApplication> _applications = const [];
  bool _applicationsLoading = true;
  bool _applicationsFailed = false;

  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSchemes();
    _loadApplications();
  }

  Future<void> _loadSchemes() async {
    setState(() {
      _schemesLoading = true;
      _schemesFailed = false;
    });
    try {
      final schemes = await _apiService.fetchSchemes();
      if (!mounted) return;
      setState(() {
        _schemes = schemes;
        _schemesLoading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _schemesLoading = false;
        _schemesFailed = true;
      });
    }
  }

  Future<void> _loadApplications() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      // Not signed in: an empty list is the honest state, not an error.
      setState(() {
        _applications = const [];
        _applicationsLoading = false;
      });
      return;
    }

    setState(() {
      _applicationsLoading = true;
      _applicationsFailed = false;
    });
    try {
      final applications = await _apiService.fetchOwnApplications(token: token);
      if (!mounted) return;
      setState(() {
        _applications = applications;
        _applicationsLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _applicationsLoading = false;
        _applicationsFailed = true;
      });
      if (isUnauthorized(error)) await _returnToLogin();
    }
  }

  /// Sends an expired session back to Login, matching the rest of the app.
  Future<void> _returnToLogin() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('auth.session_expired'.tr())),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _toggleLanguage() {
    final isEnglish = context.locale.languageCode == 'en';
    context.setLocale(isEnglish ? const Locale('hi') : const Locale('en'));
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToSchemeIntake() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SchemeIntakeScreen()),
    );
  }

  void _goToCalculator() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmiCalculatorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingCta(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Text(
                'dashboard.we_offer_header'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 12),
              _buildFeatureCardsRow(context),
              const SizedBox(height: 28),
              // "Recommended" would claim a personalisation the Dashboard
              // cannot perform without a requested amount, so this is a plain
              // catalogue. "Recently Viewed" is gone: no view history exists
              // server-side and none is invented here.
              _buildSchemeSection(
                context,
                title: 'dashboard.section_explore'.tr(),
                schemes: _schemes,
                isLoading: _schemesLoading,
                hasFailed: _schemesFailed,
                emptyKey: 'dashboard.schemes_empty',
                failedKey: 'dashboard.schemes_failed',
                onRetry: _loadSchemes,
              ),
              const SizedBox(height: 24),
              _buildApplicationsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () =>
                _showComingSoon('dashboard.profile_edit_snackbar'.tr()),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.softGray,
                  child: Icon(
                    Icons.person,
                    color: AppColors.deepNavy,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.greeting_hello'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    // Real name from the signed-in profile. Falls back to a
                    // neutral word when the user has not loaded yet -- never
                    // to a person's name.
                    Text(
                      context.watch<AuthProvider>().user?['full_name']
                              as String? ??
                          'dashboard.greeting_fallback'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: _toggleLanguage,
          icon: const Icon(Icons.language, color: AppColors.deepNavy),
        ),
        IconButton(
          onPressed: () => _showComingSoon('dashboard.profile_snackbar'.tr()),
          icon: const Icon(Icons.person_outline, color: AppColors.deepNavy),
        ),
        IconButton(
          onPressed: () => _showComingSoon('dashboard.settings_snackbar'.tr()),
          icon: const Icon(Icons.settings_outlined, color: AppColors.deepNavy),
        ),
      ],
    );
  }

  Widget _buildFloatingCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: FloatingActionButton.extended(
          onPressed: _goToSchemeIntake,
          backgroundColor: AppColors.emeraldGreen,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const StadiumBorder(),
          label: Text(
            'dashboard.start_application_cta'.tr(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCardsRow(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FeatureCard(
              icon: Icons.search,
              topLabel: 'dashboard.card_schemes_title'.tr(),
              centerLabel: 'dashboard.card_schemes_center'.tr(),
              subtitle: 'dashboard.card_schemes_subtitle'.tr(),
              isDark: false,
              onTap: _goToSchemeIntake,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FeatureCard(
              icon: Icons.calculate,
              topLabel: 'dashboard.card_calculator_title'.tr(),
              centerLabel: 'dashboard.card_calculator_center'.tr(),
              subtitle: 'dashboard.card_calculator_subtitle'.tr(),
              isDark: true,
              onTap: _goToCalculator,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FeatureCard(
              icon: Icons.location_on,
              topLabel: 'dashboard.card_partners_title'.tr(),
              centerLabel: 'dashboard.card_partners_center'.tr(),
              subtitle: 'dashboard.card_partners_subtitle'.tr(),
              isDark: false,
              onTap: () =>
                  _showComingSoon('dashboard.feature_coming_soon'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeSection(
    BuildContext context, {
    required String title,
    required List<Scheme> schemes,
    required bool isLoading,
    required bool hasFailed,
    required String emptyKey,
    required String failedKey,
    required VoidCallback onRetry,
  }) {
    // Two cards fit exactly on screen: 16px padding on each side + 16px
    // gap between the pair = 48px consumed, remainder split evenly.
    final cardWidth = (MediaQuery.of(context).size.width - 48) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 12),
        // Every state occupies the same 130px strip, so the page never
        // reflows between loading, loaded, empty and failed.
        SizedBox(
          height: 130,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : hasFailed
              ? _SectionNotice(
                  message: failedKey.tr(),
                  onRetry: onRetry,
                )
              : schemes.isEmpty
              ? _SectionNotice(message: emptyKey.tr(), onRetry: null)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: schemes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16),
                  itemBuilder: (context, index) => _SchemeCard(
                    scheme: schemes[index],
                    borderColor: _borderColor,
                    width: cardWidth,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryListScreen(title: title),
                ),
              );
            },
            child: Text(
              'dashboard.more_link'.tr(),
              style: const TextStyle(
                color: AppColors.deepNavy,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "My Applications" replaces the former "Saved/Drafted" section.
  ///
  /// The backend has no saved or draft concept -- ApplicationStatus starts at
  /// "submitted" -- so nothing here is labelled a draft. Applications are
  /// created from the application flow, never from this screen.
  Widget _buildApplicationsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'dashboard.section_my_applications'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 12),
        if (_applicationsLoading)
          const SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_applicationsFailed)
          SizedBox(
            height: 96,
            child: _SectionNotice(
              message: 'dashboard.applications_failed'.tr(),
              onRetry: _loadApplications,
            ),
          )
        else if (_applications.isEmpty)
          _EmptyApplications(borderColor: _borderColor)
        else
          for (final application in _applications) ...[
            _ApplicationCard(
              application: application,
              borderColor: _borderColor,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// Fills a section's slot when it is empty or failed, with an optional retry.
class _SectionNotice extends StatelessWidget {
  const _SectionNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
    );
  }
}

/// Shown to an applicant who has not applied for anything yet -- the normal
/// state for a new account, not an error.
class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications({required this.borderColor});

  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text(
            'dashboard.applications_empty'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'dashboard.applications_empty_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// One real application, using the same card shell as the scheme cards.
class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.borderColor,
  });

  final LoanApplication application;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  application.schemeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: application.status,
                  label: application.statusKey.tr()),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            application.partnerName,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'dashboard.application_amount'.tr(
              namedArgs: {'amount': _rupees.format(application.requestedAmount)},
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.emeraldGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colours the backend lifecycle state. Unknown states fall back to neutral
/// grey rather than asserting a meaning the app does not know.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'completed' => AppColors.emeraldGreen,
      'rejected' => AppColors.errorRed,
      'submitted' || 'under_review' => AppColors.deepNavy,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.topLabel,
    required this.centerLabel,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String topLabel;
  final String centerLabel;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  static const Color _borderColor = Color(0xFFD1D5DB);

  @override
  Widget build(BuildContext context) {
    final foreground = isDark ? Colors.white : AppColors.deepNavy;
    final centerColor = isDark ? Colors.white : AppColors.emeraldGreen;
    final subtitleColor = isDark
        ? const Color(0xFFB6C6EF)
        : Colors.grey.shade600;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.deepNavy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? null : Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    topLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              centerLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: centerColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: subtitleColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({
    required this.scheme,
    required this.borderColor,
    required this.width,
  });

  final Scheme scheme;
  final Color borderColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scheme.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const Spacer(),
          Text(
            '${scheme.interestRate}% p.a.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.emeraldGreen,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}

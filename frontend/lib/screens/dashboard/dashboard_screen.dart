import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/scheme.dart';
import '../scheme_matching/scheme_intake_screen.dart';
import 'category_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);

  // Mock data only — no backend calls. Names/rates mirror the real seeded
  // schemes for realism, but this list is static and disconnected.
  static const List<Scheme> _mockSchemes = [
    Scheme(
      id: 1,
      name: 'Demo Enterprise Boost',
      category: 'General',
      maxLoanLimit: 2000000,
      interestRate: 7.25,
    ),
    Scheme(
      id: 2,
      name: 'Demo Community Growth Credit',
      category: 'SC',
      maxLoanLimit: 1200000,
      interestRate: 6.25,
    ),
    Scheme(
      id: 3,
      name: 'Demo Women Entrepreneur Starter',
      category: 'Women',
      maxLoanLimit: 600000,
      interestRate: 4.25,
    ),
    Scheme(
      id: 4,
      name: 'Demo Artisan Opportunity Fund',
      category: 'OBC',
      maxLoanLimit: 500000,
      interestRate: 5.25,
    ),
    Scheme(
      id: 5,
      name: 'Demo Tribal Livelihood Microcredit',
      category: 'ST',
      maxLoanLimit: 200000,
      interestRate: 3.75,
    ),
    Scheme(
      id: 6,
      name: 'Demo Minority Livelihood Support',
      category: 'Minority',
      maxLoanLimit: 400000,
      interestRate: 4.75,
    ),
  ];

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

  @override
  Widget build(BuildContext context) {
    final recommended = _mockSchemes;
    final recentlyViewed = _mockSchemes.sublist(0, 3);
    final savedDrafted = _mockSchemes.sublist(4);

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
              _buildSchemeSection(
                context,
                title: 'dashboard.section_recommended'.tr(),
                schemes: recommended,
              ),
              const SizedBox(height: 24),
              _buildSchemeSection(
                context,
                title: 'dashboard.section_recently_viewed'.tr(),
                schemes: recentlyViewed,
              ),
              const SizedBox(height: 24),
              _buildSchemeSection(
                context,
                title: 'dashboard.section_saved_drafted'.tr(),
                schemes: savedDrafted,
              ),
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
                    const Text(
                      'Venika Panwar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
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
              onTap: () =>
                  _showComingSoon('dashboard.feature_coming_soon'.tr()),
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
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: schemes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
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

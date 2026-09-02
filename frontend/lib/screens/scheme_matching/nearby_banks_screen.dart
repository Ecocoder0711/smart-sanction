import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../auth/widgets/trust_footer.dart';
import '../dashboard/dashboard_screen.dart';

const Color _borderColor = Color(0xFFD1D5DB);

enum _ActionButtonStyle { filled, outlined, disabled }

class _MockPartner {
  const _MockPartner({
    required this.name,
    required this.distanceLabel,
    required this.quotaAvailable,
    required this.actionStyle,
  });

  final String name;
  final String distanceLabel;
  final bool quotaAvailable;
  final _ActionButtonStyle actionStyle;
}

class NearbyBanksScreen extends StatefulWidget {
  const NearbyBanksScreen({super.key});

  @override
  State<NearbyBanksScreen> createState() => _NearbyBanksScreenState();
}

class _NearbyBanksScreenState extends State<NearbyBanksScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _mapBackgroundColor = Color(0xFFDCE4FB);

  // Mock data only — no backend calls.
  static const List<_MockPartner> _mockPartners = [
    _MockPartner(
      name: 'First National Bank - Main Branch',
      distanceLabel: '0.8 miles away',
      quotaAvailable: true,
      actionStyle: _ActionButtonStyle.filled,
    ),
    _MockPartner(
      name: 'Community Credit Union',
      distanceLabel: '1.2 miles away',
      quotaAvailable: false,
      actionStyle: _ActionButtonStyle.disabled,
    ),
    _MockPartner(
      name: 'GovService Agency #42',
      distanceLabel: '2.5 miles away',
      quotaAvailable: true,
      actionStyle: _ActionButtonStyle.outlined,
    ),
  ];

  Future<void> _openDirections(String name) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('nearby_banks.directions_unavailable'.tr())),
      );
    }
  }

  void _selectCenter(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'nearby_banks.center_selected_snackbar'.tr(namedArgs: {'name': name}),
        ),
      ),
    );
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('nearby_banks.save_draft_snackbar'.tr())),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
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
      body: SafeArea(
        child: SingleChildScrollView(
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
                          'nearby_banks.title'.tr(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'nearby_banks.subtitle'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'nearby_banks.step_label'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepNavy,
                                ),
                              ),
                              Row(
                                children: List.generate(4, (index) {
                                  final isLast = index == 3;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: index == 0 ? 0 : 4,
                                    ),
                                    child: Container(
                                      width: 22,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isLast
                                            ? AppColors.deepNavy
                                            : AppColors.emeraldGreen,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _StaticMapPlaceholder(
                          backgroundColor: _mapBackgroundColor,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'nearby_banks.partners_header'.tr(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepNavy,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softGray,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'nearby_banks.partners_found_badge'.tr(
                                  namedArgs: {
                                    'count': _mockPartners.length.toString(),
                                  },
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final partner in _mockPartners) ...[
                          _PartnerCard(
                            partner: partner,
                            onSelect: () => _selectCenter(partner.name),
                            onDirections: () => _openDirections(partner.name),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.deepNavy,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'nearby_banks.lock_notice'.tr(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saveDraft,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'nearby_banks.save_draft_button'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _StaticMapPlaceholder extends StatelessWidget {
  const _StaticMapPlaceholder({required this.backgroundColor});

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 12,
            right: 90,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place, size: 18, color: AppColors.deepNavy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'nearby_banks.your_location_label'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        Text(
                          'nearby_banks.your_location_address'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 60,
            top: 90,
            child: Icon(
              Icons.location_on,
              size: 30,
              color: AppColors.emeraldGreen,
            ),
          ),
          Positioned(
            left: 118,
            top: 120,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _borderColor),
              ),
              child: const Icon(
                Icons.image,
                size: 16,
                color: AppColors.deepNavy,
              ),
            ),
          ),
          const Positioned(
            left: 150,
            top: 92,
            child: Icon(Icons.location_on, size: 34, color: AppColors.errorRed),
          ),
          const Positioned(
            left: 95,
            top: 155,
            child: Icon(Icons.location_on, size: 32, color: AppColors.deepNavy),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _MapControlButton(icon: Icons.add),
                const SizedBox(height: 8),
                _MapControlButton(icon: Icons.remove),
                const SizedBox(height: 8),
                _MapControlButton(icon: Icons.gps_fixed),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: AppColors.deepNavy),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.onSelect,
    required this.onDirections,
  });

  final _MockPartner partner;
  final VoidCallback onSelect;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  partner.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: partner.quotaAvailable
                        ? AppColors.deepNavy
                        : Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _QuotaPill(available: partner.quotaAvailable),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.map_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                partner.distanceLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (partner.actionStyle == _ActionButtonStyle.disabled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.softGray,
                  foregroundColor: Colors.grey.shade500,
                  disabledBackgroundColor: AppColors.softGray,
                  disabledForegroundColor: Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('nearby_banks.unavailable_button'.tr()),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: partner.actionStyle == _ActionButtonStyle.filled
                      ? ElevatedButton(
                          onPressed: onSelect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('nearby_banks.select_center_button'.tr()),
                        )
                      : OutlinedButton(
                          onPressed: onSelect,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.deepNavy,
                            side: const BorderSide(color: AppColors.deepNavy),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('nearby_banks.select_center_button'.tr()),
                        ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onDirections,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Icon(
                      Icons.turn_right,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuotaPill extends StatelessWidget {
  const _QuotaPill({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.emeraldGreen : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '• ${available ? 'nearby_banks.quota_available'.tr() : 'nearby_banks.quota_exhausted'.tr()}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

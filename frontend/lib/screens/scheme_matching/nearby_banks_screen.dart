import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../models/match_candidate.dart';
import '../auth/widgets/trust_footer.dart';
import '../dashboard/dashboard_screen.dart';

const Color _borderColor = Color(0xFFD1D5DB);

/// Rupee amounts, grouped Indian-style with no paise.
final NumberFormat _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '\u20B9',
  decimalDigits: 0,
);

/// One decimal is enough to separate branches that sit hundreds of metres
/// apart, which is the spread the router actually returns.
String _formatKm(double km) => km.toStringAsFixed(1);

class NearbyBanksScreen extends StatefulWidget {
  /// Carries the matched scheme whose routed partners this screen lists.
  ///
  /// Optional so the Dashboard's generic calculator route still compiles;
  /// without a candidate there are no partners to show and the screen says so
  /// rather than falling back to sample data.
  const NearbyBanksScreen({super.key, this.candidate});

  final MatchCandidate? candidate;

  @override
  State<NearbyBanksScreen> createState() => _NearbyBanksScreenState();
}

class _NearbyBanksScreenState extends State<NearbyBanksScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _mapBackgroundColor = Color(0xFFDCE4FB);

  /// Routed partners from `/api/match`, already active, in-quota, within the
  /// configured radius, nearest-K bounded and ordered by health score. The
  /// order is the backend's ranking and is rendered as-is.
  List<RecommendedPartner> get _partners =>
      widget.candidate?.partners ?? const [];

  /// Selection is local to this screen: no applicant-facing endpoint exists
  /// for persisting a chosen partner, so nothing here claims it was saved.
  int? _selectedPartnerId;

  /// Opens Google Maps at the branch's real coordinates.
  ///
  /// The previous version searched by bank name, which cannot resolve a
  /// branch reliably -- several partners share a name, and one is called
  /// "GovService Agency #42".
  Future<void> _openDirections(RecommendedPartner partner) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${partner.latitude},${partner.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('nearby_banks.directions_unavailable'.tr())),
      );
    }
  }

  void _selectCenter(RecommendedPartner partner) {
    setState(() => _selectedPartnerId = partner.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'nearby_banks.center_selected_snackbar'.tr(
            namedArgs: {'name': partner.bankName},
          ),
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
                                    'count': _partners.length.toString(),
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
                        if (_partners.isEmpty)
                          _EmptyPartners(
                            message: widget.candidate?.partnerMessage,
                            onBack: () => Navigator.pop(context),
                          )
                        else
                          for (final partner in _partners) ...[
                            _PartnerCard(
                              partner: partner,
                              isSelected: partner.id == _selectedPartnerId,
                              onSelect: () => _selectCenter(partner),
                              onDirections: () => _openDirections(partner),
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
                          'nearby_banks.your_location_saved'.tr(),
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
    required this.isSelected,
    required this.onSelect,
    required this.onDirections,
  });

  final RecommendedPartner partner;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.deepNavy : _borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.bankName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    // Several partners share a bank name; the branch code is
                    // what tells them apart.
                    Text(
                      partner.branchCode,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _QuotaPill(quotaRemaining: partner.quotaRemaining),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.map_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'nearby_banks.distance_km'.tr(
                  namedArgs: {'km': _formatKm(partner.distanceKm)},
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (partner.healthScore != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                // Deterministic NPA/quota/proximity score from the backend --
                // not an ML output and never recomputed here.
                Text(
                  '${'nearby_banks.partner_score_label'.tr()}: '
                  '${(partner.healthScore! * 100).round()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: isSelected
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
                        child: Text('nearby_banks.selected_badge'.tr()),
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

/// Shows the branch's actual remaining disbursement quota.
///
/// The previous version was a boolean available/exhausted flag, but
/// `/api/match` filters out zero-quota partners, so the exhausted state could
/// never appear. The amount is a branch-level figure and deliberately makes no
/// claim about the largest loan it could fund.
class _QuotaPill extends StatelessWidget {
  const _QuotaPill({required this.quotaRemaining});

  final double? quotaRemaining;

  @override
  Widget build(BuildContext context) {
    final quota = quotaRemaining;
    if (quota == null) return const SizedBox.shrink();

    const color = AppColors.emeraldGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '• ${'nearby_banks.quota_available_amount'.tr(namedArgs: {
              'amount': _rupees.format(quota),
            })}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Shown when there are no partners to list.
///
/// Covers three legitimate cases, all non-error: no branch inside the
/// configured radius, an applicant whose profile has no coordinates (the
/// wizard's manual-location path), and the Dashboard's generic calculator
/// route, which has no scheme at all. The backend's own explanation is used
/// when one is available rather than a message invented here.
class _EmptyPartners extends StatelessWidget {
  const _EmptyPartners({required this.message, required this.onBack});

  final String? message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, size: 40, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'nearby_banks.empty_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'nearby_banks.empty_no_scheme'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepNavy,
              side: const BorderSide(color: _borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'nearby_banks.empty_back_button'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

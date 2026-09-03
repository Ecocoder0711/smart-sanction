import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_error_messages.dart';
import '../../core/network/directions_launcher.dart';
import '../../models/match_candidate.dart';
import '../../models/nearby_bank.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/widgets/trust_footer.dart';
import '../dashboard/dashboard_screen.dart';
import '../wizard/login_screen.dart';
import 'widgets/bank_map.dart';

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
  const NearbyBanksScreen({super.key, this.candidate, this.apiService});

  final MatchCandidate? candidate;

  /// Injection seam for tests, matching how ApiService and AuthService take an
  /// optional client. Production callers omit it and get the default.
  final ApiService? apiService;

  @override
  State<NearbyBanksScreen> createState() => _NearbyBanksScreenState();
}

class _NearbyBanksScreenState extends State<NearbyBanksScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);

  /// Routed partners from `/api/match`, already active, in-quota, within the
  /// configured radius, nearest-K bounded and ordered by health score. The
  /// order is the backend's ranking and is rendered as-is.
  List<RecommendedPartner> get _partners =>
      widget.candidate?.partners ?? const [];

  /// Selection is local until the draft is saved. Choosing a centre never
  /// submits anything on its own.
  ///
  /// Only ever a registered partner's id. A real OpenStreetMap bank cannot
  /// reach this field, which is what keeps it out of the saved draft.
  int? _selectedPartnerId;

  late final ApiService _apiService = widget.apiService ?? ApiService();
  bool _isSavingDraft = false;

  final GlobalKey<BankMapState> _mapKey = GlobalKey<BankMapState>();

  /// Which marker is highlighted. Namespaced ("partner-3" vs an OSM id) so
  /// the two datasets can never collide on an integer id.
  String? _selectedMarkerId;

  /// Real OpenStreetMap branches, loaded independently of the partner list so
  /// a discovery outage cannot take the routed partners down with it.
  List<NearbyBank> _banks = const [];
  bool _isLoadingBanks = false;
  String? _banksError;

  /// True when more branches exist inside the radius than the backend
  /// returns, so the list can say so instead of looking complete.
  bool _banksCapped = false;
  int _banksDiscovered = 0;

  /// How far around the applicant real branches are discovered.
  ///
  /// Sent explicitly rather than relying on the backend default, so this
  /// screen's behaviour is visible here. Deliberately distinct from the
  /// backend's 50 km channel-partner routing radius, which is a different
  /// system answering a different question and is untouched.
  static const double _discoveryRadiusKm = 40;

  @override
  void initState() {
    super.initState();
    _loadNearbyBanks();
  }

  /// The applicant's stored coordinates, or null if they registered with a
  /// state and district instead of GPS.
  ///
  /// Read from the profile already loaded into AuthProvider — no second GPS
  /// permission prompt, and no invented fallback centre.
  ({double latitude, double longitude})? get _userLocation {
    final user = context.read<AuthProvider>().user;
    final latitude = user?['latitude'];
    final longitude = user?['longitude'];
    if (latitude is num && longitude is num) {
      return (latitude: latitude.toDouble(), longitude: longitude.toDouble());
    }
    return null;
  }

  Future<void> _loadNearbyBanks() async {
    final location = _userLocation;
    // No coordinates means no query: there is no honest centre to search
    // around, and guessing one would put the applicant in another city.
    if (location == null) return;

    setState(() {
      _isLoadingBanks = true;
      _banksError = null;
    });
    try {
      final result = await _apiService.fetchNearbyBanks(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: _discoveryRadiusKm,
      );
      if (!mounted) return;
      setState(() {
        _banks = result.items;
        _banksCapped = result.capped;
        _banksDiscovered = result.discovered;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      // Discovery failing is a section-level problem, never a screen-level
      // one: the routed partners below are unaffected and stay rendered.
      setState(
        () => _banksError = describeApiError(
          error,
          fallbackKey: 'nearby_banks.banks_failed',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  /// Opens external directions to an exact coordinate.
  ///
  /// Never a name search: several partners share a bank name, and
  /// OpenStreetMap has three separate "State Bank of India" entries within
  /// 2 km of the demo location. Works identically for a real OSM bank and a
  /// registered partner, since both carry real coordinates.
  Future<void> _openDirections({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    final launched = await launchDirections(
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
    // Reported only after every candidate scheme genuinely failed to launch.
    if (!launched && mounted) {
      _showMessage('nearby_banks.directions_unavailable'.tr());
    }
  }

  void _selectCenter(RecommendedPartner partner) {
    setState(() {
      _selectedPartnerId = partner.id;
      _selectedMarkerId = 'partner-${partner.id}';
    });
    // Bring the chosen branch into view without changing the zoom level.
    _mapKey.currentState?.moveTo(LatLng(partner.latitude, partner.longitude));
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

  /// Highlights whichever card a tapped marker belongs to.
  ///
  /// Tapping a real-bank marker highlights it only: it is not a selection,
  /// because a discovered bank can never become the application's partner.
  void _onMarkerTap(BankMapMarker marker) {
    setState(() => _selectedMarkerId = marker.id);
    if (marker.kind == MapMarkerKind.user) return;
    _showMessage(marker.label);
  }

  /// Persists the applicant's work as a real draft, then leaves.
  ///
  /// A draft is not a submission: the status is pinned to "draft", and the
  /// chosen centre is included only if one was actually selected, since the
  /// backend allows a draft to have none.
  Future<void> _saveDraft() async {
    final candidate = widget.candidate;
    if (candidate == null) {
      // Generic entry: there is no scheme to save against.
      _showMessage('nearby_banks.empty_no_scheme'.tr());
      return;
    }

    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) {
      await _returnToLogin();
      return;
    }

    setState(() => _isSavingDraft = true);
    try {
      await _apiService.saveApplicationDraft(
        schemeId: candidate.scheme.id,
        requestedAmount: candidate.requestedAmount,
        partnerId: _selectedPartnerId,
        token: token,
      );
      if (!mounted) return;
      _showMessage('nearby_banks.save_draft_snackbar'.tr());
      // Only now, once the row exists.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      if (isUnauthorized(error)) {
        await _returnToLogin();
        return;
      }
      // Stay put so the applicant can retry without losing their selection.
      _showMessage(
        describeApiError(error, fallbackKey: 'nearby_banks.save_draft_failed'),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _returnToLogin() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    _showMessage('auth.session_expired'.tr());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  /// The map, or an honest explanation of why there isn't one.
  Widget _buildMap(BuildContext context) {
    final location = _userLocation;
    if (location == null) {
      return const _LocationRequiredCard();
    }

    // Tall enough to be readable, capped so the list below stays reachable
    // without scrolling past a full screen of map.
    final height = (MediaQuery.of(context).size.height * 0.32).clamp(
      220.0,
      320.0,
    );

    return BankMap(
      key: _mapKey,
      height: height,
      centre: LatLng(location.latitude, location.longitude),
      selectedMarkerId: _selectedMarkerId,
      onMarkerTap: _onMarkerTap,
      markers: BankMapMarker.build(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        banks: _banks,
        partners: _partners,
      ),
    );
  }

  /// "Banks near you" -- real OpenStreetMap branches.
  ///
  /// Deliberately shows no quota, NPA, Partner Score, or Select Center: we
  /// know where these branches are and nothing about how they operate.
  Widget _buildRealBanksSection() {
    final location = _userLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'nearby_banks.real_banks_header'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
            ),
            if (_banks.isNotEmpty)
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
                  'nearby_banks.banks_found_badge'.tr(
                    namedArgs: {'count': _banks.length.toString()},
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
        const SizedBox(height: 4),
        Text(
          'nearby_banks.real_banks_subtitle'.tr(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        // Says so when the neighbourhood holds more branches than are shown,
        // rather than letting the nearest 50 read as the complete picture.
        if (_banksCapped) ...[
          const SizedBox(height: 4),
          Text(
            'nearby_banks.banks_capped_note'.tr(
              namedArgs: {
                'shown': _banks.length.toString(),
                'total': _banksDiscovered.toString(),
              },
            ),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (location == null)
          _SectionNotice(message: 'nearby_banks.banks_need_location'.tr())
        else if (_isLoadingBanks)
          const _SectionLoading()
        else if (_banksError != null)
          _SectionNotice(
            message: _banksError!,
            onRetry: _loadNearbyBanks,
          )
        else if (_banks.isEmpty)
          _SectionNotice(message: 'nearby_banks.banks_empty'.tr())
        else
          for (final bank in _banks) ...[
            _RealBankCard(
              bank: bank,
              isHighlighted: bank.osmId == _selectedMarkerId,
              onDirections: () => _openDirections(
                latitude: bank.latitude,
                longitude: bank.longitude,
                label: bank.name,
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
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
                        _buildMap(context),
                        const SizedBox(height: 24),
                        _buildRealBanksSection(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'nearby_banks.partners_header'.tr(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepNavy,
                                ),
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
                        const SizedBox(height: 4),
                        // Names what makes this list different from the one
                        // above: these are the branches an application can
                        // actually be routed through.
                        Text(
                          'nearby_banks.partners_subtitle'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
                              onDirections: () => _openDirections(
                                latitude: partner.latitude,
                                longitude: partner.longitude,
                                label: partner.bankName,
                              ),
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
                                      'nearby_banks.lock_notice_v2'.tr(),
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
                                  // Blocks a duplicate draft from a second tap.
                                  onPressed: _isSavingDraft ? null : _saveDraft,
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

/// Shown in place of the map when the applicant registered with a state and
/// district rather than GPS.
///
/// No fallback centre is invented: a map of somebody else's city would be
/// worse than no map, and Overpass is not queried at all in this state.
class _LocationRequiredCard extends StatelessWidget {
  const _LocationRequiredCard();

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
          Icon(Icons.location_off_outlined, size: 32, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            'nearby_banks.map_location_required'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'nearby_banks.map_location_required_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Placeholder row while real branches are being discovered.
class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'nearby_banks.banks_loading'.tr(),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line explanation for an empty, unavailable, or retryable section.
///
/// Scoped to the real-bank section: the registered partners below render
/// regardless of what this says.
class _SectionNotice extends StatelessWidget {
  const _SectionNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepNavy,
                side: const BorderSide(color: AppColors.deepNavy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('nearby_banks.banks_retry'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

/// A real bank branch from OpenStreetMap.
///
/// Carries a name, a distance, an optional address, and Directions -- and
/// nothing else. There is deliberately no Select Center and no Partner
/// Score: this branch is not a registered channel partner, and inventing
/// operational figures for it would misrepresent public map data.
class _RealBankCard extends StatelessWidget {
  const _RealBankCard({
    required this.bank,
    required this.isHighlighted,
    required this.onDirections,
  });

  final NearbyBank bank;
  final bool isHighlighted;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.emeraldGreen : _borderColor,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on, size: 18, color: AppColors.emeraldGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'nearby_banks.distance_km'.tr(
                    namedArgs: {'km': _formatKm(bank.distanceKm)},
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                // Only when OpenStreetMap genuinely has address tags; most
                // branches have none and simply show nothing here.
                if (bank.address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    bank.address!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
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
              child: Tooltip(
                message: 'nearby_banks.directions_button'.tr(),
                child: const Icon(
                  Icons.directions_outlined,
                  size: 18,
                  color: AppColors.deepNavy,
                ),
              ),
            ),
          ),
        ],
      ),
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

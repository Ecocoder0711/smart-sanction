import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/match_candidate.dart';
import '../../../models/nearby_bank.dart';

/// The applicant's own marker. Defined here rather than in AppColors to keep
/// this feature out of Venika's shared palette file while she is working in
/// it — the same reason `_borderColor` is screen-local in Nearby Banks.
const Color _userBlue = Color(0xFF2563EB);

/// What a marker represents. The three datasets stay distinguishable all the
/// way to the pin: a real OpenStreetMap bank and a registered channel partner
/// are different kinds of thing and must never look alike.
enum MapMarkerKind { user, realBank, registeredPartner }

/// One plotted point, built from real coordinates only — nothing here is
/// positioned by hand.
@immutable
class BankMapMarker {
  const BankMapMarker({
    required this.id,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final String id;
  final MapMarkerKind kind;
  final double latitude;
  final double longitude;
  final String label;

  LatLng get point => LatLng(latitude, longitude);

  /// Builds the full marker set for the screen.
  ///
  /// Kept as a pure function so the dataset can be tested without pumping a
  /// map: the widget only renders what this returns.
  static List<BankMapMarker> build({
    required double? userLatitude,
    required double? userLongitude,
    required List<NearbyBank> banks,
    required List<RecommendedPartner> partners,
  }) {
    return [
      if (userLatitude != null && userLongitude != null)
        BankMapMarker(
          id: 'user',
          kind: MapMarkerKind.user,
          latitude: userLatitude,
          longitude: userLongitude,
          label: 'nearby_banks.map_you_label'.tr(),
        ),
      for (final bank in banks)
        BankMapMarker(
          id: bank.osmId,
          kind: MapMarkerKind.realBank,
          latitude: bank.latitude,
          longitude: bank.longitude,
          label: bank.name,
        ),
      for (final partner in partners)
        BankMapMarker(
          id: 'partner-${partner.id}',
          kind: MapMarkerKind.registeredPartner,
          latitude: partner.latitude,
          longitude: partner.longitude,
          label: partner.bankName,
        ),
    ];
  }
}

/// Interactive OpenStreetMap view of the applicant and the branches near them.
///
/// Replaces the previous decorative placeholder, which drew pins at fixed
/// pixel offsets unrelated to any real location. Venika's rounded shell,
/// border and floating controls are preserved; only the contents are real.
class BankMap extends StatefulWidget {
  const BankMap({
    super.key,
    required this.markers,
    required this.centre,
    this.selectedMarkerId,
    this.onMarkerTap,
    this.height,
  });

  final List<BankMapMarker> markers;

  /// The applicant's own coordinates. Recentre returns here.
  final LatLng centre;

  final String? selectedMarkerId;
  final ValueChanged<BankMapMarker>? onMarkerTap;
  final double? height;

  @override
  State<BankMap> createState() => BankMapState();
}

class BankMapState extends State<BankMap> {
  final MapController _controller = MapController();

  /// Guards controller calls made before the map's first layout, which throw.
  bool _ready = false;

  static const double _initialZoom = 13;
  static const double _minZoom = 3;
  static const double _maxZoom = 18;

  /// Moves the camera to a point, used when a partner card is selected.
  void moveTo(LatLng point) {
    if (!_ready) return;
    _controller.move(point, _controller.camera.zoom);
  }

  void _zoomBy(double delta) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + delta).clamp(_minZoom, _maxZoom),
    );
  }

  void _recentre() {
    if (!_ready) return;
    _controller.move(widget.centre, _initialZoom);
  }

  /// Fits every marker in view, falling back to the applicant's own point
  /// when there is nothing else to show.
  void _fitToMarkers() {
    if (!_ready || widget.markers.length < 2) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: widget.markers.map((marker) => marker.point).toList(),
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  Color _colorFor(MapMarkerKind kind) => switch (kind) {
    MapMarkerKind.user => _userBlue,
    MapMarkerKind.realBank => AppColors.emeraldGreen,
    MapMarkerKind.registeredPartner => AppColors.deepNavy,
  };

  Marker _buildMarker(BankMapMarker marker) {
    final isSelected = marker.id == widget.selectedMarkerId;
    final color = _colorFor(marker.kind);

    return Marker(
      key: ValueKey(marker.id),
      point: marker.point,
      width: 34,
      height: 34,
      alignment:
          // A pin points at its location from above; a dot is centred on it.
          marker.kind == MapMarkerKind.user
          ? Alignment.center
          : Alignment.topCenter,
      child: GestureDetector(
        onTap: widget.onMarkerTap == null
            ? null
            : () => widget.onMarkerTap!(marker),
        child: Semantics(
          label: marker.label,
          button: widget.onMarkerTap != null,
          child: marker.kind == MapMarkerKind.user
              ? _UserDot(color: color)
              : Icon(
                  Icons.location_on,
                  color: color,
                  size: isSelected ? 34 : 28,
                  shadows: const [
                    Shadow(color: Colors.black26, blurRadius: 3),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height ?? 250;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: widget.centre,
                initialZoom: _initialZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                interactionOptions: const InteractionOptions(
                  // Rotation is disabled: a rotated map is disorienting on a
                  // demo phone and easy to trigger accidentally while pinching.
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                ),
                onMapReady: () {
                  if (!mounted) return;
                  setState(() => _ready = true);
                  _fitToMarkers();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OpenStreetMap's tile usage policy requires an identifying
                  // User-Agent; the same requirement bit the Overpass client.
                  userAgentPackageName: 'com.example.frontend',
                  maxNativeZoom: 19,
                  // Tiles failing must not blank the map: markers stay drawn
                  // over the background and the list below stays usable.
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
                MarkerLayer(markers: widget.markers.map(_buildMarker).toList()),
              ],
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                children: [
                  _MapControlButton(
                    icon: Icons.add,
                    tooltip: 'nearby_banks.map_zoom_in'.tr(),
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.remove,
                    tooltip: 'nearby_banks.map_zoom_out'.tr(),
                    onTap: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.gps_fixed,
                    tooltip: 'nearby_banks.map_recenter'.tr(),
                    onTap: _recentre,
                  ),
                ],
              ),
            ),
            const Positioned(left: 12, bottom: 12, child: _MapLegend()),
          ],
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }
}

/// Names the three marker colours. Without it the distinction between a real
/// bank and a registered partner is only a shade of green versus navy.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(
            color: _userBlue,
            label: 'nearby_banks.map_you_label'.tr(),
          ),
          const SizedBox(height: 4),
          _LegendRow(
            color: AppColors.emeraldGreen,
            label: 'nearby_banks.map_legend_bank'.tr(),
          ),
          const SizedBox(height: 4),
          _LegendRow(
            color: AppColors.deepNavy,
            label: 'nearby_banks.map_legend_partner'.tr(),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.deepNavy),
        ),
      ],
    );
  }
}

/// The floating control from the original placeholder, now with a real action.
class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: AppColors.deepNavy),
          ),
        ),
      ),
    );
  }
}

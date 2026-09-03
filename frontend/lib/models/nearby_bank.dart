/// A real bank branch discovered from OpenStreetMap.
///
/// Deliberately *not* a [RecommendedPartner]. A discovered bank is a public
/// map feature: we know where it is and what it is called, and nothing about
/// its operational health. It therefore has no quota, no NPA, and no Partner
/// Score, and it can never be sent as an application's `partner_id` — the
/// backend would reject the id anyway, since it belongs to OpenStreetMap
/// rather than to our channel-partner table.
class NearbyBank {
  const NearbyBank({
    required this.osmId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.address,
  });

  /// Stable OpenStreetMap identifier in `<type>/<id>` form, e.g. `node/123`.
  /// Used as the widget key and for marker/card correspondence.
  final String osmId;

  final String name;
  final double latitude;
  final double longitude;

  /// Great-circle distance from the applicant's stored coordinates, in
  /// kilometres, measured with the same Haversine formula the partner
  /// router uses.
  final double distanceKm;

  /// Only present when OpenStreetMap genuinely has address tags for the
  /// feature, which is the minority of Indian bank nodes. Never derived from
  /// the coordinates.
  final String? address;

  factory NearbyBank.fromJson(Map<String, dynamic> json) {
    double toDouble(Object? value) =>
        value is num ? value.toDouble() : double.parse(value.toString());

    final address = json['address'];
    return NearbyBank(
      osmId: json['osm_id'].toString(),
      name: json['name'].toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      distanceKm: toDouble(json['distance_km']),
      // Treat an empty string as absent so the UI never renders a blank line.
      address: (address == null || address.toString().trim().isEmpty)
          ? null
          : address.toString(),
    );
  }
}

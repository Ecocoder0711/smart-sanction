import 'package:url_launcher/url_launcher.dart';

/// Opens external turn-by-turn directions to an exact coordinate.
///
/// Always coordinate-based. Searching by bank name cannot resolve a branch:
/// several of our partners share a name, OpenStreetMap has three separate
/// "State Bank of India" entries within 2 km of the demo location, and a
/// name search would send the applicant to whichever one Google guessed.
///
/// Three candidates are tried in order, because no single URI works
/// everywhere:
///   1. `google.navigation:` — starts navigation directly in Google Maps.
///   2. `geo:` — any installed map app; shows a chooser if several exist.
///   3. `https://www.google.com/maps/dir/` — works with no map app at all,
///      including on a device where only a browser is installed.
///
/// Deliberately does **not** gate on [canLaunchUrl]. On Android 11+ package
/// visibility, `canLaunchUrl` returns false unless the manifest declares a
/// matching `<queries>` intent, which made Directions fail silently even
/// with Google Maps installed. Each candidate is attempted inside a
/// try/catch and only a genuine launch failure of every one of them is
/// reported to the applicant.
Future<bool> launchDirections({
  required double latitude,
  required double longitude,
  String? label,
}) async {
  final destination = '$latitude,$longitude';
  final encodedLabel = label == null ? null : Uri.encodeComponent(label);

  final candidates = <Uri>[
    Uri.parse('google.navigation:q=$destination'),
    Uri.parse(
      'geo:$destination?q=$destination'
      '${encodedLabel == null ? '' : '($encodedLabel)'}',
    ),
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    ),
  ];

  for (final uri in candidates) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } on Exception {
      // This scheme has no handler on this device; try the next one.
      continue;
    }
  }
  return false;
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/directions_launcher.dart';

/// Records the URLs url_launcher was asked to open, and controls whether each
/// attempt succeeds — the real plugin channel is unavailable under test.
class _LauncherStub {
  _LauncherStub({required this.canLaunchScheme});

  /// Returns true for a scheme this fake device has a handler for.
  final bool Function(String scheme) canLaunchScheme;

  final List<String> attempted = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method != 'launch') return null;
            final url = (call.arguments as Map)['url'] as String;
            attempted.add(url);
            return canLaunchScheme(Uri.parse(url).scheme);
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prefers Google Maps navigation to the exact coordinates', () async {
    final stub = _LauncherStub(canLaunchScheme: (_) => true)..install();

    final launched = await launchDirections(
      latitude: 30.3255,
      longitude: 78.0436,
      label: 'State Bank of India',
    );

    expect(launched, isTrue);
    expect(stub.attempted, hasLength(1));
    expect(stub.attempted.single, 'google.navigation:q=30.3255,78.0436');
  });

  test('falls back to geo: when navigation has no handler', () async {
    final stub = _LauncherStub(
      canLaunchScheme: (scheme) => scheme == 'geo',
    )..install();

    final launched = await launchDirections(
      latitude: 30.3255,
      longitude: 78.0436,
      label: 'Canara Bank',
    );

    expect(launched, isTrue);
    expect(stub.attempted.first, startsWith('google.navigation:'));
    expect(stub.attempted.last, startsWith('geo:30.3255,78.0436'));
  });

  test('falls back to the https URL when no map app exists', () async {
    final stub = _LauncherStub(
      canLaunchScheme: (scheme) => scheme == 'https',
    )..install();

    final launched = await launchDirections(
      latitude: 30.3255,
      longitude: 78.0436,
    );

    expect(launched, isTrue);
    expect(stub.attempted, hasLength(3));
    expect(
      stub.attempted.last,
      'https://www.google.com/maps/dir/?api=1&destination=30.3255,78.0436',
    );
  });

  test('reports failure only after every candidate fails', () async {
    final stub = _LauncherStub(canLaunchScheme: (_) => false)..install();

    final launched = await launchDirections(
      latitude: 30.3255,
      longitude: 78.0436,
    );

    expect(launched, isFalse);
    expect(stub.attempted, hasLength(3));
  });

  test('every candidate targets coordinates, never a name search', () async {
    final stub = _LauncherStub(canLaunchScheme: (_) => false)..install();

    await launchDirections(
      latitude: 30.3255,
      longitude: 78.0436,
      label: 'State Bank of India',
    );

    for (final url in stub.attempted) {
      expect(url, contains('30.3255,78.0436'));
      // A name search cannot resolve a branch: OpenStreetMap has three
      // separate "State Bank of India" entries within 2 km of the demo site.
      expect(url, isNot(contains('search')));
      expect(url, isNot(contains('State+Bank')));
    }
  });

  test('a label is only ever a display hint on the geo: URI', () async {
    final stub = _LauncherStub(canLaunchScheme: (scheme) => scheme == 'geo')
      ..install();

    await launchDirections(
      latitude: 30.3255,
      longitude: 78.0436,
      label: 'Bank & Trust',
    );

    // Encoded so an ampersand cannot break the query.
    expect(stub.attempted.last, contains('Bank%20%26%20Trust'));
    expect(stub.attempted.last, startsWith('geo:30.3255,78.0436?q=30.3255,78.0436'));
  });

  test('works without a label', () async {
    final stub = _LauncherStub(canLaunchScheme: (scheme) => scheme == 'geo')
      ..install();

    final launched = await launchDirections(
      latitude: 12.9716,
      longitude: 77.5946,
    );

    expect(launched, isTrue);
    expect(stub.attempted.last, 'geo:12.9716,77.5946?q=12.9716,77.5946');
  });

  test('negative and fractional coordinates survive intact', () async {
    final stub = _LauncherStub(canLaunchScheme: (_) => true)..install();

    await launchDirections(latitude: -33.8688, longitude: 151.2093);

    expect(stub.attempted.single, contains('-33.8688,151.2093'));
  });
}

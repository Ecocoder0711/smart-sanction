import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/match_candidate.dart';
import 'package:frontend/models/nearby_bank.dart';
import 'package:frontend/screens/scheme_matching/widgets/bank_map.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _bankJson({
  String osmId = 'node/1',
  String name = 'State Bank of India',
  double latitude = 30.3255,
  double longitude = 78.0436,
  double distanceKm = 0.09,
  Object? address,
}) => {
  'osm_id': osmId,
  'name': name,
  'latitude': latitude,
  'longitude': longitude,
  'distance_km': distanceKm,
  'address': address,
};

Map<String, dynamic> _partnerJson({int id = 2}) => {
  'id': id,
  'bank_name': 'Prototype Livelihood Bank',
  'branch_code': 'DEMO-DEL-002',
  'latitude': 28.615,
  'longitude': 77.2102,
  'distance_km': 0.169,
  'quota_remaining': '5000000.00',
  'npa_percentage': '2.4000',
  'health_score': 0.88499,
};

ApiService _serviceReturning(
  Object payload, {
  int status = 200,
  void Function(http.Request)? capture,
}) => ApiService(
  client: MockClient((request) async {
    capture?.call(request);
    return http.Response(
      jsonEncode(payload),
      status,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  group('NearbyBank parsing', () {
    test('parses a branch with no address', () {
      final bank = NearbyBank.fromJson(_bankJson());

      expect(bank.osmId, 'node/1');
      expect(bank.name, 'State Bank of India');
      expect(bank.latitude, 30.3255);
      expect(bank.longitude, 78.0436);
      expect(bank.distanceKm, 0.09);
      expect(bank.address, isNull);
    });

    test('keeps a real address when OpenStreetMap has one', () {
      final bank = NearbyBank.fromJson(
        _bankJson(address: '12, Rajpur Road, Dehradun'),
      );

      expect(bank.address, '12, Rajpur Road, Dehradun');
    });

    test('treats a blank address as absent', () {
      // A blank string would render as an empty line under the bank name.
      expect(NearbyBank.fromJson(_bankJson(address: '   ')).address, isNull);
    });

    test('accepts a way id and numeric strings', () {
      final bank = NearbyBank.fromJson({
        ..._bankJson(osmId: 'way/77'),
        'distance_km': '1.25',
      });

      expect(bank.osmId, 'way/77');
      expect(bank.distanceKm, 1.25);
    });
  });

  group('ApiService.fetchNearbyBanks', () {
    test('sends the coordinates and radius, unauthenticated', () async {
      late http.Request captured;
      final service = _serviceReturning(
        {'items': [_bankJson()], 'total': 1},
        capture: (r) => captured = r,
      );

      await service.fetchNearbyBanks(
        latitude: 30.3255,
        longitude: 78.0436,
        radiusKm: 40,
      );

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/nearby-banks');
      expect(captured.url.queryParameters['latitude'], '30.3255');
      expect(captured.url.queryParameters['longitude'], '78.0436');
      expect(captured.url.queryParameters['radius_km'], '40.0');
      // Public map data: no bearer token is attached.
      expect(captured.headers.containsKey('Authorization'), isFalse);
    });

    test('parses the item list', () async {
      final service = _serviceReturning({
        'items': [
          _bankJson(osmId: 'node/1', name: 'ICICI Bank'),
          _bankJson(osmId: 'node/2', name: 'Canara Bank'),
        ],
        'total': 2,
      });

      final result = await service.fetchNearbyBanks(
        latitude: 30.3255,
        longitude: 78.0436,
      );

      expect(result.items.map((b) => b.name), ['ICICI Bank', 'Canara Bank']);
      expect(result.capped, isFalse);
      expect(result.discovered, 2);
    });

    test('an empty area is an empty list, not an error', () async {
      final service = _serviceReturning({'items': [], 'total': 0});

      final result = await service.fetchNearbyBanks(
        latitude: 30.3,
        longitude: 78.0,
      );

      expect(result.items, isEmpty);
      expect(result.capped, isFalse);
    });

    test('a 503 surfaces so the section can offer a retry', () async {
      final service = _serviceReturning({'detail': 'unavailable'}, status: 503);

      await expectLater(
        service.fetchNearbyBanks(latitude: 30.3, longitude: 78.0),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
    });

    test('an unexpected shape is rejected', () async {
      final service = _serviceReturning({'unexpected': true});

      await expectLater(
        service.fetchNearbyBanks(latitude: 30.3, longitude: 78.0),
        throwsA(isA<ApiException>()),
      );
    });

    test('defaults to the 40 km discovery radius', () async {
      late http.Request captured;
      final service = _serviceReturning(
        {'items': [], 'total': 0},
        capture: (r) => captured = r,
      );

      await service.fetchNearbyBanks(latitude: 30.3255, longitude: 78.0436);

      expect(captured.url.queryParameters['radius_km'], '40.0');
    });

    test('reports a capped result so the screen can say so', () async {
      final service = _serviceReturning({
        'items': [_bankJson()],
        'total': 1,
        'discovered': 1041,
        'capped': true,
      });

      final result = await service.fetchNearbyBanks(
        latitude: 28.6304,
        longitude: 77.2177,
      );

      expect(result.capped, isTrue);
      expect(result.discovered, 1041);
      expect(result.items, hasLength(1));
    });

    test('an older backend without the cap fields still parses', () async {
      final service = _serviceReturning({
        'items': [_bankJson(), _bankJson(osmId: 'node/2')],
        'total': 2,
      });

      final result = await service.fetchNearbyBanks(
        latitude: 30.3,
        longitude: 78.0,
      );

      expect(result.capped, isFalse);
      // Falls back to what was actually returned rather than claiming more.
      expect(result.discovered, 2);
    });
  });

  group('marker dataset', () {
    final banks = [
      NearbyBank.fromJson(_bankJson(osmId: 'node/1', name: 'ICICI Bank')),
      NearbyBank.fromJson(_bankJson(osmId: 'node/2', name: 'Canara Bank')),
    ];
    final partners = [
      RecommendedPartner.fromJson(_partnerJson(id: 2)),
      RecommendedPartner.fromJson(_partnerJson(id: 3)),
    ];

    test('builds one marker per real coordinate, plus the user', () {
      final markers = BankMapMarker.build(
        userLatitude: 30.3255,
        userLongitude: 78.0436,
        banks: banks,
        partners: partners,
      );

      expect(markers, hasLength(5));
      expect(
        markers.where((m) => m.kind == MapMarkerKind.user).length,
        1,
      );
      expect(
        markers.where((m) => m.kind == MapMarkerKind.realBank).length,
        2,
      );
      expect(
        markers.where((m) => m.kind == MapMarkerKind.registeredPartner).length,
        2,
      );
    });

    test('marker coordinates come from the data, never hardcoded', () {
      final markers = BankMapMarker.build(
        userLatitude: 30.3255,
        userLongitude: 78.0436,
        banks: banks,
        partners: partners,
      );
      final bankMarker = markers.firstWhere((m) => m.id == 'node/1');
      final partnerMarker = markers.firstWhere((m) => m.id == 'partner-2');

      expect(bankMarker.latitude, banks.first.latitude);
      expect(bankMarker.longitude, banks.first.longitude);
      expect(partnerMarker.latitude, partners.first.latitude);
      expect(partnerMarker.longitude, partners.first.longitude);
    });

    test('bank and partner ids cannot collide', () {
      // An OSM id is "node/2" and a partner id is 2; namespacing keeps the
      // two datasets addressable without ambiguity.
      final markers = BankMapMarker.build(
        userLatitude: 30.3255,
        userLongitude: 78.0436,
        banks: banks,
        partners: partners,
      );

      expect(markers.map((m) => m.id).toSet(), hasLength(markers.length));
      expect(markers.map((m) => m.id), contains('partner-2'));
      expect(markers.map((m) => m.id), contains('node/2'));
    });

    test('no user marker without coordinates', () {
      final markers = BankMapMarker.build(
        userLatitude: null,
        userLongitude: null,
        banks: banks,
        partners: partners,
      );

      expect(markers.any((m) => m.kind == MapMarkerKind.user), isFalse);
      expect(markers, hasLength(4));
    });

    test('an empty screen produces only the user marker', () {
      final markers = BankMapMarker.build(
        userLatitude: 30.3255,
        userLongitude: 78.0436,
        banks: const [],
        partners: const [],
      );

      expect(markers, hasLength(1));
      expect(markers.single.kind, MapMarkerKind.user);
    });
  });
}

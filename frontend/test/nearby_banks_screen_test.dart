import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/match_candidate.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/scheme_matching/nearby_banks_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _candidateJson() => {
  'scheme': {
    'id': 6,
    'scheme_name': 'Demo Enterprise Business Boost',
    'category': {'category_name': 'OBC'},
    'max_loan_limit': '2000000.00',
    'interest_rate': '7.2500',
    'moratorium_months': 9,
  },
  'eligibility': {'eligible': true, 'reasons': const []},
  'requested_amount': '250000.00',
  'financial': {
    'principal': '250000.00',
    'annual_interest_rate': '7.2500',
    'tenure_months': 60,
    'emi': '4979.84',
    'total_repayment': '298790.40',
    'total_interest': '48790.40',
  },
  'partners': [
    {
      'id': 2,
      'bank_name': 'Prototype Livelihood Bank',
      'branch_code': 'DEMO-DEL-002',
      'latitude': 30.3260,
      'longitude': 78.0440,
      'distance_km': 0.169,
      'quota_remaining': '5000000.00',
      'npa_percentage': '2.4000',
      'health_score': 0.88499,
    },
  ],
  'partner_message': 'ok',
  'ml': null,
};

Map<String, dynamic> _bankJson({
  String osmId = 'node/1',
  String name = 'State Bank of India',
  Object? address,
}) => {
  'osm_id': osmId,
  'name': name,
  'latitude': 30.3255,
  'longitude': 78.0436,
  'distance_km': 0.09,
  'address': address,
};

class _Recorder {
  final List<http.Request> requests = [];

  List<String> get paths => requests.map((r) => r.url.path).toList();
}

/// Pumps the screen with a signed-in provider whose stored profile does — or
/// does not — carry coordinates.
Future<_Recorder> _pump(
  WidgetTester tester, {
  required FutureOr<http.Response> Function(http.Request) handler,
  bool withCoordinates = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // Untranslated keys render far wider than the real strings, so the page
  // reports layout overflows. These tests assert what is requested and what
  // is shown, not how the page lays out.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  final recorder = _Recorder();
  final client = MockClient((request) async {
    recorder.requests.add(request);
    if (request.url.path == '/api/users/me') return _profile(withCoordinates);
    return handler(request);
  });

  SharedPreferences.setMockInitialValues({'access_token': 'token-abc'});
  final auth = AuthProvider(authService: AuthService(client: client));
  await auth.loadStoredToken();
  // Seed the profile through the real GET /api/users/me path rather than a
  // test-only setter, so the screen reads coordinates exactly as it does in
  // production. These requests are recorded before the screen is pumped.
  await auth.refreshUser();
  recorder.requests.clear();

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: NearbyBanksScreen(
          candidate: MatchCandidate.fromJson(_candidateJson()),
          apiService: ApiService(client: client),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return recorder;
}

/// The applicant's stored profile, with or without GPS coordinates.
http.Response _profile(bool withCoordinates) => http.Response(
  jsonEncode({
    'id': 39,
    'full_name': 'Demo Applicant',
    'phone': '9880000901',
    'profile_complete': true,
    'latitude': withCoordinates ? 30.3255 : null,
    'longitude': withCoordinates ? 78.0436 : null,
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _banks(
  List<Map<String, dynamic>> items, {
  int? discovered,
  bool capped = false,
}) => http.Response(
  jsonEncode({
    'items': items,
    'total': items.length,
    'discovered': discovered ?? items.length,
    'capped': capped,
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('coordinates gate discovery', () {
    testWidgets('stored coordinates trigger exactly one discovery call', (
      tester,
    ) async {
      final recorder = await _pump(
        tester,
        handler: (_) => _banks([_bankJson()]),
      );

      expect(recorder.paths, ['/api/nearby-banks']);
      final query = recorder.requests.single.url.queryParameters;
      expect(query['latitude'], '30.3255');
      expect(query['longitude'], '78.0436');
      // Sent explicitly by the screen, not inherited from a backend default.
      expect(query['radius_km'], '40.0');
    });

    testWidgets('a capped result says how many of how many', (tester) async {
      await _pump(
        tester,
        handler: (_) => _banks(
          [_bankJson(name: 'Nearest Bank')],
          discovered: 1041,
          capped: true,
        ),
      );

      // The nearest 50 must not read as the whole neighbourhood.
      expect(find.textContaining('banks_capped_note'), findsOneWidget);
    });

    testWidgets('an uncapped result shows no such note', (tester) async {
      await _pump(tester, handler: (_) => _banks([_bankJson()]));

      expect(find.textContaining('banks_capped_note'), findsNothing);
    });

    testWidgets('no coordinates means no request at all', (tester) async {
      // Guessing a centre would search another city and quietly present the
      // result as the applicant's own neighbourhood.
      final recorder = await _pump(
        tester,
        handler: (_) => _banks([_bankJson()]),
        withCoordinates: false,
      );

      expect(recorder.requests, isEmpty);
    });

    testWidgets('registered partners still render without coordinates', (
      tester,
    ) async {
      await _pump(
        tester,
        handler: (_) => _banks([]),
        withCoordinates: false,
      );

      expect(find.text('Prototype Livelihood Bank'), findsOneWidget);
      expect(find.text('DEMO-DEL-002'), findsOneWidget);
    });
  });

  group('real banks versus registered partners', () {
    testWidgets('a real bank shows no Partner Score and no quota', (
      tester,
    ) async {
      await _pump(
        tester,
        handler: (_) => _banks([_bankJson(name: 'Canara Bank')]),
      );

      final bankCard = find.ancestor(
        of: find.text('Canara Bank'),
        matching: find.byType(Container),
      );
      expect(bankCard, findsWidgets);
      // The score and quota strings belong to the partner card only. Neither
      // appears anywhere beneath the real bank's name.
      expect(
        find.descendant(
          of: bankCard.first,
          matching: find.textContaining('partner_score_label'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: bankCard.first,
          matching: find.textContaining('quota_available_amount'),
        ),
        findsNothing,
      );
    });

    testWidgets('a real bank offers no Select Center', (tester) async {
      await _pump(
        tester,
        handler: (_) => _banks([_bankJson(name: 'Canara Bank')]),
      );

      // One partner is on screen, so exactly one Select Center control exists.
      expect(find.text('nearby_banks.select_center_button'), findsOneWidget);
      final bankCard = find
          .ancestor(
            of: find.text('Canara Bank'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        find.descendant(of: bankCard, matching: find.byType(OutlinedButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: bankCard, matching: find.byType(ElevatedButton)),
        findsNothing,
      );
    });

    testWidgets('registered partners keep score, quota and select', (
      tester,
    ) async {
      await _pump(tester, handler: (_) => _banks([_bankJson()]));

      expect(find.textContaining('partner_score_label'), findsOneWidget);
      expect(find.textContaining('quota_available_amount'), findsOneWidget);
      expect(find.text('nearby_banks.select_center_button'), findsOneWidget);
    });

    testWidgets('selecting a centre sends nothing to the backend', (
      tester,
    ) async {
      final recorder = await _pump(
        tester,
        handler: (_) => _banks([_bankJson()]),
      );
      final before = recorder.requests.length;

      await tester.tap(find.text('nearby_banks.select_center_button'));
      await tester.pumpAndSettle();

      expect(recorder.requests, hasLength(before));
      expect(find.text('nearby_banks.selected_badge'), findsOneWidget);
    });

    testWidgets('an address renders only when OpenStreetMap has one', (
      tester,
    ) async {
      await _pump(
        tester,
        handler: (_) => _banks([
          _bankJson(osmId: 'node/1', name: 'Nainital Bank', address: '12, Rajpur Road'),
          _bankJson(osmId: 'node/2', name: 'Bank Without Address'),
        ]),
      );

      expect(find.text('12, Rajpur Road'), findsOneWidget);
      expect(find.text('Bank Without Address'), findsOneWidget);
    });
  });

  group('discovery states', () {
    testWidgets('a failure shows a retry and keeps the partners', (
      tester,
    ) async {
      final recorder = await _pump(
        tester,
        handler: (_) => http.Response('{"detail":"unavailable"}', 503),
      );

      expect(find.text('nearby_banks.banks_retry'), findsOneWidget);
      // The whole point of loading the two independently.
      expect(find.text('Prototype Livelihood Bank'), findsOneWidget);
      expect(find.text('nearby_banks.select_center_button'), findsOneWidget);
      expect(recorder.paths, ['/api/nearby-banks']);
    });

    testWidgets('retry issues a second discovery request', (tester) async {
      var attempt = 0;
      final recorder = await _pump(
        tester,
        handler: (_) {
          attempt += 1;
          return attempt == 1
              ? http.Response('{"detail":"unavailable"}', 503)
              : _banks([_bankJson(name: 'Recovered Bank')]);
        },
      );

      await tester.tap(find.text('nearby_banks.banks_retry'));
      await tester.pumpAndSettle();

      expect(recorder.paths, ['/api/nearby-banks', '/api/nearby-banks']);
      expect(find.text('Recovered Bank'), findsOneWidget);
      expect(find.text('nearby_banks.banks_retry'), findsNothing);
    });

    testWidgets('an empty result says so honestly', (tester) async {
      await _pump(tester, handler: (_) => _banks([]));

      expect(find.text('nearby_banks.banks_empty'), findsOneWidget);
      expect(find.text('nearby_banks.banks_retry'), findsNothing);
    });

    testWidgets('a spinner shows while discovery is in flight', (tester) async {
      final gate = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path == '/api/users/me') return _profile(true);
        return gate.future;
      });
      SharedPreferences.setMockInitialValues({'access_token': 'token-abc'});
      final auth = AuthProvider(authService: AuthService(client: client));
      await auth.loadStoredToken();
      await auth.refreshUser();
      await tester.binding.setSurfaceSize(const Size(1400, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        previousOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            home: NearbyBanksScreen(
              candidate: MatchCandidate.fromJson(_candidateJson()),
              apiService: ApiService(client: client),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('nearby_banks.banks_loading'), findsOneWidget);
      // Partners are already on screen; they never waited for discovery.
      expect(find.text('Prototype Livelihood Bank'), findsOneWidget);

      gate.complete(_banks([]));
      await tester.pumpAndSettle();
      expect(find.text('nearby_banks.banks_loading'), findsNothing);
    });
  });

  group('drafts stay partner-only', () {
    testWidgets('a draft saved after viewing banks carries no OSM id', (
      tester,
    ) async {
      http.Request? draftRequest;
      final recorder = await _pump(
        tester,
        handler: (request) {
          if (request.url.path == '/api/applications') {
            draftRequest = request;
            return http.Response(
              jsonEncode({
                'id': 42,
                'user_id': 39,
                'scheme_id': 6,
                'scheme_name': 'Demo Enterprise Business Boost',
                'partner_id': null,
                'requested_amount': '250000.00',
                'application_date': '2026-09-05T10:00:00Z',
                'status': 'draft',
                'created_at': '2026-09-05T10:00:00Z',
                'updated_at': '2026-09-05T10:00:00Z',
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return _banks([_bankJson(name: 'Canara Bank')]);
        },
      );

      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(recorder.paths, contains('/api/applications'));
      final body = jsonDecode(draftRequest!.body) as Map<String, dynamic>;
      expect(body['status'], 'draft');
      // No centre chosen, so no partner claimed -- and never an OSM id.
      expect(body.containsKey('partner_id'), isFalse);
      expect(jsonEncode(body), isNot(contains('node/')));
    });

    testWidgets('selecting a partner sends that partner id, not a bank', (
      tester,
    ) async {
      http.Request? draftRequest;
      await _pump(
        tester,
        handler: (request) {
          if (request.url.path == '/api/applications') {
            draftRequest = request;
            return http.Response(
              jsonEncode({
                'id': 43,
                'user_id': 39,
                'scheme_id': 6,
                'scheme_name': 'Demo Enterprise Business Boost',
                'partner_id': 2,
                'requested_amount': '250000.00',
                'application_date': '2026-09-05T10:00:00Z',
                'status': 'draft',
                'created_at': '2026-09-05T10:00:00Z',
                'updated_at': '2026-09-05T10:00:00Z',
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return _banks([_bankJson(name: 'Canara Bank')]);
        },
      );

      await tester.tap(find.text('nearby_banks.select_center_button'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      final body = jsonDecode(draftRequest!.body) as Map<String, dynamic>;
      expect(body['partner_id'], 2);
      expect(body['partner_id'], isA<int>());
    });
  });
}

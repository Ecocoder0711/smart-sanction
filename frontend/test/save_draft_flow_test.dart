import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/match_candidate.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/dashboard/dashboard_screen.dart';
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
      'latitude': 28.615,
      'longitude': 77.2102,
      'distance_km': 0.169,
      'quota_remaining': '5000000.00',
      'npa_percentage': '2.4000',
      'health_score': 0.88499,
    },
  ],
  'partner_message': 'ok',
  'ml': null,
};

/// Records every outgoing request so a test can prove what was — and was not —
/// sent to the backend.
class _Recorder {
  final List<http.Request> requests = [];

  List<String> get paths => requests.map((r) => r.url.path).toList();
}

class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

/// Pumps Nearby Banks with a signed-in provider and a mocked API.
Future<(_Recorder, _RecordingObserver)> _pump(
  WidgetTester tester, {
  required http.Response Function(http.Request) handler,
  bool signedIn = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // With no translations loaded, raw keys render far wider than the real
  // strings and the screen reports layout overflows. These tests assert what
  // is sent to the backend and where the applicant ends up, not how the page
  // lays out, so overflow reports are collected instead of failing them.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  final recorder = _Recorder();
  final observer = _RecordingObserver();
  final client = MockClient((request) async {
    recorder.requests.add(request);
    return handler(request);
  });

  final auth = AuthProvider(authService: AuthService(client: client));
  if (signedIn) {
    SharedPreferences.setMockInitialValues({'access_token': 'token-abc'});
    await auth.loadStoredToken();
  }

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        navigatorObservers: [observer],
        home: NearbyBanksScreen(
          candidate: MatchCandidate.fromJson(_candidateJson()),
          apiService: ApiService(client: client),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (recorder, observer);
}

http.Response _created() => http.Response(
  jsonEncode({
    'id': 42,
    'user_id': 39,
    'user_name': 'Draft Owner',
    'scheme_id': 6,
    'scheme_name': 'Demo Enterprise Business Boost',
    'partner_id': null,
    'partner_name': null,
    'requested_amount': '250000.00',
    'application_date': '2026-09-05T10:00:00Z',
    'status': 'draft',
    'created_at': '2026-09-05T10:00:00Z',
    'updated_at': '2026-09-05T10:00:00Z',
  }),
  201,
  headers: {'content-type': 'application/json'},
);

/// "Save Draft" is the only full-width button below the partner list.
Finder _saveDraftButton() => find.byType(ElevatedButton).last;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Select Center sends nothing to the backend', (tester) async {
    final (recorder, observer) = await _pump(
      tester,
      handler: (_) => _created(),
    );

    // Selecting a centre is local state only. It must never create or submit
    // an application.
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();

    expect(recorder.requests, isEmpty);
    expect(observer.pushed, isEmpty);
  });

  testWidgets('Save as Draft posts a draft and then navigates', (tester) async {
    final (recorder, observer) = await _pump(
      tester,
      handler: (_) => _created(),
    );

    await tester.tap(_saveDraftButton());
    await tester.pumpAndSettle();

    expect(recorder.paths, ['/api/applications']);
    final body = jsonDecode(recorder.requests.single.body) as Map<String, dynamic>;
    expect(body['status'], 'draft');
    expect(body['scheme_id'], 6);
    expect(body['requested_amount'], 250000.0);
    // No centre was selected, so none is claimed.
    expect(body.containsKey('partner_id'), isFalse);
    expect(observer.pushed, hasLength(1));
  });

  testWidgets('a selected centre is saved with the draft', (tester) async {
    final (recorder, _) = await _pump(tester, handler: (_) => _created());

    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    await tester.tap(_saveDraftButton());
    await tester.pumpAndSettle();

    final body = jsonDecode(recorder.requests.single.body) as Map<String, dynamic>;
    expect(body['partner_id'], 2);
    expect(body['status'], 'draft');
  });

  testWidgets('navigation happens only after a successful save', (
    tester,
  ) async {
    final (recorder, observer) = await _pump(
      tester,
      handler: (_) => http.Response('{"detail":"boom"}', 500),
    );

    await tester.tap(_saveDraftButton());
    await tester.pumpAndSettle();

    // The request was attempted, and the applicant stays put.
    expect(recorder.paths, ['/api/applications']);
    expect(observer.pushed, isEmpty);
    expect(find.byType(NearbyBanksScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('a validation failure also keeps the applicant on screen', (
    tester,
  ) async {
    final (_, observer) = await _pump(
      tester,
      handler: (_) => http.Response(
        jsonEncode({'detail': 'partner_id is required unless status is draft'}),
        422,
      ),
    );

    await tester.tap(_saveDraftButton());
    await tester.pumpAndSettle();

    expect(observer.pushed, isEmpty);
    expect(find.byType(NearbyBanksScreen), findsOneWidget);
  });

  testWidgets('the button is disabled while a save is in flight', (
    tester,
  ) async {
    // A real request takes time; the mock must too, or there is no in-flight
    // frame to observe.
    final gate = Completer<void>();
    final recorder = _Recorder();
    await tester.binding.setSurfaceSize(const Size(1600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    final client = MockClient((request) async {
      recorder.requests.add(request);
      await gate.future;
      return _created();
    });
    SharedPreferences.setMockInitialValues({'access_token': 'token-abc'});
    final auth = AuthProvider(authService: AuthService(client: client));
    await auth.loadStoredToken();

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

    await tester.tap(_saveDraftButton());
    await tester.pump();

    // Still saving: a second tap cannot start another draft.
    expect(
      tester.widget<ElevatedButton>(_saveDraftButton()).onPressed,
      isNull,
      reason: 'disabled while saving',
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(recorder.requests, hasLength(1));
  });
}

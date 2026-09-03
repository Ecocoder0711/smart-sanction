import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/registration_draft_provider.dart';
import 'package:frontend/screens/dashboard/dashboard_screen.dart';
import 'package:frontend/screens/wizard/eligibility_screen.dart';
import 'package:frontend/screens/wizard/location_screen.dart';
import 'package:frontend/screens/wizard/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A login response carrying the whole UserResponse, as the backend sends it.
///
/// Routing reads profile_complete, latitude and longitude from exactly this
/// payload, so the fixtures mirror the four states a real account can be in.
Map<String, dynamic> _loginBody({
  required bool profileComplete,
  double? latitude,
  double? longitude,
}) => {
  'access_token': 'token-abc',
  'token_type': 'bearer',
  'user': {
    'id': 39,
    'full_name': 'Returning Applicant',
    'phone': '9880000001',
    'annual_income': profileComplete ? '400000.00' : null,
    'category': profileComplete ? 'OBC' : null,
    'gender': profileComplete ? 'FEMALE' : null,
    'state': profileComplete ? 'Haryana' : null,
    'district': profileComplete ? 'Kaithal' : null,
    'latitude': latitude,
    'longitude': longitude,
    'profile_complete': profileComplete,
    'created_at': '2026-09-03T05:45:44Z',
    'updated_at': '2026-09-03T05:45:44Z',
  },
};

/// Records navigation so the destination can be identified without building
/// it.
///
/// Both callbacks matter: pushReplacement reports through didReplace, while
/// pushAndRemoveUntil reports through didPush plus didRemove. Watching only
/// one would silently miss half the routing.
class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];
  final List<Route<dynamic>> replaced = [];
  final List<Route<dynamic>> removed = [];

  /// Every route this screen navigated to, however it got there.
  List<Route<dynamic>> get navigated => [...pushed, ...replaced];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The initial home route arrives with no previous route; ignore it.
    if (previousRoute != null) pushed.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replaced.add(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removed.add(route);
    super.didRemove(route, previousRoute);
  }
}

Future<_RecordingObserver> _pumpAndLogin(
  WidgetTester tester, {
  required http.Response response,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // The destination screens really do build once routing happens, and with no
  // translations loaded their raw keys render far wider than the real strings,
  // so they report layout overflows. Those belong to the destination, not to
  // the routing under test, so they are collected rather than failing the
  // test -- and asserted afterwards to make sure none came from LoginScreen.
  final layoutErrors = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed')) {
      layoutErrors.add(text);
      return;
    }
    previousOnError?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = previousOnError;
    expect(
      layoutErrors.where((e) => e.contains('login_screen.dart')),
      isEmpty,
      reason: 'LoginScreen itself must not overflow',
    );
  });

  final observer = _RecordingObserver();
  final auth = AuthProvider(
    authService: AuthService(client: MockClient((_) async => response)),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => RegistrationDraftProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        navigatorObservers: [observer],
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pump();

  await tester.enterText(find.byType(TextFormField).first, '9880000001');
  await tester.enterText(find.byType(TextFormField).last, 'CorrectHorse123!');
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();

  return observer;
}

http.Response _ok(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

/// Identifies the pushed destination without building it: the destination
/// screens need their own providers and localisation.
Widget _destination(Route<dynamic> route, WidgetTester tester) {
  final materialRoute = route as MaterialPageRoute;
  return materialRoute.builder(tester.element(find.byType(MaterialApp)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('returning-user routing', () {
    testWidgets('incomplete profile goes to Eligibility', (tester) async {
      final observer = await _pumpAndLogin(
        tester,
        response: _ok(_loginBody(profileComplete: false)),
      );

      expect(observer.navigated, hasLength(1));
      expect(_destination(observer.navigated.single, tester),
          isA<EligibilityScreen>());
    });

    testWidgets('complete profile without location goes to Location', (
      tester,
    ) async {
      final observer = await _pumpAndLogin(
        tester,
        response: _ok(_loginBody(profileComplete: true)),
      );

      expect(observer.navigated, hasLength(1));
      expect(_destination(observer.navigated.single, tester),
          isA<LocationScreen>());
    });

    testWidgets('only latitude present still goes to Location', (tester) async {
      // Half a coordinate pair cannot locate anyone; the backend treats it as
      // no location at all.
      final observer = await _pumpAndLogin(
        tester,
        response: _ok(_loginBody(profileComplete: true, latitude: 30.409579)),
      );

      expect(_destination(observer.navigated.single, tester),
          isA<LocationScreen>());
    });

    testWidgets('only longitude present still goes to Location', (
      tester,
    ) async {
      final observer = await _pumpAndLogin(
        tester,
        response: _ok(_loginBody(profileComplete: true, longitude: 77.967221)),
      );

      expect(_destination(observer.navigated.single, tester),
          isA<LocationScreen>());
    });

    testWidgets('complete profile with coordinates goes to Dashboard', (
      tester,
    ) async {
      final observer = await _pumpAndLogin(
        tester,
        response: _ok(
          _loginBody(
            profileComplete: true,
            latitude: 30.409579,
            longitude: 77.967221,
          ),
        ),
      );

      expect(observer.navigated, hasLength(1));
      expect(_destination(observer.navigated.single, tester),
          isA<DashboardScreen>());
      // pushAndRemoveUntil: Login is taken off the stack, so Back cannot
      // return to it.
      expect(observer.removed, isNotEmpty);
    });
  });

  group('failure paths', () {
    testWidgets('bad credentials navigate nowhere', (tester) async {
      final observer = await _pumpAndLogin(
        tester,
        response: http.Response(
          jsonEncode({'detail': 'Invalid phone or password'}),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(observer.navigated, isEmpty);
      expect(observer.removed, isEmpty);
    });

    testWidgets('a server error navigates nowhere', (tester) async {
      final observer = await _pumpAndLogin(
        tester,
        response: http.Response('{"detail":"boom"}', 500),
      );

      expect(observer.navigated, isEmpty);
    });
  });

  group('registration is unchanged', () {
    testWidgets('a fresh account is always incomplete, so it starts at '
        'Eligibility', (tester) async {
      // registerMinimal sends only credentials, so the account it creates can
      // only ever come back profile_complete=false -- which is exactly the
      // first branch above. Register therefore needs no conditional routing.
      final observer = await _pumpAndLogin(
        tester,
        response: _ok(_loginBody(profileComplete: false)),
      );

      expect(_destination(observer.navigated.single, tester),
          isA<EligibilityScreen>());
    });
  });
}

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/scheme.dart';
import 'package:frontend/screens/dashboard/category_list_screen.dart';
import 'package:frontend/screens/scheme_matching/scheme_intake_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors a real `GET /api/schemes` item.
Map<String, dynamic> _schemeJson({
  int id = 6,
  String name = 'Demo Enterprise Business Boost',
  String category = 'OBC',
  String maxLoanLimit = '2000000.00',
  String interestRate = '7.2500',
}) => {
  'id': id,
  'scheme_name': name,
  'category_id': 4,
  'category': {'id': 4, 'category_name': category},
  'gender_eligibility': 'ANY',
  'max_loan_limit': maxLoanLimit,
  'interest_rate': interestRate,
  'moratorium_months': 9,
  'max_income_limit': '900000.00',
  'is_active': true,
};

/// The screen builds its own ApiService, so the HTTP layer is swapped instead.
/// `http` resolves the client through this override in tests.
/// Records pushed routes so navigation can be asserted without building the
/// destination screen.
class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The initial home route arrives with no previous route; ignore it.
    if (previousRoute != null) pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

Widget _screenWith(
  Future<http.Response> Function(http.Request) handler, {
  String title = 'Explore Schemes',
  NavigatorObserver? observer,
}) {
  return Provider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      navigatorObservers: [?observer],
      home: CategoryListScreen(
        title: title,
        apiService: ApiService(client: MockClient(handler)),
      ),
    ),
  );
}

final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('scheme data mapping', () {
    test('parses every field the list card renders', () {
      final scheme = Scheme.fromJson(_schemeJson());

      expect(scheme.name, 'Demo Enterprise Business Boost');
      expect(scheme.category, 'OBC');
      expect(scheme.interestRate, 7.25);
      expect(scheme.maxLoanLimit, 2000000.00);
    });

    test('the whole seeded catalogue maps cleanly', () async {
      // Categories and rates as returned by the live backend.
      final rows = [
        _schemeJson(id: 5, name: 'Demo Artisan Opportunity Fund',
            category: 'OBC', interestRate: '5.2500', maxLoanLimit: '500000.00'),
        _schemeJson(id: 1, name: 'Demo Community Enterprise Starter',
            category: 'SC', interestRate: '4.5000', maxLoanLimit: '300000.00'),
        _schemeJson(id: 11, name: 'Demo Inclusive Livelihood Support',
            category: 'ANY', interestRate: '4.7500', maxLoanLimit: '400000.00'),
        _schemeJson(id: 8, name: 'Demo Innovation Venture Credit',
            category: 'GENERAL', interestRate: '9.5000',
            maxLoanLimit: '3000000.00'),
        _schemeJson(id: 3, name: 'Demo Tribal Livelihood Microcredit',
            category: 'ST', interestRate: '3.7500', maxLoanLimit: '200000.00'),
      ];
      final service = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'items': rows, 'total': rows.length}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final schemes = await service.fetchSchemes();

      expect(schemes, hasLength(5));
      expect(
        schemes.map((s) => s.category).toSet(),
        {'OBC', 'SC', 'ANY', 'GENERAL', 'ST'},
      );
      // Backend ordering is preserved; the screen does not re-sort.
      expect(schemes.map((s) => s.id).toList(), [5, 1, 11, 8, 3]);
    });
  });

  group('formatting', () {
    test('max loan limit renders with Indian grouping', () {
      expect(_rupees.format(2000000.0), '₹20,00,000');
      expect(_rupees.format(300000.0), '₹3,00,000');
      expect(_rupees.format(3000000.0), '₹30,00,000');
    });

    test('rate renders as the dashboard card does', () {
      // Matches the existing '${scheme.interestRate}% p.a.' treatment; this
      // task deliberately does not refactor rate formatting.
      expect('${Scheme.fromJson(_schemeJson()).interestRate}% p.a.',
          '7.25% p.a.');
      expect(
        '${Scheme.fromJson(_schemeJson(interestRate: "4.5000")).interestRate}'
        '% p.a.',
        '4.5% p.a.',
      );
    });
  });

  group('CategoryListScreen widget', () {
    testWidgets('shows a spinner while loading, then the schemes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screenWith(
          (_) async => http.Response(
            jsonEncode({'items': [_schemeJson()], 'total': 1}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      // First frame: request in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps the app bar title it was opened with', (tester) async {
      await tester.pumpWidget(
        _screenWith(
          (_) async => http.Response(
            jsonEncode({'items': const [], 'total': 0}),
            200,
            headers: {'content-type': 'application/json'},
          ),
          title: 'Explore Schemes',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explore Schemes'), findsOneWidget);
      // The obsolete placeholder must be gone.
      expect(find.text('List UI Pending'), findsNothing);
    });

    testWidgets('an empty catalogue shows a notice, not an error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _screenWith(
          (_) async => http.Response(
            jsonEncode({'items': const [], 'total': 0}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
      // Empty state offers no retry: nothing failed.
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('a failure shows a retry that re-requests', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _screenWith((_) async {
          calls++;
          return calls == 1
              ? http.Response('{"detail":"boom"}', 500)
              : http.Response(
                  jsonEncode({'items': [_schemeJson()], 'total': 1}),
                  200,
                  headers: {'content-type': 'application/json'},
                );
        }),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      final retry = find.byType(TextButton);
      expect(retry, findsOneWidget);

      await tester.tap(retry);
      await tester.pumpAndSettle();

      // Retry re-issued the request and the list replaced the notice.
      expect(calls, 2);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('tapping a scheme pushes the Scheme Intake route', (
      tester,
    ) async {
      // Asserts the route this screen pushes, without building the
      // destination: SchemeIntakeScreen needs EasyLocalization and both
      // providers, and its own layout is out of scope for this task.
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        _screenWith(
          (_) async => http.Response(
            jsonEncode({'items': [_schemeJson()], 'total': 1}),
            200,
            headers: {'content-type': 'application/json'},
          ),
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();

      expect(observer.pushedRoutes, isEmpty);
      expect(find.byType(InkWell), findsWidgets);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      // Exactly one route pushed, and it builds SchemeIntakeScreen. Nothing
      // financial is passed: intake collects the requested amount itself.
      expect(observer.pushedRoutes, hasLength(1));
      final pushed = observer.pushedRoutes.single;
      expect(pushed, isA<MaterialPageRoute<dynamic>>());
      final built = (pushed as MaterialPageRoute).builder(
        tester.element(find.byType(CategoryListScreen)),
      );
      expect(built, isA<SchemeIntakeScreen>());
    });
  });
}

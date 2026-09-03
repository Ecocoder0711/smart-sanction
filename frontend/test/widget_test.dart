import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/registration_draft_provider.dart';
import 'package:frontend/screens/wizard/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replaces the Flutter counter scaffold that shipped with `flutter create`.
///
/// That test asserted on a counter UI this app has never had, so it failed
/// from the first commit onwards and told us nothing. These check what the app
/// actually does at startup.
///
/// Assertions anchor on [MaterialApp] rather than the routed screen:
/// EasyLocalization resolves its delegate asynchronously, and on the second
/// and later tests in one file the routed child is not rebuilt within the
/// pumped frames. MaterialApp is the direct child of the MultiProvider, so its
/// element still has both providers above it.
Future<void> _pumpApp(WidgetTester tester) async {
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
  await tester.pump();
}

BuildContext _appContext(WidgetTester tester) =>
    tester.element(find.byType(MaterialApp));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('app boots with the wizard welcome screen as its entry point', (
    tester,
  ) async {
    await _pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.home, isA<WelcomeScreen>());
    expect(app.title, 'SMART-SANCTION');
  });

  testWidgets('English and Hindi are both offered', (tester) async {
    await _pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.supportedLocales.map((l) => l.languageCode),
      containsAll(<String>['en', 'hi']),
    );
  });

  testWidgets('both providers are available to the widget tree', (
    tester,
  ) async {
    await _pumpApp(tester);
    final context = _appContext(tester);

    // Every wired screen reads one or both of these. A missing provider fails
    // at runtime, not compile time, so it is worth asserting.
    expect(
      () => Provider.of<AuthProvider>(context, listen: false),
      returnsNormally,
    );
    expect(
      () => Provider.of<RegistrationDraftProvider>(context, listen: false),
      returnsNormally,
    );
  });

  testWidgets('a fresh launch is signed out and claims no profile', (
    tester,
  ) async {
    await _pumpApp(tester);

    final auth = Provider.of<AuthProvider>(_appContext(tester), listen: false);

    // No stored token in a clean install, so no name is shown and matching
    // stays gated behind an incomplete profile.
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(auth.isProfileComplete, isFalse);
  });

  testWidgets('the registration draft starts empty', (tester) async {
    await _pumpApp(tester);

    final draft = Provider.of<RegistrationDraftProvider>(
      _appContext(tester),
      listen: false,
    );

    expect(draft.hasRegistrationDetails, isFalse);
    expect(draft.hasProfileDetails, isFalse);
    expect(draft.hasCoordinates, isFalse);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/registration_draft_provider.dart';
import 'package:frontend/screens/wizard/login_screen.dart';
import 'package:frontend/screens/wizard/register_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps one wizard screen with the providers it reads.
///
/// A generous surface keeps these tests about the eye toggle rather than about
/// layout: untranslated keys render much wider than the real strings, which
/// would otherwise overflow the default 800x600 test window.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RegistrationDraftProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

/// The password field is the only one carrying the eye button.
EditableText _passwordField(WidgetTester tester) {
  final editables = tester.widgetList<EditableText>(find.byType(EditableText));
  return editables.firstWhere((e) => e.obscureText || e.obscuringCharacter == '•',
      orElse: () => editables.last);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final entry in <String, Widget>{
    'LoginScreen': const LoginScreen(),
    'RegisterScreen': const RegisterScreen(),
  }.entries) {
    group(entry.key, () {
      testWidgets('password starts hidden with a show icon', (tester) async {
        await _pump(tester, entry.value);

        // Default must stay hidden.
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsNothing);

        final obscured = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .where((e) => e.obscureText);
        expect(obscured, hasLength(1));
      });

      testWidgets('tapping the eye reveals the password', (tester) async {
        await _pump(tester, entry.value);

        await tester.tap(find.byIcon(Icons.visibility_off));
        await tester.pump();

        expect(find.byIcon(Icons.visibility), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off), findsNothing);
        expect(
          tester
              .widgetList<EditableText>(find.byType(EditableText))
              .where((e) => e.obscureText),
          isEmpty,
        );
      });

      testWidgets('tapping again hides it, so the toggle is reversible', (
        tester,
      ) async {
        await _pump(tester, entry.value);

        await tester.tap(find.byIcon(Icons.visibility_off));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pump();

        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(
          tester
              .widgetList<EditableText>(find.byType(EditableText))
              .where((e) => e.obscureText),
          hasLength(1),
        );
      });

      testWidgets('toggling preserves the typed text', (tester) async {
        await _pump(tester, entry.value);
        final field = find.byWidget(_passwordField(tester));

        await tester.enterText(field, 'CorrectHorse123!');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.visibility_off));
        await tester.pump();

        // Revealing must not clear or re-validate the field.
        expect(find.text('CorrectHorse123!'), findsOneWidget);
      });

      testWidgets('the eye is the only added control', (tester) async {
        await _pump(tester, entry.value);

        // Exactly one IconButton on the screen: the eye. Nothing else was
        // introduced alongside it.
        expect(find.byType(IconButton), findsOneWidget);
      });
    });
  }
}

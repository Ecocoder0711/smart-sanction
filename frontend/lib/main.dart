import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/registration_draft_provider.dart';
import 'screens/wizard/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color deepNavyBlue = Color(0xFF0B1F3D);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emeraldGreen,
      primary: emeraldGreen,
      secondary: deepNavyBlue,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadStoredToken()),
        // Temporary holder for wizard input; no screen reads it yet.
        ChangeNotifierProvider(create: (_) => RegistrationDraftProvider()),
      ],
      child: MaterialApp(
        title: 'SMART-SANCTION',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          colorScheme: colorScheme,
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}

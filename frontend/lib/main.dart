import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const MyApp());
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
      ],
      child: MaterialApp(
        title: 'SMART-SANCTION',
        theme: ThemeData(
          colorScheme: colorScheme,
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

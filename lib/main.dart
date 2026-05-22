import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/api_key_screen.dart';

void main() {
  runApp(const HireMindApp());
}

class HireMindApp extends StatelessWidget {
  const HireMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HireMind AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56DB),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF5F7FF),
      ),
      home: const ApiKeyScreen(),
    );
  }
}

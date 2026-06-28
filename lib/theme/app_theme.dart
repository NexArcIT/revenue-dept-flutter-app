import 'package:flutter/material.dart';

class AppTheme {
  static const primaryGreen = Color(0xFF1a6b2e);
  static const darkGreen = Color(0xFF0f3d1a);
  static const deepGreen = Color(0xFF0a2810);
  static const gold = Color(0xFFd97706);
  static const amber = Color(0xFFfbbf24);
  static const bgGreen = Color(0xFFf0f7f2);
  static const lightBorder = Color(0xFFa7d4b3);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: bgGreen,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryGreen, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      );
}
